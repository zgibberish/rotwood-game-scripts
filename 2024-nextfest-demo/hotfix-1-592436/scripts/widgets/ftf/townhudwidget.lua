local Consumable = require "defs.consumable"
local CurrencyPanel = require "widgets.ftf.currencypanel"
local Image = require("widgets/image")
local PlayerPuppet = require("widgets/playerpuppet")
local Text = require("widgets/text")
local Widget = require("widgets/widget")
local WeaponTips = require("widgets/ftf/weapontips")
local templates = require "widgets.ftf.templates"
local PlayerTitleWidget = require("widgets/ftf/playertitlewidget")
local lume = require "util.lume"
local playerutil = require "util.playerutil"

------------------------------------------------------------------------------------------
--- Displays the player's portrait, username and konjur
----
local TownPlayerInfoWidget = Class(Widget, function(self)
	Widget._ctor(self, "TownPlayerInfoWidget")

	self.width = 640 -- Default width. Will be updated when changing the username
	self.leftPadding = 380 -- Space between the left edge and the text
	self.rightPadding = 80 -- Space between the right edge and the text
	self.height = 200

	self.bg = self:AddChild(Image("images/ui_ftf_town/town_username_bg.tex"))
		:SetSize(self.width, self.height)
	self.hitbox = self:AddChild(Image("images/global/square.tex"))
		:SetMultColor(HexToRGB(0xff00ff30))
		:SetSize(self.width, self.height)
		:LayoutBounds("left", nil, self.bg)
		:Offset(self.leftPadding, 0)
		:SetMultColorAlpha(0)

	self.portrait = self:AddChild(Widget("Portrait"))
		:SetHiddenBoundingBox(true)
	self.portraitMask = self.portrait:AddChild(Image("images/ui_ftf_town/town_username_mask.tex"))
		:SetSize(self.width, self.height * 2)
		:SetMask()
	self.puppet = self.portrait:AddChild(PlayerPuppet())
		:SetScale(0.9)
		:SetFacing(FACING_RIGHT)
		:SetMasked()

	-- TODO(multiplayer): Move out of player widget? Each player won't have
	-- their own tips, so doesn't make sense to put this here.
	self.weapontips = self:AddChild(WeaponTips())
		:SetOnLayoutFn(function() self:LayoutWeaponTips() end)

	-- Shown over the portrait, so the masking jaggies aren't visible
	self.overlay = self:AddChild(Image("images/ui_ftf_town/town_username_overlay.tex"))
		:SetSize(self.width, self.height)

	self.textContainer = self:AddChild(Widget("Text Container"))
	self.username = self.textContainer:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_SUBTITLE))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT)

	self.player_title = self.textContainer:AddChild(PlayerTitleWidget(nil, FONTSIZE.SCREEN_TEXT))
		:SetColor(UICOLORS.LIGHT_TEXT)

	self.currency = self.textContainer:AddChild(CurrencyPanel())
		:SetFontSize(48)
		:SetBgColor(1,1,1,0)
		:SetRemoveVPadding()
end)

function TownPlayerInfoWidget:SetOwningPlayer(owner)
	TownPlayerInfoWidget._base.SetOwningPlayer(self, owner)
	if self.owner then
		self.inst:RemoveEventCallback("sheathe_weapon", self._onsheatheweapon, self.owner)
		self.inst:RemoveEventCallback("charactercreator_load", self._refresh_frame, self.owner)
		self.inst:RemoveEventCallback("player_post_load", self._refresh_frame, self.owner)
		self.owner = nil
	end

	self.owner = owner

	self._onsheatheweapon = function(source, sheathed) self:OnWeaponChanged(sheathed) end
	self.inst:ListenForEvent("sheathe_weapon", self._onsheatheweapon, self.owner)

	self._refresh_frame = function() self:Refresh(self.owner) end
	self.inst:ListenForEvent("charactercreator_load", self._refresh_frame, self.owner)
	self.inst:ListenForEvent("player_post_load", self._refresh_frame, self.owner)
end

