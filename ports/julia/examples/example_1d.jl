# 1D Regularization Example
# Port of Examples/example1D.m
#
# Dataset from:
# https://mathformeremortals.wordpress.com/2013/01/29/
#   introduction-to-regularizing-with-2d-data-part-1-of-3/
#
# Run from any directory:
#   julia ports/julia/examples/example_1d.jl

include(joinpath(@__DIR__, "..", "src", "RegularizeNd.jl"))
using .RegularizeNd

# Scattered input/output data
x = reshape(Float64[0, 0.55, 1.1, 2.6, 2.99], :, 1)
y = Float64[1, 1.1, 1.5, 2.5, 1.9]

# Two grids: one coarse, one fine
x_grid_coarse = [Float64[-0.50, 0.0, 0.50, 1.0, 1.50, 2.0, 2.50, 3.0, 3.30, 3.60]]
x_grid_fine   = [collect(-0.5:0.1:3.6)]

smoothness = 5e-3

y_grid_coarse = regularize_nd(x, y, x_grid_coarse; smoothness=smoothness)
y_grid_fine   = regularize_nd(x, y, x_grid_fine;   smoothness=smoothness)

println("Coarse grid: $(length(y_grid_coarse)) points, " *
        "range [$(round(minimum(y_grid_coarse), digits=3)), " *
        "$(round(maximum(y_grid_coarse), digits=3))]")
println("Fine grid:   $(length(y_grid_fine)) points, " *
        "range [$(round(minimum(y_grid_fine), digits=3)), " *
        "$(round(maximum(y_grid_fine), digits=3))]")

println("\nFirst 5 coarse-grid values: $(round.(y_grid_coarse[1:5], digits=4))")
println("First 5 fine-grid values:   $(round.(y_grid_fine[1:5], digits=4))")
