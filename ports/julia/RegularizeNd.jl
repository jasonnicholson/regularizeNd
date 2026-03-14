# Backward-compatibility shim — the module source lives in src/RegularizeNd.jl.
# For proper package usage, activate the project and then `using RegularizeNd`:
#
#   import Pkg
#   Pkg.activate(joinpath(@__DIR__, "."))   # from within ports/julia/
#   using RegularizeNd
#
# To run tests:  julia --project=ports/julia ports/julia/test/runtests.jl
include(joinpath(@__DIR__, "src", "RegularizeNd.jl"))
