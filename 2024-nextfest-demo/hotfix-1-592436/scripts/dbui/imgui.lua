-- Lua implementation of imgui api: https://github.com/ocornut/imgui/blob/master/imgui.h
-- See imgui_helpers.lua for additional functions.
--
-- Functions prefixed with underscore skip the "modified" return bool to allow
-- direct assignment when you don't need to detect dirty state:
--		self.x = ui:_DragFloat("x", x)

imgui = {
	Layer = {
		Window = 0,   		-- Only visible in window space, but coords in screen space
		WindowGlobal = 1,	-- Only visible in windows space, coords in window space
		Foreground = 2,		-- Foreground layer
		Background = 3		-- Background layer
	}
}


local function PushStyleVar(singleton, style_index, val_or_x, nil_or_y)
	assert(style_index ~= nil)
	assert(val_or_x ~= nil)
	if nil_or_y == nil then
		--    IMGUI_API void          PushStyleVar(ImGuiStyleVar idx, float val);
		return singleton:PushStyleVar(style_index, val_or_x)
	else
		--    IMGUI_API void          PushStyleVar(ImGuiStyleVar idx, const ImVec2& val);
		return singleton:PushStyleVar_2(style_index, val_or_x, nil_or_y)
	end
end


local function Value(singleton, prefix, value, nil_or_fmt)
	assert(prefix ~= nil)
	local value_t = type(value)
	if nil_or_fmt == nil then
		if value_t == "nil" then
			-- Accept and print nil values so users don't need to guard.
			return singleton:Text(prefix ..': nil')
		elseif value_t == "boolean" then
			--    IMGUI_API void          Value(const char* prefix, bool b);
			return singleton:Value(prefix, value)
		else
			-- Imgui doesn't natively let you print anything, but this is useful.
			-- For printing lots of stuff, consider DebugPanel:AppendKeyValues().
			return singleton:Text(prefix ..': '.. tostring(value))
		end
	else
		assert(value ~= nil)
		--    IMGUI_API void          Value(const char* prefix, float v, const char* float_format = NULL);
		return singleton:Value_3(prefix, value, nil_or_fmt)
	end
end

local function RadioButton(singleton, label, active_or_v, nil_or_v_button)
	assert(label ~= nil)
	assert(active_or_v ~= nil)
	if nil_or_v_button == nil then
		--    IMGUI_API bool          RadioButton(const char* label, bool active);
		return singleton:RadioButton(label, active_or_v)
	else
		--    IMGUI_API bool          RadioButton(const char* label, int* v, int v_button);
		return singleton:RadioButton_3(label, active_or_v, nil_or_v_button)
	end
end

-- Force input to be a string if we're passing it to Text to prevent nil errors.
local function Text(singleton,str)
	return singleton:Text(tostring(str))
end

-- Force input to be a string if we're passing it to SetClipboardText to prevent nil errors.
local function SetClipboardText(singleton,str)
	return singleton:SetClipboardText(tostring(str))
end

-- Unimplemented in imgui_luaproxy
--~ local function IsRectVisible(singleton, size_or_min_x, size_or_min_y, nil_or_max_x, nil_or_max_y)
--~ 	if nil_or_max_x == nil then
--~ 		--    IMGUI_API bool          IsRectVisible(const ImVec2& size);                                  // test if rectangle (of given size, starting from cursor position) is visible / not clipped.
--~ 		return singleton.IsRectVisible(size_or_min_x, size_or_min_y)
--~ 	else
--~ 		--    IMGUI_API bool          IsRectVisible(const ImVec2& rect_min, const ImVec2& rect_max);      // test if rectangle (in screen space) is visible / not clipped. to perform coarse clipping on user's side.
--~ 		return singleton.IsRectVisible_2(size_or_min_x, size_or_min_y, nil_or_max_x, nil_or_max_y)
--~ 	end
--~ end

local function WorldLine(singleton, p1,p2,color, thickness)
	local scale = singleton:GetDisplayScale()
	local sx1,sy1 = TheSim:WorldToScreenXY(p1[1],p1[2],p1[3])
	local sx2,sy2 = TheSim:WorldToScreenXY(p2[1],p2[2],p2[3])
	-- Imgui lives in another space, because the screen can be a subsection of where ImGui can draw
	local x,y,w,h = TheSim:GetWindowInset()
	sx1 = sx1 + x
	sx2 = sx2 + x
	sy1 = sy1 + y
	sy2 = sy2 + y
	singleton:DrawLine(imgui.Layer.Background, sx1 / scale, sy1 / scale, sx2 /scale , sy2 / scale, color or {1,1,1,1}, thickness or 1)
