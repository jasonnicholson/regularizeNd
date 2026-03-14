from __future__ import annotations

from typing import List, Sequence, Tuple

import numpy as np
from scipy import sparse
from scipy.sparse import linalg as spla


SUPPORTED_INTERP = {"linear", "nearest", "cubic"}
SUPPORTED_SOLVER = {"\\", "normal", "lsqr", "pcg", "symmlq"}


def regularize_nd_matrices(
    x: np.ndarray,
    x_grid: Sequence[Sequence[float]],
    smoothness: float | Sequence[float] = 1e-2,
    interp_method: str = "linear",
) -> Tuple[sparse.csr_matrix, List[sparse.csr_matrix]]:
    x = np.asarray(x, dtype=float)
    if x.ndim != 2:
        raise ValueError("x must be 2D")
    if interp_method not in SUPPORTED_INTERP:
        raise ValueError("unsupported interpolation method")

    n_scattered, n_dims = x.shape
    if len(x_grid) != n_dims:
        raise ValueError("dimension mismatch")

    grids = [np.asarray(g, dtype=float).reshape(-1) for g in x_grid]
    n_grid = np.array([g.size for g in grids], dtype=int)

    if np.isscalar(smoothness):
        smooth = np.full(n_dims, float(smoothness), dtype=float)
    else:
        smooth = np.asarray(smoothness, dtype=float).reshape(-1)
        if smooth.size != n_dims:
            raise ValueError("smoothness shape mismatch")
    if np.any(smooth < 0):
        raise ValueError("smoothness must be non-negative")

    x_min = np.array([g.min() for g in grids])
    x_max = np.array([g.max() for g in grids])
    if np.any(x < x_min) or np.any(x > x_max):
        raise ValueError("points not within range")

    dx = [np.diff(g) for g in grids]
    if any(np.any(d <= 0) for d in dx):
        raise ValueError("grid vectors must be strictly increasing")

    min_len = 4 if interp_method == "cubic" else 3
    if np.any(n_grid < min_len):
        raise ValueError("not enough grid points in at least one dimension")

    afidelity = _build_fidelity_matrix(x, grids, n_grid, interp_method)
    lreg = _build_regularization_matrices(x, grids, n_grid, smooth)
    return afidelity, lreg


def regularize_nd(
    x: np.ndarray,
    y: np.ndarray,
    x_grid: Sequence[Sequence[float]],
    smoothness: float | Sequence[float] = 1e-2,
    interp_method: str = "linear",
    solver: str = "normal",
    max_iterations: int | None = None,
    solver_tolerance: float | None = None,
) -> np.ndarray:
    x = np.asarray(x, dtype=float)
    y = np.asarray(y, dtype=float).reshape(-1, 1)
    if y.shape[0] != x.shape[0]:
        raise ValueError("x and y row counts must match")
    if solver not in SUPPORTED_SOLVER:
        raise ValueError("unsupported solver")

    n_total_grid_points = int(np.prod([len(g) for g in x_grid]))
    if max_iterations is None:
        max_iterations = int(min(1e5, n_total_grid_points))
    if solver_tolerance is None:
        y_span = float(np.max(y) - np.min(y))
        solver_tolerance = 1e-11 * abs(y_span if y_span > 0 else 1.0)

    afidelity, lreg = regularize_nd_matrices(x, x_grid, smoothness, interp_method)
    lreg_nonempty = [li for li in lreg if li.shape[0] > 0]
    a = sparse.vstack([afidelity, *lreg_nonempty], format="csr") if lreg_nonempty else afidelity

    n_total_smooth = a.shape[0] - afidelity.shape[0]
    rhs = np.vstack([y, np.zeros((n_total_smooth, 1), dtype=float)]).reshape(-1)

    if solver == "\\":
        # MATLAB backslash solves least-squares for rectangular sparse systems.
        y_vec = spla.lsqr(a, rhs, atol=solver_tolerance, btol=solver_tolerance, iter_lim=max_iterations)[0]
    elif solver == "normal":
        ata = (a.T @ a).tocsc()
        aty = a.T @ rhs
        y_vec = spla.spsolve(ata, aty)
    elif solver == "lsqr":
        y_vec = spla.lsqr(a, rhs, atol=solver_tolerance, btol=solver_tolerance, iter_lim=max_iterations)[0]
    elif solver == "pcg":
        ata = (a.T @ a).tocsc()
        aty = a.T @ rhs
        y_vec, _ = spla.cg(ata, aty, rtol=solver_tolerance, maxiter=max_iterations)
    else:
        ata = (a.T @ a).tocsc()
        aty = a.T @ rhs
        y_vec, _ = spla.minres(ata, aty, rtol=solver_tolerance, maxiter=max_iterations)

    y_vec = np.asarray(y_vec).reshape(-1)
    n_grid = [len(g) for g in x_grid]
    if x.shape[1] > 1:
        return np.reshape(y_vec, n_grid, order="F")
    return y_vec


