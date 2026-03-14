"""
2D Solver Comparison Example
Port of Examples/example_solver_differences.m

Demonstrates the difference between the 'normal' and '\\' solvers on a
2-D scattered dataset with added noise.

Run from the ports/python/ directory or any location after installing the package.
"""

import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from regularize_nd import regularize_nd
import numpy as np

rng = np.random.default_rng(42)

# Build a 2-D scattered dataset on a regular grid
x = np.arange(0.5, 4.6, 0.1)
y = np.arange(0.5, 5.6, 0.1)
xx, yy = np.meshgrid(x, y, indexing="ij")

z = np.tanh(xx - 3) * np.sin(2 * np.pi / 6 * yy)
noise = (rng.random(xx.shape) - 0.5) * xx * yy / 30
z_noise = z + noise

# Scale x axis (demonstrates axis-independent smoothness handling)
x_scale = 100
xx_scaled = x_scale * xx
x_scaled = x_scale * x

# Lookup-table grid (smaller than MATLAB example for speed)
x_grid = [np.linspace(0, x_scale * 6, 21), np.linspace(0, 6.6, 20)]
smoothness = 0.001

pts = np.column_stack([xx_scaled.ravel(), yy.ravel()])

print("Solving with 'normal' solver...")
z_grid_normal = regularize_nd(pts, z_noise.ravel(), x_grid, smoothness=smoothness, solver="normal")

print("Solving with '\\\\' solver...")
z_grid_backslash = regularize_nd(pts, z_noise.ravel(), x_grid, smoothness=smoothness, solver="\\")

max_diff = np.max(np.abs(z_grid_normal - z_grid_backslash))
print(f"Output shape:          {z_grid_normal.shape}")
print(f"Max solver difference: {max_diff:.2e}")

try:
    import matplotlib.pyplot as plt

    xg, yg = np.meshgrid(x_grid[0] / x_scale, x_grid[1], indexing="ij")

    fig, axes = plt.subplots(1, 3, figsize=(15, 4))

    im0 = axes[0].pcolormesh(xg, yg, z_grid_normal, shading="auto", cmap="viridis")
    axes[0].set_title("'normal' solver")
    fig.colorbar(im0, ax=axes[0])

    im1 = axes[1].pcolormesh(xg, yg, z_grid_backslash, shading="auto", cmap="viridis")
    axes[1].set_title("'\\\\' solver")
    fig.colorbar(im1, ax=axes[1])

    im2 = axes[2].pcolormesh(xg, yg, np.abs(z_grid_normal - z_grid_backslash), shading="auto", cmap="plasma")
    axes[2].set_title("Absolute difference")
    fig.colorbar(im2, ax=axes[2])

    for ax in axes:
        ax.set_xlabel("x")
        ax.set_ylabel("y")

    plt.tight_layout()
    out = os.path.join(os.path.dirname(__file__), "example_2d.png")
    plt.savefig(out, dpi=100)
    print(f"Plot saved to {out}")
    plt.show()
except ImportError:
    print("matplotlib not available — skipping plot.")
