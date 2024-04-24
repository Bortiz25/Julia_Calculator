# comment for quicker testing
# calc separates parsing and solving for benefit of graphing, but underlying design is slower for non-variable expressions
    # UNFORTUNATELY, solveExpression mutates the expression passed via parsed expression when simplifying down, thus breaking variables
    # The caveman approach (modifying the input before sending it to parser to substitute x value) would have worked better
    # and would simplify the whole 'parsing segment, as parentheses and functions could be cleared recursively before continuing to parse
#include("./graphing.jl")

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
    digits::Int
end

struct Settings
    base::Int
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

# reserved levels: 4 for functs (composition), 5 for vars, 6 for parens 
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
    lnext::Union{Term,Nothing}
    vnext::Union{Term,Nothing}
    gnext::Union{Term,Nothing}
    fnext::Union{Term,Nothing}
end

mutable struct LevelHead <: Term
end

mutable struct Expression
    tail::Term
    levels::Dict{Int8, Array{Term}}
end

mutable struct Constant <: Term
    value::Float64
    op::Function
    prev::Term
    next::Union{Term,Nothing}
    lnext::Union{Term,Nothing}
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
    # for constant value after solving
    value::Float64
    op::Function
    prev::Term
    next::Union{Term,Nothing}
    lnext::Union{Term,Nothing}
    vnext::Union{Term,Nothing}
end

mutable struct FunctionTerm <: Term
    funct::Function
    prev::Term
    # must have value but can't when it is first set
    next::Union{Term,Nothing}
    fnext::Union{Term,Nothing}
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
    # for constantvalue after solving
    value::Float64
    expr::Expression
    op::Function
    prev::Term
    next::Union{Term,Nothing}
    lnext::Union{Term,Nothing}
    gnext::Union{Term,Nothing}
end

function newExpr()
    return Expression(Head(nothing,nothing,nothing,nothing,nothing),Dict())
end

last_graph::Expression = newExpr()

function parseInput(input::AbstractString)
    # always strip before recursive call
    if input == "" throw("Couldn't parse empty input") end
    
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
            if index == len || haskey(operators, input[index]) throw("Couldn't parse " * input[index] *": bad negative") end
            expr.tail.next = Constant(-1, mult(x,y), expr.tail, nothing, nothing)
            index += 1
        # parse variables
        elseif input[index] == 'x'
            global graph = true
            expr.tail.next = Variable(0.0, x->x, expr.tail, nothing, nothing, nothing)
            index += 1
            # insert variable term into variable dict
            if (haskey(expr.levels, 4))
                expr.levels[5][2].vnext = expr.tail.next
                expr.levels[5][2] = expr.tail.next
            else expr.levels[5] = [Head(nothing,nothing,expr.tail.next,nothing,nothing), expr.tail.next] end
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
            if (open != close) throw("Couldn't parse "*input[start:index-1]*": bad parentheses")
            # parse inside, add to expression
            else 
                println(strip(input[start+1:index-2]))
                expr.tail.next = Group(0.0, parseInput(strip(input[start+1:index-2])), x->x, expr.tail, nothing, nothing, nothing)
                # hardcoded - insert parentheses term into 6th level
                if (haskey(expr.levels, 6))
                    expr.levels[6][2].gnext = expr.tail.next
                    expr.levels[6][2] = expr.tail.next
                else expr.levels[6] = [Head(nothing,nothing,nothing,expr.tail.next,nothing), expr.tail.next] end
            end
        else
            # parse digits
            while index <= len && (isdigit(input[index]) || input[index] == '.') index += 1 end
            if start != index
                try  
                    parse(Float64, input[start:index-1])
                catch
                    throw("Couldn't parse "*input[start:index-1]*": bad digits")
                end
                println(parse(Float64, input[start:index-1]))
                expr.tail.next = Constant(parse(Float64, input[start:index-1]), x->x, expr.tail, nothing, nothing)
            # parse constants and functions
            else
                while index<=len && !(isdigit(input[index])||input[index]=='.'||input[index]==' '||input[index]=='('||haskey(operators,input[index])) index+=1 end
                if haskey(constants, input[start:index-1])
                    expr.tail.next = Constant(constants[input[start:index-1]], x->x, expr.tail, nothing, nothing)
                elseif haskey(functions, input[start:index-1])
                    expr.tail.next = FunctionTerm(functions[input[start:index-1]], expr.tail, nothing, nothing)
                    expr.tail = expr.tail.next
                    # hardcoded - insert function term into precedence (levels) dict
                    if (haskey(expr.levels, 4))
                        expr.levels[4][2].fnext = expr.tail
                        expr.levels[4][2] = expr.tail
                    else expr.levels[4] = [Head(nothing,nothing,nothing,nothing,expr.tail), expr.tail] end
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
                expr.levels[operators[input[index]].lvl][2].lnext = expr.tail
                expr.levels[operators[input[index]].lvl][2] = expr.tail
            else
                expr.levels[operators[input[index]].lvl] = Term[Head(nothing,expr.tail,nothing,nothing,nothing), expr.tail]
            end
            index += 1
        elseif index < len
            expr.tail.op = (x,y) -> x*y
            if haskey(expr.levels, 2)
                expr.levels[2][2].lnext = expr.tail
                expr.levels[2][2] = expr.tail
            else expr.levels[2] = [Head(nothing,expr.tail,nothing,nothing,nothing), expr.tail] end
        end
    end
    # Should not be reachable because if index > len return expr
    throw("Control flow error: parsing exited without returning parsed expression.")
