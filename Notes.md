# Notes
## To Do
- Parsing
    - Currently, basic operations are implemented, but we will have to implement the following:
    - ~~Variables~~
        - simple linear and quadratic could have a separate interface from main parser, but will at least require 'x' parsing
        - can avoid parsing other variables if calculator limited to expressions outside of above graphs
    - ~~Constants~~
        - pi
        - e
    - Functions
        - ~~Logarithms~~
            - nat log
        - ~~Roots (not strictly necessary bc already have exponent)~~
        - '=' (depending on how we implement equations)
            - **removed for now, may add back for var assigns**
        - Multiplication (without *)
            - Re-writing main parsing and solving to fix this
        - ~~trigonometric functs, inverse trig~~
    - Errors
        - wondering how we will handle more complex errors. If someone enters a function like sine wrong, for example. Should we give a more detailed message (i.e. highlight the typo/unreadable character) or just error the parsing?
- ~~Settings~~ **May still want to create file, but vars and consts are there**
    - we have to either enable settings, say via a conf file, or make some choices up front
    - radians vs degrees?
    - fraction output?
    - graph formatting
    - default log base (2, 10)

## Messages/Requests

## Progress

## Main Rewrite Plan
I rewrote parsing and plan to rewrite solving. I thought the following design may be easier to work with. It's fairly similar, but I use linked lists to organize the terms, and I think the operations are a bit better systematized. Implicit multiplication is already implemented, and it's my intent that the solver will be easier with the single `Term` abstract type and the very similar concrete types.

- Parts
	- Digits
	- Constants
	- Functions
	- Parentheses
	- Variables
	- Specials
	- Operations

Structure
	
    Initial Setup (vars, consts, functs, structs)
		include graphing
		
		Structs and types
			struct Operator
				operation (function(x,y))
				precedence (integer)
			operators (dictionary)
			
			abst type Term
				(next) operator
				prev node
				next node
			
			struct Terms
				head::Term
				tail::Term
			
			struct priority (dictionary, op to terms) (nvm, not a struct)
			
			struct Parsed expression
				Terms
				Priorities
				
			implemented Term:
				Constant
					+ value (float)
				constants (dictionary)	
				
				Variable
					(no value)
				Group
					+ Terms
					+ Priorities (dict int to Terms)
				Function (applies to next node/term)
					+ Terms (structure)
				functions (dictionary)
				Tail
					- operator
					- next
			Other globals 
				const step (float) = graph length / graph steps
				var graph = false
				var last_graph = false
				var last = empty Terms
		
		Quit strings (set)
		Settings (const)
			base (int) = 10
			rounding digits (int) = 10
			logbase (float) = 2
			angles = "radians"
			graphing
				length (float) = 8
				steps (int) = 128

		Functions
			ParseInput(string (slice))
				new Parsed expression (incl. terms and dict of precedence)
				prev_term (head)
				Loop on chars until end:
					Strip spaces
					(new terms: attach to previous, tail to next)
					Parse variables (x) > Var term, graph = true
					else if Parse Parentheses > Paren term
						Throw error if incomplete
					else if Parse Digits (may start with -, contain .) > Const term
					else if Parse Constants and Functions (may not contain digits, operators, or parens)
						if string a constant > Const term
						else if string a function > Funct term (add immediately to dict with composition (1st priority (not counting parens) operator, use continue to skip operator section)
					else: throw error
					remove spaces
					if end:
						return parsed expression
					Collect char operator (if none, multiply; if invalid, error)
					
	Shell loop
		Ask input
		Create empty expression (linked list of terms)
		Remove whitespace
		check if empty -> return expression with constant term 0
		check if quit string -> quit
		(extra: check if defining statement 'var=')
		check if starts with op, then if '-', if space after -> graph = last_graphed, (last) op parse input (w/o op)
		else: parsed expression = parse input
		last = parsed_expression
		if graph -> display graph using vars, last_graph = true
		else print(solve expression(parsed expression)), last_graph = false
		reset global (graph)