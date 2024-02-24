local PrefabUtil = require "prefabs.prefabutil"
local filepath = require "util.filepath"
local lume = require "util.lume"

DEFAULT_AMBIENT = HexToStr(0xFFFFFFFF)
DEFAULT_RIMLIGHT_COLOR = HexToStr(0x9b6dFFFF)
DEFAULT_RIMLIGHT_POS = {0,40,40}
DEFAULT_CLIFFLIGHT_DIRECTION = {-0.6,-0.7,0.9}
DEFAULT_CLIFFLIGHT_WEIGHT = 1.0
DEFAULT_SHADOW_SKEW = {-100.0, 100.0, 0.6, 0.4}
DEFAULT_SHADOW_SQUISH = {-10.0, 10.0, 0.9, 0.8}
DEFAULT_GROUNDSHADOW_STRENGTH = 0.4

local function VerifyInterface(type)
	local expected_members = {
		'AddTreeNodeEnder',
		'SetDirty',
		'RefreshLighting',
		'AddSectionStarter',
		'AddSectionEnder',
		'Button_CopyToGroup',
		'PushRedButtonColor',
		'PopButtonColor',
		'PushRedFrameColor',
		'PopFrameColor',
		'OnColorCubeChanged',
		'OnRampTextureChanged',
		'OnSkirtTextureChanged',
	}
	for _, expected_member in ipairs(expected_members) do
		assert(type[expected_member],"Editor does not fully implement LightingUi interface: '"..expected_member.."' is unimplemented")
	end
end

function GetLightingKeys()
	return {
		"ambient",
		"exposure_min",
		"exposure_max",
		"colorcube",
		"rimlightcolor",
		"rimlightpos",
		"clifflightdirection",
		"clifflightweight",
		"clifframp",
		"cliffskirt",
		"clifframp",
		"clifframp",
		"clifframp",
		"shadowSkew",
		"shadowSquish",
	}
end

function CopyLightingProperties(from, to)
	for _, k in ipairs(GetLightingKeys()) do
		if from[k] then
			to[k] = deepcopy(from[k])
		end
	end
end

local function GetColorCubeList()
	local files = { "" }
	filepath.list_files("images/color_cubes/", "*.tex", false, files)
	local j = 2
	for i = 2, #files do
		files[j] = string.match(files[i], "^images/color_cubes/(.+)[.]tex$")
		if files[j] ~= "identity_cc" then
			j = j + 1
		end
	end
	for i = j, #files do
		files[i] = nil
	end
	return files
end

local function GetRampList()
	local files = { "" }
	filepath.list_files("images/", "ramp_*.tex", false, files)
	local j = 2
	for i = 2, #files do
		files[i] = string.match(files[i], "^images/(.+)[.]tex$")
	end
	return files
end

local function GetSkirtList()
	local files = { "" }
	filepath.list_files("levels/tiles", "*_cliff*.tex", false, files)
	local j = 2
	for i = 2, #files do
		files[i] = string.match(files[i], "^levels/tiles/(.+)[.]tex$")
	end
	return files
end

