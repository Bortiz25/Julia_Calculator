import Pkg
Pkg.add("Plots")
Pkg.pkg"add Plots#master"

using Plots

# Array{Int64,1}

struct Plotter 
    x_vals::Vector{Float64}
    y_vals::Vector{Float64}
end

function plotGraph(input::Plotter) 
    gui(plot(input.x_vals, input.y_vals))
end 

plt::Plotter = Plotter([0.0,100.0], [3.0, 80.0])

plotGraph(plt)