function TownPlayerInfoWidget:Refresh(player)

	self:SetOwningPlayer(player)
	-- Update player portrait
	self.puppet:CloneCharacterWithEquipment(player)

	-- Update Username
	self.username:SetText(player:GetCustomUserName())
		:LayoutBounds("left", nil, self.bg)
		:Offset(self.leftPadding, 50)
	
	self.player_title:SetOwner(self.owner)
		:LayoutBounds("left", "below", self.username)

	-- Update konjur count
	self.currency:SetPlayer(player)
	self.currency:LayoutBounds("left", "below", self.player_title)

	-- Get text width and calculate background size
	local textW, textH = self.textContainer:GetSize()
	self.width = self.leftPadding + textW + self.rightPadding

	-- Resize and layout!
	self.bg:SetSize(self.width, self.height)
	self.portraitMask:SetSize(self.width, self.height * 2)
		:LayoutBounds("left", "bottom", self.bg)
	self.puppet
		:LayoutBounds("left", "bottom", self.bg)
		:Offset(227, -170)
	self.overlay:SetSize(self.width, self.height)
	self.textContainer:LayoutBounds("left", "center", self.bg)
		:Offset(self.leftPadding, 2)
	self.hitbox:SetSize(textW, self.height)
		:LayoutBounds("left", "center", self.bg)
		:Offset(self.leftPadding, 0)

	local weapon_type = self.owner.components.inventory:GetEquippedWeaponType()
	self.weapontips:SetWeaponType(weapon_type)
	self:LayoutWeaponTips()

	return self
end

function TownPlayerInfoWidget:LayoutWeaponTips()
	self.weapontips:LayoutBounds("left", "below", self.bg)
		:Offset(50, -10)
	return self
end

function TownPlayerInfoWidget:SetIsPrimary(is_primary)
	self.weapontips:SetShown(is_primary)
	return self
end

function TownPlayerInfoWidget:OnWeaponChanged(sheathed)
	if sheathed then
		-- hide tips UI
		self.weapontips:AnimateOut()
	else
		-- show tips UI
		self.weapontips:AnimateIn()
	end
end

------------------------------------------------------------------------------------------
--- Shows a week progress bar
----
local WeekCalendarProgressBar = Class(Widget, function(self, height)
	Widget._ctor(self, "WeekCalendarProgressBar")

	self.dayWidth = height or 40
	self.connectorWidth = self.dayWidth * 0.4
	self.spacing = -self.dayWidth * 0.3
	self.height = 220

	self.dayIcons = {}
	self.dayConnectors = {}

	-- Assemble days
	for idx, day in ipairs(STRINGS.TOWN.HUD.DAYS_OF_WEEK) do

		-- And a connector behind the icon, except the first
		if idx > 1 then
			local connector = self:AddChild(Image("images/ui_ftf_town/town_weekday_connector_empty.tex"))
				:SetSize(self.connectorWidth, self.dayWidth)
				:LayoutBounds("after", nil)
				:Offset(self.spacing, 0)
			self.dayConnectors[idx] = connector
		end

		-- Add icon for this day
		local icon = self:AddChild(Image("images/ui_ftf_town/town_weekday_empty.tex"))
			:SetSize(self.dayWidth, self.dayWidth)
		if idx > 1 then
			icon:LayoutBounds("after", nil)
				:Offset(self.spacing, 0)
		end
		self.dayIcons[idx] = icon

	end

	-- Send connectors to the back, so they show behind the dots
	for key, connector in pairs(self.dayConnectors) do
		connector:SendToBack()
	end

end)

function WeekCalendarProgressBar:SetDay(dayIndex)

	-- Change the color of the icons and connectors
	for idx, day in ipairs(STRINGS.TOWN.HUD.DAYS_OF_WEEK) do

		local icon = self.dayIcons[idx]
		local connector = self.dayConnectors[idx] -- The connector behind this day

		if idx == dayIndex then

			-- This is the current day
			icon:SetTexture("images/ui_ftf_town/town_weekday_today.tex")
			if connector then connector:SetTexture("images/ui_ftf_town/town_weekday_connector_full.tex") end

		elseif idx < dayIndex then

			-- This day has passed
			icon:SetTexture("images/ui_ftf_town/town_weekday_full.tex")
			if connector then connector:SetTexture("images/ui_ftf_town/town_weekday_connector_full.tex") end

		else

			-- This day has yet to come
			icon:SetTexture("images/ui_ftf_town/town_weekday_empty.tex")
			if connector then connector:SetTexture("images/ui_ftf_town/town_weekday_connector_empty.tex") end

		end

	end

	return self
end

------------------------------------------------------------------------------------------
--- Shows the current weekday, and a progress bar
----
local WeekCalendarWidget = Class(Widget, function(self)
	Widget._ctor(self, "WeekCalendarWidget")

	self.width = 630
	self.height = 220

	self.bg = self:AddChild(Image("images/ui_ftf_town/town_weekday_bg.tex"))
		:SetSize(self.width, self.height)

	self.weekday = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.CONFIRM_DIALOG_TITLE * 1.1))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARK)

	local progressSize = 34
	self.progress = self:AddChild(WeekCalendarProgressBar(progressSize))

