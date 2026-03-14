module RegularizeNd

using SparseArrays
using LinearAlgebra

export regularize_nd_matrices, regularize_nd, monotonic_constraint

const SUPPORTED_INTERP = Set(["linear", "nearest", "cubic"])
const SUPPORTED_SOLVER = Set(["\\", "normal", "lsqr", "pcg", "symmlq"])

function regularize_nd_matrices(x::AbstractMatrix{<:Real}, x_grid::AbstractVector{<:AbstractVector{<:Real}};
    smoothness::Union{Real, AbstractVector{<:Real}}=1e-2,
    interp_method::String="linear")

    interp_method in SUPPORTED_INTERP || throw(ArgumentError("unsupported interpolation method"))

    X = Matrix{Float64}(x)
    n_scattered, n_dims = size(X)
    length(x_grid) == n_dims || throw(ArgumentError("dimension mismatch"))

    grids = [Float64.(collect(g)) for g in x_grid]
    n_grid = [length(g) for g in grids]

    smooth = if smoothness isa Real
        fill(Float64(smoothness), n_dims)
    else
        s = Float64.(collect(smoothness))
        length(s) == n_dims || throw(ArgumentError("smoothness shape mismatch"))
        s
    end
    any(smooth .< 0) && throw(ArgumentError("smoothness must be non-negative"))

    x_min = [minimum(g) for g in grids]
    x_max = [maximum(g) for g in grids]
    for d in 1:n_dims
        all(X[:, d] .>= x_min[d]) || throw(ArgumentError("points not within range"))
        all(X[:, d] .<= x_max[d]) || throw(ArgumentError("points not within range"))
    end

    dx = [diff(g) for g in grids]
    any(any(v .<= 0) for v in dx) && throw(ArgumentError("grid vectors must be strictly increasing"))

    min_len = interp_method == "cubic" ? 4 : 3
    all(n_grid .>= min_len) || throw(ArgumentError("not enough grid points in at least one dimension"))

    A = _build_fidelity_matrix(X, grids, n_grid, interp_method)
    L = _build_regularization_matrices(X, grids, n_grid, smooth)
    return A, L
end

function regularize_nd(x::AbstractMatrix{<:Real}, y::AbstractVector{<:Real}, x_grid::AbstractVector{<:AbstractVector{<:Real}};
    smoothness::Union{Real, AbstractVector{<:Real}}=1e-2,
    interp_method::String="linear",
    solver::String="normal",
    max_iterations::Union{Nothing,Int}=nothing,
    solver_tolerance::Union{Nothing,Float64}=nothing)

    solver in SUPPORTED_SOLVER || throw(ArgumentError("unsupported solver"))

    X = Matrix{Float64}(x)
    yv = Float64.(collect(y))
    size(X, 1) == length(yv) || throw(ArgumentError("x and y row counts must match"))

    n_total_grid_points = prod(length.(x_grid))
    maxiter = isnothing(max_iterations) ? min(100000, n_total_grid_points) : max_iterations
    y_span = maximum(yv) - minimum(yv)
    tol = isnothing(solver_tolerance) ? 1e-11 * abs(y_span > 0 ? y_span : 1.0) : solver_tolerance

    A, L = regularize_nd_matrices(X, x_grid; smoothness=smoothness, interp_method=interp_method)
    Lnz = [Li for Li in L if size(Li, 1) > 0]
    M = isempty(Lnz) ? A : vcat(A, Lnz...)

    rhs = vcat(yv, zeros(size(M, 1) - size(A, 1)))

    yvec = if solver == "\\"
        M \ rhs
    elseif solver == "normal"
        (M' * M) \ (M' * rhs)
    else
        try
            @eval using IterativeSolvers
            if solver == "lsqr"
                IterativeSolvers.lsqr(M, rhs; atol=tol, btol=tol, maxiter=maxiter)
            elseif solver == "pcg"
                IterativeSolvers.cg(M' * M, M' * rhs; reltol=tol, maxiter=maxiter)
            else
                IterativeSolvers.minres(M' * M, M' * rhs; reltol=tol, maxiter=maxiter)
            end
        catch
            (M' * M) \ (M' * rhs)
        end
    end

    n_dims = size(X, 2)
    if n_dims > 1
        return reshape(yvec, Tuple(length.(x_grid)))
    end
    return yvec
