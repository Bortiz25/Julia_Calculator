# Notes
## To Do
- Parsing
    - Currently, basic operations are implemented, but we will have to implement the following:
    - Variables
        - simple linear and quadratic could have a separate interface from main parser, but will at least require 'x' parsing
        - can avoid parsing other variables if calculator limited to expressions outside of above graphs
    - Constants
        - pi
        - e
    - Functions
        - Logarithms
            - nat log
        - Roots (not strictly necessary bc already have exponent)
        - '=' (depending on how we implement equations)
        - Multiplication (without *)
        - trigonometric functs, inverse trig
    - Errors
        - wondering how we will handle more complex errors. If someone enters a function like sine wrong, for example. Should we give a more detailed message (i.e. highlight the typo/unreadable character) or just error the parsing?
- Settings
    - we have to either enable settings, say via a conf file, or make some choices up front
    - radians vs degrees?
    - fraction output?
    - graph formatting
    - default log base (2, 10)

## Messages/Requests

## Progress