end)

function WeekCalendarWidget:SetDay(dayIndex)
	self.weekday:SetText(STRINGS.TOWN.HUD.DAYS_OF_WEEK[dayIndex])
		:SetPosition(0, 9)
	self.progress:SetDay(dayIndex)
		:LayoutBounds("center", "below", self.weekday)
		:Offset(0, 0)

	return self
end

------------------------------------------------------------------------------------------
--- Widget displaying info about the town (top of screen).
----
local TownHudWidget = Class(Widget, function(self, debug_root)
	Widget._ctor(self, "TownHudWidget")

	self.players = {}

	self.debugButtonsRoot = debug_root

	self.bg = self:AddChild(Image("images/global/square.tex"))
		:SetMultColor(1, 0, 1, 0)
		:SetSize(RES_X, 260)

	self.players_root = self:AddChild(Widget("players_root"))
	self.player_infos = {}

	-- Add weekday widget
	-- TODO: re-enable WEEKDAY
	self.weekday = self:AddChild(WeekCalendarWidget())
		:SetScale(0.66)
		:Hide()

	-- Maybe remove these in the future :)
	self:_AddDebugButtons()

	self._oninventory_changed = function(source, itemdef) self:Refresh() end

	-- Don't initialize the widgets' data until we have a player
	-- self:Refresh()
end)

function TownHudWidget:AttachPlayerToHud(player)
	if not player:IsLocal() then
		return
	end
	assert(player:IsLocal())
	table.insert(self.players, player)
	playerutil.SortByHunterId(self.players)

	self.inst:ListenForEvent("inventory_stackable_changed", self._oninventory_changed, player)
	self.inst:ListenForEvent("loadout_changed", self._oninventory_changed, player)
	self:Refresh()
end
function TownHudWidget:DetachPlayerFromHud(player)
	if not player:IsLocal() then
		return
	end
	self.inst:RemoveEventCallback("inventory_stackable_changed", self._oninventory_changed, player)
	self.inst:RemoveEventCallback("loadout_changed", self._oninventory_changed, player)

	lume.remove(self.players, player)

	self.player_infos[player]:Remove()
	self.player_infos[player] = nil
end

