--local BodyParts = require "defs.legacybodyparts"
local CharacterPreviewScreen = require "screens.character.characterpreviewscreen"
local CharacterScreen = require "screens.character.characterscreen"
local Cosmetic = require "defs.cosmetics.cosmetics"
local DebugNodes = require "dbui.debug_nodes"
local Mastery = require "defs.mastery.mastery"
local PrefabEditorBase = require "debug.inspectors.prefabeditorbase"
local lume = require "util.lume"
require "prefabs.prop_autogen" --Make sure our util functions are loaded


local _static = PrefabEditorBase.MakeStaticData("cosmetic_autogen_data")

local CosmeticEditor = Class(PrefabEditorBase, function(self)
	PrefabEditorBase._ctor(self, _static)
	self.name = "Cosmetic Editor"
	self.prefab_label = "Cosmetic"
	self.test_enabled = false

	self:LoadLastSelectedPrefab("cosmeticeditor")
end)

CosmeticEditor.PANEL_WIDTH = 670
CosmeticEditor.PANEL_HEIGHT = 800

local MASTERY_SLOTS = shallowcopy(Mastery.GetOrderedSlots())
table.insert(MASTERY_SLOTS, 1, "NONE")
local COSMETIC_SLOTS = Cosmetic.GetOrderedSlots()

local COLORGROUPS = lume.keys(Cosmetic.ColorGroups)
table.insert(COLORGROUPS, 1, "NONE")

local SPECIES = shallowcopy(Cosmetic.Species)

local SPECIES_WITH_NONE = shallowcopy(Cosmetic.Species)
table.insert(SPECIES_WITH_NONE, 1, "none")

local BODYPART_GROUPS = lume.keys(Cosmetic.BodyPartGroups)

function CosmeticEditor:CosmeticDataDropDown(ui, params, label, paramname, values)
	if params.cosmetic_data == nil then
		params.cosmetic_data = {}
	end

	local idx = 1
	if params.cosmetic_data[paramname] then
		for i,v in ipairs(values) do
			if params.cosmetic_data[paramname] == v then
				idx = i
				break
			end
		end
	else
		params.cosmetic_data[paramname] = values[1]
		self:SetDirty()
	end

	local changed = false
	changed, idx = ui:Combo(label, idx, values)

	if changed or params.cosmetic_data[paramname] == nil then
		params.cosmetic_data[paramname] = values[idx]
		if changed then
			self:SetDirty()
		end
	end
end

function CosmeticEditor:CosmeticDataList(ui, params, label, item_label, paramname, btn_label)
	if params.cosmetic_data[paramname] == nil then
		params.cosmetic_data[paramname] = {}
	end

	local data = params.cosmetic_data[paramname]

	ui:Text(label)

	for i, v in ipairs(data) do
		ui:Columns(2, nil, false)

		local changed, newvalue = ui:InputText(item_label .. tostring(i) .."##".. paramname .. tostring(i), v)
		if changed then
			data[i] = newvalue
			self:SetDirty()
		end

		ui:NextColumn()
		if ui:Button(ui.icon.remove .. "##remove".. paramname .. tostring(i)) then
			table.remove(data, i)
			self:SetDirty()
			break
		end

		ui:Columns()
	end

	if ui:Button(btn_label) then
		table.insert(data, "")
	end
end

function CosmeticEditor:PushPreviewScreen()
	if self.preview_screen == nil then
		self.preview_screen = CharacterPreviewScreen()
		self.preview_screen:SetCloseCallback(function() self.preview_screen = nil end)
		TheFrontEnd:PushScreen(self.preview_screen)
	end
end

function CosmeticEditor:RenderTitle(ui, params)
	if ui:CollapsingHeader("Title Data", ui.TreeNodeFlags.DefaultOpen) then
		if params["cosmetic_data"] == nil then
			params["cosmetic_data"] = {}
		end
	
		local current_title = params["cosmetic_data"].title_key or ""
		local changed = false
		changed, current_title = ui:InputText("String Key##key", current_title, imgui.InputTextFlags.CharsNoBlank)
	
		if changed then
			params["cosmetic_data"].title_key = current_title
			self:SetDirty()
		end
	
		if ui:Button("Gen from batch") then
			local batch = require "defs.cosmetics.batchtitles"
	
			for _, title in pairs(batch) do
				local name = title.name
				title.name = nil
				title.group = title.slot
				self.static.data[name] = title
			end
	
			self:SetDirty()
			self:Save()
		end
	end

end

