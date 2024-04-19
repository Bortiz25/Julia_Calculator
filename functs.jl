# cut-down trie containing functions based on their string
struct FunctionTrie{}

    funct::Function
    children::Dict{Char, FunctionTrie}
    
    function FunctionTrie(entries::Dict{String, Function})
        # Sort input to be alphabetical, then to be from shortest to longest, so trie will be sorted, but might not matter unless ordereddict 
        sorted_entries = Array{Tuple{String, Function}}(undef, 0)
        for key in sort(collect(keys(entries)))
            push!(sorted_entries, (key, entries[key]))
        end
        return FunctionTrie(() -> missing, sort(sorted_entries, by = entry -> length(entry[1])))
    end
    # How could this constructor be private? It doesn't really matter but I think it's supposed to be
    function FunctionTrie(funct::Function, sorted_family::Array{Tuple{String, Function}})
        children = Dict{Char, FunctionTrie}()
        temp_children = Dict{Char, Array{Tuple{String,Function}}}()
        for heir in sorted_family
            if haskey(temp_children, heir[1][1]) 
                println((heir[1][2:end], heir[2]))
                push!(temp_children[heir[1][1]],(heir[1][2:end], heir[2]))
            else temp_children[heir[1][1]] = [(heir[1][2:end], heir[2])] end
        end
        for (key, family) in temp_children
            if family[1][1] == "" children[key] = FunctionTrie(family[1][2], family[2:end])
            else children[key] = FunctionTrie(() -> missing, family) end
        end
        return new(funct, children)
    end
end

# add methods to check and return if function found, check if a funct is at greater depth
functions = Dict("sin" => sin, "cosine" => cos, "sine" => sin, "cos" => cos)
functs_trie = FunctionTrie(functions)