end

local function ScreenLine(singleton, p1,p2,color, thickness)
	local scale = singleton:GetDisplayScale()
	local sx1,sy1 = p1[1],p1[2]
	local sx2,sy2 = p2[1],p2[2]
	local x,y,w,h = TheSim:GetWindowInset()
	sx1 = sx1 + x
	sx2 = sx2 + x
	sy1 = sy1 + y
	sy2 = sy2 + y
	singleton:DrawLine(imgui.Layer.Background, sx1 / scale, sy1 / scale, sx2 /scale , sy2 / scale, color or {1,1,1,1}, thickness or 1)
end

local RawImgui = {}

-- Shims - have a lua wrapper to deal with multiple variations
RawImgui.Value = Value
RawImgui.RadioButton = RadioButton
RawImgui.PushStyleVar = PushStyleVar
RawImgui.Text = Text
--~ RawImgui.IsRectVisible = IsRectVisible
RawImgui.SetClipboardText = SetClipboardText
RawImgui.WorldLine = WorldLine
RawImgui.ScreenLine = ScreenLine

-- Cursor positioning
--   ui:GetCursorPos(...)       -- cursor position in window coordinates (relative to window position)
--   ui:GetCursorPosX(...)      -- (some functions are using window-relative coordinates, such as: GetCursorPos, GetCursorStartPos, GetContentRegionMax, GetWindowContentRegion* etc.
--   ui:GetCursorPosY(...)      -- other functions such as GetCursorScreenPos or everything in ImDrawList::
--   ui:SetCursorPos(...)       -- are using the main, absolute coordinate system.
--   ui:SetCursorPosX(...)      -- GetWindowPos() + GetCursorPos() == GetCursorScreenPos() etc.)
--   ui:GetCursorStartPos(...)  -- initial cursor position in window coordinates
--   ui:GetCursorScreenPos(...) -- cursor position in absolute screen coordinates [0..io.DisplaySize] (useful to work with ImDrawList API)
--   ui:SetCursorScreenPos(...) -- cursor position in absolute screen coordinates [0..io.DisplaySize]


-- not sure why we expose a different name.
RawImgui.CalcItemWidth = TheRawImgui.GetItemWidth
-- We don't support Text's formatting. Instead, we expose TextUnformatted as
-- Text to push formatting to lua. We could shim that formatting here, but :shrug:
RawImgui.TextUnformatted = TheRawImgui.Text

RawImgui._Checkbox = function(...)
	local _,v = TheRawImgui.Checkbox(...)
	return v
end

function RawImgui._CheckboxFlags(...)
	local _,v = TheRawImgui.CheckboxFlags(...)
	return v
end

RawImgui._Combo = function(self, label, param, list, ...)
	-- Combo always returns three values. It updates value while it's valid
	-- (open) and returns 0 when closed.
	local confirmed, value, closed = TheRawImgui.Combo(self, label, param, list, ...)
	if closed then
		value = param
	end
	return value, closed
end
function RawImgui:InputText(label, text, flags, cb, ...)
	-- InputText is identical to InputTextWithHint, except that it doesn't pass hint.
	return TheRawImgui.InputTextWithHint(self, label, nil, text, flags, cb, ...)
end
function RawImgui:_InputText(label, text, flags, cb, ...)
	local changed,newtext = TheRawImgui.InputTextWithHint(self, label, nil, text, flags, cb, ...)
	if changed then
		return newtext
	end
	return text
end
function RawImgui:_InputTextWithHint(label, hint, text, flags, cb, ...)
	local changed,newtext = TheRawImgui.InputTextWithHint(self, label, hint, text, flags, cb, ...)
	if changed then
		return newtext
	end
	return text
end

RawImgui.SetNextTreeNodeOpen = TheRawImgui.SetNextItemOpen -- SetNextTreeNodeOpen is "obsolete"

RawImgui._DragFloat3 = function(self,label,x,y,z,speed, minv, maxv)
	local changed,nx,ny,nz = TheRawImgui.DragFloat3(self,label,x,y,z,speed,minv,maxv)
	if changed then
		return nx,ny,nz
	else
		return x,y,z
	end
end

