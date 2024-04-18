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
function lowestPrecedence(eq_str::String)
  lowestP = 100
  index = -1
  for i in range(length(eq_str), 1, step=-1)
    c = eq_str[i]
    c_precedence = get(precedence, c, 100)
    if c_precedence < lowestP
      lowestP = c_precedence
      index = i
    end
  end
  return index
end

# replace leftmost EmptyExpression with group
function attachGroup(group::Expression, other_eq::OpExpression, right=false)
  if right
    recur = attachGroup(group, other_eq.right)
    return OpExpression(other_eq.left, other_eq.op, recur)
  else
    recur = attachGroup(group, other_eq.left)
    return OpExpression(recur, other_eq.op, other_eq.right)
  end
end

function attachGroup(group::Expression, other_eq::EmptyExpression)
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
function parseExpression(eq_str::String)
  if eq_str == ""
    return EmptyExpression()
  end

  # grouping
  open = findfirst(==('('), eq_str)
  if !isnothing(open)
    num_open = 1
    close = open
    while num_open > 0 && close < length(eq_str)
      close += 1
      if eq_str[close] == '('
        num_open += 1
      end
      if eq_str[close] == ')'
        num_open -= 1
      end
    end
    if num_open > 0
      throw("No matching close parenthesis found")
    end

    left = EmptyExpression()
    right = EmptyExpression()
    if open > 1
      left = parseExpression(eq_str[1:open-1])
    end
    if close < length(eq_str)
      right = parseExpression(eq_str[close+1:length(eq_str)])
    end

    inside = GroupExpression(parseExpression(eq_str[open+1:close-1]))
    return sandwichGroup(inside, left, right)
  end

  lowestPIndex = lowestPrecedence(eq_str)
  # no operations
  if lowestPIndex < 0
    try
      if eq_str == "x"
        return Variable('x')
      else 
        value = parse(Float64, eq_str)
        return Constant(value)
      end
    catch
      # need to support variables too
      throw("Non-operation characters must be numbers.")
    end
  end

  op = eq_str[lowestPIndex]
  eq_op = operation[op]
  left = parseExpression(eq_str[1:lowestPIndex-1])
  right = parseExpression(eq_str[lowestPIndex+1:length(eq_str)])
  return OpExpression(left, eq_op, right)
end

# simplifies series of Expressions
function solveExpression(eq::OpExpression, x::Float64) return eq.op(solveExpression(eq.left, x), solveExpression(eq.right, x)) end
function solveExpression(eq::GroupExpression, x::Float64) return solveExpression(eq.group, x) end
function solveExpression(eq::EmptyExpression, x::Float64) return 0 end
function solveExpression(eq::Constant, x::Float64) return eq.value end
function solveExpression(eq::Variable, x::Float64) return x end

const len = 10.0
step = len * 0.01
graph = false
var_x = -1.0 * len

println("Enter an expression:")
expression = replace(readline(), ' ' => "")
if startswith(expression, "y=")
  graph = true
  expression = expression[3:end]
end
parsed_eq = parseExpression(expression)
println(parsed_eq)
if graph
  coords::Array{Tuple{Float64, Float64}} = []
  while var_x <= len
    push!(coords, tuple(var_x,solveExpression(parsed_eq,var_x)))
    global var_x += step 
  end
  println(coords)
end
println(solveExpression(parsed_eq, 0.0))