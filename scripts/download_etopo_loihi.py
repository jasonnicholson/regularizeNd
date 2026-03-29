"""
Download DEM data for the Kamaʻehuakanaloa Seamount (formerly Lōʻihi) region
and create the a01_etopo_loihi.mat example data file for regularizeNd.

Seamount coordinates: 18.92°N, 155.27°W  (Wikipedia)
https://en.wikipedia.org/wiki/Kama%CA%BBehuakanaloa_Seamount

The bounding box is centred on the seamount summit so the feature dominates
the example scatter/surface plot.

Data source
-----------
NOAA NCEI DEM Global Mosaic (ArcGIS ImageServer) via getSamples endpoint.
This mosaic incorporates the highest-resolution available source for each
location; for the open-ocean seamount that is typically NOAA multibeam
survey data (sub-100 m resolution) or GEBCO/ETOPO where surveys are absent.

Output
------
  Examples/a01_etopo_loihi.mat
      x    – longitude vector  (N,)  float64
      y    – latitude vector   (N,)  float64
      z    – elevation (m)     (N,)  float64  (negative = below sea level)

Usage
-----
    uv run python scripts/download_etopo_loihi.py
"""

import argparse
import json
import pathlib
import time

import numpy as np
import requests
import scipy.io
from scipy.stats import qmc

# ── Configuration ──────────────────────────────────────────────────────────
REPO_ROOT   = pathlib.Path(__file__).resolve().parent.parent
OUTPUT_MAT_DEFAULT = REPO_ROOT / "Examples" / "a01_etopo_loihi.mat"

# Bounding box centred on the seamount summit (18.92°N, 155.27°W)
# Wide enough to show the seamount rising from the surrounding seafloor,
# while including more of the northern flank and nearby bathymetry.
WEST,  EAST  = -155.345, -155.13
SOUTH, NORTH =  18.736647,  19.02

# Pseudo-random sample configuration.
# Supported methods: "sobol", "latin_hypercube"
SAMPLE_METHOD = "sobol"
N_SAMPLES_DEFAULT = 1500
RNG_SEED = 42

# ArcGIS ImageServer endpoint – best-available global DEM (includes NOAA
# multibeam data and ETOPO 2022)
_BASE = ("https://gis.ngdc.noaa.gov/arcgis/rest/services/"
         "DEM_mosaics/DEM_global_mosaic/ImageServer")
_BATCH = 300   # max points per getSamples request (empirically safe)



# ── Helpers ─────────────────────────────────────────────────────────────────
def _samples_for_points(lons: list[float], lats: list[float]) -> dict[int, float]:
    """
    Query getSamples for a list of (lon, lat) pairs.
    Returns {locationId: elevation_m}.  When multiple raster tiles overlap a
    point the finest-resolution (smallest resolution value) is used.
    """
    geometry = json.dumps({
        "points": [[lo, la] for lo, la in zip(lons, lats)],
        "spatialReference": {"wkid": 4326},
    })
    params = {
        "geometry":     geometry,
        "geometryType": "esriGeometryMultipoint",
        "mosaicRule":   "",
        "pixelSize":    "",
        "returnFirstValueOnly": "false",
        "f": "json",
    }
    r = requests.post(f"{_BASE}/getSamples", data=params, timeout=120)
    r.raise_for_status()
    data = r.json()

    # Group by locationId and keep the finest-resolution sample
    best: dict[int, tuple[float, float]] = {}   # locationId → (resolution, value)
    for s in data.get("samples", []):
        lid   = s["locationId"]
        val   = float(s["value"])
        res   = float(s["resolution"])
        if lid not in best or res < best[lid][0]:
            best[lid] = (res, val)

    return {lid: v for lid, (_, v) in best.items()}


def _sample_bbox_points(method: str, n_samples: int, seed: int) -> tuple[np.ndarray, np.ndarray]:
    """Sample (lon, lat) points inside the bbox using pseudo-random low-discrepancy methods."""
    if method == "sobol":
        sampler = qmc.Sobol(d=2, scramble=True, seed=seed)
        # Sobol base-2 draw avoids quality warnings for non-power-of-two n.
        m = int(np.ceil(np.log2(n_samples)))
        unit_pts = sampler.random_base2(m=m)[:n_samples]
    elif method == "latin_hypercube":
        sampler = qmc.LatinHypercube(d=2, seed=seed)
        unit_pts = sampler.random(n=n_samples)
    else:
        raise ValueError(f"Unsupported SAMPLE_METHOD: {method}")

    scaled = qmc.scale(unit_pts, [WEST, SOUTH], [EAST, NORTH])
    return scaled[:, 0], scaled[:, 1]