RawImgui._DragFloat2 = function(self, label, x, y, speed, minv, maxv)
	local changed, nx, ny = TheRawImgui.DragFloat2(self, label, x, y, speed, minv, maxv)
	if changed then
		return nx, ny
	else
		return x, y
	end
end


RawImgui._ColorEdit3 = function(self, label, r, g, b, flags)
	local changed, new_r, new_g, new_b, new_a = TheRawImgui.ColorEdit3(self, label, r, g, b, flags)
	if changed then
		return new_r, new_g, new_b, new_a
	end
	return r, g, b
end

RawImgui._ColorEdit4 = function(self, label, r, g, b, a, flags)
	local changed, new_r, new_g, new_b, new_a = TheRawImgui.ColorEdit4(self, label, r, g, b, a, flags)
	if changed then
		return new_r, new_g, new_b, new_a
	end
	return r, g, b, a
end

RawImgui._DragFloat = function(self, label, value, speed, minv, maxv, format)
	local changed,v = TheRawImgui.DragFloat(self, label, value, speed, minv, maxv, format)
	if changed then
		return v
	else
		return value
	end
end

RawImgui._SliderFloat = function(...)
	local _,v = TheRawImgui.SliderFloat(...)
	return v
end

RawImgui._VSliderFloat = function(...)
	local _,v = TheRawImgui.VSliderFloat(...)
	return v
end

RawImgui._SliderInt = function(...)
	local _,v = TheRawImgui.SliderInt(...)
	return v
end

RawImgui._VSliderInt = function(...)
	local _,v = TheRawImgui.VSliderInt(...)
	return v
end

function RawImgui._RadioButton(...)
	local _,v = RadioButton(...)
	return v
end






-- Drawing commands
--   ui:DrawLine(...)
--   ui:DrawRect(...)
--   ui:DrawRectFilled(...)
--   ui:DrawRectFilledMultiColor(...)
--   ui:DrawQuad(...)
--   ui:DrawQuadFilled(...)
--   ui:DrawTriangle(...)
--   ui:DrawTriangleFilled(...)
--   ui:DrawCircle(...)
--   ui:DrawCircleFilled(...)
--   ui:DrawNgon(...)
--   ui:DrawNgonFilled(...)
--   ui:DrawText(...)
--   ui:DrawPolyline(...)
--   ui:DrawConvexPolyFilled(...)
--   ui:DrawBezierCurve(...)
--   ui:DrawImage(...)
--   ui:DrawImageRounded(...)

-- Stateful path API, add points then finish with PathFillConvex() or PathStroke()
--   ui:PathClear(...)
--   ui:PathLineTo(...)
--   ui:PathLineToMergeDuplicate(...)
--   ui:PathFillConvex(...)
--   ui:PathStroke(...)
--   ui:PathArcTo(...)
--   ui:PathArcToFast(...)
--   ui:PathBezierCurveTo(...)
--   ui:PathRect(...)

--------------------------------------------------- imgui value tables ------------------------------------
require "dbui.flags.imguiallflags"
require "dbui.imguiicon"


-- Remap RawImgui.Func() -> imgui:Func()
--
-- We expose the imgui table but the functions must be called on TheRawImgui
-- object (ImguiLuaProxy) instead. Bind the functions in RawImgui with a
-- closure that invokes it as a member function of TheRawImgui.
--
-- We don't use TheRawImgui directly so we can add lua-only helpers here.
local function binder(singleton, destination)
	return function(self,...)
		-- If you hit "bad argument #2 to 'fn'" errors here, go up the stack to the
		-- ui:Blah() call and compare those arguments to the definition in
		-- imgui_luaproxy.cpp or dear-imgui/imgui.h
		--
		-- "attempt to call a nil value (upvalue 'destination')" means you
		-- called an unimplemented function or typo.
		return destination(singleton, ...)
	end
end
-- Copy shims to imgui table.
for key,fn in pairs(RawImgui) do
	dbassert(imgui[key] == nil, "Name clash in flags?")
	imgui[key] = binder(TheRawImgui, fn)
end
-- Use metamethod to redirect to C-side implementations. Some argument
-- disambiguation is handled there.
setmetatable(imgui, {
		__index = function(t, key)
			local fn = binder(TheRawImgui, TheRawImgui[key])
			t[key] = fn
			return fn
		end
	})

-- dump imgui functions
--~ for i,v in pairs(imgui) do print(i,v) end

require "dbui.imgui_helpers"

return imgui
