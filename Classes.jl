module Classes
# extension: a non-class concrete parent just inherits the fields, without supertype

export @class

#=
immutable ClassType
    fields::Vector{Expr}
end # ClassType

class_auto_add = true # false would mean throw error if parent fields not present
class_data = Dict{Symbol,ClassType}
=#

function merge_block!(x::Expr, y::Expr)
    @assert(x.head == :block && y.head == :block, 
    	    "merge_block!() only works on block (a.k.a. quote) expressions")
    append!(x.args, y.args)
    return x
end # merge_block!

# The @class macro does very little direct evaluation. It instead returns a set of expressions
# to be evaluated in the calling context.
macro class(def)
    @assert(typeof(def) == Expr && def.head == :type, "@class requires a type definition as argument")

    if typeof(def.args[2]) == Expr && def.args[2].head == :<:
        name = def.args[2].args[1]
        dec_parent = def.args[2].args[2]
    else # superclass specified
        name = def.args[2]
        dec_parent = Symbol("")
        def.args[2] = Expr(:<:, name, name) # creates dummy parent space
    end # else superclass specified
    ac_name = symbol("AC$name")
    def.args[2].args[2] = ac_name

    Qac_name    = QuoteNode(ac_name)
    ret = quote
        local ex = $(QuoteNode(def)) 
        ac_name  = $Qac_name
    end # quote

    if dec_parent == symbol("")
        tmp = quote 
            abstract $ac_name
        end # quote
    else #  dec_parent == symbol("")
        Qdec_parent = QuoteNode(dec_parent)
        Qacd_parent = QuoteNode(symbol("AC" * string(dec_parent)))
        tmp = quote
            local nparent
            if $dec_parent.abstract
                nparent = eval($Qdec_parent)
            else
                @assert(isdefined($Qacd_parent), 
                    "specified parent \"$dec_parent\" must be either abstract or declared with @class")
                nparent = eval($Qacd_parent)
                prepend!(ex.args[3].args, 
                     [Expr(:(::), n, t) for (n, t) in zip(fieldnames($dec_parent), $dec_parent.types)])
            end
            eval(Expr(:abstract, Expr(:<:, $Qac_name, nparent))) # probably could do this with QuoteNodes
        end
    end # else dec_parent == symbol("")
    merge_block!(ret, tmp)

    # could just push!() a parse() result, this is more uniform, cleaner & more expandable
    tmp = quote
        eval(ex)
    end
    merge_block!(ret, tmp)

    return esc(ret)
end # @class

end # Classes