function CosmeticEditor:RenderColor(ui, params)
	if ui:CollapsingHeader("Color Data", ui.TreeNodeFlags.DefaultOpen) then
		if params["cosmetic_data"] == nil then
			params["cosmetic_data"] = {}
		end
	
		if params["cosmetic_data"].color == nil then
			params["cosmetic_data"].color = {0,0,0}
		end

		self:CosmeticDataDropDown(ui, params, "Color Group##colorgroup", "colorgroup", COLORGROUPS)
	
		local flags = (ui.ColorEditFlags.InputHSV | ui.ColorEditFlags.DisplayHSV )
		local col = params["cosmetic_data"].color
		local changed, h,s,b = ui:ColorEdit3("Edit Color", col[1], col[2], col[3], flags)
	
		if changed then
			params["cosmetic_data"].color = {h,s,b}
			self:SetDirty()
		end
		

		if params.cosmetic_data["colorgroup"] ~= "SMEAR_SKIN_COLOR" and params.cosmetic_data["colorgroup"] ~= "SMEAR_WEAPON_COLOR" then
			self:CosmeticDataDropDown(ui, params, "Species##species", "color_species", SPECIES)
		else
			if params.cosmetic_data["species"] ~= nil then
				params.cosmetic_data["species"] = nil
				self:SetDirty()
			end
		end
	
	
		local changed, newvalue = ui:Checkbox("Species Default Color##default_color", params["cosmetic_data"].is_default_color)
		if changed then
			params["cosmetic_data"].is_default_color = newvalue
		end
		
		self:PushGreenButtonColor(ui)
		if ui:Button("Preview Color") then
			self:PushPreviewScreen()
	
			local hsb = params["cosmetic_data"].color
			local basehsb = Cosmetic.ColorGroupBaseHSBs[params["cosmetic_data"].colorgroup]
	
			local hsbshift =
			{
				hsb[1] - basehsb[1],
				hsb[2] / basehsb[2],
				hsb[3] / basehsb[3],
			}
			hsbshift[1] = hsbshift[1] - math.floor(hsbshift[1])
	
			local def = {
				hsb = hsbshift,
				species = params["cosmetic_data"].color_species,
				colorgroup = params["cosmetic_data"].colorgroup
			}
	
			self.preview_screen:PreviewColor(def)
		end
		self:PopButtonColor(ui)
	end
end

function CosmeticEditor:RenderBodyPart(ui, params)
	if ui:CollapsingHeader("Body Part Data", ui.TreeNodeFlags.DefaultOpen) then
		self:CosmeticDataDropDown(ui, params, "Body Part Group##bodypart_group", "bodypart_group", BODYPART_GROUPS)
		
		if params.cosmetic_data["colorgroup"] == nil then
			params.cosmetic_data.colorgroup = "NONE"
		end
		self:CosmeticDataDropDown(ui, params, "Color Group##bodypart_colorgroup", "colorgroup", COLORGROUPS)
	
		if params.cosmetic_data["bodypart_group"] ~= "SMEAR" and params.cosmetic_data["bodypart_group"] ~= "SMEAR_WEAPON" then
			self:CosmeticDataDropDown(ui, params, "Species##bodyspecies", "bodypart_species", SPECIES)
		else
			if params.cosmetic_data["bodypart_species"] ~= nil then
				params.cosmetic_data["bodypart_species"] = nil
				self:SetDirty()
			end
		end
	
		local current_value = params.cosmetic_data["build"] or ""
		local changed, newvalue = ui:InputText("Build##build", current_value)
		if changed then
			if newvalue == "" then
				params.cosmetic_data["build"] = nil
			else	
				params.cosmetic_data["build"] = newvalue
			end
	
			self:SetDirty()
		end
	
		self:CosmeticDataList(ui, params, "\nSymbol Tags:", "Symbol Tag ", "symboltags", "Add Symbol Tag##addsymboltag")
		self:CosmeticDataList(ui, params, "\nUI Tags:", "UI Tag ", "uitags", "Add UI Tag##adduitag")
		
		self:PushGreenButtonColor(ui)
		if ui:Button("Preview Body Part") then
			self:PushPreviewScreen()
	
			local temp_def = {
				bodypart = params.cosmetic_data["bodypart_group"],
				colorgroup = params.cosmetic_data["colorgroup"],
				build = params.cosmetic_data["build"],
				species = params.cosmetic_data["bodypart_species"]
			}
	
			self.preview_screen:PreviewBodyPart(temp_def)
		end
		self:PopButtonColor(ui)
	end
end

