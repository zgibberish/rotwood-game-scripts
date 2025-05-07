local Enum = require "util.enum"
local inspect = require "inspect"
local loc = require "questral.util.loc"


local Validator = Class(function(self, ...) self:init(...) end)


Validator.UNDEFINED_ASSET = "" -- A dummy property to satisfy Req(), without needing to specify a valid asset.


function Validator:init()
    self.fields = {} -- Map of 'name' -> validator table
    self.fields_array = {} -- Array of validator tables, for deterministic evaluation
end

function Validator.InheritClass( class, key )
    assert( Class.IsClass( class ), "InheritClass must be called with a Class" )
    assert( key )

    -- Check if a base class has a validator already defined
    local validator
    local base_class = class
    while base_class do
        local class_validator = rawget(base_class, key )
        if class_validator then
            validator = class_validator:Clone()
            break
        end
        base_class = base_class._base
    end

    -- No base validator, construct a fresh one
    if not validator then
        validator = Validator()
    end

    rawset( class, key, validator )
    return validator
end


function Validator:Clone()
    local copy = Validator()
    copy.fields = shallowcopy(self.fields)
    copy.fields_array = shallowcopy(self.fields_array)
    copy.silent = self.silent
    return copy
end

function Validator:Silent( silent )
    self.silent = silent
    return self
end

function Validator:IsSilent()
    return self.silent
end

function Validator:HasReq()
    for i, v in ipairs( self.fields_array ) do
        if v.required then
            return true
        end
    end

    return false
end

function Validator:OptSubVal(name, validator)
    assert( Validator.is_instance(validator))
    return self:Opt(name, "table", nil,
        function(v, t, userdata)
            if type(v) == "table" then -- if silent, we may still reach here with the incorrect type.
                local _, errs = validator:Validate(v, self.silent, userdata)
                return errs == nil, errs and table.concat( errs, "\n" )
            end
         end )
end

function Validator:OptSubValArray(name, validator, default)
    assert( Validator.is_instance(validator))
    return self:Opt(name, "table", default,
        function(v, t, userdata)
            if type(v) == "table" then -- if silent, we may still reach here with the incorrect type.
                for k,vv in ipairs(v) do
                    local _, errs = validator:Validate(vv, self.silent, userdata)
                    if errs then
                        return false, table.concat( errs, "\n" )
                    end
                end
                return true
            end
         end )
end

