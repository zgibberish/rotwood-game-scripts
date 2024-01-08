local filepath = require "util.filepath"

local DEFAULT_WATER_COLOR = HexToStr(0x9ac3e500)
local DEFAULT_WATER_HEIGHT = -1.2
local DEFAULT_WATER_BOB_SPEED = 1
local DEFAULT_WATER_BOB_AMPLITUDE = 0.2

local DEFAULT_WATER_WAVE_SPEED = 1
local DEFAULT_WATER_WAVE_HEIGHT = 0.2
local DEFAULT_WATER_WAVE_PERIOD = 1
local DEFAULT_WATER_WAVE_OUTLINE = 0.05

local DEFAULT_WATER_REFRACTION = 0.3
local DEFAULT_WATER_REFRACTION_SPEED = 2

local WATER_CLIPBOARD_CONTEXT = "++WATER_CLIPBOARD_CONTEXT"

local function VerifyInterface(type)
	local expected_members = {
		'AddTreeNodeEnder',
		'SetDirty',
		'RefreshWater',
		'AddSectionStarter',
		'AddSectionEnder',
		'Button_CopyToGroup',
		'PushRedButtonColor',
		'PushRedFrameColor',
		'PopFrameColor',
		'PopButtonColor',
		'OnWaterRampTextureChanged'
	}
	for _, expected_member in ipairs(expected_members) do
		assert(type[expected_member],"Editor does not fully implement Water interface: '"..expected_member.."' is unimplemented")
	end
end

local function GetWaterKeys()
	return {
		"water_settings",

		-- settings
		-- "has_water",
		-- "water_color",
		-- "additive",
		-- "water_height",
		-- "refraction",
		-- "refraction_speed",
		-- "prop",
		-- "cliff",
		-- "ramp",
	}
end

function CopyWaterProperties(from, to)
	for _, k in ipairs(GetWaterKeys()) do
		if from[k] then
			to[k] = deepcopy(from[k])
		end
	end
end

function ApplyWater(params, dungeon_progress)
	local settings = params.water_settings or {}
	local water = TheWorld.components.worldwater

	water:Enable(settings.has_water)
	if not settings.has_water then
		return
	end

	water:SetColor(HexToRGBFloats(StrToHex(settings.water_color or DEFAULT_WATER_COLOR)))
	water:SetAdditiveBlending(settings.additive)
	water:SetHeight(settings.water_height or DEFAULT_WATER_HEIGHT)
	water:SetRampTexture(settings.ramp and "images/" .. settings.ramp .. ".tex" or "images/water_ramp_01.tex")

	water:SetRefraction(settings.refraction or DEFAULT_WATER_REFRACTION)
	water:SetRefractionSpeed(settings.refraction_speed or DEFAULT_WATER_REFRACTION_SPEED)

	for i=1,2 do
		local layer_settings = i == 1 and settings.prop or i==2 and settings.cliff or {}
		-- These two aren't live updated as they'd dirty the scene if there's props on the water
		if not TheDungeon:GetDungeonMap():IsDebugMap() then
			water:SetBobSpeed(layer_settings.bob_speed or DEFAULT_WATER_BOB_SPEED, i)
			water:SetBobAmplitude(layer_settings.bob_amplitude or DEFAULT_WATER_BOB_AMPLITUDE, i)
		else
			water:SetBobSpeed(0, i)
			water:SetBobAmplitude(0, i)
		end
		water:SetWaveSpeed(layer_settings.wave_speed or DEFAULT_WATER_WAVE_SPEED, i)
		water:SetWaveHeight(layer_settings.wave_height or DEFAULT_WATER_WAVE_HEIGHT, i)
		water:SetWavePeriod(layer_settings.wave_period or DEFAULT_WATER_WAVE_PERIOD, i)
		water:SetWaveOutline(layer_settings.wave_outline or DEFAULT_WATER_WAVE_OUTLINE, i)
	end
end

function ApplyDefaultWater()
	ApplyWater({}, nil)
end

local function GetWaterRampList()
	local files = { "" }
	filepath.list_files("images/", "water_ramp_*.tex", false, files)
	for i = 2, #files do
		files[i] = string.match(files[i], "^images/(.+)[.]tex$")
	end
	return files
