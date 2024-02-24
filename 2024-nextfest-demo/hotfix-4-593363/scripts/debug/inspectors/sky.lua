local colorutil = require "util.colorutil"
local kstring = require "util.kstring"
local lume = require "util.lume"

DEFAULT_PROP_FADE_COLOR = HexToStr(0x00000000)
PROGRESS_ENDPOINTS = { "entrance", "boss", }

local function VerifyInterface(type)
	local expected_members = {
		'CanEditSkyGradient',
		'AddTreeNodeEnder',
		'SetDirty',
		'RefreshSky',
		'AddSectionStarter',
		'AddSectionEnder',
		'Button_CopyToGroup',
		'curve_key',
		'backgroundgradientEditorPane'
	}
	for _, expected_member in ipairs(expected_members) do
		assert(type[expected_member],"Editor does not fully implement Sky interface: '"..expected_member.."' is unimplemented")
	end
end

function GetSkyKeys()
	return {
		"backgroundGradientCurve",
		"prop_fade_color"
	}
end

function CopySkyProperties(from, to)
	for _, k in ipairs(GetSkyKeys()) do
		if from[k] then
			to[k] = deepcopy(from[k])
		end
	end
end

local function SkyGradientUi(editor, ui, sky_gradient)
	if not ui:TreeNode("Sky Gradient", ui.TreeNodeFlags.DefaultOpen) then
		return
	end

	if not editor:CanEditSkyGradient(ui) then
		editor:AddTreeNodeEnder(ui)
		return
	end

	sky_gradient.backgroundGradientCurve = sky_gradient.backgroundGradientCurve or {}

	local function count_colors(curve_list, key)
		local curve = curve_list and curve_list[key]
		return curve and #curve or 0
	end
	local color_counts = {}
	local key_index = lume.find(PROGRESS_ENDPOINTS, editor.curve_key)
	for i, key in ipairs(PROGRESS_ENDPOINTS) do
		if not sky_gradient.town or key ~= "boss" then
			local clicked = ui:RadioButton(key, key_index, i)
			if clicked then
				editor.curve_key = PROGRESS_ENDPOINTS[i]
			end
			color_counts[key] = count_colors(sky_gradient.backgroundGradientCurve, key)
		end
	end

	if #lume.unique(color_counts) > 1 then
		editor:WarningMsg(ui, "Color Counts must match!",
			kstring.subfmt(
			"Sky Gradient will not blend because the number of colors aren't the same in each gradient:\n\tentrance = {entrance}\n\tboss = {boss}\n",
				color_counts))
	end

	local curve_param = sky_gradient.backgroundGradientCurve[editor.curve_key]

	local work_curve = curve_param
	local changed, newcurve = editor.backgroundgradientEditorPane:OnRender(ui, work_curve)
	if changed then
		work_curve = newcurve
	end
	ui:Spacing()

	local pasted_curve = ui:CopyPasteButtons("++bg_gradient", "##bg_gradient", work_curve)
	if pasted_curve then
		work_curve = pasted_curve
		changed = true
	end

	if changed then
		sky_gradient.backgroundGradientCurve = sky_gradient.backgroundGradientCurve or {}
		sky_gradient.backgroundGradientCurve[editor.curve_key] = deepcopy(work_curve)

		editor:SetDirty()
		editor:RefreshSky(sky_gradient)
	end

	if not next(sky_gradient.backgroundGradientCurve) then
		sky_gradient.backgroundGradientCurve = nil
	end

	ui:Spacing()
	editor:Button_CopyToGroup(ui, "Copy '%s' sky to group: '%s'", GetSkyKeys())

	editor:AddTreeNodeEnder(ui)
end

local function ColorUi(ui, label, string_color)
	local r, g, b = HexToRGBFloats(StrToHex(string_color or DEFAULT_PROP_FADE_COLOR))
	local _, newr, newg, newb = ui:ColorEdit3(label, r, g, b,
		ui.ColorEditFlags.PickerHueBar | ui.ColorEditFlags.Uint8 | ui.ColorEditFlags.DisplayRGB |
		ui.ColorEditFlags.InputRGB)
	if newr ~= nil or newg ~= nil or newb ~= nil then
		local new_prop_fade_color = HexToStr(RGBFloatsToHex(newr or r, newg or g, newb or b))
		if new_prop_fade_color == DEFAULT_PROP_FADE_COLOR then
			new_prop_fade_color = nil
		end
		if string_color ~= new_prop_fade_color then
			return true, new_prop_fade_color
		end
	end
	return false, string_color
end

function SkyUi(editor, ui, sky, enabled)
	VerifyInterface(editor)

	if not ui:CollapsingHeader("Sky") or not enabled then
		return
	end

	ui:Indent()

	editor:AddSectionStarter(ui)

	if ui:TreeNode("Prop Fade Color", ui.TreeNodeFlags.DefaultOpen) then
		local dirty = false
		local changed, new_color = ColorUi(ui, "From (Entrance)##prop_fade_color", sky.prop_fade_color)
		if changed then
			sky.prop_fade_color = new_color
			dirty = true
		end
		local changed, new_color = ColorUi(ui, "To (Boss)##prop_fade_to_color", sky.prop_fade_to_color)
		if changed then
			sky.prop_fade_to_color = new_color
			dirty = true
		end
		if dirty then
			editor:SetDirty()
			editor:RefreshSky(sky)
		end
		editor:AddTreeNodeEnder(ui)
	end

	SkyGradientUi(editor, ui, sky)

	ui:Unindent()

	editor:AddSectionEnder(ui)
end

local function SetSkyGradient(sky_gradient, dungeon_progress)
	local curve = sky_gradient.backgroundGradientCurve.entrance
	if sky_gradient.backgroundGradientCurve.boss
		and #sky_gradient.backgroundGradientCurve.boss == #curve
	then
		curve = colorutil.GradientLerp(
			sky_gradient.backgroundGradientCurve.entrance,
			sky_gradient.backgroundGradientCurve.boss,
			dungeon_progress)
	end
	TheSim:SetSkyGradient(curve)
end

function ApplySky(sky, dungeon_progress)
	dungeon_progress = dungeon_progress or 0
	if sky.backgroundGradientCurve then
		SetSkyGradient(sky, dungeon_progress)
	end
	local r, g, b, a = HexToRGBFloats(StrToHex(sky.prop_fade_color or DEFAULT_PROP_FADE_COLOR))
	local to_r, to_g, to_b, to_a = HexToRGBFloats(StrToHex(sky.prop_fade_to_color or DEFAULT_PROP_FADE_COLOR))
	TheSim:SetPropFadeColor(
		lume.lerp(r, to_r, dungeon_progress),
		lume.lerp(g, to_g, dungeon_progress),
		lume.lerp(b, to_b, dungeon_progress),
		lume.lerp(a, to_a, dungeon_progress)
	)
end

function ApplyDefaultSky()
	ApplySky({}, nil)
end

function LoadSkyAssets(editor, sky)
end
