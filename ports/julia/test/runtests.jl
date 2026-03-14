using Test
using SparseArrays

# Load the module directly from src/ (canonical location).
# Alternatively, activate the project and `using RegularizeNd`:
#   julia --project=ports/julia ports/julia/test/runtests.jl
include(joinpath(@__DIR__, "..", "src", "RegularizeNd.jl"))
using .RegularizeNd

function data_2d()
    x1 = collect(range(0.5, 3.5, length=9))
    x2 = collect(range(0.2, 2.8, length=8))
    pts = collect(Iterators.product(x1, x2))
    X = Matrix{Float64}(undef, length(pts), 2)
    y = Vector{Float64}(undef, length(pts))
    for (i, t) in enumerate(pts)
        X[i, 1] = t[1]
        X[i, 2] = t[2]
        y[i] = tanh(t[1] - 1.5) * sin(2pi / 3 * t[2])
    end
    xgrid = [collect(range(minimum(X[:,1]) - 0.1, maximum(X[:,1]) + 0.1, length=14)),
             collect(range(minimum(X[:,2]) - 0.1, maximum(X[:,2]) + 0.1, length=13))]
    return X, y, xgrid
end

function data_1d()
    x = collect(0:0.3:2.7)
    X = reshape(x, :, 1)
    y = sin.(2 .* x) .+ 0.1 .* x
    xgrid = [collect(range(-0.1, 2.8, length=25))]
    return X, y, xgrid
end

@testset "RegularizeNd Julia Port" begin
    X, y, xgrid = data_2d()

    @test_throws ArgumentError regularize_nd(X, y, xgrid[1:1])
    @test_throws ArgumentError regularize_nd(X, y, xgrid; smoothness=[1,2,3])

    for m in ["nearest", "linear", "cubic"]
        yg = regularize_nd(X, y, xgrid; smoothness=5e-3, interp_method=m, solver="normal")
        @test size(yg) == (length(xgrid[1]), length(xgrid[2]))
        @test all(isfinite.(yg))
    end

    X1, y1, g1 = data_1d()
    for s in ["\\", "normal", "lsqr", "pcg", "symmlq"]
        yg = regularize_nd(X1, y1, g1; smoothness=1e-3, interp_method="linear", solver=s)
        @test length(yg) == length(g1[1])
        @test all(isfinite.(yg))
    end

    A, b = monotonic_constraint([collect(1:6)]; dimension=1, dx_min=0.25)
    @test size(A) == (5, 6)
    @test all(sum(abs.(A) .> 0, dims=2) .== 2)
    @test Vector(A[1,1:2]) == [1.0, -1.0]
    @test b == fill(-0.25, 5)
end