def monotonic_constraint(
    x_grid: Sequence[Sequence[float]],
    dimension: int = 1,
    dx_min: float = 0.0,
) -> Tuple[sparse.csr_matrix, np.ndarray]:
    grids = [np.asarray(g, dtype=float).reshape(-1) for g in x_grid]
    n_dim = len(grids)
    if not 1 <= dimension <= n_dim:
        raise ValueError("dimension out of range")

    d = dimension - 1
    sub1 = [g.copy() for g in grids]
    sub2 = [g.copy() for g in grids]
    sub1[d] = sub1[d][:-1]
    sub2[d] = sub2[d][1:]

    a1 = _monotonic_helper(sub1, grids)
    a2 = _monotonic_helper(sub2, grids)
    a = (a1 - a2).tocsr()
    b = -dx_min * np.ones(a.shape[0], dtype=float)
    return a, b


def _monotonic_helper(sub_grid: Sequence[np.ndarray], full_grid: Sequence[np.ndarray]) -> sparse.csr_matrix:
    mesh = np.meshgrid(*sub_grid, indexing="ij")
    points = np.column_stack([m.reshape(-1, order="F") for m in mesh])
    a, _ = regularize_nd_matrices(points, full_grid)
    return a


def _build_fidelity_matrix(
    x: np.ndarray,
    grids: Sequence[np.ndarray],
    n_grid: np.ndarray,
    interp_method: str,
) -> sparse.csr_matrix:
    n_scattered, n_dims = x.shape

    if interp_method == "nearest":
        subs = []
        for i in range(n_dims):
            idx = np.searchsorted(grids[i], x[:, i], side="right") - 1
            idx = np.clip(idx, 0, len(grids[i]) - 2)
            frac = (x[:, i] - grids[i][idx]) / (grids[i][idx + 1] - grids[i][idx])
            frac = np.clip(frac, 0.0, 1.0)
            subs.append(np.rint(frac).astype(int) + idx)

        cols = np.ravel_multi_index(tuple(subs), tuple(n_grid), order="F")
        rows = np.arange(n_scattered)
        data = np.ones(n_scattered, dtype=float)
        return sparse.coo_matrix((data, (rows, cols)), shape=(n_scattered, int(np.prod(n_grid)))).tocsr()

    if interp_method == "linear":
        p = 2
        local_idx = _local_cell_index(p, n_dims)
        n_nodes = p**n_dims
        weight = np.ones((n_scattered, n_nodes), dtype=float)
        subs = []
        for i in range(n_dims):
            idx = np.searchsorted(grids[i], x[:, i], side="right") - 1
            idx = np.clip(idx, 0, len(grids[i]) - 2)
            frac = (x[:, i] - grids[i][idx]) / (grids[i][idx + 1] - grids[i][idx])
            frac = np.clip(frac, 0.0, 1.0)
            wc = np.column_stack([1 - frac, frac])
            weight *= wc[:, local_idx[i, :]]
            subs.append(idx[:, None] + local_idx[i, :][None, :])

        cols = np.ravel_multi_index(tuple(subs), tuple(n_grid), order="F")
        rows = np.repeat(np.arange(n_scattered), n_nodes)
        return sparse.coo_matrix((weight.reshape(-1), (rows, cols.reshape(-1))), shape=(n_scattered, int(np.prod(n_grid)))).tocsr()

    p = 4
    local_idx = _local_cell_index(p, n_dims)
    n_nodes = p**n_dims
    weight = np.ones((n_scattered, n_nodes), dtype=float)
    subs = []

    for i in range(n_dims):
        idx = np.searchsorted(grids[i], x[:, i], side="right") - 1
        idx = np.clip(idx, 0, len(grids[i]) - 2)
        idx = np.clip(idx - 1, 0, len(grids[i]) - 4)

        x1 = grids[i][idx]
        x2 = grids[i][idx + 1]
        x3 = grids[i][idx + 2]
        x4 = grids[i][idx + 3]
        xv = x[:, i]

        a1 = xv - x1
        a2 = xv - x2
        a3 = xv - x3
        a4 = xv - x4
        b12 = x1 - x2
        b13 = x1 - x3
        b14 = x1 - x4
        b23 = x2 - x3
        b24 = x2 - x4
        b34 = x3 - x4

        wc = np.column_stack([
            a2 / b12 * a3 / b13 * a4 / b14,
            -a1 / b12 * a3 / b23 * a4 / b24,
            a1 / b13 * a2 / b23 * a4 / b34,
            -a1 / b14 * a2 / b24 * a3 / b34,
        ])

        weight *= wc[:, local_idx[i, :]]
        subs.append(idx[:, None] + local_idx[i, :][None, :])

    cols = np.ravel_multi_index(tuple(subs), tuple(n_grid), order="F")
    rows = np.repeat(np.arange(n_scattered), n_nodes)
    return sparse.coo_matrix((weight.reshape(-1), (rows, cols.reshape(-1))), shape=(n_scattered, int(np.prod(n_grid)))).tocsr()


