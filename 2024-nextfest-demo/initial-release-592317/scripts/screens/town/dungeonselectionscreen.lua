local ActionButton = require "widgets/actionbutton"
local ConfirmDialog = require "screens.dialogs.confirmdialog"
local Image = require("widgets/image")
local MapLocationMarker = require"widgets.ftf.dungeonselection.maplocationmarker"
local MapSidebar = require"widgets.ftf.dungeonselection.mapsidebar"
local RoomLoader = require "roomloader"
local Screen = require "widgets.screen"
local Text = require "widgets.text"
local UIAnim = require "widgets.uianim"
local Widget = require "widgets.widget"
local biomes = require "defs.biomes"
local easing = require "util.easing"
local fmodtable = require "defs.sound.fmodtable"
local iterator = require "util.iterator"
local kassert = require "util.kassert"
local lume = require "util.lume"
local playerutil = require"util/playerutil"
local templates = require "widgets.ftf.templates"


local DungeonSelectionScreen = Class(Screen, function(self, player)
	Screen._ctor(self, "DungeonSelectionScreen")
	self:SetAudioCategory(Screen.AudioCategory.s.Fullscreen)
	self:SetOwningPlayer(player)

	self.bg = self:AddChild(templates.SolidBackground())

	-- The map can scroll around, so it's bigger than the screen.
	self.mapRoot = self:AddChild(Widget())

	-- Info sidebar (contains the close-button)
	self.sidebar = self:AddChild(MapSidebar())
		:SetOnLocationUnlockedFn(function(locationData) self:OnLocationUnlocked() end)
		:SetOwningPlayer(player)
		:SetOnCloseFn(function() self:OnCloseButton() end)
		:PrepareAnimation()

	-- Travel button
	self.travel_button_backing = self:AddChild(Image("images/map_ftf/travel_btn_backing.tex"))
		:SetName("Travel button backing")
		:SetMultColorAlpha(0)
	self.travel_button = self:AddChild(ActionButton())
		:SetName("Travel button")
		:SetMultColorAlpha(0)
		:SetPrimary()
		:SetNavFocusable(false)
		:SetSize(BUTTON_W * 1.1, BUTTON_H)
		:SetText(STRINGS.UI.MAPSCREEN.TRAVEL_BUTTON)
		:SetOnClick(function() self:OnClickTravel() end)

	-- Region-locked error
	self.lockedregion_error_widget = self:AddChild(Widget())
		:SetName("Locked-region error widget")
		:SetHiddenBoundingBox(true)
		:SetMultColorAlpha(0)
		:Hide()
	self.lockedregion_error_bg = self.lockedregion_error_widget:AddChild(Image("images/ui_ftf/popup_message_down.tex"))
		:SetName("Locked-region error bg")
	self.lockedregion_error_text = self.lockedregion_error_widget:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT))
		:SetName("Locked-region error text")
		:SetGlyphColor(UICOLORS.BACKGROUND_DARK)
		:SetHAlign(ANCHOR_MIDDLE)
		:SetAutoSize(450)

	self:CreateMap()
	self.default_focus = self.travel_button
	self.current_marker = nil

	self:Layout()
	self:AnimateIn()
end)

DungeonSelectionScreen.CONTROL_MAP =
{
	-- {
	-- 	control = Controls.Digital.Y,
	-- 	fn = function(self)
	-- 		-- Switch weapon
	-- 		self.sidebar:TriggerWeaponSwitch()
	-- 		return true
	-- 	end,
	-- },
	{
		control = Controls.Digital.CANCEL,
		hint = function(self, left, right)
			table.insert(right, loc.format(LOC"UI.CONTROLS.CANCEL", Controls.Digital.CANCEL))
		end,
		fn = function(self)
			self:OnCloseButton()
			return true
		end,
	},
	{
		control = Controls.Digital.MENU_TAB_PREV,
		hint = function(self, left, right)
			table.insert(right, loc.format(LOC"UI.CONTROLS.PREV_TAB", Controls.Digital.MENU_TAB_PREV))
		end,
		fn = function(self)
			if self.travel_button_done_animating then
				self.sidebar:DecreaseAscensionLevel()
				return true
			end
		end,
	},
	{
		control = Controls.Digital.MENU_TAB_NEXT,
		hint = function(self, left, right)
			table.insert(right, loc.format(LOC"UI.CONTROLS.NEXT_TAB", Controls.Digital.MENU_TAB_NEXT))
		end,
		fn = function(self)
			if self.travel_button_done_animating then
				self.sidebar:IncreaseAscensionLevel()
				return true
			end
		end,
	},
}


