"""
1D Regularization Example
Port of Examples/example1D.m

Dataset from:
https://mathformeremortals.wordpress.com/2013/01/29/introduction-to-regularizing-with-2d-data-part-1-of-3/

Run from the ports/python/ directory or any location after installing the package.
"""

import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from regularize_nd import regularize_nd
import numpy as np

# Scattered input/output data
x = np.array([[0], [0.55], [1.1], [2.6], [2.99]])
y = np.array([1, 1.1, 1.5, 2.5, 1.9])

# Two grids: one coarse, one fine
x_grid_coarse = [np.array([-0.50, 0.0, 0.50, 1.0, 1.50, 2.0, 2.50, 3.0, 3.30, 3.60])]
x_grid_fine = [np.arange(-0.5, 3.61, 0.1)]

smoothness = 5e-3

y_grid_coarse = regularize_nd(x, y, x_grid_coarse, smoothness=smoothness)
y_grid_fine = regularize_nd(x, y, x_grid_fine, smoothness=smoothness)

print(f"Coarse grid: {len(y_grid_coarse)} points, range [{y_grid_coarse.min():.3f}, {y_grid_coarse.max():.3f}]")
print(f"Fine grid:   {len(y_grid_fine)} points, range [{y_grid_fine.min():.3f}, {y_grid_fine.max():.3f}]")

try:
    import matplotlib.pyplot as plt

    fig, ax = plt.subplots(figsize=(8, 5))
    ax.plot(x.ravel(), y, "rx", markersize=12, label="Scattered data", zorder=5)
    ax.plot(x_grid_coarse[0], y_grid_coarse, "b-o", markersize=4, label="Coarse grid")
    ax.plot(x_grid_fine[0], y_grid_fine, "g--", label="Fine grid")
    ax.set_xlabel("x")
    ax.set_ylabel("y")
    ax.set_title("1D Regularization Example")
    ax.legend()
    ax.grid(True)
    plt.tight_layout()
    out = os.path.join(os.path.dirname(__file__), "example_1d.png")
    plt.savefig(out, dpi=100)
    print(f"Plot saved to {out}")
    plt.show()
except ImportError:
    print("matplotlib not available — skipping plot.")