function CosmeticEditor:RenderEmote(ui, params)

	if ui:CollapsingHeader("Emote Data", ui.TreeNodeFlags.DefaultOpen) then
		if params["cosmetic_data"] == nil then
			params["cosmetic_data"] = {}
		end
	
		self:CosmeticDataDropDown(ui, params, "Species##species", "emote_species", SPECIES_WITH_NONE)
	
		ui:Text("Emote name string key: " .. string.upper(params.__displayName))
	
		local current_anim = params["cosmetic_data"].anim or ""
		local changed = false
		changed, current_anim = ui:InputText("Animation##anim", current_anim, imgui.InputTextFlags.CharsNoBlank)
	
		if changed then
			params["cosmetic_data"].anim = current_anim
			self:SetDirty()
		end
	
		local icons_emotes = require "gen.atlas.icons_emotes"

		local icon_path = icons_emotes.tex[params.__displayName]

		ui:Text("Icon Path: " .. icon_path)
		local atlas, icon = GetAtlasTex(icon_path) --"images/icons_ftf/"
		ui:AtlasImage(atlas, icon, 100, 100)
		
		self:PushGreenButtonColor(ui)
		if ui:Button("Preview Emote") then
			self:PushPreviewScreen()
	
			self.preview_screen:PreviewEmote(params["cosmetic_data"])
		end
		self:PopButtonColor(ui)
	end
end

function CosmeticEditor:RenderEquipmentDye(ui, params)
	if ui:CollapsingHeader("Equipment Dye Data", ui.TreeNodeFlags.DefaultOpen) then
		if params["cosmetic_data"] == nil then
			params["cosmetic_data"] = {}
		end
	
		-- Armour Set (e.g. yammo, cabbageroll, etc)
		local armour_set = params["cosmetic_data"].armour_set or ""
		local changed = false
		changed, armour_set = ui:InputText("Armour Set##armour_set", armour_set, imgui.InputTextFlags.CharsNoBlank)
	
		if changed then
			params["cosmetic_data"].armour_set = armour_set
			self:SetDirty()
		end
	
		-- Dye Number (e.g 1, 2, 3, 4)
		local dye_number = params["cosmetic_data"].dye_number or 1
		changed = false
		changed, dye_number = ui:InputInt("Dye Number##dye_number", dye_number, 1, 5)
	
		if changed then
			params["cosmetic_data"].dye_number = dye_number
			self:SetDirty()
		end
	
		local build_override = params["cosmetic_data"].build_override or ""
		changed = false
		changed, build_override = ui:InputText("Build Override##build_override", build_override, imgui.InputTextFlags.CharsNoBlank)
	
		if changed then
			params["cosmetic_data"].build_override = build_override
			self:SetDirty()
		end
	
		if ui:Button("Preview Dye") then
			self:PushPreviewScreen()
			self.preview_screen:PreviewArmorDye(params["cosmetic_data"])
		end

		if ui:Button("Preview in Game") then
			if self.preview_screen ~= nil then
				TheFrontEnd:PopScreen(self.preview_screen)
			end

			ThePlayer.components.inventory:Debug_ForceEquipVisuals(params["cosmetic_data"])
		end
	end
end

function CosmeticEditor:RenderCategory(slot, ui, params)
	if slot == "PLAYER_TITLE" then
		self:RenderTitle(ui, params)
	elseif slot == "PLAYER_COLOR" then
		self:RenderColor(ui, params)
	elseif slot == "PLAYER_BODYPART" then
		self:RenderBodyPart(ui, params)
	elseif slot == "PLAYER_EMOTE" then
		self:RenderEmote(ui, params)
	elseif slot == "EQUIPMENT_DYE" then
		self:RenderEquipmentDye(ui, params)
	end
end

