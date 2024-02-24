local Image = require "widgets/image"
local ImageButton = require "widgets/imagebutton"
local Text = require "widgets/text"
local Widget = require "widgets/widget"
local UIAnim = require "widgets.uianim"

local FrenzySelectionWidget = require"widgets.ftf.dungeonselection.frenzyselectionwidget"
local LocationBossesWidget = require"widgets.ftf.dungeonselection.locationbosseswidget"
local InventoryScreen = require "screens.town.inventoryscreen"
local DungeonLevelWidget = require"widgets/ftf/dungeonlevelwidget"

local MetaProgress = require "defs.metaprogression"

local playerutil = require"util/playerutil"
local easing = require "util.easing"

local monster_pictures = require "gen.atlas.monster_pictures"

------------------------------------------------------------------------------------------
--- A map info panel
----
local MapSidebar = Class(Widget, function(self)
	Widget._ctor(self, "MapSidebar")

	self.width = 1270
	self.height = 1630

	self.bosses_width = self.width + 100

	-- Background
	self.bg = self:AddChild(Image("images/map_ftf/panel_bg.tex"))
		:SetName("Background")

	-- The boss header backing, behind the monsters and the background
	self.boss_header_hitbox = self:AddChild(Image("images/global/square.tex"))
		:SetName("Boss header hitbox")
		:SetSize(self.width, 320)
		:SetMultColor(UICOLORS.DEBUG)
		:SetMultColorAlpha(0)
	self.boss_header_anim_back = self:AddChild(UIAnim())
		:SetName("Bosses header anim")
		:SetScale(1.17)
		:SetHiddenBoundingBox(true)
		:SendToBack()
	self.boss_header_anim_back:GetAnimState():SetBank("world_map_banner")
	self.boss_header_anim_back:GetAnimState():SetBuild("world_map_banner")
	self.boss_header_anim_back:GetAnimState():PlayAnimation("treemon_forest_back", false)
	-- The monsters
	self.bosses_widget = self:AddChild(LocationBossesWidget(self.bosses_width, nil))
		:SetName("Bosses widget")
		:SetHiddenBoundingBox(true)
	-- The foreground, in front of the monsters and background
	self.boss_header_anim_front = self:AddChild(UIAnim())
		:SetName("Bosses header anim")
		:SetScale(1.17)
		:SetHiddenBoundingBox(true)
	self.boss_header_anim_front:GetAnimState():SetBank("world_map_banner")
	self.boss_header_anim_front:GetAnimState():SetBuild("world_map_banner")
	self.boss_header_anim_front:GetAnimState():PlayAnimation("treemon_forest_front", false)

	-- Location title and exploration progress bar
	self.dungeon_level = self:AddChild(DungeonLevelWidget())
		:SetName("Dungeon level widget")
		:ShowLargePresentation(HexToRGB(0xA3897B77), UICOLORS.LIGHT_TEXT, FONTSIZE.SCREEN_TITLE, self.width)
		:SetHiddenBoundingBox(true)

	-- Ascension selector widget
	self.ascension_widget = self:AddChild(FrenzySelectionWidget())
		:SetName("Ascension widget")
		:SetOnSelectLevelFn(function()
			-- self:RefreshMaterialDrops()
			self:DoLayout()
		end)
		-- :SetOnChangeWeaponClickFn(function()
		-- 	self:TriggerWeaponSwitch()
		-- end)

	-- Mobs list
	self.mobs_title = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT*1.3, STRINGS.ASCENSIONS.MOBS_TITLE, UICOLORS.LIGHT_TEXT))
		:SetName("Mobs title")
	self.mobs_container = self:AddChild(Widget())
		:SetName("Mobs container")

	-- Close button
	self.close_button = self:AddChild(ImageButton("images/ui_ftf/HeaderClose.tex"))
		:SetNavFocusable(false) -- rely on CONTROL_MAP
		:SetSize(BUTTON_SQUARE_SIZE, BUTTON_SQUARE_SIZE)
		:LayoutBounds("right", "top", self.bg)
		:Offset(20, 0)
		:SetOnClick(function()
			if self.on_close_fn then self.on_close_fn() end
		end)
end)

function MapSidebar:SetPlayer(player)
	self:SetOwningPlayer(player)

	self.dungeon_level:SetPlayer(player)
	self.ascension_widget:SetPlayer(player)

	return self
end

function MapSidebar:IsUnlocked(locationData)
	for i,key in ipairs(locationData.required_unlocks) do
		if not self:GetOwningPlayer().components.unlocktracker:IsLocationUnlocked(key) then -- Region unlock check
			return false
		end
	end
	return true
end

function MapSidebar:SetLocationData(locationData)
	-- Save data
	self.locationData = locationData

	-- Update header
	local location_id = self.locationData.id
	self.boss_header_anim_back:GetAnimState():PlayAnimation(location_id .. "_back", false)
	self.boss_header_anim_front:GetAnimState():PlayAnimation(location_id .. "_front", false)

	-- Refresh level widget
	self.dungeon_level:SetBiomeTitle(self.locationData.pretty.name)
	self.dungeon_level:ShouldPlaySound(false)
	local mrm = self:GetOwningPlayer().components.metaprogressmanager
	local def = MetaProgress.FindProgressByName(self.locationData.region_id)
	local progress = mrm:GetProgress(def)
	if not progress and def ~= nil then
		-- The player hasn't made progress on this location
		progress = mrm:StartTrackingProgress(mrm:CreateProgress(def))
	end
	self.dungeon_level:SetProgress(progress:GetLevel(), progress:GetEXP(), progress:GetEXPForLevel(progress:GetLevel()))

	-- Update ascension widget
	self.ascension_widget:SetLocation(self.locationData)

	-- Update center contents
	self:RefreshContents()
	self:StartUpdating()

	return self