function TownHudWidget:Refresh()
	assert(#self.players > 0, "Don't call Refresh until we have a player.")

	for i,player in ipairs(self.players) do
		if not self.player_infos[player] then
			local info = self.players_root:AddChild(TownPlayerInfoWidget())
				:LayoutBounds("left", "top", self.bg)
				:Offset(40, -40)

			self.player_infos[player] = info
		end

		self.player_infos[player]:SendToFront() -- match order of self.players (hunter id)
			:SetIsPrimary(i == 1)
			:Refresh(player)
	end

	self.players_root:LayoutChildrenInGrid(999, 10)


	-- Update weekday
	self.weekday:LayoutBounds("after", "top", self.players_root)
		:Offset(40, 0)
	self.weekday:SetDay(TheDungeon.progression.components.towncalendar:GetDay())

	return self
end

function TownHudWidget:_GetDebugPlayer()
	return self.players[1]
end

function TownHudWidget:_AddDebugButtons()
	assert(self.debugButtonsRoot, "Expected to be passed by ctor")
	self.debugButtonsRoot:AddChild(templates.Button("<p img='images/ui_ftf_options/checkbox_checked.tex' color=0> Save Game"))
		:SetDebug()
		:SetOnClickFn(function() TheSaveSystem:SaveAll() end)
	self.debugButtonsRoot:AddChild(templates.Button("<p img='images/ui_ftf_icons/players.tex' color=0 scale=0.9> Character slots"))
		:SetDebug()
		:SetOnClickFn(function()
			local CharacterSelectionScreen = require("screens.character.characterselectionscreen")
			TheFrontEnd:PushScreen(CharacterSelectionScreen(self:_GetDebugPlayer()))
		end)
	self.debugButtonsRoot:AddChild(templates.Button("<p img='images/icons_ftf/inventory_sets.tex' color=0 scale=1.1>Appearance"))
		:SetDebug()
		:SetOnClickFn(function()
			local CharacterScreen = require("screens/character/characterscreen")
			TheFrontEnd:PushScreen(CharacterScreen(self:_GetDebugPlayer()))
		end)
	self.debugButtonsRoot:AddChild(templates.Button("<p img='images/hud_images/hud_konjur_heart_drops_currency.tex' color=0 scale=1.1>Heart"))
		:SetDebug()
		:SetOnClickFn(function()
			d_open_screen("screens.town.heartscreen")
		end)
	self.debugButtonsRoot:AddChild(templates.Button("<p img='images/icons_ftf/inventory_head.tex' color=0> Armor Research"))
		:SetDebug()
		:SetOnClickFn(function()
			local ForgeArmourScreen = require("screens/town/ForgeArmourScreen")
			TheFrontEnd:PushScreen(ForgeArmourScreen(self:_GetDebugPlayer()))
		end)
	self.debugButtonsRoot:AddChild(templates.Button("<p img='images/icons_ftf/inventory_weapon.tex' color=0> Weapon Crafting"))
		:SetDebug()
		:SetOnClickFn(function()
			local ForgeWeaponScreen = require("screens/town/forgeweaponscreen")
			TheFrontEnd:PushScreen(ForgeWeaponScreen(self:_GetDebugPlayer()))
		end)
	self.debugButtonsRoot:AddChild(templates.Button("<p img='images/icons_ftf/inventory_currency_drops.tex' scale=1.1 color=0> Gem Screen"))
		:SetDebug()
		:SetOnClickFn(function()
			local GemScreen = require("screens.town.gemscreen")
			TheFrontEnd:PushScreen(GemScreen(GetDebugPlayer()))
		end)
	self.debugButtonsRoot:AddChild(templates.Button("<p img='images/ui_ftf_pausescreen/ic_food.tex' scale=1.2 color=0> Food Screen"))
		:SetDebug()
		:SetOnClickFn(function()
			local FoodScreen = require("screens.town.foodscreen")
			TheFrontEnd:PushScreen(FoodScreen(GetDebugPlayer()))
		end)

	self.debugButtonsRoot:AddChild(templates.Button("Add Glitz"))
		:SetDebug()
		:SetOnClickFn(function() self:OnDebugAddKonjurButton() end)
	self.debugButtonsRoot:AddChild(templates.Button("Unlock all craftables"))
		:SetDebug()
		:SetOnClickFn(function() self:OnDebugUnlockAllCraftables() end)
	self.debugButtonsRoot:AddChild(templates.Button("Reset craftables"))
		:SetDebug()
		:SetOnClickFn(function() self:OnDebugResetCraftables() end)

	self.debugButtonsRoot:AddChild(templates.Button("Unlock All Locations"))
		:SetDebug()
		:SetOnClickFn(function() d_unlock_all_locations() end)

	self.debugButtonsRoot:AddChild(templates.Button("Player buildtest"))
		:SetDebug()
		:SetOnClickFn(function()
			d_buildtest()
			self.debugButtonsRoot.randomize:Show()
		end)
	-- keep last and right after buildtest since it's not always visible.
	self.debugButtonsRoot.randomize = self.debugButtonsRoot:AddChild(templates.Button("Randomize Player"))
		:SetOnClickFn(function()
			self:_GetDebugPlayer().components.charactercreator:Randomize()
		end)

	self.debugButtonsRoot:LayoutChildrenInGrid(1, 6)
		:LayoutBounds("left", "below", self.debugButtonsRoot.toggle_btn)
		:Offset(0, -10)
		:Hide()

	-- Most useful when using buildtest
	self.debugButtonsRoot.randomize:Hide()

	self.debug_inventory_btns = self.debugButtonsRoot:AddChild(Widget())

	self.debug_inventory_btns:AddChild(templates.Button("Give Equipment"))
		:SetToolTip("All Equipment included in the next release.")
		:SetDebug()
		:SetOnClickFn(function() self:OnDebugAddRelevantEquipmentButton() end)
	self.debug_inventory_btns:AddChild(templates.Button("Give Materials"))
		:SetToolTip("All Materials included in the next release.")
		:SetDebug()
		:SetOnClickFn(function() self:OnDebugAddReleventMaterialsButton() end)

	self.debug_inventory_btns:AddChild(templates.Button("Give WIP Equipment"))
		:SetToolTip("Equipment that's incomplete or not ready for release.")
		:SetDebug()
		:SetOnClickFn(function() self:OnDebugAddEquipmentButton() end)
	self.debug_inventory_btns:AddChild(templates.Button("Give WIP Materials"))
		:SetToolTip("Materials that are incomplete or not ready for release.")
		:SetDebug()
		:SetOnClickFn(function() self:OnDebugAddMaterialsButton() end)
	self.debug_inventory_btns:AddChild(templates.Button("(WIP) Give Gems"))
		:SetDebug()
		:SetOnClickFn(function() self:OnDebugAddGemsButton() end)
	self.debug_inventory_btns:AddChild(templates.Button("Give Armor Recipes"))
		:SetToolTip("Allow crafing all armor items with Berna.")
		:SetDebug()
		:SetOnClickFn(function()
			for _,p in ipairs(AllPlayers) do
				p.components.unlocktracker:DEBUG_UnlockAllRecipes()
			end
			self:OnDebugAddKeyItems()
		end)
	-- self.debug_inventory_btns:AddChild(templates.Button("Unlock All Recipes"))
	-- 	:SetOnClickFn(function() self:OnDebugUnlockRecipesButton() end)
	-- self.debug_inventory_btns:AddChild(templates.Button("Reset Recipes"))
	-- 	:SetOnClickFn(function() self:OnDebugResetUnlocksButton() end)
	self.debug_inventory_btns:AddChild(templates.Button("Reset Inventory"))
		:SetDebug()
		:SetOnClickFn(function() self:OnDebugResetInventoryButton() end)

	-- self.debug_inventory_btns:AddChild(templates.Button("Next Loadout"))
	-- 	:SetOnClickFn(function() self:OnNextLoadoutButton() end)

	self.debug_inventory_btns:LayoutChildrenInGrid(1, 6)
		:LayoutBounds("before", "below", self.debugButtonsRoot.toggle_btn)
		:Offset(-20, -10)
end

function TownHudWidget:OnDebugAddKonjurButton()
	for _,p in ipairs(AllPlayers) do
		local inventoryhoard = p.components.inventoryhoard
		inventoryhoard:AddStackable(Consumable.Items.MATERIALS.glitz, 1000)
	end
	self:Refresh()
end

function TownHudWidget:OnDebugAddRelevantEquipmentButton()
	for _,p in ipairs(AllPlayers) do
		local inventoryhoard = p.components.inventoryhoard
		inventoryhoard:Debug_GiveRelevantEquipment()
	end
end

function TownHudWidget:OnDebugAddEquipmentButton()
	for _,p in ipairs(AllPlayers) do
		local inventoryhoard = p.components.inventoryhoard
		inventoryhoard:Debug_GiveAllEquipment()
	end
end

function TownHudWidget:OnNextLoadoutButton()
	for _,p in ipairs(AllPlayers) do
		local inventoryhoard = p.components.inventoryhoard
		inventoryhoard:NextLoadout()
	end
end

function TownHudWidget:OnDebugAddReleventMaterialsButton()
	for _,p in ipairs(AllPlayers) do
		local inventoryhoard = p.components.inventoryhoard
		inventoryhoard:Debug_GiveRelevantMaterials()
	end
end

function TownHudWidget:OnDebugAddMaterialsButton()
	for _,p in ipairs(AllPlayers) do
		local inventoryhoard = p.components.inventoryhoard
		inventoryhoard:Debug_GiveMaterials()
	end
end

function TownHudWidget:OnDebugAddGemsButton()
	for _,p in ipairs(AllPlayers) do
		local inventoryhoard = p.components.inventoryhoard
		inventoryhoard:Debug_GiveGems()
	end
end

function TownHudWidget:OnDebugAddKeyItems()
	for _,p in ipairs(AllPlayers) do
		local inventoryhoard = p.components.inventoryhoard
		inventoryhoard:Debug_GiveKeyItems()
	end
end

function TownHudWidget:OnDebugUnlockRecipesButton()
	for _,p in ipairs(AllPlayers) do
		local crafter = p.components.playercrafter
		crafter:UnlockAll()
	end
end

function TownHudWidget:OnDebugResetUnlocksButton()
	for _,p in ipairs(AllPlayers) do
		local crafter = p.components.playercrafter
		crafter:ResetData()
	end
end

function TownHudWidget:OnDebugResetInventoryButton()
	for _,p in ipairs(AllPlayers) do
		local inventoryhoard = p.components.inventoryhoard
		inventoryhoard:ResetData()
	end
end

function TownHudWidget:OnDebugUnlockAllCraftables()
	for _,p in ipairs(AllPlayers) do
		p.components.playercrafter:UnlockAll()
	end
end

function TownHudWidget:OnDebugResetCraftables()
	for _,p in ipairs(AllPlayers) do
		p.components.playercrafter:ResetData()
	end
end

return TownHudWidget