local MapLayer = Class(Widget, function(self, name)
	Widget._ctor(self, "MapLayer: ".. name)
end)

function MapLayer:IsCloud()
	return self.is_cloud
end

function MapLayer:SetCloud()
	self.is_cloud = true
	return self
end

local ImageMapLayer = Class(MapLayer, function(self, name, tex)
	MapLayer._ctor(self, name)
	self.image = self:AddChild(Image(tex))
end)

function MapLayer:UseScreenWidth()
	self.image:SetWidth_PreserveAspect(RES_X)
	return self
end

local AnimMapLayer = Class(MapLayer, function(self, name)
	MapLayer._ctor(self, name)
	self.anim = self:AddChild(UIAnim())
		:SetScale(0.733) -- around the same as old png map
		:SetBank("dungeon_map_art")
		:SetName(name)
	-- Should we play a full width anim and CaptureCurrentAnimBBox to have a
	-- consistent size for layout? Instead, I just position these all
	-- identically.
end)

function AnimMapLayer:PlayLayerAnimation(anim)
	self.anim:PlayAnimation(anim)
	return self
end


local LocationRevealLayer = Class(AnimMapLayer, function(self, biome_location)
	AnimMapLayer._ctor(self, biome_location.id)
	self.biome_location = biome_location
end)

function LocationRevealLayer:ApplyUnlocks(unlocks)
	if unlocks:IsLocationUnlocked(self.biome_location.id) then
		self:Unlock()
	else
		self:Lock()
	end
	return self
end

function LocationRevealLayer:_PlayState(suffix)
	self.anim:PlayAnimation(self.biome_location.id .. suffix)
	return self
end

function LocationRevealLayer:Lock()
	return self:_PlayState("_cloud_locked")
end

function LocationRevealLayer:Unlock()
	return self:_PlayState("_cloud_unlocked")
end

function LocationRevealLayer:Reveal()
	return self:_PlayState("_cloud_reveal")
end

function LocationRevealLayer:IsLocked()
	local anim = self.anim:GetAnimState():GetCurrentAnimationName() or ""
	return anim:find("_locked")
end




