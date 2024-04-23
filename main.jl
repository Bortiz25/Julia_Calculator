include("./graphing.jl")

const base = 2.0
const len = 8.0
const is_round = true
const digits = 10
const exits = Set{String}(["exit", "exit()", "quit", "quit()", "end"])
const step = len / 128
prev = 0.0

# reset per-run variables
function reset()
  global graph = false
  global var_x = -len
end

reset()

abstract type Expression end

struct Constant <: Expression
  value::Float64
end

struct Variable <: Expression
  value::Char
end

struct OpExpression <: Expression
  left::Expression
  op::Function
  right::Expression
end

struct GroupExpression <: Expression
  group::Expression
end

struct FunExpression <: Expression
  funct::Function
  group::Expression
end

struct EmptyExpression <: Expression end

const precedence::Dict{Char, Int8} = Dict(
  '(' => 4,
  '^' => 3,
  '%' => 2,
  '*' => 2,
  '/' => 2,
  '+' => 1,
  '-' => 1
)

const operation::Dict{Char, Function} = Dict(
  '*' => function mult(x,y) return x*y end,
  '/' => function div(x,y) return x/y end,
  '+' => function add(x,y) return x+y end,
  '-' => function sub(x,y) return x-y end,
  '%' => function mod(x,y) return x%y end,
  '^' => function pow(x,y) return x^y end
)

const constant::Dict{String, Function} = Dict(
  "pi" => () -> π,
  "π" => () -> π,
  "e" => () -> ℯ,
  "ℯ" => () -> ℯ,
  "prev" =>  () -> prev,
  "ans" => () -> prev
)

