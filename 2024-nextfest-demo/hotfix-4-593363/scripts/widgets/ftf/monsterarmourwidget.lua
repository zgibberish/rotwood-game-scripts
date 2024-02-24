local Widget = require("widgets/widget")
local Image = require("widgets/image")
local Clickable = require("widgets/clickable")
local ActionAvailableIcon = require("widgets/ftf/actionavailableicon")
local ArmourResearchRadial = require("widgets/ftf/armourresearchradial")
local monster_pictures = require "gen.atlas.monster_pictures"

local itemforge = require "defs.itemforge"
local recipes = require "defs.recipes"

local easing = require "util.easing"

--------------------------------------------------------------

local MonsterArmourWidget = Class(Clickable, function(self, player, monster_id, armour)
	Clickable._ctor(self, "MonsterArmourWidget")
	self.player = player
	self.monster_id = monster_id
	self.armour = armour
	self.recipe = recipes.FindRecipeForItem('armour_unlock_'..monster_id)

	self.w = 540
	self.h = 540

	self.bg_color_normal = UICOLORS.LIGHT_BACKGROUNDS_MID
	self.bg_color_focus = UICOLORS.FOCUS
	self.shadow_color_normal = UICOLORS.LIGHT_BACKGROUNDS_DARK
	self.shadow_color_focus = HexToRGB(0xEDAE3AFF)

	self.desaturated_portrait_mult = HexToRGB(0x14100FFF)
	self.desaturated_portrait_add = HexToRGB(0x967D71ff)
	self.desaturated_portrait_focus_mult = HexToRGB(0x14100FFF)
	self.desaturated_portrait_focus_add = UICOLORS.BLACK

	self.hitbox = self:AddChild(Image("images/global/square.tex"))
		:SetName("Hitbox")
		:SetSize(362, 438)
		:SetMultColor(UICOLORS.DEBUG)
		:SetMultColorAlpha(0)
	self.bg = self:AddChild(Image("images/ui_ftf_research/research_widget_bg.tex"))
		:SetName("Background")
		:SetSize(self.w, self.h)
		:SetHiddenBoundingBox(true)
		:SetMultColor(self.bg_color_normal)
	self.frame = self:AddChild(Image("images/ui_ftf_research/research_widget_frame.tex"))
		:SetName("Background")
		:SetSize(self.w, self.h)
		:SetHiddenBoundingBox(true)
		:SetMultColor(self.shadow_color_normal)
	self.mask = self:AddChild(Image("images/ui_ftf_research/research_widget_mask.tex"))
		:SetName("Mask")
		:SetSize(self.w, self.h)
		:SetHiddenBoundingBox(true)
		:SetMask()
	self.image_shadow = self:AddChild(Image(monster_pictures.tex[string.format("research_widget_%s", self.monster_id)]))
	-- self.image_shadow = self:AddChild(Image("images/monster_pictures/research_widget_yammo.tex"))
		:SetName("Image shadow")
		:SetSize(self.w, self.h)
		:Offset(-20, -20)
		:SetHiddenBoundingBox(true)
		:SetMultColor(UICOLORS.BLACK)
		:SetAddColor(self.shadow_color_normal)
		:SetMasked()
	self.image = self:AddChild(Image(monster_pictures.tex[string.format("research_widget_%s", self.monster_id)]))
	-- self.image = self:AddChild(Image("images/monster_pictures/research_widget_yammo.tex"))
		:SetName("Image")
		:SetSize(self.w, self.h)
		:SetHiddenBoundingBox(true)
		:SetMasked()
	self.overlay = self:AddChild(Image("images/ui_ftf_research/research_widget_overlay.tex"))
		:SetName("Overlay")
		:SetSize(self.w, self.h)
		:SetHiddenBoundingBox(true)
		:SetMultColor(self.shadow_color_normal)

	self.lock_icon = self:AddChild(Image("images/ui_ftf_research/research_widget_lock.tex"))
		:SetName("Lock icon")
		:SetHiddenBoundingBox(true)
		:SetMultColor(UICOLORS.LIGHT_TEXT_DARK)
		:SetScale(0.6)
		:LayoutBounds("center", "center", self.bg)
		:Hide()

	-- Add armour widgets
	self.head_icon = self:AddChild(ArmourResearchRadial(125)) --try at 135?
		:SetName("Head icon")
		:SetIcon("images/ui_ftf_research/item_radial_head.tex")
		:SetShadowColor(self.shadow_color_normal)
		:SetShadowSizeOffset(20)
		:SetHiddenBoundingBox(true)
		:LayoutBounds("right", "bottom", self.bg)
		:Offset(5, 107) --DIAGONAL LAYOUT
		-- :Offset(40, 340) --VERTICAL LAYOUT 
		:SetShown(self.armour.HEAD)
	self.body_icon = self:AddChild(ArmourResearchRadial(125)) --try at 135?
		:SetName("Body icon")
		:SetIcon("images/ui_ftf_research/item_radial_body.tex")
		:SetShadowColor(self.shadow_color_normal)
		:SetShadowSizeOffset(20)
		:SetHiddenBoundingBox(true)
		:LayoutBounds("right", "bottom", self.bg)
		:Offset(-95, 45) --DIAGONAL LAYOUT
		-- :Offset(40, 215) --VERTICAL LAYOUT
		:SetShown(self.armour.BODY)
	self.waist_icon = self:AddChild(ArmourResearchRadial(125)) --try at 135?
		:SetName("Waist icon")
		:SetIcon("images/ui_ftf_research/item_radial_waist.tex") -- TODO: need item_radial_waist
		:SetShadowColor(self.shadow_color_normal)
		:SetShadowSizeOffset(20)
		:SetHiddenBoundingBox(true)
		:LayoutBounds("right", "bottom", self.bg)
		:Offset(-195, -17) --DIAGONAL LAYOUT
		-- :Offset(40, 90) --VERTICAL LAYOUT
		:SetShown(self.armour.WAIST)
	self.armour_icons = {
		HEAD = self.head_icon,
		BODY = self.body_icon,
		WAIST = self.waist_icon,
	}

	-- Add action-available icons
	self.action_available_head = self:AddChild(ActionAvailableIcon())
		:SetName("Action available - head")
		:LayoutBounds("right", "top", self.head_icon)
		:Offset(-30, -2)
		:Hide()
	self.action_available_body = self:AddChild(ActionAvailableIcon())
		:SetName("Action available - body")
		:LayoutBounds("right", "top", self.body_icon)
		:Offset(-30, -2)
		:Hide()
	self.action_available_waist = self:AddChild(ActionAvailableIcon())
		:SetName("Action available - waist")
		:LayoutBounds("right", "top", self.waist_icon)
		:Offset(-30, -2)
		:Hide()
	self.action_available_monster = self:AddChild(ActionAvailableIcon())
		:SetName("Action available - monster")
		:SetScale(1.5)
		:LayoutBounds("right", "top", self.bg)
		:Offset(-115, -95)
		:Hide()
	self.action_available_icons = {
		HEAD = self.action_available_head,
		BODY = self.action_available_body,
		WAIST = self.action_available_waist,
	}

	-- Add equipped icons
	self.item_equipped_head = self:AddChild(Image("images/ui_ftf_research/icon_equipped.tex"))
		:SetName("Item equipped - head")
		:SetSize(40, 40)
		:LayoutBounds("right", "bottom", self.head_icon)
		:Offset(-23, 4)
		:Hide()
	self.item_equipped_body = self:AddChild(Image("images/ui_ftf_research/icon_equipped.tex"))
		:SetName("Item equipped - body")
		:SetSize(40, 40)
		:LayoutBounds("right", "bottom", self.body_icon)
		:Offset(-23, 4)
		:Hide()
	self.item_equipped_waist = self:AddChild(Image("images/ui_ftf_research/icon_equipped.tex"))
		:SetName("Item equipped - waist")
		:SetSize(40, 40)
		:LayoutBounds("right", "bottom", self.waist_icon)
		:Offset(-23, 4)
		:Hide()
	self.item_equipped_icons = {
		HEAD = self.item_equipped_head,
		BODY = self.item_equipped_body,
		WAIST = self.item_equipped_waist,
	}

	-- Setup interactions
	self:SetOnGainFocus(function() self:OnFocusChange(true) end)
	self:SetOnLoseFocus(function() self:OnFocusChange(false) end)
	self:SetOnGainHover(function() self:OnFocusChange(nil) end)
	self:SetOnLoseHover(function() self:OnFocusChange(nil) end)
	self:SetOnSelect(function() self:OnFocusChange(nil) end)
	self:SetOnUnSelect(function() self:OnFocusChange(nil) end)

	self.inst:ListenForEvent("inventory_stackable_changed", function(_, def)
		self:Refresh()
	end, self.player)

	self.inst:ListenForEvent("inventory_changed", function(_, def)
		self:Refresh()
	end, self.player)

	self.inst:ListenForEvent("recipe_unlocked", function(player, recipe_data, c, d)
		self:Refresh()
	end, self.player)

	self.inst:ListenForEvent("item_unlocked", function(player, data, c, d)
		self:Refresh()
	end, self.player)

	self.inst:ListenForEvent("item_locked", function(player, data, c, d)
		self:Refresh()
	end, self.player)

	self.inst:ListenForEvent("loadout_changed", function()
		self:Refresh()
	end, self.player)

	self:Refresh()
end)