function DungeonSelectionScreen:DebugDraw_AddSection(ui, panel)
	DungeonSelectionScreen._base.DebugDraw_AddSection(self, ui, panel)

	ui:Spacing()
	ui:Text("DungeonSelectionScreen")
	ui:Indent() do
		if ui:CollapsingHeader("Map Markers", ui.TreeNodeFlags.DefaultOpen) then
			ui:Indent()

			ui:Text("Tune map marker locations. Paste these values right into biomes.lua.")
			self.dbg_map_data = self.dbg_map_data or deepcopy(biomes.locations.treemon_forest)
			local data = self.dbg_map_data
			data.map_x = ui:_SliderFloat("map_x", data.map_x, 0, 1)
			data.map_y = ui:_SliderFloat("map_y", data.map_y, 0, 1)
			self:_LayoutMarker(self.k_mapMarkers.treemon_forest, data)
			if ui:Button("Copy Marker Location Lua") then
				local txt = ([[
	map_x = %.3f,
	map_y = %.3f,
]]):format(data.map_x, data.map_y)
				ui:SetClipboardText(txt)
			end
			ui:Unindent()
		end

		if ui:CollapsingHeader("Layers", ui.TreeNodeFlags.DefaultOpen)
			and ui:BeginTable("layer-toggle", 5, ui.TableFlags.SizingFixedFit)
		then
			ui:Indent()

			for _,layer in iterator.sorted_pairs(self.map_layers:GetChildren()) do
				local id = layer._widgetname
				ui:TableNextRow()
				ui:TableNextColumn()
				ui:Text(id)

				ui:TableNextColumn()
				if ui:Button("Debug##".. id) then
					d_viewinpanel(layer)
				end
				ui:TableNextColumn()
				local will_show = not layer:IsShown()
				if ui:Button((will_show and "Show##" or "Hide##").. id) then
					layer:SetShown(will_show)
				end
				if LocationRevealLayer.is_instance(layer) then
					ui:TableNextColumn()
					local will_lock = not layer:IsLocked()
					if ui:Button((will_lock and "Lock##" or "Unlock##").. id) then
						if will_lock then
							layer:Lock()
						else
							layer:Unlock()
						end
					end
					ui:TableNextColumn()
					if ui:Button("Reveal##".. id, nil, nil, self.k_mapMarkers[layer.biome_location.id] == nil) then
						-- Clear brackets to simulate first entering screen
						-- because we only add them *after* clicking on a
						-- location.
						self.selection_brackets:Remove()
						self.selection_brackets = nil
						self.focus_brackets_enabled = false

						self:_RevealLocation(layer.biome_location, "cheat_reveal")
					end
				end
			end
			ui:Unindent()
			ui:EndTable()
		end

		if ui:CollapsingHeader("Biomes", ui.TreeNodeFlags.DefaultOpen)
			and ui:BeginTable("biome-toggle", 4, ui.TableFlags.SizingFixedFit)
		then
			ui:Indent()

			local player = self:GetOwningPlayer()
			local unlocks = player.components.unlocktracker
			for id,location in iterator.sorted_pairs(biomes.locations) do
				ui:TableNextColumn()
				ui:Text(id)

				ui:TableNextColumn()
				if ui:Button("Debug##".. id) then
					d_viewinpanel(location)
				end
				ui:TableNextColumn()
				local should_lock = unlocks:IsLocationUnlocked(id)
				if ui:Button((should_lock and "Lock" or "Unlock") .." Location##".. id) then
					if should_lock then
						unlocks:LockLocation(id)
					else
						unlocks:UnlockLocation(id)
					end
				end
				ui:TableNextColumn()
				local reveal_flag = id .."_reveal"
				should_lock = unlocks:IsFlagUnlocked(reveal_flag)
				if ui:Button((should_lock and "Mark unrevealed (lock)" or "Mark revealed (unlock)") .."##".. reveal_flag) then
					if should_lock then
						unlocks:LockFlag(reveal_flag)
					else
						unlocks:UnlockFlag(reveal_flag)
					end
				end
			end
			ui:EndTable()
			ui:Unindent()
		end
	end
	ui:Unindent()
end

function DungeonSelectionScreen:OnScreenResize(w, h)
	DungeonSelectionScreen._base.OnScreenResize(self, w, h)

	self:Layout()
end

function DungeonSelectionScreen:OnOpen()
	DungeonSelectionScreen._base.OnOpen(self)
	self:OnInputModeChanged()
end

function DungeonSelectionScreen:OnInputModeChanged(old_device_type, new_device_type)
	if TheFrontEnd:IsRelativeNavigation() then
		self.travel_button_backing:Hide()
		self.travel_button:Hide()
	else
		self.travel_button_backing:Show()
		self.travel_button:Show()
	end
end

-- function DungeonSelectionScreen:OnFocusMove(dir, down)
-- 	DungeonSelectionScreen._base.OnFocusMove(self, dir, down)

-- 	-- If we're navigating to a new location marker with keys (not with mouse),
-- 	-- click it automatically
-- 	if TheFrontEnd:IsRelativeNavigation() then
-- 		local focus = self:GetDeepestFocus()
-- 		if focus:is_a(MapLocationMarker) then
-- 			focus:Click()
-- 		end
-- 	end
-- end