function Validator:Opt(name, vtype, default, fn)
    assert(type(vtype) == "string" or vtype == nil or Enum.IsEnumType(vtype) or is_class(vtype), "Not a valid type!")
    assert(self.fields[name] == nil or self.fields[name].type == vtype, string.format( "Overriding validated field '%s'", name))
    assert(fn == nil or type(fn) == "function")
    local idx = self.fields[ name ] and table.arrayfind( self.fields_array, self.fields[ name ] ) or (#self.fields_array + 1)
    self.fields[name] = { name = name, type = vtype, default = default, fn = fn }
    self.fields_array[ idx ] = self.fields[ name ]
    if default then
        if not self:ValidateElement( self.fields[ name ], "default", self.fields[ name ]) then
            error( table.concat( self.errors, "\n" ))
        end
    end

    return self
end

local function AddAsset( value, t, class )
    if Class.hasSubclasses( class ) and value == Validator.UNDEFINED_ASSET then
        -- Base classes are forced to satisfy Req() properties, so use Validator.UNDEFINED_ASSET.  These should pass through.
        return true
    end

    class:PreloadAsset( value )
    return true
end

local function AddAnim( value, t, class )
    class:PreloadAnim( value, value )
    return true
end

function Validator:OptAsset(name, default)
    return self:Opt(name, "string", default, AddAsset )
end

function Validator:OptAnim(name, default)
    return self:Opt(name, "string", default, AddAnim )
end

-- Only one the keys from 'names' can exist (mutually exclusive)
function Validator:OptChoice(names, vtype, default, fn)
    assert(type(vtype) == "string" or Enum.IsEnumType(vtype), "Not a valid type!")
    assert( type(names) == "table", "invalid choices table" )
    for i, name in ipairs(names) do
        assert(self.fields[name] == nil or self.fields[name].type == vtype, string.format( "Overriding validated field '%s'", name))
        local idx = self.fields[ name ] and table.arrayfind( self.fields_array, self.fields[ name ] ) or (#self.fields_array + 1)
        self.fields[name] = { name = name, type = vtype, default = default, fn = fn, exclusive = names }
        self.fields_array[ idx ] = self.fields[ name ]
    end
    return self
end

function Validator:OptRange(min_name, max_name, min_default, max_default, fn)
    assert(self.fields[min_name] == nil and self.fields[max_name] == nil)

    self.fields[min_name] = { name = min_name, type = "number", default = min_default, fn = fn }
    self.fields[max_name] = { name = max_name, type = "number", default = max_default, fn = fn }
    table.insert( self.fields_array, self.fields[ min_name ] )
    table.insert( self.fields_array, self.fields[ max_name ] )

    local function RangeValidator( _, t )
        local min_val, max_val = t[ min_name ], t[ max_name ]
        if (max_val == nil and min_val ~= nil) or (max_val ~= nil and min_val == nil) then
            return false, string.format( "incomplete range: %s -> %s", tostring(min_val), tostring(max_val))
        elseif type(min_val) == "number" and type(max_val) == "number" and max_val < min_val then
            return false, string.format( "%s (%s) must be >= %s (%s)", max_name, tostring(max_val), min_name, tostring(min_val))
        else
            return true
        end
    end
    table.insert( self.fields_array, { fn = RangeValidator } )
    return self
end

function Validator:Req(name, vtype, fn, req_fn)
    assert(type(vtype) == "string" or Enum.IsEnumType(vtype) or is_class(vtype) or fn ~= nil, "Not a valid required type!")
    assert(self.fields[name] == nil or self.fields[name].type == vtype, string.format( "Overriding validated field '%s'", name))
    assert(fn == nil or type(fn) == "function")

    local idx = self.fields[ name ] and table.arrayfind( self.fields_array, self.fields[ name ] ) or (#self.fields_array + 1)
    self.fields[name] = { name = name, type = vtype, required = true, req_fn = req_fn, fn = fn }
    self.fields_array[ idx ] = self.fields[ name ]
    return self
end

function Validator:ReqAsset(name)
    return self:Req(name, "string", AddAsset )
end

function Validator:ReqAnim(name)
    return self:Req(name, "string", AddAnim )
end

function Validator:OptList(name, vtype, fn)
    assert(self.fields[name] == nil or (self.fields[name].type == vtype and self.fields[name].is_list == true), string.format( "Overriding validated field '%s'", name))

    local idx = self.fields[ name ] and table.arrayfind( self.fields_array, self.fields[ name ] ) or (#self.fields_array + 1)
    self.fields[name] = { name = name, is_list = true, type = vtype, fn = fn }
    self.fields_array[ idx ] = self.fields[ name ]
    return self
end

function Validator:ReqList(name, vtype, fn)
    assert(self.fields[name] == nil or (self.fields[name].type == vtype and self.fields[name].is_list == true), string.format( "Overriding validated field '%s'", name))

    local idx = self.fields[ name ] and table.arrayfind( self.fields_array, self.fields[ name ] ) or (#self.fields_array + 1)
    self.fields[name] = { name = name, is_list = true, required = true, type = vtype, fn = fn }
    self.fields_array[ idx ] = self.fields[ name ]
    return self
end

function Validator:Pick(name, vals, default, fn)
    assert(self.fields[name] == nil, string.format( "Overriding validated field '%s'", name))
    if default then
        self.fields[name] = { name = name, default = default, fn = fn, options = vals }
    else
        self.fields[name] = { name = name, required = true, fn = fn, options = vals }
    end
    table.insert( self.fields_array, self.fields[ name ] )
    return self
end


function Validator:ValidateArray(t, min_vals, max_vals)

    if t == nil and (min_vals == nil or min_vals == 0) then
        return table.empty
    end

    if type(t) ~= "table" then
        return false, "not an array"
    elseif min_vals and #t < min_vals then
        return false, "not enough array entries"
    elseif max_vals and #t > max_vals then
        return false, "too many array entries"
    elseif #t ~= table.count(t) then
        return false, "Table is not an array: #t ~= table.count(t)"
    else
        for k, v in ipairs(t) do
            if type(v) ~= "table" then
                return false, string.format( "array entry %d is not table", k )
            end
            local _, errs = self:Validate(v)
            if errs then
                return false, table.concat( errs, "\n" )
            end
        end
    end

    return true
end


function Validator:ValidateDictionary(t, silent)
    self:Silent( silent )

    if type(t) ~= "table" then
        return false, "not a dictionary"

    else
        for k, v in pairs(t) do
            if type(v) ~= "table" then
                return false, string.format( "dictionary entry %s is not table", tostring(k) )
            end
            local _, errs = self:Validate(v, silent)
            if errs then
                return false, table.concat( errs, "\n" )
            end
        end
    end

    return true
end


function Validator.IsRGBColour(v)
    return type(v) == "number" and math.floor(v) == v and v >= 0 and v <= 0xffffff, "must be an RGB colour (do not include alpha)"
end

function Validator.IsColour(v)
    return type(v) == "number" and math.floor(v) == v and v >= 0 and v <= 0xffffffff, "must be a colour"
end

function Validator.IsVec2(v)
    return type(v) == "table" and #v == 2 and type(v[1]) == "number" and type(v[2]) == "number", "must be a vec2"
end

function Validator.IsNonNegative(v)
    return type(v) == "number" and v >= 0, "must be non-negative"
end

function Validator.IsPositive(v)
    return type(v) == "number" and v > 0, "must be positive"
end

function Validator.IsNegative(v)
    return type(v) == "number" and v < 0, "must be negative"
end

function Validator.IsNonPositive(v)
    return type(v) == "number" and v <= 0, "must be non-positive"
end

function Validator.IsUnit(v)
    return type(v) == "number" and v >= 0 and v <= 1.0, "must be in the range [0, 1]"
end

function Validator.IsClass( class )
    if class == nil then
        return function(v) return type(v) == "table" and is_class( v, class ), "must be a Class" end
    else
        assert( is_class( class ))
        return function(v) return type(v) == "table" and is_class( v, class ), "must be a Class of "..class._classname end
    end
end

function Validator:ValidateElement(t, k, def)
    if type(def.type) == "string" then
        if def.type ~= type(t[k]) then
            self:_AddError( loc.format( "INCORRECT TYPE - field {1} requires type '{2}' ({3} is a {4})", k, def.type, tostring(t[k]), type(t[k])))
            return false
        end
    elseif table.isEnumType( def.type ) then
        if not table.isEnum( t[k], def.type ) then
            self:_AddError( string.format( "Expected enum: %s, got %s", def.type, tostring(t[k])))
            return false
        end
    elseif is_class( def.type ) then
        if not def.type.is_instance(t[k]) then
            self:_AddError( string.format( "Expected class: %s, got %s", def.type._classname, tostring(t[k])))
            return false
        end
    elseif def.type ~= nil then
        self:_AddError( "invalid type: " ..tostring(def.type) )
        return false
    end

    return true
end

function Validator:_AddError( msg )
    if self.errors == nil then
        self.errors = {}
    end
    table.insert( self.errors, msg )
end

function Validator:Validate(t, silent, userdata)
    if silent then
        self:Silent( true )
    end

    self.errors = nil

    for k,v in pairs(t) do
        if not self.fields[k] then
            self:_AddError( loc.format( "UNKNOWN FIELD '{1}'", k ))
        end
    end

    for i, def in ipairs(self.fields_array) do
        local val = def.name and t[ def.name ]
        if val == nil then
            if def.required and (def.req_fn == nil or def.req_fn( val, t, userdata )) then
                self:_AddError( loc.format( "MISSING FIELD {1}", def.name))

            elseif def.default ~= nil then
                val = def.default
                t[ def.name ] = val
            end

        elseif val ~= nil then
            if def.is_list then
                if type(val) ~= "table" then
                    self:_AddError( string.format( "Expected list for %s", def.name ))
                else
                    for idx in ipairs(val) do
                        self:ValidateElement(val, idx, def)
                    end
                end

            elseif def.type then
                if not self:ValidateElement(t, def.name, def) then
                    val = nil -- No further validation should take place.
                end
            end
        end

        if val ~= nil then
            if def.options then
                if not table.arrayfind(def.options, val) then
                    self:_AddError( "NOT A VALID PICK OPTION: " ..tostring(val))
                end
            end

            if def.exclusive then
                for i, v in ipairs( def.exclusive ) do
                    if v ~= def.name and t[ v ] ~= nil then
                        self:_AddError( string.format( "'%s' is mutually exclusive with '%s'", def.name, tostring(v) ))
                    end
                end
            end
        end

        if def.fn and (val ~= nil or def.name == nil) then
            if def.is_list then
                for i, v in ipairs( val ) do
                    local ok, reason = def.fn(v, t, userdata )
                    if not ok then
                        self:_AddError( loc.format( "Error validating '{1}[{2}]': {3}", def.name or "", i, reason or "failed validation fn" ))
                    end
                end
            else
                local ok, reason = def.fn(val, t, userdata )
                if not ok then
                    self:_AddError( loc.format( "Error validating '{1}': {2}", def.name or "", reason or "failed validation fn" ))
                end
            end
        end
    end

    if not silent and not self.silent and self.errors ~= nil then
        error("Validation errors:\n".. inspect(self.errors))
    end

    return t, self.errors
end

return Validator
