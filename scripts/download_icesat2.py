"""
Download ICESat-2 ATL06 land-ice-height granules for use in regularizeNd
promotional images.

Usage
-----
    .venv/bin/python3 scripts/download_icesat2.py

Authentication uses a Bearer token read from the GNOME Keyring.
Set it first with:
    .venv/bin/python3 scripts/setup_earthdata_credentials.py

Outputs (all under data/external/icesat2/)
------------------------------------------
  atl06_greenland_<track>_<date>.h5   – original HDF5 granule(s)
  greenland_atl06_points.csv          – merged lon, lat, h_li, beam columns
  greenland_atl06_points.npz          – same as NumPy arrays

Region selected: southern Greenland ice sheet, ~65-72 N / 50-40 W
  - Dramatic land-ice terrain, multiple parallel ICESat-2 beams
  - Complements ETOPO Greenland tiles for the hybrid concept
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
OUT_DIR = REPO_ROOT / "data" / "external" / "icesat2"
OUT_DIR.mkdir(parents=True, exist_ok=True)

_KR_SERVICE = "nasa-earthdata"
_TOKEN_KEY   = "token"
_USER_KEY    = "username"

# ── region of interest (S Greenland ice sheet extent) ──────────────────────
BBOX = (-50, 65, -40, 72)   # (min_lon, min_lat, max_lon, max_lat)

# We grab a window of a few months to ensure we capture at least 1-2 passes.
DATE_RANGE = ("2024-09-01", "2024-12-31")

# ── beams to extract; each contributes a separate along-track profile ───────
BEAMS = ["gt1l", "gt1r", "gt2l", "gt2r", "gt3l", "gt3r"]


def require_project_venv() -> None:
    """Fail fast if the script is run outside the project's .venv."""
    venv_python = REPO_ROOT / ".venv" / "bin" / "python3"
    if pathlib.Path(sys.executable).resolve() != venv_python.resolve():
        raise RuntimeError(
            "Wrong Python runtime detected.\n"
            f"  Running:  {sys.executable}\n"
            f"  Expected: {venv_python}\n\n"
            "Run with:\n"
            "  .venv/bin/python3 scripts/download_icesat2.py"
        )


def login() -> None:
    """
    Authenticate against NASA Earthdata using a Bearer token from the keyring.

        Requires:
            1. Bearer token stored in GNOME Keyring (setup_earthdata_credentials.py)
            2. Earthdata username stored in GNOME Keyring

    The token is injected into the process environment for this run only
    and is never written to any file by this script.
    """
    token    = keyring.get_password(_KR_SERVICE, _TOKEN_KEY)
    username = keyring.get_password(_KR_SERVICE, _USER_KEY)

    if not token or not username:
        raise RuntimeError(
            "No Earthdata token/username found in GNOME Keyring.\n"
            "Run first:\n"
            "  .venv/bin/python3 scripts/setup_earthdata_credentials.py"
        )

    print("Authenticating via Bearer token (GNOME Keyring)...")
    os.environ["EARTHDATA_USERNAME"] = username
    os.environ["EARTHDATA_TOKEN"] = token
    earthaccess.login(strategy="environment")

    print("Authentication successful.\n")


def search_granules() -> list:
    """Return ATL06 granules intersecting the target bounding box."""
    print(f"Searching ATL06 granules for bbox={BBOX}, dates={DATE_RANGE}...")
    results = earthaccess.search_data(
        short_name="ATL06",
        bounding_box=BBOX,
        temporal=DATE_RANGE,
        count=20,
    )
    print(f"  Found {len(results)} granule(s).\n")
    return results


def download_granules(granules: list) -> list[pathlib.Path]:
    """Download granules to OUT_DIR and return local paths."""
    if not granules:
        raise RuntimeError("No granules found for the specified search criteria.")
    print(f"Downloading {len(granules)} granule(s) to {OUT_DIR}...")
    local_paths = earthaccess.download(granules, local_path=str(OUT_DIR))
    print(f"  Download complete: {len(local_paths)} file(s).\n")
    return [pathlib.Path(p) for p in local_paths]


def extract_points(h5_path: pathlib.Path) -> dict:
    """
    Extract lon, lat, h_li from all available beams in one ATL06 HDF5 file.

    Returns a dict with arrays: lon, lat, h_li, beam_id (int 1-6).
    """
    lons, lats, heights, beam_ids = [], [], [], []

    with h5py.File(h5_path, "r") as f:
        for bid, beam in enumerate(BEAMS, start=1):
            grp = f.get(f"{beam}/land_ice_segments")
            if grp is None:
                continue
            lat = grp["latitude"][:]
            lon = grp["longitude"][:]
            h = grp["h_li"][:]

            # ATL06 fill value is 3.4028235e+38; also mask NaN/Inf
            valid = (
                np.isfinite(h) & np.isfinite(lat) & np.isfinite(lon) &
                (h < 1e10) & (h > -500)
            )
            lons.append(lon[valid])
            lats.append(lat[valid])
            heights.append(h[valid])
            beam_ids.append(np.full(valid.sum(), bid, dtype=np.int8))

    return {
        "lon":  np.concatenate(lons),
        "lat":  np.concatenate(lats),
        "h_li": np.concatenate(heights),
        "beam": np.concatenate(beam_ids),
    }


def main() -> None:
    require_project_venv()
    login()
    granules = search_granules()
    local_files = download_granules(granules)

    # --- merge points from all downloaded granules -------------------------
    all_lon, all_lat, all_h, all_beam = [], [], [], []
    for f in local_files:
        pts = extract_points(f)
        all_lon.append(pts["lon"])
        all_lat.append(pts["lat"])
        all_h.append(pts["h_li"])
        all_beam.append(pts["beam"])

    lon  = np.concatenate(all_lon)
    lat  = np.concatenate(all_lat)
    h_li = np.concatenate(all_h)
    beam = np.concatenate(all_beam)

    print(f"Total points extracted: {len(lon):,}")
    print(f"  h_li range: {h_li.min():.1f} – {h_li.max():.1f} m\n")

    # --- save CSV (MATLAB-friendly) ----------------------------------------
    csv_path = OUT_DIR / "greenland_atl06_points.csv"
    header = "lon,lat,h_li,beam"
    data_out = np.column_stack([lon, lat, h_li, beam.astype(float)])
    np.savetxt(str(csv_path), data_out, delimiter=",", header=header, comments="")
    print(f"Saved CSV  → {csv_path}")

    # --- save NPZ (Python-friendly) ----------------------------------------
    npz_path = OUT_DIR / "greenland_atl06_points.npz"
    np.savez_compressed(str(npz_path), lon=lon, lat=lat, h_li=h_li, beam=beam)
    print(f"Saved NPZ  → {npz_path}")

    print("\nDone. Run the MATLAB image-generation scripts next.")


if __name__ == "__main__":
    main()
