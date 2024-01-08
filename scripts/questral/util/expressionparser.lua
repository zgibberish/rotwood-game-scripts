local kstring = require "util.kstring"
local lpeg = require("lpeg")


local character = lpeg.R("az", "AZ", "09") + lpeg.S"_"
local spc = lpeg.S(" \t\n")^0
local name = lpeg.C( (lpeg.R("az", "AZ") + lpeg.S"_") * (lpeg.R("az", "AZ", "09") + lpeg.S"_")^0 )
local expr = lpeg.P{
    "THEEXPR";
    THEEXPR = lpeg.V("EXPR")*spc*-1,
    EXPR = ( lpeg.V("TERM") * spc * lpeg.V("BINOP") * spc * lpeg.V("EXPR") +
             lpeg.V("TERM") ) / function(a,b,c) if a and b and c then return {op=b, left=a, right=c} else return a end end,
    BINOP = lpeg.C( lpeg.P("and")*(-character) + lpeg.P("or")*(-character)),
    TERM = lpeg.C((lpeg.P("not")*(-character))^0) *spc* ( "(" * lpeg.V("EXPR") * ")" * spc + 
             lpeg.V("NAME")) / function(a,b) if a == "not" then return {op = "not", left = b} else return b end end,
    
    NAME = (name - (lpeg.P("and")*(-character) + lpeg.P("or")*(-character) +lpeg.P("not")*(-character))) / function(a) return {term = a} end,
}


local function GetTreeVal(node, term_fn)
    if node.op == "and" then
        return GetTreeVal(node.left, term_fn) and GetTreeVal(node.right, term_fn)
    elseif node.op == "or" then
        return GetTreeVal(node.left, term_fn) or GetTreeVal(node.right, term_fn)
    elseif node.op == "not" then
        return not GetTreeVal(node.left, term_fn)
    elseif node.term then
        
        if term_fn then
            return term_fn(node.term) 
        else
            return node.term
        end
    end

    return false
end


local function Evaluate(expression, value_get_fn)
    local str = kstring.trim(expression or "")
    local tree = expr:match(str)
    --print (serpent.block(tree))
    if not tree then
        LOGWARN("Bad expression syntax: '%s'", expression or "")
    end
    
    if tree then
        return GetTreeVal(tree, value_get_fn)
    end

end

return {Evaluate = Evaluate}