function DungeonSelectionScreen:_LayoutMarker(marker, data)
	marker:LayoutBounds("left", "top", self.map_layers.terrain)
		:Offset(self.map_size.x * data.map_x, -self.map_size.y * data.map_y)

	-- TODO(map): Can we get this symbol position lookup to work?
	--~ -- Symbol positioning is only relative to the animstate it comes from, so
	--~ -- we reparent to one to capture the right position.
	--~ local map_anim = self.map_layers.base_map.anim
	--~ local symbol = "map_marker_".. marker:GetId()
	--~ local pos = Vector2(map_anim:GetSymbolPosition_Vec2(symbol))
	--~ marker
	--~ 	:Reparent(map_anim)
	--~ 	:SetPosition(pos:unpack())
	--~ 	:Reparent(self.mapRoot)
end

function DungeonSelectionScreen:CreateMap()
	local all_locations = {}

	local player = self:GetOwningPlayer()
	local unlocks = player.components.unlocktracker

	-- we should always show everything the owning players has unlocked.
	for region_id, region_data in pairs(biomes.regions) do
		if region_id ~= "town" and unlocks:IsRegionUnlocked(region_id) then -- LOCATION
			for location_id, location_data in pairs(region_data.locations) do
				if unlocks:IsLocationUnlocked(location_id) then -- LOCATION
					all_locations[location_id] = location_data
				end
			end
		end
	end

	-- The layers are larger than the screen to pan around.
	self.map_layers = self.mapRoot:AddChild(Widget("map_layers"))

	self.map_layers.ocean = self.map_layers:AddChild(MapLayer("Ocean"))
	local grid_count = Vector2(2, 2)
	for x=1,grid_count.x do
		for y=1,grid_count.y do
			self.map_layers.ocean:AddChild(Image("images/bg_world_map_ocean_texture/world_map_ocean_texture.tex"))
		end
	end
	self.map_layers.ocean:LayoutChildrenInGrid(grid_count.x, 0)
		:LayoutBounds("left", "center", self)
		:Offset(-200, -10) -- it's bigger than the screen anyway.

	-- HACK(map): Having problems exporting map at high quality, so use png for
	-- now instead of terrain_layers.
	self.map_layers.terrain = self.map_layers:AddChild(ImageMapLayer("Image: terrain", "images/bg_world_map_full/world_map_full.tex"))
		:LayoutBounds("left", "top", self)
	self.map_layers.bottom_cloud = self.map_layers:AddChild(ImageMapLayer("Image: bottom_cloud", "images/bg_world_map_art_cloud_below/world_map_art_cloud_below.tex"))
		:UseScreenWidth()
		:SetCloud()
		:SetScale(1.2)
		:LayoutBounds("left", "center", self)
		:Offset(-510, -200)
	self.map_layers.top_cloud = self.map_layers:AddChild(ImageMapLayer("Image: top_cloud", "images/bg_world_map_art_cloud_above/world_map_art_cloud_above.tex"))
		:UseScreenWidth()
		:SetCloud()
		:LayoutBounds("right", "center", self)
		:Offset(80, 0)
	-- Cloud covers too much, so push edges beyond screen bounds.
	self.map_layers.top_cloud.image:SetScale(1.350)

	--~ local terrain_layers = {
	--~ 	"ocean",
	--~ 	"base_map",
	--~ 	"forest_map",
	--~ 	"ancient_map",
	--~ 	"desert_map",
	--~ 	"swamp_map",
	--~ 	"ice_map",
	--~ 	"home_map",
	--~ 	"base_map_overlay",
	--~ 	"bottom_cloud",
	--~ 	"top_cloud",
	--~ }
	--~ for _,anim in ipairs(terrain_layers) do
	--~ 	self.map_layers[anim] = self.map_layers:AddChild(AnimMapLayer(anim))
	--~ 		:PlayLayerAnimation(anim .."_idle")
	--~ end
	--~ self.map_layers.bottom_cloud:SetCloud()

	for id,location in pairs(biomes.locations) do
		if location.type == biomes.location_type.DUNGEON then
			self.map_layers[id] = self.map_layers:AddChild(LocationRevealLayer(location))
				:ApplyUnlocks(unlocks)
				:SetCloud()
				:Offset(240, 170)
		end
	end

	self.map_layers.top_cloud
		:SetCloud()
		:MoveToFront()


	self.map_size = Vector2(self.map_layers.terrain:GetSize())

	-- TODO(map): Remove all cloud handling and let animators do it in flash.
	self.cloud_list = lume.filter(self.map_layers:GetChildren(), function(v)
		return v:IsCloud()
	end)
	self:AnimateClouds()

	-- Add map locations
	self.mapMarkers = {}
	self.k_mapMarkers = {}
	for id, data in pairs(all_locations) do
		local marker = self.mapRoot:AddChild(MapLocationMarker(self:GetOwningPlayer(), id, data))
		self:_LayoutMarker(marker, data)

		-- Set click callback
		marker:SetOnClick(function() self:OnLocationClicked(marker, id, data) end)
		marker:SetOnGainFocus(function() self:OnLocationFocused(marker, id, data) end)

		-- Save reference
		table.insert(self.mapMarkers, marker)
		self.k_mapMarkers[id] = marker
	end


	-- "Scroll" to show all current locations
	self.mapRoot:SetPosition(125, 0)


	for id,location in iterator.sorted_pairs(all_locations) do
		local reveal_flag = id ..'_reveal'
		if unlocks:IsLocationUnlocked(id)
			and not unlocks:IsFlagUnlocked(reveal_flag) -- LOCATION OR FLAG
		then
			self:_RevealLocation(location, reveal_flag)
			break
		end
	end