function MonsterArmourWidget:Refresh()
	-- Checs
	local monster_unlocked = self.player.components.unlocktracker:IsEnemyUnlocked(self.monster_id)
	local unlocked_recipes = self.player.components.unlocktracker:IsMonsterArmourSetUnlocked(self.monster_id)

	-- Update accordingly
	if monster_unlocked then
		self.locked = false
		self.lock_icon:Hide()
		self.image_shadow:Show()
		self.image:Show()
		self.head_icon:SetShown(self.armour.HEAD)
			:SetLocked(monster_unlocked and not unlocked_recipes)
			:SetIcon("images/ui_ftf_research/item_radial_head.tex")
		self.body_icon:SetShown(self.armour.BODY)
			:SetLocked(monster_unlocked and not unlocked_recipes)
			:SetIcon("images/ui_ftf_research/item_radial_body.tex")
		self.waist_icon:SetShown(self.armour.WAIST)
			:SetLocked(monster_unlocked and not unlocked_recipes)
			:SetIcon("images/ui_ftf_research/item_radial_waist.tex")
	else
		self.locked = true
		self.lock_icon:Show()
		self.image_shadow:Hide()
		self.image:Hide()
		self.head_icon:Hide()
		self.body_icon:Hide()
		self.waist_icon:Hide()
	end

	-- Hide icons before checking their status
	self.action_available_head:Hide()
	self.action_available_body:Hide()
	self.action_available_waist:Hide()
	self.item_equipped_head:Hide()
	self.item_equipped_body:Hide()
	self.item_equipped_waist:Hide()

	-- Make monster look normal
	self.desaturated_portrait = false
	self.image:SetSaturation(1)
		:SetMultColor(UICOLORS.WHITE)
		:SetAddColor(UICOLORS.BLACK)

	for slot, itemdef in pairs(self.armour) do

		-- Get this item out of the player's inventory
		local recipe = recipes.FindRecipeForItemDef(itemdef)
		local item = self.player.components.inventoryhoard:GetInventoryItem(itemdef)
		local owned = item ~= nil

		-- Check what item the player has equipped in this slot
		local selectedLoadoutIndex = self.player.components.inventoryhoard.data.selectedLoadoutIndex
		local currently_equipped = self.player.components.inventoryhoard:GetLoadoutItem(selectedLoadoutIndex, slot)

		if owned then
			recipe = recipes.FindUpgradeRecipeForItem(item)
		else
			item = itemforge.CreateEquipment( itemdef.slot, itemdef )
		end

		local can_craft = recipe and recipe:CanPlayerCraft(self.player) and item:GetUsageLevel() + 1 <= item:GetMaxUsageLevel()
		self.action_available_icons[slot]:SetShown(not self.locked and can_craft)

		self.armour_icons[slot]:SetMax(item:GetMaxUsageLevel())
			:SetProgress((owned and item:GetUsageLevel() or 0)/item:GetMaxUsageLevel(), item:GetUsageLevel() == item:GetMaxUsageLevel() and UICOLORS.FOCUS_LIGHT)
			:SetBackgroundColor(item:GetUsageLevel() == item:GetMaxUsageLevel() and UICOLORS.FOCUS_BOLD)
			:SetImageColor(item:GetUsageLevel() == item:GetMaxUsageLevel() and UICOLORS.BLACK)

		if not owned and can_craft then
			-- Show as locked still
			self.armour_icons[slot]:SetLocked(true)
		end

		-- The player owns this. Is it equipped?
		if owned then
			if currently_equipped and currently_equipped == item then
				-- The player has this item equipped already
				self.item_equipped_icons[slot]:Show()
			else
				-- The player has something else equipped, or nothing
				self.item_equipped_icons[slot]:Hide()
			end
		end

	end

	-- Check if the recipe is unlockable
	if monster_unlocked and not unlocked_recipes then
		self.desaturated_portrait = true

		self.image:Show()
		self.image_shadow:Show()
		self.lock_icon:Hide()

		-- Make monster look desaturated
		self.image:SetSaturation(0)
			:SetMultColor(self.desaturated_portrait_mult)
			:SetAddColor(self.desaturated_portrait_add)

		-- Show the bouncing icon if the player can unlock this right now
		self.action_available_monster:SetShown(monster_unlocked and not unlocked_recipes and self.recipe:CanPlayerCraft(self.player))
	end
	self.lock_icon:LayoutBounds("center", "center", self.bg)

	if self.onChangeFn then self.onChangeFn() end
