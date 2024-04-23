# comment for quicker testing
# include("./graphing.jl")

# Globals
const exits = Set{String}(["exit", "exit()", "quit", "quit()", "end"])
graph = false
last::Float64 = 0

struct Graphing
    length::Float64
    steps::Int64
end

struct Rounding
    enableRound::Bool
    digits::Int8
end

struct Settings
    base::Int8
    logbase::Float64
    angles::String
    rounding::Rounding
    graphing::Graphing
end

# Default Settings
const settings = Settings(
    Int8(10),
    2.0,
    "radians",
    Rounding(
        true,
        Int8(10)
    ),
    Graphing(
        8.0,
        128
    )
)

const step::Float64 = settings.graphing.length / settings.graphing.steps

struct Operator
    op::Function
    lvl::Int8
end

# Not including composition (for internal use only)
const operators::Dict{Char, Operator} = Dict(
  '+' => Operator(function add(x,y) return x+y end, 1),
  '-' => Operator(function sub(x,y) return x-y end, 1),
  '*' => Operator(function mult(x,y) return x*y end, 2),
  '/' => Operator(function div(x,y) return x/y end, 2),
  '%' => Operator(function mod(x,y) return x%y end, 2),
  '^' => Operator(function pow(x,y) return x^y end, 3)
)

abstract type Term end

mutable struct Head <: Term
    next::Union{Term,Nothing}
end

mutable struct Expression
    tail::Term
    levels::Dict{Int8, Array{Term}}
end

mutable struct Constant <: Term
    value::Float64
    op::Function
    next::Union{Term,Nothing}
end

const constants::Dict{String, Float64} = Dict(
  "pi" => π,
  "π" => π,
  "e" => ℯ,
  "ℯ" => ℯ,
  "prev" => last,
  "last" => last,
  "ans" => last
)

mutable struct Variable <: Term
    op::Function
    next::Union{Term,Nothing}
end

mutable struct FunctionTerm <: Term
    funct::Function
    next::Union{Term,Nothing}
end

const functions::Dict{String, Function} = Dict(
  # trig functions
  "sin" => x -> sin(x),
  "sine" => x -> sin(x),
  "cos" => x -> cos(x),
  "cosine" => x -> cos(x),
  "tan" => x -> tan(x),
  "tangent" => x -> tan(x),
  "sec" => x -> sec(x),
  "secant" => x -> sec(x),
  "cot" => x -> cot(x),
  "cotangent" => x -> cot(x),
  
  # inverse trig
  "arcsin" => x -> asin(x),
  "asin" => x -> asin(x),
  "arcsine" => x -> asin(x),
  "arccos" => x -> acos(x),
  "acos" => x -> acos(x),
  "arccosine" => x -> acos(x),
  "arctan" => x -> x -> atan(x),
  "atan" => x -> atan(x),
  "arctangent" => x -> atan(x),
  "arcsec" => x -> asec(x),
  "asec" => x -> asec(x),
  "arcsecant" => x -> asec(x),
  "arccot" => x -> acot(x),
  "acot" => x -> acot(x),
  "arccotangent" => x -> acot(x),

  #logarithms
  "log" => x -> log(base, x),
  "ln" => x -> log(x),

  # roots
  "sqrt" => x -> sqrt(x),
  "cbrt" => x -> cbrt(x)
)

mutable struct Group <: Term
    expr::Expression
    op::Function
    next::Union{Term,Nothing}
end

function newExpr()
    return Expression(Head(nothing),Dict())
end

last_graph::Expression = newExpr()

