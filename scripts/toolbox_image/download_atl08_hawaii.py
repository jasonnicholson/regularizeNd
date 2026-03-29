"""
Download ICESat-2 ATL08 (Land and Vegetation Height) granules for the
Big Island of Hawaii (Mauna Kea / Mauna Loa / Kilauea).

Usage
-----
    .venv/bin/python3 scripts/download_atl08_hawaii.py

Authentication uses a Bearer token read from the GNOME Keyring.
Set it first with:
    .venv/bin/python3 scripts/setup_earthdata_credentials.py

Outputs (all under data/external/atl08_hawaii/)
------------------------------------------------
  ATL08_*.h5                  – original HDF5 granules
  hawaii_atl08_points.npz     – merged lon, lat, h_te arrays (NumPy)
"""

import os
import sys
import pathlib
import numpy as np
import h5py
import keyring
import earthaccess

# ── paths ──────────────────────────────────────────────────────────────────
REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT_DIR   = REPO_ROOT / "data" / "external" / "atl08_hawaii"
OUT_DIR.mkdir(parents=True, exist_ok=True)

_KR_SERVICE = "nasa-earthdata"
_TOKEN_KEY  = "token"
_USER_KEY   = "username"

# Big Island of Hawaii – generous margin so we catch full granule passes
BBOX       = (-156.2, 18.8, -154.6, 20.4)   # (min_lon, min_lat, max_lon, max_lat)
DATE_RANGE = ("2022-01-01", "2024-06-30")    # ~2.5 yr window → several repeat cycles
MAX_GRANULES = 25

# ATL08 beam groups
BEAMS = ["gt1l", "gt1r", "gt2l", "gt2r", "gt3l", "gt3r"]


def login() -> None:
    token    = keyring.get_password(_KR_SERVICE, _TOKEN_KEY)
    username = keyring.get_password(_KR_SERVICE, _USER_KEY)
    if not token or not username:
        raise RuntimeError(
            "No Earthdata token/username found in GNOME Keyring.\n"
            "Run first:  .venv/bin/python3 scripts/setup_earthdata_credentials.py"
        )
    print("Authenticating via Bearer token (GNOME Keyring)...")
    os.environ["EARTHDATA_USERNAME"] = username
    os.environ["EARTHDATA_TOKEN"]    = token
    earthaccess.login(strategy="environment")
    print("Authentication successful.\n")


def search_granules() -> list:
    print(f"Searching ATL08 granules: bbox={BBOX}, dates={DATE_RANGE} ...")
    results = earthaccess.search_data(
        short_name   = "ATL08",
        bounding_box = BBOX,
        temporal     = DATE_RANGE,
        count        = MAX_GRANULES,
    )
    print(f"  Found {len(results)} granule(s).\n")
    return results


def download_granules(granules: list) -> list[pathlib.Path]:
    if not granules:
        raise RuntimeError("No granules found.")
    print(f"Downloading {len(granules)} granule(s) to {OUT_DIR} ...")
    local_paths = earthaccess.download(granules, local_path=str(OUT_DIR))
    print(f"  Download complete: {len(local_paths)} file(s).\n")
    return [pathlib.Path(p) for p in local_paths]


def extract_points(h5_path: pathlib.Path) -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    """
    Read terrain height from one ATL08 HDF5 file.

    Relevant dataset path (per beam):
        /gtXy/land_segments/longitude
        /gtXy/land_segments/latitude
        /gtXy/land_segments/terrain/h_te_best_fit   (median terrain height, m above WGS84)

    The 100 m segment h_te_best_fit is the cleanest terrain-height estimate.
    Returns (lon, lat, h_te, beam_id) arrays (all valid, finite points only).
    """
    lons, lats, htes, beam_ids = [], [], [], []

    with h5py.File(h5_path, "r") as f:
        for bid, beam in enumerate(BEAMS, start=1):
            grp = f.get(f"{beam}/land_segments")
            if grp is None:
                continue
            lon = grp["longitude"][:]
            lat = grp["latitude"][:]
            # h_te_best_fit lives under terrain/ sub-group
            ter = grp.get("terrain")
            if ter is None:
                continue
            hte = ter["h_te_best_fit"][:]

            valid = (
                np.isfinite(lon) & np.isfinite(lat) & np.isfinite(hte)
                & (hte > -100) & (hte < 5000)   # sanity range for Big Island
            )
            lons.append(lon[valid])
            lats.append(lat[valid])
            htes.append(hte[valid])
            beam_ids.append(np.full(valid.sum(), bid, dtype=np.int8))

    if not lons:
        return np.array([]), np.array([]), np.array([]), np.array([], dtype=np.int8)

    return (
        np.concatenate(lons),
        np.concatenate(lats),
        np.concatenate(htes),
        np.concatenate(beam_ids),
    )


def main() -> None:
    login()
    granules = search_granules()
    h5_paths = download_granules(granules)

    print("Extracting terrain height from all granules ...")
    all_lon, all_lat, all_h, all_beam = [], [], [], []
    for p in h5_paths:
        lon, lat, h, beam = extract_points(p)
        # Clip strictly to Big Island bbox
        inside = (
            (lon >= BBOX[0]) & (lon <= BBOX[2])
            & (lat >= BBOX[1]) & (lat <= BBOX[3])
        )
        all_lon.append(lon[inside])
        all_lat.append(lat[inside])
        all_h.append(h[inside])
        all_beam.append(beam[inside])

    lon_arr  = np.concatenate(all_lon)
    lat_arr  = np.concatenate(all_lat)
    h_arr    = np.concatenate(all_h)
    beam_arr = np.concatenate(all_beam)
    print(f"  Total valid points inside bbox: {len(lon_arr):,}")

    out_npz = OUT_DIR / "hawaii_atl08_points.npz"
    np.savez_compressed(out_npz, lon=lon_arr, lat=lat_arr, h=h_arr, beam=beam_arr)
    print(f"  Saved: {out_npz}")

    # Quick summary per beam
    for b in range(1, 7):
        n = int((beam_arr == b).sum())
        print(f"    beam {b}: {n:,} pts")


if __name__ == "__main__":
    main()
