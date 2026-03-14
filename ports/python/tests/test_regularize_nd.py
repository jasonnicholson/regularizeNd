import numpy as np

from regularize_nd import monotonic_constraint, regularize_nd, regularize_nd_matrices


def _data_2d():
    rng = np.random.default_rng(42)
    x1 = np.linspace(0.5, 3.5, 9)
    x2 = np.linspace(0.2, 2.8, 8)
    xx, yy = np.meshgrid(x1, x2, indexing="ij")
    z = np.tanh(xx - 1.5) * np.sin(2 * np.pi / 3 * yy)
    noise = 0.01 * (rng.random(z.shape) - 0.5)
    x = np.column_stack([xx.reshape(-1), yy.reshape(-1)])
    y = z.reshape(-1) + noise.reshape(-1)
    x_grid = [
        np.linspace(np.min(x[:, 0]) - 0.1, np.max(x[:, 0]) + 0.1, 14),
        np.linspace(np.min(x[:, 1]) - 0.1, np.max(x[:, 1]) + 0.1, 13),
    ]
    return x, y, x_grid


def _data_1d():
    x = np.arange(0, 2.8, 0.3).reshape(-1, 1)
    y = np.sin(2 * x[:, 0]) + 0.1 * x[:, 0]
    x_grid = [np.linspace(-0.1, 2.8, 25)]
    return x, y, x_grid


def test_input_validation():
    x, y, x_grid = _data_2d()

    try:
        regularize_nd(x, y, x_grid[:1])
        assert False
    except ValueError:
        pass

    try:
        regularize_nd(x, y, x_grid, [1, 2, 3])
        assert False
    except ValueError:
        pass


def test_interpolation_methods():
    x, y, x_grid = _data_2d()
    for method in ["nearest", "linear", "cubic"]:
        y_grid = regularize_nd(x, y, x_grid, 5e-3, method, "normal")
        assert y_grid.shape == (len(x_grid[0]), len(x_grid[1]))
        assert np.all(np.isfinite(y_grid))


def test_solvers():
    x, y, x_grid = _data_1d()
    for solver in ["\\", "normal", "lsqr", "pcg", "symmlq"]:
        y_grid = regularize_nd(x, y, x_grid, 1e-3, "linear", solver)
        assert y_grid.shape == (len(x_grid[0]),)
        assert np.all(np.isfinite(y_grid))


def test_matrix_form_matches_backslash_like_solution():
    x, y, x_grid = _data_2d()
    afidelity, lreg = regularize_nd_matrices(x, x_grid, [1e-3, 2e-3], "linear")

    # Keep this close to MATLAB: assemble sparse and solve directly.
    from scipy import sparse
    from scipy.sparse import linalg as spla

    a = sparse.vstack([afidelity, *lreg], format="csr")
    b = np.hstack([y, np.zeros(a.shape[0] - y.size)])
    y_vec = spla.lsqr(a, b)[0]
    y_grid_mat = y_vec.reshape((len(x_grid[0]), len(x_grid[1])), order="F")

    y_grid_api = regularize_nd(x, y, x_grid, [1e-3, 2e-3], "linear", "\\")
    assert np.allclose(y_grid_mat, y_grid_api, atol=1e-4)


def test_monotonic_constraint_structure():
    a, b = monotonic_constraint([np.arange(1, 7)], dimension=1, dx_min=0.25)
    assert a.shape == (5, 6)
    assert np.all((a != 0).sum(axis=1).A.ravel() == 2)
    assert np.allclose(a.toarray()[0, :2], [1.0, -1.0])
    assert np.allclose(b, -0.25)