function LightingUi(editor, ui, lighting, enabled)
	VerifyInterface(editor)

	if not ui:CollapsingHeader("Lighting") or not enabled then
		return
	end

	editor:AddSectionStarter(ui)

	ui:Indent()

	if ui:TreeNode("Ambient", ui.TreeNodeFlags.DefaultOpen) then
		local r, g, b = HexToRGBFloats(StrToHex(lighting.ambient or DEFAULT_AMBIENT))
		local _, newr, newg, newb = ui:ColorEdit3("##ambientcolor", r, g, b, ui.ColorEditFlags.PickerHueBar | ui.ColorEditFlags.Uint8 | ui.ColorEditFlags.DisplayRGB | ui.ColorEditFlags.InputRGB)
		if newr ~= nil or newg ~= nil or newb ~= nil then
			local newambient = HexToStr(RGBFloatsToHex(newr or r, newg or g, newb or b))
			if newambient == DEFAULT_AMBIENT then
				newambient = nil
			end
			if lighting.ambient ~= newambient then
				lighting.ambient = newambient
				editor:SetDirty()
				editor:RefreshLighting(lighting)
			end
		end

		editor:AddTreeNodeEnder(ui)
	end

	if ui:TreeNode("Exposure", ui.TreeNodeFlags.DefaultOpen) then
		ui:Columns(2, nil, false)
		local changed, exposure_min = ui:DragFloat("Min##exposure", lighting.exposure_min or 0, 0.01, -2, 2, "%.2f")
		if changed then
			lighting.exposure_min = exposure_min
			if lighting.exposure_min == 0 then
				lighting.exposure_min = nil
			end
			editor:SetDirty()
			editor:RefreshLighting(lighting)
		end
		ui:NextColumn()
		local changed, exposure_max = ui:DragFloat("Max##exposure", lighting.exposure_max or 1, 0.01, -2, 2, "%.2f")
		if changed then
			lighting.exposure_max = exposure_max
			if lighting.exposure_max == 0 then
				lighting.exposure_max = nil
			end
			editor:SetDirty()
			editor:RefreshLighting(lighting)
		end
		ui:Columns(1)
		if ui:Button("Reset##exposure") then
			lighting.exposure_min = nil
			lighting.exposure_max = nil
			editor:SetDirty()
			editor:RefreshLighting(lighting)
		end
		editor:AddTreeNodeEnder(ui)
	end

	if ui:TreeNode("Color Cube", ui.TreeNodeFlags.DefaultOpen) then
		--Color Cube
		lighting.colorcube = lighting.colorcube or {}
		local colorcubelist = GetColorCubeList()

		local function RenderColorCubePicker(key)
			local colorcubeidx = lume.find(colorcubelist, lighting.colorcube[key])
			local missing = colorcubeidx == nil and lighting.colorcube[key] ~= nil
			if missing then
				colorcubeidx = 1
				colorcubelist[1] = lighting.colorcube[key].." (missing)"
				editor:PushRedButtonColor(ui)
				editor:PushRedFrameColor(ui)
			end
			local newcolorcubeidx = ui:_Combo(key .."##colorcube", colorcubeidx or 1, colorcubelist)
			if newcolorcubeidx ~= colorcubeidx then
				local newcolorcube = colorcubelist[newcolorcubeidx]
				if string.len(newcolorcube) == 0 then
					newcolorcube = nil
				end
				if lighting.colorcube[key] ~= newcolorcube then
					lighting.colorcube[key] = newcolorcube
					editor:SetDirty()
					editor:OnColorCubeChanged(editor.prefabname, lighting)
					editor:RefreshLighting(lighting)
				end
			end
			if missing then
				editor:PopFrameColor(ui)
				editor:PopButtonColor(ui)
			end
		end
		for _,key in ipairs(PROGRESS_ENDPOINTS) do
			RenderColorCubePicker(key)
		end

		if next(lighting.colorcube) == nil then
			lighting.colorcube = nil
		end

		editor:AddTreeNodeEnder(ui)
	end

	if ui:TreeNode("Rim Lights", ui.TreeNodeFlags.DefaultOpen) then
		local r, g, b = HexToRGBFloats(StrToHex(lighting.rimlightcolor or DEFAULT_RIMLIGHT_COLOR))
		local changed, newr, newg, newb = ui:ColorEdit3("##ambientcolor", r, g, b, ui.ColorEditFlags.PickerHueBar | ui.ColorEditFlags.Uint8 | ui.ColorEditFlags.DisplayRGB | ui.ColorEditFlags.InputRGB)
		if changed then
			local newrimlightcolor = HexToStr(RGBFloatsToHex(newr or r, newg or g, newb or b))
			if newrimlightcolor == DEFAULT_RIMLIGHT_COLOR then
				newrimlightcolor = nil
			end
			if lighting.rimlightcolor ~= newrimlightcolor then
				lighting.rimlightcolor = newrimlightcolor
				editor:SetDirty()
				editor:RefreshLighting(lighting)
			end
		end
		local pos = lighting.rimlightpos or DEFAULT_RIMLIGHT_POS
		local changed, newx, newy, newz = ui:DragFloat3("Position", pos[1], pos[2], pos[3],0.1,-50,50)
		if changed then
			local newrimlightpos = {newx, newy, newz}
			if deepcompare(newrimlightpos, DEFAULT_RIMLIGHT_POS) then
				newrimlightpos = nil
			end
			if not deepcompare(lighting.rimlightpos,newrimlightpos) then
				lighting.rimlightpos = {newx, newy, newz}
				editor:SetDirty()
				editor:RefreshLighting(lighting)
			end
		end
		editor:AddTreeNodeEnder(ui)
	end

	if ui:TreeNode("Cliff Lights", ui.TreeNodeFlags.DefaultOpen) then
		--[[
		local r, g, b = HexToRGBFloats(StrToHex(lighting.rimlightcolor or DEFAULT_RIMLIGHT_COLOR))
		local changed, newr, newg, newb = ui:ColorEdit3("##ambientcolor", r, g, b, ui.ColorEditFlags.PickerHueBar | ui.ColorEditFlags.Uint8 | ui.ColorEditFlags.DisplayRGB | ui.ColorEditFlags.InputRGB)
		if changed then
			local newrimlightcolor = HexToStr(RGBFloatsToHex(newr or r, newg or g, newb or b))
			if newrimlightcolor == DEFAULT_RIMLIGHT_COLOR then
				newrimlightcolor = nil
			end
			if lighting.rimlightcolor ~= newrimlightcolor then
				lighting.rimlightcolor = newrimlightcolor
				editor:SetDirty()
				editor:Refresh(editor.prefabname, lighting)
			end
		end
		]]
		local direction = lighting.clifflightdirection or DEFAULT_CLIFFLIGHT_DIRECTION
		local changed, newx, newy, newz = ui:DragFloat3("Direction", direction[1], direction[2], direction[3],0.1,-50,50)
		if changed then
			local newclifflightdirection = {newx, newy, newz}
			if deepcompare(newclifflightdirection, DEFAULT_CLIFFLIGHT_DIRECTION) then
				newclifflightdirection = nil
			end
			if not deepcompare(lighting.clifflightdirection,newclifflightdirection) then
				lighting.clifflightdirection = {newx, newy, newz}
				editor:SetDirty()
				editor:RefreshLighting(lighting)
			end
		end
		local weight = lighting.clifflightweight or DEFAULT_CLIFFLIGHT_WEIGHT
		local changed, newweight = ui:SliderFloat("Strength", weight,0,1)
		if changed then
			local newclifflightweight = newweight
			if newweight == DEFAULT_CLIFFLIGHT_WEIGHT then
				newweight = nil
			end
			if lighting.clifflightweight ~= newweight then
				lighting.clifflightweight = newweight
				editor:SetDirty()
				editor:RefreshLighting(lighting)
			end
		end
		editor:AddTreeNodeEnder(ui)

		-- ramp texture
		local ramplist = GetRampList()
		local rampidx = nil
		for i = 1, #ramplist do
			if lighting.clifframp == ramplist[i] then
				rampidx = i
				break
			end
		end
		local missing = rampidx == nil and lighting.clifframp ~= nil
		if missing then
			rampidx = 1
			ramplist[1] = lighting.clifframp.." (missing)"
			editor:PushRedButtonColor(ui)
			editor:PushRedFrameColor(ui)
		end
		local newrampidx = ui:_Combo("Ramp Texture", rampidx or 1, ramplist)
		if newrampidx ~= rampidx then
			local newramp = ramplist[newrampidx]
			if string.len(newramp) == 0 then
				newramp = nil
			end
			if lighting.clifframp ~= newramp then
				lighting.clifframp = newramp
				editor:SetDirty()
				editor:OnRampTextureChanged(editor.prefabname, lighting)
				editor:RefreshLighting(lighting)
			end
		end
		if missing then
			editor:PopFrameColor(ui)
			editor:PopButtonColor(ui)
		end


		-- skirt texture
		local skirtlist = GetSkirtList()
		local skirtidx = nil
		for i = 1, #skirtlist do
			if lighting.cliffskirt == skirtlist[i] then
				skirtidx = i
				break
			end
		end
		local missing = skirtidx == nil and lighting.cliffskirt ~= nil
		if missing then
			skirtidx = 1
			skirtlist[1] = lighting.cliffskirt.." (missing)"
			editor:PushRedButtonColor(ui)
			editor:PushRedFrameColor(ui)
		end
		local newskirtidx = ui:_Combo("Cliff Texture", skirtidx or 1, skirtlist)
		if newskirtidx ~= skirtidx then
			local newskirt = skirtlist[newskirtidx]
			if string.len(newskirt) == 0 then
				newskirt = nil
			end
			if lighting.cliffskirt ~= newskirt then
				lighting.cliffskirt = newskirt
				editor:SetDirty()
				editor:OnSkirtTextureChanged(editor.prefabname, lighting)
				editor:RefreshLighting(lighting)
			end
		end
		if missing then
			editor:PopFrameColor(ui)
			editor:PopButtonColor(ui)
		end

	end

	if ui:TreeNode("Object Shadows", ui.TreeNodeFlags.DefaultOpen) then
		ui:Columns(2)
		local shadowSkew = lighting.shadowSkew or DEFAULT_SHADOW_SKEW
		local skewMinX, skewMaxX, skewMin, skewMax = shadowSkew[1], shadowSkew[2], shadowSkew[3], shadowSkew[4]
		local pos = {0,0}
		local changed, newSkewMinX, newSkewMaxX = ui:DragFloat2("X Range##ObjectShadow", skewMinX, skewMaxX,0.1,-50,50)
		if changed then
			skewMinX = lume.round(newSkewMinX, 0.01)
			skewMaxX = lume.round(newSkewMaxX, 0.01)
		end
		ui:NextColumn()
		local changed, newSkewMin, newSkewMax = ui:DragFloat2("Skew##ObjectShadow", skewMin, skewMax,0.05,-1,1)
		if changed then
			skewMin = lume.round(newSkewMin, 0.01)
			skewMax = lume.round(newSkewMax, 0.01)
		end

		ui:NextColumn()
		local shadowSquish = lighting.shadowSquish or DEFAULT_SHADOW_SQUISH
		local squishMinZ, squishMaxZ, squishMin, squishMax = shadowSquish[1], shadowSquish[2], shadowSquish[3], shadowSquish[4]
		local changed, newSquishMinZ, newSquishMaxZ = ui:DragFloat2("Z Range##ObjectShadow", squishMinZ, squishMaxZ,0.1,-50,50)
		if changed then
			squishMinZ = lume.round(newSquishMinZ, 0.01)
			squishMaxZ = lume.round(newSquishMaxZ, 0.01)
		end
		ui:NextColumn()

		local changed, newSquishMin, newSquishMax = ui:DragFloat2("Squish##ObjectShadow", squishMin, squishMax,0.05,-1,1)
		if changed then
			squishMin = lume.round(newSquishMin, 0.01)
			squishMax = lume.round(newSquishMax, 0.01)
		end
		ui:Columns(1)

		local newShadowSkew = {skewMinX, skewMaxX, skewMin, skewMax}
		local newShadowSquish = {squishMinZ, squishMaxZ, squishMin, squishMax}

		if ui:Button("Reset##ObjectShadow") then
			newShadowSkew = nil
			newShadowSquish = nil
		end

		if not deepcompare(newShadowSkew, shadowSkew) then
			if deepcompare(newShadowSkew, DEFAULT_SHADOW_SKEW) then
				newShadowSkew = nil
			end
			lighting.shadowSkew = newShadowSkew
			editor:SetDirty()
			editor:RefreshLighting(lighting)
		end
		if not deepcompare(newShadowSquish, shadowSquish) then
			if deepcompare(newShadowSquish, DEFAULT_SHADOW_SQUISH) then
				newShadowSquish = nil
			end
			lighting.shadowSquish = newShadowSquish
			editor:SetDirty()
			editor:RefreshLighting(lighting)
		end

		editor:AddTreeNodeEnder(ui)
	end

	-- TODO @chrisp #scenegen - modulate by dungeon progress
	local changed, v = ui:DragFloat("Ground Shadow Strength", lighting.ground_shadow_strength or 0.4, 0.01, 0, 1)
	if changed then
		lighting.ground_shadow_strength = v ~= DEFAULT_GROUNDSHADOW_STRENGTH and v or nil
		TheSim:SetGroundShadowStrength(lighting.ground_shadow_strength or DEFAULT_GROUNDSHADOW_STRENGTH)
		editor:SetDirty()
	end

	ui:Spacing()
	editor:Button_CopyToGroup(ui, "Copy '%s' lighting to group: '%s'", GetLightingKeys())

	ui:Unindent()

	editor:AddSectionEnder(ui)