end

function WaterUi(editor, ui, water, enabled)
	VerifyInterface(editor)

	if not ui:CollapsingHeader("Water") or not enabled then
		return
	end

	ui:Indent()

	water.water_settings = water.water_settings or {}

	local pasted = ui:CopyPasteButtons(WATER_CLIPBOARD_CONTEXT, "##Water", water.water_settings)
	if pasted then
		water.water_settings = pasted
	end

	local settings = water.water_settings

	local oldwater = settings.has_water == true
	local _, newwater = ui:Checkbox("Has Water", oldwater)
	if newwater ~= oldwater then
		if newwater then
			settings.has_water = true
		else
			settings.has_water = nil
		end
		editor:SetDirty()
		editor:RefreshWater(editor.prefabname, water)
	end
	if settings.has_water then
		-- water color
		local r, g, b = HexToRGBFloats(StrToHex(settings.water_color or DEFAULT_WATER_COLOR))
		local color_edit_flags = ui.ColorEditFlags.PickerHueBar | ui.ColorEditFlags.Uint8 | ui.ColorEditFlags.DisplayRGB | ui.ColorEditFlags.InputRGB;
		local _, newr, newg, newb = ui:ColorEdit3("Color##watercolor", r, g, b, color_edit_flags)
		if newr ~= nil or newg ~= nil or newb ~= nil then
			local newwatercolor = HexToStr(RGBFloatsToHex(newr or r, newg or g, newb or b))
			if newwatercolor == DEFAULT_WATER_COLOR then
				newwatercolor = nil
			end
			if settings.water_color ~= newwatercolor then
				settings.water_color = newwatercolor
				editor:SetDirty()
				editor:RefreshWater(editor.prefabname, water)
			end
		end

		-- additive/multiplied
		local index = settings.additive and 1 or 0
		local newIndex = index
		local clicked = ui:RadioButton("Multiplied Blending", index, 0)
		if clicked then
			newIndex = 0
		end
		ui:SameLineWithSpace()
		local clicked = ui:RadioButton("Additive Blending", index, 1)
		if clicked then
			newIndex = 1
		end
		if newIndex ~= index then
			settings.additive = newIndex == 1 and 1 or nil
			editor:SetDirty()
			editor:RefreshWater(editor.prefabname, water)
		end

		-- water height
		local height = settings.water_height or DEFAULT_WATER_HEIGHT
		local changed, newheight = ui:SliderFloat("Water Height", height,-5,0)
		if changed then
			if newheight == DEFAULT_WATER_HEIGHT then
				newheight = nil
			end
			if settings.water_height ~= newheight then
				settings.water_height = newheight
				editor:SetDirty()
				editor:RefreshWater(editor.prefabname, water)
			end
		end

		local refraction = settings.refraction or DEFAULT_WATER_REFRACTION
		local changed, newrefrection = ui:SliderFloat("Refraction Strength", refraction,0,2)
		if changed then
			if newrefrection == DEFAULT_WATER_REFRACTION then
				newrefrection = nil
			end
			if settings.refraction ~= newrefrection then
				settings.refraction = newrefrection
				editor:SetDirty()
				editor:RefreshWater(editor.prefabname, water)
			end
		end

		local refraction_speed = settings.refraction_speed or DEFAULT_WATER_REFRACTION_SPEED
		local changed, newrefrection_speed = ui:SliderFloat("Refraction Wobble Speed", refraction_speed,0,20)
		if changed then
			if newrefrection_speed == DEFAULT_WATER_REFRACTION_SPEED then
				newrefrection_speed = nil
			end
			if settings.refraction_speed ~= newrefrection_speed then
				settings.refraction_speed = newrefrection_speed
				editor:SetDirty()
				editor:RefreshWater(editor.prefabname, water)
			end
		end

		local function water_setting(settings, index, name, label, min, max, default_val)
			local layer_settings = settings[index] or {}
			local val = layer_settings[name] or default_val
			local changed, newval = ui:SliderFloat(label.."##"..index, val,min,max)
			if changed then
				if newval == default_val then
					newval = nil
				end
				if layer_settings[name] ~= newval then
					settings[index] = settings[index] or {}
					settings[index][name] = newval
					editor:SetDirty()
					editor:RefreshWater(editor.prefabname, water)
				end
				if settings[index] and not next(settings[index]) then
					settings[index] = nil
				end
			end
		end

		local function noLiveEdit()
			if TheDungeon:GetDungeonMap():IsDebugMap() then
				ui:SameLine()
				ui:TextColored(WEBCOLORS.YELLOW, "(*)")
				if ui:IsItemHovered() then
					ui:SetTooltip("Not live updated - Use 'Test Level'")
				end
			end
		end

		if ui:TreeNode("Props##water", ui.TreeNodeFlags.DefaultOpen) then
			water_setting(settings, "prop", "bob_speed", "Bobbing Speed", 0, 2, DEFAULT_WATER_BOB_SPEED)
			noLiveEdit()

			water_setting(settings, "prop", "bob_amplitude", "Bobbing Amplitude", 0, 1, DEFAULT_WATER_BOB_AMPLITUDE)
			noLiveEdit()

			water_setting(settings, "prop", "wave_speed", "Wave Speed", -5, 5, DEFAULT_WATER_WAVE_SPEED)
			water_setting(settings, "prop", "wave_height", "Wave Height", 0, 0.5, DEFAULT_WATER_WAVE_HEIGHT)
			water_setting(settings, "prop", "wave_period", "Wave Period", 0, 5, DEFAULT_WATER_WAVE_PERIOD)
			water_setting(settings, "prop", "wave_outline", "Wave Outline Thickness", 0, 0.2, DEFAULT_WATER_WAVE_OUTLINE)
			editor:AddTreeNodeEnder(ui)
		end

		if ui:TreeNode("Cliffs##water", ui.TreeNodeFlags.DefaultOpen) then
			water_setting(settings, "cliff", "bob_speed", "Bobbing Speed", 0, 2, DEFAULT_WATER_BOB_SPEED)
			noLiveEdit()

			water_setting(settings, "cliff", "bob_amplitude", "Bobbing Amplitude", 0, 1, DEFAULT_WATER_BOB_AMPLITUDE)
			noLiveEdit()

			water_setting(settings, "cliff", "wave_speed", "Wave Speed", -5, 5, DEFAULT_WATER_WAVE_SPEED)
			water_setting(settings, "cliff", "wave_height", "Wave Height", 0, 0.5, DEFAULT_WATER_WAVE_HEIGHT)
			water_setting(settings, "cliff", "wave_period", "Wave Period", 0, 5, DEFAULT_WATER_WAVE_PERIOD)
			water_setting(settings, "cliff", "wave_outline", "Wave Outline Thickness", 0, 0.2, DEFAULT_WATER_WAVE_OUTLINE)
			editor:AddTreeNodeEnder(ui)
		end
	end
	if not next(water.water_settings) then
		water.water_settings = nil
	end

	local ramplist = GetWaterRampList()
	local rampidx = nil
	for i = 1, #ramplist do
		if settings.ramp == ramplist[i] then
			rampidx = i
			break
		end
	end
	local missing = rampidx == nil and settings.ramp ~= nil
	if missing then
		rampidx = 1
		ramplist[1] = settings.ramp.." (missing)"
		editor:PushRedButtonColor(ui)
		editor:PushRedFrameColor(ui)
	end
	local newrampidx = ui:_Combo("Edge Ramp Texture##waterramp", rampidx or 1, ramplist)
	if newrampidx ~= rampidx then
		local newramp = ramplist[newrampidx]
		if string.len(newramp) == 0 then
			newramp = nil
		end
		if settings.ramp ~= newramp then
			settings.ramp = newramp
			editor:SetDirty()
			editor:OnWaterRampTextureChanged(editor.prefabname, water)
			editor:RefreshWater(editor.prefabname, water)
		end
	end
	if missing then
		editor:PopFrameColor(ui)
		editor:PopButtonColor(ui)
	end

	ui:Spacing()
	editor:Button_CopyToGroup(ui, "Copy '%s' water to group: '%s'", {'water_settings'})

	ui:Unindent()
end

function LoadWaterAssets(editor, water)
	editor:OnWaterRampTextureChanged(editor.prefabname, water)
end
