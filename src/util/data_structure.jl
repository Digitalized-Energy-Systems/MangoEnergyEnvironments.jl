export pycallunwrap

using PyCall

struct DotDict{K,V}
    dict::Dict{K,V}
end

function Base.getproperty(dd::DotDict, s::Symbol)
    if s in fieldnames(typeof(dd))
        return getfield(dd, s)
    else
        return dd.dict[String(s)]
    end
end

np_bool = pyimport("numpy").bool_
np_int = pyimport("numpy").integer
np_float = pyimport("numpy").floating
py_bool  = pyimport("builtins").bool
py_int   = pyimport("builtins").int
py_float = pyimport("builtins").float
py_str   = pyimport("builtins").str
py_list  = pyimport("builtins").list
py_dict  = pyimport("builtins").dict

function pycallunwrap(o::PyObject)
    @error o[:__class__]
    if pyisinstance(o, np_bool)
        return Bool(o)
    elseif pyisinstance(o, np_int)
        return Int(o)
    elseif pyisinstance(o, np_float)
        return Float64(o)
    elseif pyisinstance(o, py_bool)
        return Bool(o)
    elseif pyisinstance(o, py_int)
        return Int(o)
    elseif pyisinstance(o, py_float)
        return Float64(o)
    elseif pyisinstance(o, py_str)
        return String(o)
    elseif pyisinstance(o, py_list)
        return [pycallunwrap(item) for item in o]
    elseif pyisinstance(o, py_dict)
        return Dict(pycallunwrap(k) => pycallunwrap(v) for (k,v) in o)
    else
        return o
    end
end