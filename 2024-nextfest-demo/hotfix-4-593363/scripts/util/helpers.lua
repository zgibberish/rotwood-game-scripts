function LOGWARN( ... )

    local str
    if select( "#", ... ) > 0 then
        str = debug.traceback( string.format( ... ), 2 )
    else
        str = debug.traceback( "failed assert", 2 )
    end

    print(str)
--[[
    if TheGame and TheGame:GetDebug() then
        engine.inst:ShowWarning( str )
    end
]]
end

function assert_warning(assertion, ...)
    if not assertion then
        LOGWARN(...)
    end
end

