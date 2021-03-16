struct VariableUnit end
struct VariableConnectType end
Symbolics.option_to_metadata_type(::Val{:unit}) = VariableUnit
Symbolics.option_to_metadata_type(::Val{:connect}) = VariableConnectType

"""
$(SIGNATURES)

Takes a list of pairs of `variables=>values` and an ordered list of variables
and creates the array of values in the correct order with default values when
applicable.
"""
function varmap_to_vars(varmap, varlist; defaults=Dict())
    if varmap isa DiffEqBase.NullParameters || isempty(varmap)
        varmap = Dict()
    end
    T = typeof(varmap)
    container_type = T <: Dict ? Array : T

    if eltype(varmap) <: Pair
        varmap isa Dict || (varmap = Dict(varmap))
        rules = Dict(varmap)
        vals = _varmap_to_vars(varmap, varlist; defaults=defaults)
    end
    if isempty(vals)
        return nothing
    elseif container_type <: Tuple
        (vals...,)
    else
        SymbolicUtils.Code.create_array(container_type, eltype(vals), Val(length(vals)), vals...)
    end
end

function _varmap_to_vars(varmap::Dict, varlist; defaults=Dict())
    varmap = merge(defaults, varmap) # prefers the `varmap`
    varmap = Dict(Symbolics.diff2term(value(k))=>value(varmap[k]) for k in keys(varmap))
    # resolve symbolic parameter expressions
    for (p, v) in pairs(varmap)
        varmap[p] = fixpoint_sub(v, varmap)
    end
    T′ = eltype(values(varmap))
    T = Base.isconcretetype(T′) ? T′ : Base.promote_typeof(values(varmap)...)
    out = Vector{T}(undef, length(varlist))
    missingvars = setdiff(varlist, keys(varmap))
    isempty(missingvars) || throw(ArgumentError("$missingvars are missing from the variable map."))

    for (i, var) in enumerate(varlist)
        out[i] = varmap[var]
    end
    out
end