end

function solveExpression(expr::Expression, var::Float64)
    # PEMDAS levels still hardcoded 4 (function composition) to 1 (add and subtract)
    result::Float64 = 0
    # Convert group to constant
    if haskey(expr.levels, 6)
        term = expr.levels[6][1]
        while !isnothing(term.gnext)
            term.gnext.value = solveExpression(term.gnext.expr, var)
            expr.tail = term.gnext
            term = term.gnext
        end
    end
    # Convert var to constant
    if haskey(expr.levels, 5)
        term = expr.levels[5][1]
        while !isnothing(term.vnext)
            println(term.vnext)
            term.vnext.value = var
            expr.tail = term.vnext
            term = term.vnext
        end
    end
    if haskey(expr.levels, 4)
        term = expr.levels[4][1]
        while !isnothing(term.fnext)
            # what if nested function???
            if term.fnext.next isa FunctionTerm
                throw("Nested functions require parentheses")
            end
            term.fnext.next.value = term.fnext.funct(term.fnext.next.value)
            term.fnext.prev.next = term.fnext.next
            term.fnext.next.prev = term.fnext.prev
            expr.tail = term.fnext.next
            term = term.fnext
        end
    end
    # Constants (everything should be)
    lvl = 3
    while lvl > 0
        if(haskey(expr.levels, lvl))
            term = expr.levels[lvl][1]
            while !isnothing(term.lnext)
                term.lnext.next.value = term.lnext.op(term.lnext.value, term.lnext.next.value)
                term.lnext.prev.next = term.lnext.next
                if !isnothing(term.lnext.next) term.lnext.next.prev = term.lnext.prev end
                term = term.lnext
                expr.tail = term.next
            end
        end
        lvl -= 1
    end
    return expr.tail.value
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
        parsed_ex = parseInput("0" * stripped_exp)
        else parsed_ex = parseInput("(" * string(prev) * ")" * stripped_exp) end
    else parsed_ex = parseInput(stripped_exp) end
    # for debug
    # println(parsed_ex)
    
    # for graphed equations
    if graph
        global last_graph = parsed_ex
        var_x::Float64 = -settings.graphing.length
        x_vals = Vector{Float64}([])
        y_vals = Vector{Float64}([])
        while var_x <= settings.graphing.length
            push!(x_vals, var_x)
            push!(y_vals, solveExpression(parsed_ex,var_x))
            var_x += step 
        end
        plotGraph(Plotter(x_vals,y_vals))
        println("See graph")
    else
        # for expressions, print integers properly, round floats to conceal error
        solution = solveExpression(parsed_ex, 0.0)
        global last = solution
        if settings.rounding.enableRound solution = round(solution, digits=settings.rounding.digits) end
        if isinteger(solution)
        println(Int64(solution))
        else println(solution) end
    end
    
    global graph = false
    
    loop()
end
  
loop()
