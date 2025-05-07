----------------------------------------

local UIHelpers = Class( function()
end)

function UIHelpers.KeepOnScreen(widget)
    -- take the letterbox into account. If we don't want this we need to use
    -- the ScreenDims instead, and use the world boundingbox of the widget
    local screenw, screenh = RES_X, RES_Y

    local scrx_min, scrx_max = -screenw/2, screenw/2
    local scry_min, scry_max = -screenh/2, screenh/2

    local xmin, ymin, xmax, ymax = widget:GetVirtualBoundingBox()
    local tw, th = xmax - xmin, ymax - ymin

    if xmax > scrx_max then
        widget:Offset( scrx_max - xmax )
    elseif xmin < scrx_min then
        widget:Offset( scrx_min-xmin )
    end

    if ymax > scry_max then
        widget:Offset( 0, scry_max - ymax )
    elseif ymin < scry_min then
        widget:Offset( 0, scry_min - ymin)
    end
end

function UIHelpers.SetBrightnessMapNative(widget, gradient_tex, intensity)
	if gradient_tex == nil then
		widget:ClearBrightnessMap()
	else
		local atlas, tex, checkatlas = GetAtlasTex(gradient_tex)
		assert(atlas ~= nil)
		assert(tex ~= nil)
		widget:SetBrightnessMap(atlas, tex, intensity)
	end
end

return UIHelpers