function parseInput(input::AbstractString)
    
    # Create parsed expression (eventual retval)
    expr = newExpr()

    # iter through string
    index = 1
    len = length(input)
    while index <= len
        # strip spaces in front of input
        if input[index] == ' '
            index += 1
            continue
        end
        start = index
        # parse negative
        if input[index] == '-'
            expr.tail.next = Constant(-1, div(x,y), nothing)
            index += 1
        # parse variables
        elseif input[index] == 'x'
            global graph = true
            expr.tail.next = Variable(x->x, nothing)
            index += 1
        # parse parentheses
        elseif input[index] == '('
            open = 1
            close = 0
            index += 1
            # check if valid
            while open > close && index <= len
              if input[index] == '(' open += 1 
              elseif input[index] == ')' close += 1 end
              index += 1
            end
            if (open != close) throw("Couldn't parse "*input[start:index]*": bad parentheses") end
            # parse inside, add to expression
            if index - start == 1 throw("Couldn't parse "*input[start:index]*": empty parentheses")
            else expr.tail.next = Group(parseInput(input[start+1:index-2]), x->x, nothing) end
        else
            # parse digits
            while index <= len && (isdigit(input[index]) || input[index] == '.') index += 1 end
            if start != index
                try  
                    parse(Float64, input[start:index-1])
                catch
                    throw("Couldn't parse "*input[start:index-1]*": bad digits")
                end
                expr.tail.next = Constant(parse(Float64, input[start:index-1]), x->x, nothing)
            # parse constants and functions
            else
                while index<=len && !(isdigit(input[index])||input[index]=='.'||input[index]=='(') index+=1 end
                if haskey(constants, input[start:index-1])
                    expr.tail.next = Constant(constants[input[start:index-1]], x->x, nothing)
                elseif haskey(functions, input[start:index-1])
                    expr.tail.next = FunctionTerm(functions[input[start:index-1]], nothing)
                    expr.tail = expr.tail.next
                    # hardcoded - insert function term into precedence (levels) dict
                    if (haskey(expr.levels, 4))
                        expr.levels[4][2].prev = expr.tail
                        expr.levels[4][2] = expr.tail
                    else expr.levels[4] = [Head(expr.tail), expr.tail] end
                    continue
                else throw("Couldn't parse "*input[start:index-1]*": no matching constant or function.") end
            end
        end
        expr.tail = expr.tail.next
        
        # Parse operation (function operation is continue so it skips)
        # Remove spaces
        while index <= len && input[index] == ' '
            index += 1
            continue
        end
        # Return if end
        if index > len
            return expr
        end

        if haskey(operators, input[index])
            expr.tail.op = operators[input[index]].op
            if haskey(expr.levels, operators[input[index]].lvl)
                expr.levels[operators[input[index]].lvl][2].prev = expr.tail
                expr.levels[operators[input[index]].lvl][2] = expr.tail
            else
                expr.levels[operators[input[index]].lvl] = Term[Head(expr.tail), expr.tail]
            end
            index += 1
        elseif index < len
            expr.tail.op = (x,y) -> x*y
            if haskey(expr.levels, 2)
                expr.levels[2][2].prev = expr.tail
                expr.levels[2][2] = expr.tail
            else expr.levels[2] = [Head(expr.tail), expr.tail] end
        end
    end
    # Should not be reachable because if index > len return expr
    throw("Control flow error: parsing exited without returning parsed expression.")
end

function loop()
    print("Expression: ")
    expression = readline()

    # pre-parsing, unnecessary if parseInput called recursively
    if in(expression, exits)
        exit()
    end
    # check if carrying previous answer ("" check is clunky but more efficient than checking starting operation in recursive)
    stripped_exp = lstrip(expression)
    if stripped_exp != "" && haskey(operators, stripped_exp[1])
        if length(stripped_exp) > 1 && stripped_exp[2] != ' ' && stripped_exp[1] == '-'
        parsed_ex = parseInput("0" * expression)
        else parsed_ex = parseInput("(" * string(prev) * ")" * expression) end
    else parsed_ex = parseInput(expression) end

    # for debug
    println(parsed_ex)
    
    #=
    # for graphed equations
    if graph
        global last_graph = parsed_ex
        x_vals = Vector{Float64}([])
        y_vals = Vector{Float64}([])
        while var_x <= len
        push!(x_vals, var_x)
        push!(y_vals, solveExpression(parsed_ex,var_x))
        global var_x += step 
        end
        plotGraph(Plotter(x_vals,y_vals))
        println("See graph")
    else
        # for expressions, print integers properly, round floats to conceal error
        solution = solveExpression(parsed_ex, 0.0)
        global last = solution
        if settings.rounding.enableRound solution = round(solution, digits = digits) end
        if isinteger(solution)
        println(Int64(solution))
        else println(solution) end
    end
    =#
    
    global graph = false
    
    loop()
end
  
loop()