end

function monotonic_constraint(x_grid::AbstractVector{<:AbstractVector{<:Real}}; dimension::Int=1, dx_min::Real=0.0)
    grids = [Float64.(collect(g)) for g in x_grid]
    n_dim = length(grids)
    1 <= dimension <= n_dim || throw(ArgumentError("dimension out of range"))

    sub1 = [copy(g) for g in grids]
    sub2 = [copy(g) for g in grids]
    sub1[dimension] = sub1[dimension][1:end-1]
    sub2[dimension] = sub2[dimension][2:end]

    A1 = _monotonic_helper(sub1, grids)
    A2 = _monotonic_helper(sub2, grids)
    A = A1 - A2
    b = fill(-Float64(dx_min), size(A, 1))
    return A, b
end

function _monotonic_helper(sub_grid, full_grid)
    pts = collect(Iterators.product(sub_grid...))
    n = length(pts)
    d = length(full_grid)
    X = Matrix{Float64}(undef, n, d)
    for (i, t) in enumerate(pts)
        for j in 1:d
            X[i, j] = t[j]
        end
    end
    A, _ = regularize_nd_matrices(X, full_grid)
    return A
end

function _build_fidelity_matrix(X, grids, n_grid, interp_method)
    n_scattered, n_dims = size(X)

    if interp_method == "nearest"
        rows = Int[]; cols = Int[]; vals = Float64[]
        for r in 1:n_scattered
            subs = zeros(Int, n_dims)
            for d in 1:n_dims
                idx = searchsortedlast(grids[d], X[r, d])
                idx = clamp(idx, 1, length(grids[d]) - 1)
                frac = (X[r, d] - grids[d][idx]) / (grids[d][idx + 1] - grids[d][idx])
                frac = clamp(frac, 0.0, 1.0)
                subs[d] = idx + round(Int, frac)
            end
            c = LinearIndices(Tuple(n_grid))[CartesianIndex(Tuple(subs))]
            push!(rows, r); push!(cols, c); push!(vals, 1.0)
        end
        return sparse(rows, cols, vals, n_scattered, prod(n_grid))
    end

    if interp_method == "linear"
        p = 2
        local_idx = _local_cell_index(p, n_dims)
        n_nodes = p^n_dims
        rows = Int[]; cols = Int[]; vals = Float64[]

        for r in 1:n_scattered
            idx0 = zeros(Int, n_dims)
            frac = zeros(Float64, n_dims)
            for d in 1:n_dims
                idx = searchsortedlast(grids[d], X[r, d])
                idx = clamp(idx, 1, length(grids[d]) - 1)
                idx0[d] = idx
                frac[d] = clamp((X[r, d] - grids[d][idx]) / (grids[d][idx + 1] - grids[d][idx]), 0.0, 1.0)
            end

            for node in 1:n_nodes
                subs = zeros(Int, n_dims)
                w = 1.0
                for d in 1:n_dims
                    li = local_idx[d, node]
                    subs[d] = idx0[d] + li
                    w *= li == 0 ? (1 - frac[d]) : frac[d]
                end
                c = LinearIndices(Tuple(n_grid))[CartesianIndex(Tuple(subs))]
                push!(rows, r); push!(cols, c); push!(vals, w)
            end
        end
        return sparse(rows, cols, vals, n_scattered, prod(n_grid))
    end

    p = 4
    local_idx = _local_cell_index(p, n_dims)
    n_nodes = p^n_dims
    rows = Int[]; cols = Int[]; vals = Float64[]

    for r in 1:n_scattered
        idx0 = zeros(Int, n_dims)
        wdim = [zeros(4) for _ in 1:n_dims]
        for d in 1:n_dims
            idx = searchsortedlast(grids[d], X[r, d])
            idx = clamp(idx, 1, length(grids[d]) - 1)
            idx = clamp(idx - 1, 1, length(grids[d]) - 3)
            idx0[d] = idx

            x1 = grids[d][idx]; x2 = grids[d][idx + 1]; x3 = grids[d][idx + 2]; x4 = grids[d][idx + 3]
            xv = X[r, d]
            a1 = xv - x1; a2 = xv - x2; a3 = xv - x3; a4 = xv - x4
            b12 = x1 - x2; b13 = x1 - x3; b14 = x1 - x4
            b23 = x2 - x3; b24 = x2 - x4; b34 = x3 - x4

            wdim[d][1] = a2 / b12 * a3 / b13 * a4 / b14
            wdim[d][2] = -a1 / b12 * a3 / b23 * a4 / b24
            wdim[d][3] = a1 / b13 * a2 / b23 * a4 / b34
            wdim[d][4] = -a1 / b14 * a2 / b24 * a3 / b34
        end

        for node in 1:n_nodes
            subs = zeros(Int, n_dims)
            w = 1.0
            for d in 1:n_dims
                li = local_idx[d, node] + 1
                subs[d] = idx0[d] + (li - 1)
                w *= wdim[d][li]
            end
            c = LinearIndices(Tuple(n_grid))[CartesianIndex(Tuple(subs))]
            push!(rows, r); push!(cols, c); push!(vals, w)
        end
    end

    return sparse(rows, cols, vals, n_scattered, prod(n_grid))