end

function DungeonSelectionScreen:_RevealLocation(biome_location, reveal_flag)
	local map_marker = self.k_mapMarkers[biome_location.id]
	map_marker:Hide()
	local lock_layer = self.map_layers[biome_location.id]
	lock_layer:Lock()

	self:Hide()

	self:RunUpdater(
		Updater.Series({
			Updater.Do(function() TheFrontEnd:Fade(FADE_OUT, 1) end),
			Updater.Wait(1.5),
			Updater.Do(function()
				TheFrontEnd:GetLetterbox():SetDisplayAmount(0)
				self:Show()
				TheFrontEnd:Fade(FADE_IN, 1)
			end),
			Updater.Wait(1.5),
			Updater.Do(function()
				lock_layer:Reveal()
			end),
			Updater.Wait(0.33),
			Updater.Do(function()
				map_marker:SetMultColorAlpha(0)
				map_marker:Show()
			end),
			Updater.Ease(function(v)
				map_marker:SetMultColorAlpha(v)
			end, 0, 1, 0.66, easing.linear),
			Updater.Wait(0.33),
			Updater.Do(function()
				map_marker:Click()
				self.selection_brackets:SetMultColorAlpha(0) -- hide to fade in
				-- Use unlock as seen because default state is locked.
				self:GetOwningPlayer().components.unlocktracker:UnlockFlag(reveal_flag)
			end),
			Updater.Ease(function(v)
				self.selection_brackets:SetMultColorAlpha(v)
			end, 0, 1, 0.66, easing.linear),
		})
	)

end

function DungeonSelectionScreen:_ScaleClouds(s)
	for _,cloud in ipairs(self.cloud_list) do
		cloud:SetScale(s)
	end
end

function DungeonSelectionScreen:AnimateClouds()
	local time = 8
	local scale_min = 1.00
	local scale_max = 1.01
	self:RunUpdater(
		Updater.Loop({
			Updater.Ease(function(v) self:_ScaleClouds(v) end, scale_min, scale_max, time, easing.inOutSine),
			Updater.Ease(function(v) self:_ScaleClouds(v) end, scale_max, scale_min, time, easing.inOutSine),
		})
	)
	return self
end