def download_samples(n_samples: int) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Download elevation for pseudo-randomly sampled points in the bbox."""
    lons, lats = _sample_bbox_points(SAMPLE_METHOD, n_samples, RNG_SEED)

    flat_lons = lons.tolist()
    flat_lats = lats.tolist()
    n_total = len(flat_lons)

    elevations = np.full(n_total, np.nan)

    print(f"Querying {n_total} grid points in batches of {_BATCH} …")
    for start in range(0, n_total, _BATCH):
        end    = min(start + _BATCH, n_total)
        chunk_lons = flat_lons[start:end]
        chunk_lats = flat_lats[start:end]

        # locationId from getSamples corresponds to index within the batch
        # geometry array, so we shift back to absolute index.
        result = _samples_for_points(chunk_lons, chunk_lats)
        for local_id, val in result.items():
            elevations[start + local_id] = val

        pct = end / n_total * 100
        print(f"  {end}/{n_total}  ({pct:.0f}%)", end="\r", flush=True)
        time.sleep(0.1)

    print()
    return lons, lats, elevations


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Download ETOPO/DEM samples near Kamaehuakanaloa and save a MATLAB .mat file."
        )
    )
    parser.add_argument(
        "--points",
        type=int,
        default=N_SAMPLES_DEFAULT,
        help=f"Number of pseudo-random sample points (default: {N_SAMPLES_DEFAULT}).",
    )
    parser.add_argument(
        "--output",
        type=pathlib.Path,
        default=OUTPUT_MAT_DEFAULT,
        help=f"Output .mat path (default: {OUTPUT_MAT_DEFAULT}).",
    )
    return parser.parse_args()



def main() -> None:
    args = parse_args()
    n_samples = int(args.points)
    output_mat = pathlib.Path(args.output).expanduser()
    if not output_mat.is_absolute():
        output_mat = (REPO_ROOT / output_mat).resolve()

    if n_samples <= 0:
        raise ValueError("--points must be a positive integer")

    print(f"Downloading DEM for Kamaʻehuakanaloa Seamount region")
    print(f"  Bbox: lon [{WEST}, {EAST}]  lat [{SOUTH}, {NORTH}]")
    print(f"  Sampling: {SAMPLE_METHOD} ({n_samples} points, seed={RNG_SEED})")
    print(f"  Output: {output_mat}")
    print()

    lons, lats, elevs = download_samples(n_samples)

    print(f"  Total sampled points: {len(lons)}")

    # Drop NaN (e.g. points with no coverage, extremely rare in this region)
    valid = np.isfinite(elevs)
    n_nan = (~valid).sum()
    if n_nan:
        print(f"  Warning: {n_nan} NaN values dropped.")
    lons, lats, elevs = lons[valid], lats[valid], elevs[valid]

    print(f"\nData statistics:")
    print(f"  Points:    {len(lons)}")
    print(f"  Lon range: [{lons.min():.4f}, {lons.max():.4f}]")
    print(f"  Lat range: [{lats.min():.4f}, {lats.max():.4f}]")
    print(f"  Z range:   [{elevs.min():.1f}, {elevs.max():.1f}] m")
    seamount_mask = (np.abs(lons - (-155.27)) < 0.15) & (np.abs(lats - 18.92) < 0.15)
    if seamount_mask.any():
        sh = elevs[seamount_mask].max()
        print(f"  Shallowest z near seamount summit: {sh:.1f} m  (Wikipedia: ~-975 m)")


    output_mat.parent.mkdir(parents=True, exist_ok=True)

    # Save as column vectors for consistent MATLAB handling.
    scipy.io.savemat(
        str(output_mat),
        {
            "x":    lons.reshape(-1, 1),
            "y":    lats.reshape(-1, 1),
            "z":    elevs.reshape(-1, 1),
        },
    )
    print(f"\nSaved: {output_mat}  ({output_mat.stat().st_size / 1024:.0f} KB)")


if __name__ == "__main__":
    main()
