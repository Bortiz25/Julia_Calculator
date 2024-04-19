# include("./graphing.jl")


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

# this is dumb
const funcToPrecedence::Dict{Function, Int8} = Dict(
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

function sandwichGroup(group::Expression, left::OpExpression, right::OpExpression)
  left_leaf = left
  right_leaf = right
  while left_leaf.right != EmptyExpression()
    try 
      left_leaf = left_leaf.right
    catch
      throw("Expected an OpExpression but got: $left_leaf")
    end
    
  end
  while right_leaf.left != EmptyExpression()
    try 
      right_leaf = right_leaf.left
    catch
      throw("Expected an OpExpression but got: $right_leaf", )
    end
  end
  if funcToPrecedence[left_leaf.op] > funcToPrecedence[right_leaf.op]
    return attachGroup(attachGroup(group, left, true), right)
  else
    return attachGroup(attachGroup(group, right), left, true)
  end
end

function sandwichGroup(group::Expression, left::EmptyExpression, right::EmptyExpression)
  return group
end

function sandwichGroup(group::Expression, left::OpExpression, right::EmptyExpression)
  return attachGroup(group, left, true)
end

function sandwichGroup(group::Expression, left::EmptyExpression, right::OpExpression)
  return attachGroup(group, right)
end

# turns string into series of Expressions
function parseExpression(ex_str::String)
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
    if open > 1
      left = parseExpression(ex_str[1:open-1])
    end
    if close < length(ex_str)
      right = parseExpression(ex_str[close+1:length(ex_str)])
    end

    inside = GroupExpression(parseExpression(ex_str[open+1:close-1]))
    return sandwichGroup(inside, left, right)
  end

  lowestPIndex = lowestPrecedence(ex_str)
  # no operations
  if lowestPIndex < 0
    try
      if ex_str == "x"
        return Variable('x')
      else 
        value = parse(Float64, ex_str)
        return Constant(value)
      end
    catch
      # need to support variables too
      throw("Non-operation characters must be numbers.")
    end
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
function solveExpression(ex::EmptyExpression, x::Float64) return 0 end
function solveExpression(ex::Constant, x::Float64) return ex.value end
function solveExpression(ex::Variable, x::Float64) return x end

const len = 8.0
step = len / 128
graph = false
var_x = -1.0 * len

println("Enter an expression:")
expression = replace(readline(), ' ' => "")
if startswith(expression, "y=")
  graph = true
  expression = expression[3:end]
end
parsed_ex = parseExpression(expression)
println(parsed_ex)
if graph
  coords::Array{Tuple{Float64, Float64}} = []
  while var_x <= len
    push!(coords, tuple(var_x,solveExpression(parsed_ex,var_x)))
    global var_x += step 
  end
  println(coords)
end
println(solveExpression(parsed_ex, 0.0))