function DungeonSelectionScreen:_GetDefaultMapDestination()
	local last_location = TheSaveSystem.progress:GetValue("last_selected_location")

	if last_location and self.k_mapMarkers[last_location] then
		return self.k_mapMarkers[last_location]
	end

	kassert.greater(#self.mapMarkers, 0, "Expected map markers (from CreateMap)")

	for k, v in ipairs(self.mapMarkers) do
		if v:IsUnlocked(v.locationData) then
			-- this should only run the first time the map is opened, and after
			-- that there will be data for 'last_selected_location'
			return v
		end
	end
	error("All known locations were locked!")
end

function DungeonSelectionScreen:OnLocationFocused(locationMarker, locationId, locationData)
	-- On gamepad, focusing on a location should update the sidebar
	if TheFrontEnd:IsRelativeNavigation() and self.current_marker ~= locationMarker then
		self:_ShowLocationInfo(locationMarker, locationId, locationData)
	end
end

function DungeonSelectionScreen:OnLocationClicked(locationMarker, locationId, locationData)
	TheSaveSystem.progress:SetValue("last_selected_location", locationId)

	-- If this location was already selected, and clicked on again with a controller, travel to it
	if TheFrontEnd:IsRelativeNavigation()
		and self.current_marker == locationMarker
	then
		local location_data = self.current_marker:GetLocationData()
		local is_unlocked, invalid_players = playerutil.GetLocationUnlockInfo(location_data)
		if is_unlocked then
			self:PromptToTravel(locationMarker, locationData)
		else
			self:_ShowLockedPrompt(locationMarker, invalid_players)
		end
		return
	end

	self:_ShowLocationInfo(locationMarker, locationId, locationData)
end

function DungeonSelectionScreen:_ShowLocationInfo(locationMarker, locationId, locationData)

	self.current_marker = locationMarker
	self.current_marker:SetFocus() -- Moves the brackets to it

	----------------------------------------------------------------------
	-- Focus selection brackets
	if not self.focus_brackets_enabled then
		self:EnableFocusBracketsForGamepadAndMouse("images/mapicons_ftf/biome_brackets.tex", 66, 74, 114, 106, 1)
	end
	----------------------------------------------------------------------

	-- Update sidebar
	local isPlayerHere = false
	self.sidebar:SetLocationData(locationData, isPlayerHere)

	self:Layout()

	-- Animate in the details panel
	self.sidebar:AnimateIn()

	-- And the travel button
	if self.travel_button_done_animating then
		local target_x, target_y = self.travel_button:GetPos()
		self.travel_button:Offset(0, -20)
		self.travel_button:MoveTo(target_x, target_y, 0.8, easing.outElastic)
	end
end

-- Happens when the player clicks the Travel button
function DungeonSelectionScreen:OnClickTravel()
	if self.current_marker then
		local location_data = self.current_marker:GetLocationData()
		local is_unlocked, invalid_players = playerutil.GetLocationUnlockInfo(location_data)

		if is_unlocked then
			-- Everyone in the party can travel here. Let's go!
			self:OnTravelToLocation(self.current_marker:GetLocationData())
		else
			-- This location hasn't been locked by someone. Show a popup instead
			self:ShowLockedRegionError(invalid_players)
		end
	end
end

function DungeonSelectionScreen:_BuildLockedRegionText(invalid_players)
	-- Collate player usernames
	local player_names = {}
	for k, player in pairs(invalid_players) do
		player_names[k] = player:GetCustomUserName()
	end
	-- Display them in the error
	local error_text = string.format(STRINGS.UI.MAPSCREEN.LOCKED_REGION_ERROR, table.concat(player_names, ", "))
	return error_text
end

function DungeonSelectionScreen:ShowLockedRegionError(invalid_players)
	if not self.lockedregion_error_widget_displayed then

		self.lockedregion_error_text:SetText(self:_BuildLockedRegionText(invalid_players))

		-- Layout error widget
		self.lockedregion_error_text:LayoutBounds("center", "center", self.lockedregion_error_bg)
			:Offset(-5, 17)
		self.lockedregion_error_widget:LayoutBounds("center", "above", self.travel_button)
			:Offset(0, 15)
		self.lockedregion_error_widget_x, self.lockedregion_error_widget_y = self.lockedregion_error_widget:GetPos() -- For animation

		-- Animate in the error message
		self.lockedregion_error_widget_displayed = true
		self.lockedregion_error_widget:SetPosition(self.lockedregion_error_widget_x, self.lockedregion_error_widget_y - 40)
			:MoveTo(self.lockedregion_error_widget_x, self.lockedregion_error_widget_y, 0.95, easing.outElasticUI)
			:AlphaTo(1, 0.2, easing.outQuad)
			:Show()
			:ScaleTo(1, 1, 3.0, easing.linear, function()
				self:HideLockedRegionError()
			end)
		TheFrontEnd:GetSound():PlaySound(fmodtable.Event.error_bump)
	end
	return self
end

function DungeonSelectionScreen:HideLockedRegionError()
	if self.lockedregion_error_widget_displayed then
		self.lockedregion_error_widget_displayed = false
		self.lockedregion_error_widget:AlphaTo(0, 0.15, easing.outQuad)
			:MoveTo(self.lockedregion_error_widget_x, self.lockedregion_error_widget_y - 10, 0.15, easing.outQuad, function()
				self.lockedregion_error_widget:SetMultColorAlpha(0)
					:Hide()
			end)
	end
	return self
end

function DungeonSelectionScreen:OnLocationUnlocked()

	-- Refresh all locations
	for k, v in ipairs(self.mapMarkers) do
		v:SetLocationData(v.locationId, v.locationData)
	end

end

function DungeonSelectionScreen:PromptToTravel()
	assert(self.current_marker)
	if self.confirm then
		return
	end

	self.confirm = ConfirmDialog(nil, self.current_marker, true, STRINGS.UI.DUNGEONSELECTIONSCREEN.CONFIRM_TRAVEL.TITLE)
		:SetArrowUp()

	self.confirm:SetYesButtonText(STRINGS.UI.DUNGEONSELECTIONSCREEN.CONFIRM_TRAVEL.YES)
		:SetNoButtonText(STRINGS.UI.DUNGEONSELECTIONSCREEN.CONFIRM_TRAVEL.NO)
		:SetOnDoneFn(function(accepted)
			TheFrontEnd:PopScreen()
			self.confirm = nil
			if accepted then
				self:OnClickTravel()
			end
		end)

	TheFrontEnd:PushScreen(self.confirm)

	self.confirm:AnimateIn()
end

function DungeonSelectionScreen:_ShowLockedPrompt(location_marker, invalid_players)
	local title = self:_BuildLockedRegionText(invalid_players)
	self.confirm = ConfirmDialog(nil, self.current_marker, true)
		:SetSubtitle(title)
		:SetArrowUp()

	-- Use cancel button so B dismisses the popup.
	self.confirm
		:SetCancelButtonText(STRINGS.UI.BUTTONS.CANCEL)
		:MoveCancelButtonToTop()
		:HideYesButton()
		:HideNoButton()
		:CenterButtons()
		:SetOnDoneFn(function()
			TheFrontEnd:PopScreen(self.confirm)
			self.confirm = nil
		end)

	-- HACK(demo): ConfirmDialog should set the first visible button as the default. Smallest fix possible for now.
	self.confirm.default_focus = self.confirm:GetCancelButton()

	TheFrontEnd:PushScreen(self.confirm)

	self.confirm:AnimateIn()
end

function DungeonSelectionScreen:OnTravelToLocation(biome_location)
	if biome_location.type == biomes.location_type.DUNGEON then
		-- Send a 'requestrun' message to the host:
		local playerID = self:GetOwningPlayer().Network:GetPlayerID()
		RoomLoader.RequestRunWithLocationData(playerID, biome_location)
		self:OnCloseButton()
	end
end

function DungeonSelectionScreen:OnCloseButton()
	TheFrontEnd:PopScreen()

	--sound
	TheFrontEnd:GetSound():PlaySound(fmodtable.Event.dungeonSelectionScreen_hide)
end

function DungeonSelectionScreen:AnimateIn()

	--sound
	TheFrontEnd:GetSound():PlaySound(fmodtable.Event.dungeonSelectionScreen_show)

	-- Hide elements
	self.map_layers:SetMultColorAlpha(0)
	-- self.close_button:SetMultColorAlpha(0)
	self.travel_button_backing:SetMultColorAlpha(0)
	self.travel_button:SetMultColorAlpha(0)


	-- Get default positions
	local bgX, bgY = self.map_layers:GetPosition()
	-- local close_buttonX, close_buttonY = self.close_button:GetPosition()
	local travel_button_backingX, travel_button_backingY = self.travel_button_backing:GetPosition()
	local travel_buttonX, travel_buttonY = self.travel_button:GetPosition()


	-- Animate in locations
	local locationsUpdater = Updater.Series()
	local numDestinationMarkers = #self.mapMarkers
	kassert.greater(numDestinationMarkers, 0, "Animating in with zero map markers")
	for k, marker in ipairs(self.mapMarkers) do

		-- Fade out marker
		marker:SetMultColorAlpha(0)

		-- Get marker position
		local markerX, markerY = marker:GetPosition()

		-- Animate each marker in
		locationsUpdater:Add(Updater.Parallel({
			Updater.Do(function() TheFrontEnd:GetSound():PlaySoundWithParams(fmodtable.Event.dungeonSelectScreen_locationAppear, { Count = k, isLastDestinationMarker = (k == numDestinationMarkers) and 1 or 0 }, nil, 1) end),
			Updater.Ease(function(v) marker:SetMultColorAlpha(v) end, 0, 1, 0.11, easing.outQuad),
			Updater.Ease(function(v) marker:SetScale(v) end, 1.05, 1, 0.08, easing.outQuad),
			Updater.Ease(function(v) marker:SetPosition(markerX, v) end, markerY + 10, markerY, 0.08, easing.outQuad)
		}))

		-- And add a delay before the next marker starts animating in too
		locationsUpdater:Add(Updater.Wait(0.02))
	end


	-- Start animating
	self:RunUpdater(Updater.Parallel({

		-- Animate map background
		Updater.Series({
			Updater.Parallel({
				Updater.Ease(function(v)
					self.map_layers:SetMultColorAlpha(v)
				end, 0, 1, 0.5, easing.outQuad),
				Updater.Ease(function(v)
					self.map_layers:SetPosition(bgX, v)
				end, bgY + 10, bgY, 0.3, easing.outQuad),
			}),
		}),

		-- Show location markers
		Updater.Series({
			Updater.Wait(0.4),
			locationsUpdater,
		}),

		-- Select a location
		Updater.Series({
			Updater.Wait(0.6),
			Updater.Do(function()
				self.default_focus = self.current_marker or self:_GetDefaultMapDestination()
				self.default_focus:Click()
			end),
		}),

		-- Animate the travel_button
		Updater.Series({
			Updater.Wait(1),
			Updater.Parallel({
				Updater.Ease(function(v) self.travel_button_backing:SetMultColorAlpha(v) end, 0, 1, 0.1, easing.inOutQuad),
				Updater.Ease(function(v) self.travel_button_backing:SetPosition(travel_button_backingX, v) end, travel_button_backingY - 30, travel_button_backingY, 0.7, easing.outElastic),
			}),
		}),
		Updater.Series({
			Updater.Wait(1.1),
			Updater.Parallel({
				Updater.Ease(function(v) self.travel_button:SetMultColorAlpha(v) end, 0, 1, 0.1, easing.inOutQuad),
				Updater.Ease(function(v) self.travel_button:SetPosition(travel_buttonX, v) end, travel_buttonY - 20, travel_buttonY, 0.8, easing.outElastic),
			}),
			Updater.Do(function()
				self.travel_button_done_animating = true
			end)
		}),

	}))
end

function DungeonSelectionScreen:SetOwningPlayer(player)
	DungeonSelectionScreen._base.SetOwningPlayer(self, player)

	if self.sidebar then
		self.sidebar:SetPlayer(player)
	end

	if self.k_mapMarkers then
		for id, marker in pairs(self.k_mapMarkers) do
			marker:SetOwningPlayer(player)
		end
	end
end

function DungeonSelectionScreen:Layout()

	-- Layout sidebar
	self.sidebar:LayoutBounds("right", "center", self.bg)
		:Offset(-50, 0)

	-- Travel button
	self.travel_button_backing:LayoutBounds("center", "bottom", self.bg)
		:Offset(0, -20)
	self.travel_button:LayoutBounds("center", "bottom", self.travel_button_backing)
		:Offset(0, 50)

	return self
end

return DungeonSelectionScreen
