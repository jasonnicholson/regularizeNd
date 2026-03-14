# 2D Solver Comparison Example
# Port of Examples/example_solver_differences.m
#
# Demonstrates the difference between the 'normal' and '\\' solvers on a
# 2-D scattered dataset with added noise.
#
# Run from any directory:
#   julia ports/julia/examples/example_2d.jl

include(joinpath(@__DIR__, "..", "src", "RegularizeNd.jl"))
using .RegularizeNd

using Random: seed!, rand
seed!(42)

# Build a 2-D scattered dataset on a regular grid
x = collect(0.5:0.1:4.5)
y = collect(0.5:0.1:5.5)

# ndgrid-style: xx[i,j] = x[i], yy[i,j] = y[j]
xx = repeat(x, 1, length(y))
yy = repeat(y', length(x), 1)

z = tanh.(xx .- 3) .* sin.(2π / 6 .* yy)
noise = (rand(size(xx)) .- 0.5) .* xx .* yy ./ 30
z_noise = z .+ noise

# Scale x axis (demonstrates axis-independent smoothness handling)
x_scale = 100
xx_scaled = x_scale .* xx
x_scaled = x_scale .* x

# Lookup-table grid (smaller than MATLAB example for speed)
x_grid = [collect(LinRange(0, x_scale * 6, 21)), collect(LinRange(0, 6.6, 20))]
smoothness = 0.001

pts = hcat(vec(xx_scaled), vec(yy))

println("Solving with 'normal' solver...")
z_grid_normal = regularize_nd(pts, vec(z_noise), x_grid; smoothness=smoothness, solver="normal")

println("Solving with '\\\\' solver...")
z_grid_backslash = regularize_nd(pts, vec(z_noise), x_grid; smoothness=smoothness, solver="\\")

max_diff = maximum(abs.(z_grid_normal .- z_grid_backslash))
println("Output shape:          $(size(z_grid_normal))")
println("Max solver difference: $(round(max_diff, sigdigits=3))")

println("\nFirst 3×3 block of 'normal' result:")
display(round.(z_grid_normal[1:3, 1:3], digits=4))
