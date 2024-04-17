abstract type Equation end

struct Constant <: Equation
  value::Float64
end

struct Variable <: Equation
  value::Char
end

struct OpEquation <: Equation
  left::Equation
  op::Function
  right::Equation
end

struct GroupEquation <: Equation
  group::Equation
end

struct EmptyEquation <: Equation end

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
  '%' => function mod(x,y) return x%y end
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

# replace leftmost EmptyEquation with group
function attachGroup(group::Equation, other_eq::OpEquation, right=false)
  if right
    recur = attachGroup(group, other_eq.right)
    return OpEquation(other_eq.left, other_eq.op, recur)
  else
    recur = attachGroup(group, other_eq.left)
    return OpEquation(recur, other_eq.op, other_eq.right)
  end
end

function attachGroup(group::Equation, other_eq::EmptyEquation)
  return group
end

function sandwichGroup(group::Equation, left::OpEquation, right::OpEquation)
  left_leaf = left
  right_leaf = right
  while left_leaf.right != EmptyEquation()
    try 
      left_leaf = left_leaf.right
    catch
      throw("Expected an OpEquation but got: $left_leaf")
    end
    
  end
  while right_leaf.left != EmptyEquation()
    try 
      right_leaf = right_leaf.left
    catch
      throw("Expected an OpEquation but got: $right_leaf", )
    end
  end
  if funcToPrecedence[left_leaf.op] > funcToPrecedence[right_leaf.op]
    return attachGroup(attachGroup(group, left, true), right)
  else
    return attachGroup(attachGroup(group, right), left, true)
  end
end

function sandwichGroup(group::Equation, left::EmptyEquation, right::EmptyEquation)
  return group
end

function sandwichGroup(group::Equation, left::OpEquation, right::EmptyEquation)
  return attachGroup(group, left, true)
end

function sandwichGroup(group::Equation, left::EmptyEquation, right::OpEquation)
  return attachGroup(group, right)
end

# turns string into series of Equations
function parseEquation(eq_str::String)
  if eq_str == ""
    return EmptyEquation()
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

    left = EmptyEquation()
    right = EmptyEquation()
    if open > 1
      left = parseEquation(eq_str[1:open-1])
    end
    if close < length(eq_str)
      right = parseEquation(eq_str[close+1:length(eq_str)])
    end

    inside = GroupEquation(parseEquation(eq_str[open+1:close-1]))
    return sandwichGroup(inside, left, right)
  end

  lowestPIndex = lowestPrecedence(eq_str)
  # no operations
  if lowestPIndex < 0
    try
      value = parse(Float64, eq_str)
      return Constant(value)
    catch
      # need to support variables too
      throw("Non-operation characters must be numbers.")
    end
  end

  op = eq_str[lowestPIndex]
  eq_op = operation[op]
  left = parseEquation(eq_str[1:lowestPIndex-1])
  right = parseEquation(eq_str[lowestPIndex+1:length(eq_str)])
  return OpEquation(left, eq_op, right)
end

# simplifies series of Equations
function solveEquation(eq::OpEquation) return eq.op(solveEquation(eq.left), solveEquation(eq.right)) end
function solveEquation(eq::GroupEquation) return solveEquation(eq.group) end
function solveEquation(eq::EmptyEquation) return 0 end
function solveEquation(eq::Constant) return eq.value end
function solveEquation(eq::Variable) end

println("Enter an equation:")
equation = readline()
parsed_eq = parseEquation(equation)
println(parsed_eq)
println(solveEquation(parsed_eq))