end

local function SetColorCube(lighting, dungeon_progress)
	local cubes = lighting.colorcube or {}
	local cc0 = PrefabUtil.ColorCubeNameToTex(cubes.entrance)
	local cc1 = PrefabUtil.ColorCubeNameToTex(cubes.boss or cubes.entrance)
	PostProcessor:SetColorCubeData(0, cc0, cc1)
	PostProcessor:SetColorCubeLerp(0, dungeon_progress)
end

function ApplyLighting(lighting, dungeon_progress)
	if lighting.colorcube then
		SetColorCube(lighting, dungeon_progress)
	end

	if lighting.ambient then
		TheWorld.components.lightcoordinator:SetDefaultAmbient(HexToRGBFloats(StrToHex(lighting.ambient)))
	end

	PostProcessor:SetBloomScale(0.35)
	PostProcessor:SetExposure(lighting.exposure_min or 0, lighting.exposure_max or 1)

	TheSim:SetRimLightPosition(table.unpack(lighting.rimlightpos or DEFAULT_RIMLIGHT_POS))
	TheSim:SetRimLightColor(HexToRGBFloats(StrToHex(lighting.rimlightcolor or DEFAULT_RIMLIGHT_COLOR)))

	TheSim:SetCliffLightWeight(lighting.clifflightweight or DEFAULT_CLIFFLIGHT_WEIGHT)
	TheSim:SetCliffLightDirection(table.unpack(lighting.clifflightdirection or DEFAULT_CLIFFLIGHT_DIRECTION))
	if TheWorld.cliff_mesh and lighting.clifframp then
		TheWorld.cliff_mesh.Model:SetTopTexture("images/"..lighting.clifframp..".tex")
	end
	if TheWorld.cliff_mesh and lighting.cliffskirt then
		TheWorld.cliff_mesh.Model:SetTexture("levels/tiles/"..lighting.cliffskirt..".tex")
	end

	TheSim:SetLightmapExpansion(8.0)

	TheSim:SetShadowSkew(table.unpack(lighting.shadowSkew or DEFAULT_SHADOW_SKEW))
	TheSim:SetShadowSquish(table.unpack(lighting.shadowSquish or DEFAULT_SHADOW_SQUISH))

	TheSim:SetGroundShadowStrength(lighting.ground_shadow_strength or DEFAULT_GROUNDSHADOW_STRENGTH)
end

function ApplyDefaultLighting()
	ApplyLighting({}, nil)
end

function LoadLightingAssets(editor, lighting)
	editor:OnColorCubeChanged(editor.prefabname, lighting)
	editor:OnRampTextureChanged(editor.prefabname, lighting)
	editor:OnSkirtTextureChanged(editor.prefabname, lighting)
end