def _build_regularization_matrices(
    x: np.ndarray,
    grids: Sequence[np.ndarray],
    n_grid: np.ndarray,
    smoothness: np.ndarray,
) -> List[sparse.csr_matrix]:
    n_scattered, n_dims = x.shape
    x_min = np.array([g.min() for g in grids])
    x_max = np.array([g.max() for g in grids])
    n_total_grid_points = int(np.prod(n_grid))

    out: List[sparse.csr_matrix] = []
    for d in range(n_dims):
        if smoothness[d] == 0:
            out.append(sparse.csr_matrix((0, n_total_grid_points), dtype=float))
            continue

        n_eq_dims = n_grid.copy()
        n_eq_dims[d] -= 2
        n_eq = int(np.prod(n_eq_dims))

        ranges = [np.arange(n_grid[k]) for k in range(n_dims)]
        ranges[d] = np.arange(n_grid[d] - 2)
        mesh = np.meshgrid(*ranges, indexing="ij")
        base = [m.reshape(-1) for m in mesh]

        subs1 = [s.copy() for s in base]
        subs2 = [s.copy() for s in base]
        subs3 = [s.copy() for s in base]
        subs2[d] += 1
        subs3[d] += 2

        ind1 = np.ravel_multi_index(tuple(subs1), tuple(n_grid), order="F")
        ind2 = np.ravel_multi_index(tuple(subs2), tuple(n_grid), order="F")
        ind3 = np.ravel_multi_index(tuple(subs3), tuple(n_grid), order="F")

        w1, w2, w3 = _second_derivative_weights_1d(grids[d])
        idx = base[d]
        ws = np.column_stack([w1[idx], w2[idx], w3[idx]])

        scale = smoothness[d] * np.sqrt(n_scattered / n_eq) * (x_max[d] - x_min[d]) ** 2
        ws *= scale

        rows = np.repeat(np.arange(n_eq), 3)
        cols = np.column_stack([ind1, ind2, ind3]).reshape(-1)
        data = ws.reshape(-1)
        out.append(sparse.coo_matrix((data, (rows, cols)), shape=(n_eq, n_total_grid_points)).tocsr())

    return out


def _second_derivative_weights_1d(grid: np.ndarray) -> Tuple[np.ndarray, np.ndarray, np.ndarray]:
    x1 = grid[:-2]
    x2 = grid[1:-1]
    x3 = grid[2:]
    return (
        2.0 / ((x1 - x3) * (x1 - x2)),
        2.0 / ((x2 - x1) * (x2 - x3)),
        2.0 / ((x3 - x1) * (x3 - x2)),
    )


def _local_cell_index(points_per_dim: int, n_dims: int) -> np.ndarray:
    values = np.arange(points_per_dim)
    out = np.empty((n_dims, points_per_dim**n_dims), dtype=int)
    for i in range(n_dims):
        a = np.tile(values, points_per_dim ** (n_dims - i - 1))
        out[i, :] = np.tile(a, points_per_dim**i)
    return out