end

function _build_regularization_matrices(X, grids, n_grid, smooth)
    n_scattered, n_dims = size(X)
    n_total = prod(n_grid)
    x_min = [minimum(g) for g in grids]
    x_max = [maximum(g) for g in grids]

    out = Vector{SparseMatrixCSC{Float64, Int}}(undef, n_dims)
    for d in 1:n_dims
        if smooth[d] == 0
            out[d] = spzeros(0, n_total)
            continue
        end

        n_eq_dims = copy(n_grid)
        n_eq_dims[d] -= 2
        n_eq = prod(n_eq_dims)

        ranges = [collect(1:n_grid[k]) for k in 1:n_dims]
        ranges[d] = collect(1:(n_grid[d] - 2))
        combos = collect(Iterators.product(ranges...))

        w1, w2, w3 = _second_derivative_weights_1d(grids[d])
        scale = smooth[d] * sqrt(n_scattered / n_eq) * (x_max[d] - x_min[d])^2

        rows = Int[]; cols = Int[]; vals = Float64[]
        for (r, t) in enumerate(combos)
            s1 = collect(t); s2 = copy(s1); s3 = copy(s1)
            s2[d] += 1; s3[d] += 2

            c1 = LinearIndices(Tuple(n_grid))[CartesianIndex(Tuple(s1))]
            c2 = LinearIndices(Tuple(n_grid))[CartesianIndex(Tuple(s2))]
            c3 = LinearIndices(Tuple(n_grid))[CartesianIndex(Tuple(s3))]

            wd = s1[d]
            push!(rows, r); push!(cols, c1); push!(vals, scale * w1[wd])
            push!(rows, r); push!(cols, c2); push!(vals, scale * w2[wd])
            push!(rows, r); push!(cols, c3); push!(vals, scale * w3[wd])
        end

        out[d] = sparse(rows, cols, vals, n_eq, n_total)
    end

    return out
end

function _second_derivative_weights_1d(grid)
    x1 = grid[1:end-2]; x2 = grid[2:end-1]; x3 = grid[3:end]
    return (
        2.0 ./ ((x1 .- x3) .* (x1 .- x2)),
        2.0 ./ ((x2 .- x1) .* (x2 .- x3)),
        2.0 ./ ((x3 .- x1) .* (x3 .- x2)),
    )
end

function _local_cell_index(points_per_dim::Int, n_dims::Int)
    values = collect(0:(points_per_dim - 1))
    out = Array{Int}(undef, n_dims, points_per_dim^n_dims)
    for i in 1:n_dims
        a = repeat(values, inner=points_per_dim^(n_dims - i))
        out[i, :] = repeat(a, outer=points_per_dim^(i - 1))
    end
    return out
end

end
