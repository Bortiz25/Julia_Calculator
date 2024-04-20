import Pkg
Pkg.add("Plots")
Pkg.pkg"add Plots#master"

using Plots
Plots.default(show=true)

# in order for plot to show must run julia -i 
# this will open the repl and keep the graph visible 

struct Plotter 
    x_vals::Vector{Float64}
    y_vals::Vector{Float64}
end

function plotGraph(input::Plotter)
    # use display instead of gui to see in VSCODE (when available), but GUI is interactive
    # gui(plot(input.x_vals, input.y_vals))
    display(plot(input.x_vals, input.y_vals))
end 

# x = range(-100.0,100.0)
# y1 = @. x^2-8*x+12
# y2 = @. ((x-2)^2)-3
# f(x) = 1/x
#plot(f, -3, 3, ylims = (-10, 10))
#plt::Plotter = Plotter(x,y2)

#plotGraph(plt)
# plot(x , range(100.0, -100.0, step=-1.0))