end

function MonsterArmourWidget:IsLocked()
	return self.locked
end

function MonsterArmourWidget:OnFocusChange(has_focus)
	local has_hover = self.hover
	local show_highlight = has_hover or self.selected
	local show_hover = show_highlight or has_focus

	self.image:MoveTo(0, show_hover and 15 or 0, show_highlight and 0.2 or 0.3, easing.outQuad)
	self.image_shadow:MoveTo(-20, show_hover and -13 or -20, show_highlight and 0.2 or 0.3, easing.outQuad)
	self.bg:TintTo(nil, show_highlight and self.bg_color_focus or self.bg_color_normal, show_highlight and 0.1 or 0.3, easing.outQuad)
	self.frame:TintTo(nil, show_highlight and self.shadow_color_focus or self.shadow_color_normal, show_highlight and 0.1 or 0.3, easing.outQuad)
	self.image_shadow:ColorAddTo(nil, show_highlight and self.shadow_color_focus or self.shadow_color_normal, show_highlight and 0.1 or 0.3, easing.outQuad)
	self.overlay:TintTo(nil, show_highlight and self.shadow_color_focus or self.shadow_color_normal, show_highlight and 0.1 or 0.3, easing.outQuad)
	self.lock_icon:TintTo(nil, show_highlight and UICOLORS.BLACK or UICOLORS.LIGHT_TEXT_DARK, show_highlight and 0.1 or 0.3, easing.outQuad)
	self.head_icon:TintShadowTo(show_highlight and self.shadow_color_focus or self.shadow_color_normal, show_highlight and 0.1 or 0.3, easing.outQuad)
	if self.head_icon:IsLocked() then
		self.head_icon:TintBackgroundTo(show_highlight and UICOLORS.BLACK or nil, show_highlight and 0.1 or 0.3, easing.outQuad)
			:TintIconTo(show_highlight and self.shadow_color_focus or self.shadow_color_normal, show_highlight and 0.1 or 0.3, easing.outQuad)
	else
		self.head_icon:TintBackgroundTo(nil, show_highlight and 0.1 or 0.3, easing.outQuad)
			:TintIconTo(nil, show_highlight and 0.1 or 0.3, easing.outQuad)
	end
	self.body_icon:TintShadowTo(show_highlight and self.shadow_color_focus or self.shadow_color_normal, show_highlight and 0.1 or 0.3, easing.outQuad)
	if self.body_icon:IsLocked() then
		self.body_icon:TintBackgroundTo(show_highlight and UICOLORS.BLACK or nil, show_highlight and 0.1 or 0.3, easing.outQuad)
			:TintIconTo(show_highlight and self.shadow_color_focus or self.shadow_color_normal, show_highlight and 0.1 or 0.3, easing.outQuad)
	else
		self.body_icon:TintBackgroundTo(nil, show_highlight and 0.1 or 0.3, easing.outQuad)
			:TintIconTo(nil, show_highlight and 0.1 or 0.3, easing.outQuad)
	end
	self.waist_icon:TintShadowTo(show_highlight and self.shadow_color_focus or self.shadow_color_normal, show_highlight and 0.1 or 0.3, easing.outQuad)
	if self.waist_icon:IsLocked() then
		self.waist_icon:TintBackgroundTo(show_highlight and UICOLORS.BLACK or nil, show_highlight and 0.1 or 0.3, easing.outQuad)
			:TintIconTo(show_highlight and self.shadow_color_focus or self.shadow_color_normal, show_highlight and 0.1 or 0.3, easing.outQuad)
	else
		self.waist_icon:TintBackgroundTo(nil, show_highlight and 0.1 or 0.3, easing.outQuad)
			:TintIconTo(nil, show_highlight and 0.1 or 0.3, easing.outQuad)
	end
	if self.desaturated_portrait then
		self.image:ColorAddTo(nil, show_highlight and self.desaturated_portrait_focus_add or self.desaturated_portrait_add, show_highlight and 0.1 or 0.3, easing.outQuad)
			:TintTo(nil, show_highlight and self.desaturated_portrait_focus_mult or self.desaturated_portrait_mult, show_highlight and 0.1 or 0.3, easing.outQuad)
	end

	if self.onFocusedFn and has_focus then self.onFocusedFn() end

	return self
end

function MonsterArmourWidget:SetOnClick(fn)
	self.onClickFn = fn
	return self
end

-- Gets called when the progress/unlock status changes
function MonsterArmourWidget:SetOnChange(fn)
	self.onChangeFn = fn
	return self
end

function MonsterArmourWidget:SetOnFocused(fn)
	self.onFocusedFn = fn
	return self
end

return MonsterArmourWidget