function CosmeticEditor:AddEditableOptions(ui, params)
	local function DropDown(ui, params, label, paramname, values)
		local idx = 1
		if params[paramname] then
			for i,v in ipairs(values) do
				if params[paramname] == v then
					idx = i
					break
				end
			end
		else
			params[paramname] = values[1]
			self:SetDirty()
		end

		local changed = false
		changed, idx = ui:Combo(label, idx, values)

		if changed or params[paramname] == nil then
			params[paramname] = values[idx]
			if changed then
				self:SetDirty()
			end
		end
	end

	if ui:CollapsingHeader("General Data", ui.TreeNodeFlags.DefaultOpen) then
		DropDown(ui, params, "Rarity##rarity", "rarity", Cosmetic.Rarities)
		DropDown(ui, params, "Mastery##mastery", "mastery", MASTERY_SLOTS)
	
		if params["locked"] == nil then
			params["locked"] = true
			self:SetDirty()
		end
	
		local locked = params["locked"]
		local changed = false
		changed, locked = ui:Checkbox("Locked", locked)
		if changed then
			params["locked"] = locked
			if locked then
				params["purchased"] = false
			end
	
			self:SetDirty()
		end
	
		if params["purchased"] == nil then
			params["purchased"] = false
			self:SetDirty()
		end
	
		if params["hidden"] == nil then
			params["hidden"] = false
			self:SetDirty()
		end
	
	
		local purchased = params["purchased"]
		changed = false
		changed, purchased = ui:Checkbox("Purchased", purchased)
		if changed then
			params["purchased"] = purchased
			if purchased then
				params["locked"] = false
			end
	
			self:SetDirty()
		end
	
		if ui:TreeNode("Deprecated/Hidden", ui.TreeNodeFlags.DefaultClosed) then
			local hidden = params["hidden"]
			changed = false
			changed, hidden = ui:Checkbox("Hidden", hidden)
			if changed then
				params["hidden"] = hidden
				self:SetDirty()
			end
		
			local deprecated = params["deprecated"]
			changed = false
			changed, deprecated = ui:Checkbox("Deprecated", deprecated)
			if changed then
				params["deprecated"] = deprecated
				self:SetDirty()
			end
			self:AddTreeNodeEnder(ui)
		end
	end

	-- Keeping this here in case we need to iterate through all the data
	-- if ui:Button("Clean Emotes") then
	-- 	for name, data in pairs(self.static.data) do
	-- 		if data.group == "PLAYER_EMOTE" then
	-- 			data.icon_path = nil
	-- 			data.name_key = nil
	-- 		end
	-- 	end
	-- 	self:SetDirty()
	-- end

	self:AddSectionEnder(ui)
	self:RenderCategory(params["group"], ui, params)
	self:AddSectionEnder(ui)

	-- Only render the unlock tracker option if it can be changed from the character screen
	if params["group"] == "PLAYER_TITLE" or params["group"] == "PLAYER_COLOR" or params["group"] == "PLAYER_BODYPART" then
		self:RenderGenerateFromUnlockTracker(ui)
	end
end

function CosmeticEditor:RenderGenerateFromUnlockTracker(ui)
	if self.generated_categories == nil then
		self.generated_categories = 
		{
			TITLE = false,
			PLAYER_COLOR = false,
			PLAYER_BODYPART = false
		}
	end

	if ui:CollapsingHeader("Generate from Character Screen", ui.TreeNodeFlags.DefaultClosed) then
		for category, should_generate in pairs(self.generated_categories) do
			local cat_str = tostring(category)
			local changed, newvalue = ui:Checkbox(cat_str .. "##" .. cat_str .. "_unlocktracker", should_generate)
			if changed then
				self.generated_categories[category] = newvalue
			end
		end
		
		if ui:Button("Open Character Screen") then
			if self.debug_character_screen == nil then
				self.debug_character_screen = CharacterScreen(ThePlayer, nil, nil, true)
				self.debug_character_screen:SetCloseCallback(function() self.debug_character_screen = nil end)
				TheFrontEnd:PushScreen(self.debug_character_screen)
			end
		end
		
		self:PushGreenButtonColor(ui)
		if ui:Button("Generate") then
			if ThePlayer == nil then
				return
			end

			for category, should_generate in pairs(self.generated_categories) do
				for name, data in pairs(self.static.data) do
					if data.group == category and not data.deprecated then
						local is_locked = not ThePlayer.components.unlocktracker:IsCosmeticUnlocked(name, category)
						local is_purchased = ThePlayer.components.unlocktracker:IsCosmeticPurchased(name, category)

						self.static.data[name].locked = is_locked
						self.static.data[name].purchased = is_purchased
						
						if ThePlayer.sg.mem.hidden_cosmetics~= nil and ThePlayer.sg.mem.hidden_cosmetics[name] ~= nil then
							self.static.data[name].hidden = ThePlayer.sg.mem.hidden_cosmetics[name]
						end

						if ThePlayer.sg.mem.rarity_changes ~= nil and ThePlayer.sg.mem.rarity_changes[category] ~= nil and 
						   ThePlayer.sg.mem.rarity_changes[category][name] ~= nil then
							self.static.data[name].rarity = ThePlayer.sg.mem.rarity_changes[category][name]
						end

						self:SetDirty()
					end
				end
			end

			ThePlayer.sg.mem.hidden_cosmetics = nil
		end
		self:PopButtonColor(ui)
	end
end

function CosmeticEditor:OnDeactivate()
	if self.preview_screen then
		TheFrontEnd:PopScreen(self.preview_screen)
	end
	CosmeticEditor._base.OnDeactivate(self)
end

DebugNodes.CosmeticEditor = CosmeticEditor

return CosmeticEditor