end

function MapSidebar:OnUpdate()
	local is_unlocked = playerutil.GetLocationUnlockInfo(self.locationData)

	if is_unlocked ~= self.is_unlocked then
		self:RefreshContents()
	else
		self.ascension_widget:OnUpdate()
	end
end

function MapSidebar:TriggerWeaponSwitch()
	local inventory_screen = InventoryScreen(self:GetOwningPlayer())
	inventory_screen:SetCloseCallback(function()
		self:RefreshContents()
	end)
	TheFrontEnd:PushScreen(inventory_screen)
end

function MapSidebar:RefreshContents()

	-- Refresh monsters
	self.bosses_widget:SetMonsters(self.locationData.monsters)

	if self:GetOwningPlayer() then
		-- when the screen refreshes without calling set player again
		-- happens when closing the 'change weapon' overlay screen
		self.ascension_widget:SetPlayer(self:GetOwningPlayer())
	end

	-- Update local mobs list
	self:UpdateMobs()

	-- Update footer
	local is_unlocked, invalid_players = playerutil.GetLocationUnlockInfo(self.locationData)

	self.is_unlocked = is_unlocked
	self.invalid_players = invalid_players

	self:DoLayout()
end

function MapSidebar:UpdateMobs()
	-- Remove old ones
	self.mobs_container:RemoveAllChildren()

	-- Add new ones
	local monster_count = 1
	for k, monster_id in ipairs(self.locationData.monsters.mobs) do

		-- Only show named creatures
		local monster_name = STRINGS.NAMES[monster_id]
		if monster_name then

			local even = monster_count%2 == 0
			local unlocked = self:GetOwningPlayer().components.unlocktracker:IsEnemyUnlocked(monster_id)

			local widget = self.mobs_container:AddChild(Widget())
				:SetName("Mob "..monster_count)

			local texture = even and "images/map_ftf/rots_bg_even.tex" or "images/map_ftf/rots_bg_odd.tex"
			widget.bg = widget:AddChild(Image(texture))
				:SetName("Bg")
				:SetMultColor(HexToRGB(0x302423FF))
			widget.icon = widget:AddChild(Image(monster_pictures.tex[string.format("research_widget_%s", monster_id)]))
				:SetName("Icon")
				:SetHiddenBoundingBox(true)
				:SetScale(0.45)

			if unlocked then

				-- Show a tooltip with the creature name, if unlocked
				widget:SetToolTip(STRINGS.NAMES[monster_id])
			else

				-- Make this monster a silhouette if not seen before
				widget.icon
					:SetMultColor(UICOLORS.BLACK)
					:SetAddColor(HexToRGB(0x181312FF))
				widget:SetToolTip(STRINGS.UI.MAPSCREEN.UNKNOWN_CREATURE)
			end

			monster_count = monster_count + 1
		end

	end
end

function MapSidebar:DoLayout()

	self.boss_header_hitbox:LayoutBounds("center", "above", self.bg)
		:Offset(0, -10)
	self.boss_header_anim_back:LayoutBounds("center", "above", self.bg)
		:Offset(-20, -10)
	self.bosses_widget:LayoutBounds("center", "bottom", self.boss_header_anim_back)
		:Offset(80, -40)
	self.boss_header_anim_front:SetPos(self.boss_header_anim_back:GetPos())

	self.dungeon_level:LayoutBounds("center", "above", self.bg)
		:Offset(0, -450)

	self.ascension_widget:SetPos(0, 7)

	self.mobs_title:LayoutBounds("center", "center", self.bg)
		:Offset(0, -335)
	self.mobs_container:LayoutChildrenInGrid(6, {h=5, v=10})
		:LayoutBounds("center", "center", self.bg)
		:Offset(0, -565)

	return self
end

function MapSidebar:SetOnCloseFn(fn)
	self.on_close_fn = fn
	return self
end

function MapSidebar:IncreaseAscensionLevel()
	self.ascension_widget:DeltaLevel(1)
	return self
end

function MapSidebar:DecreaseAscensionLevel()
	self.ascension_widget:DeltaLevel(-1)
	return self
end

function MapSidebar:SetOnLocationUnlockedFn(fn)
	self.onLocationUnlockedFn = fn
	return self
end

function MapSidebar:PrepareAnimation()
	self:SetMultColorAlpha(0)
	return self
end

function MapSidebar:AnimateIn(on_done)

	local target_x, target_y = self:GetPos()
	self:Offset(0, -70)
	self:MoveTo(target_x, target_y, 0.6, easing.outElasticUI)
	self:AlphaTo(1, 0.2, easing.outQuad, on_done)

	return self
end

return MapSidebar