const funct::Dict{String, Function} = Dict(
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

# this is dumb
const funcToPrecedence::Dict{Function, Int8} = Dict(
  pow => 3,
  mult => 2,
  div => 2,
  mod => 2,
  add => 1,
  sub => 1
)

# returns index of operation with higher precedence, returns -1 if there are no operations
function lowestPrecedence(ex_str::String)
  lowestP = 100
  index = -1
  for i in range(length(ex_str), 1, step=-1)
    c = ex_str[i]
    c_precedence = get(precedence, c, 100)
    if c_precedence < lowestP
      lowestP = c_precedence
      index = i
    end
  end
  return index
end

# replace leftmost EmptyExpression with group
function attachGroup(group::Expression, other_ex::OpExpression, right=false)
  if right
    recur = attachGroup(group, other_ex.right)
    return OpExpression(other_ex.left, other_ex.op, recur)
  else
    recur = attachGroup(group, other_ex.left)
    return OpExpression(recur, other_ex.op, other_ex.right)
  end
end

function attachGroup(group::Expression, other_ex::EmptyExpression)
  return group
end

function getLeaf(exp::OpExpression, right=false)
  child = EmptyExpression
  if right
    child = exp.right
  else
    child = exp.left
  end
  leaf = getLeaf(child, right)
  if leaf == EmptyExpression()
    return exp
  else
    return leaf
  end
end

function getLeaf(exp::EmptyExpression, right=false) return exp end
function getLeaf(exp::Union{GroupExpression, FunExpression}, right=false) 
  if right
    return OpExpression(exp, mult, EmptyExpression()) 
  else
    return OpExpression(EmptyExpression(), mult, exp) 
  end
end

function sandwichGroup(group::Expression, left::OpExpression, right::OpExpression)
  left_leaf = getLeaf(left, true)
  right_leaf = getLeaf(right)
  if funcToPrecedence[left_leaf.op] > funcToPrecedence[right_leaf.op]
    return attachGroup(attachGroup(group, left, true), right)
  else
    return attachGroup(attachGroup(group, right), left, true)
  end
end

function sandwichGroup(group::Expression, left::OpExpression, right::Union{GroupExpression, Constant, FunExpression})
  left_leaf = getLeaf(left, true)
  if funcToPrecedence[mult] > funcToPrecedence[left_leaf.op]
    return attachGroup(OpExpression(group, mult, right), left, true)
  else
    return OpExpression(attachGroup(group, left, true), mult, right)
  end
end

function sandwichGroup(group::Expression, left::OpExpression, right::EmptyExpression)
  return attachGroup(group, left, true)
end

function sandwichGroup(group::Expression, left::Constant, right::OpExpression)
  right_leaf = getLeaf(right)
  if funcToPrecedence[mult] > funcToPrecedence[right_leaf.op]
    return attachGroup(OpExpression(left, mult, group), right)
  else
    return OpExpression(left, mult, attachGroup(group, right))
  end
end

function sandwichGroup(group::Expression, left::Constant, right::Union{GroupExpression, Constant, FunExpression})
  return OpExpression(OpExpression(left, mult, group), mult, right)
end

function sandwichGroup(group::Expression, left::Constant, right::EmptyExpression)
  return OpExpression(left, mult, group)
end

function sandwichGroup(group::Expression, left::EmptyExpression, right::OpExpression)
  return attachGroup(group, right)
end

function sandwichGroup(group::Expression, left::EmptyExpression, right::Union{GroupExpression, Constant, FunExpression})
  return OpExpression(group, mult, right)
end

function sandwichGroup(group::Expression, left::EmptyExpression, right::EmptyExpression) return group end

# turns string into series of Expressions
function parseExpression(ex_str::AbstractString)
  ex_str = String(strip(ex_str))
  if ex_str == ""
    return EmptyExpression()
  end
  # grouping
  open = findfirst(==('('), ex_str)
  if !isnothing(open)
    num_open = 1
    close = open
    while num_open > 0 && close < length(ex_str)
      close += 1
      if ex_str[close] == '('
        num_open += 1
      end
      if ex_str[close] == ')'
        num_open -= 1
      end
    end
    if num_open > 0
      throw("No matching close parenthesis found")
    end

    left = EmptyExpression()
    right = EmptyExpression()
    inside = GroupExpression(parseExpression(ex_str[open+1:close-1]))
    if open > 1
      end_left = open - 1
      while ex_str[end_left] == ' ' end_left -= 1 end
      start_funct = end_left
      last_funct = start_funct
      is_funct = false
      while start_funct != 0
        if haskey(funct, ex_str[start_funct: end_left])
          inside = FunExpression(funct[ex_str[start_funct:end_left]], inside)
          is_funct = true
          last_funct = start_funct
        end
        start_funct -= 1
      end
      if is_funct end_left = last_funct - 1 end
      if end_left > 0
        left = parseExpression(ex_str[1:end_left])
      end
    end  

    if close < length(ex_str)
      right = parseExpression(ex_str[close+1:length(ex_str)])
    end

    return sandwichGroup(inside, left, right)
  end

  lowestPIndex = lowestPrecedence(ex_str)
  # no operations
  if lowestPIndex < 0
    index = 1
    ex_str = strip(ex_str)
    while index <= length(ex_str) && (isdigit(ex_str[index]) || ex_str[index] == '.')
      index += 1
    end
    if index > 1
      num = parse(Float64, ex_str[1:index-1])
      if index > length(ex_str)
        return Constant(num)
      end
      recur = parseExpression(ex_str[index:end])
      if recur isa EmptyExpression
        return Constant(num)
      else
        return OpExpression(Constant(num), mult, recur)
      end
    end

    while index <= length(ex_str) && !(isdigit(ex_str[index]) || ex_str[index] == '.' || ex_str[index] == ' ')
      index += 1
    end
    if index > 1
      if ex_str[1:index-1] == "x"
        global graph = true
        recur = parseExpression(ex_str[index:end])
        if recur isa EmptyExpression
          return Variable('x')
        else
          return OpExpression(Variable('x'), mult, recur)
        end
        
      end
      if haskey(constant, ex_str[1:index-1])
        recur = parseExpression(ex_str[index:end])
        if recur isa EmptyExpression
          return Constant(constant[ex_str]())
        else
          return OpExpression(Constant(constant[ex_str]()), mult, recur)
        end
      end 
    end
    throw("invalid string")
  end    

  op = ex_str[lowestPIndex]
  ex_op = operation[op]
  left = parseExpression(ex_str[1:lowestPIndex-1])
  right = parseExpression(ex_str[lowestPIndex+1:length(ex_str)])
  return OpExpression(left, ex_op, right)
end

# simplifies series of Expressions
function solveExpression(ex::OpExpression, x::Float64) return ex.op(solveExpression(ex.left, x), solveExpression(ex.right, x)) end
function solveExpression(ex::GroupExpression, x::Float64) return solveExpression(ex.group, x) end
function solveExpression(ex::FunExpression, x::Float64) return ex.funct(solveExpression(ex.group, x)) end
function solveExpression(ex::EmptyExpression, x::Float64) return 0 end
function solveExpression(ex::Constant, x::Float64) return ex.value end
function solveExpression(ex::Variable, x::Float64) return x end

function loop()
  print("Expression: ")
  expression = readline()

  # pre-parsing, unnecessary if parseExpression called recursively
  if in(expression, exits)
    exit()
  end
  # check if carrying previous answer ("" check is clunky but more efficient than checking starting operation in recursive)
  stripped_exp = lstrip(expression)
  if stripped_exp != "" && haskey(operation, stripped_exp[1])
    parsed_ex = parseExpression("(" * string(prev) * ")" * expression)
  else
    parsed_ex = parseExpression(expression)
  end

  # for debug
  # println(parsed_ex)

  # for graphed equations
  if graph
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
    if is_round solution = round(solution, digits = digits) end
    if isinteger(solution)
      println(Int64(solution))
    else println(solution) end
    global prev = solution
  end
  reset()
  loop()
end

loop()