local Screen = require("widgets/screen")
local ActionButton = require("widgets/actionbutton")
local Text = require("widgets/text")
local Image = require("widgets/image")
local Widget = require("widgets/widget")
local PopupDialog = require("screens/dialogs/popupdialog")

local easing = require "util.easing"
local lume = require"util.lume"

------------------------------------------------------------------------------------------------
-- Shows an item image with a silhouette shadow
-- The shadow doesn't contribute to the widget size
--   ┌─────────┐
-- ┌─┤         │
-- │ │         │
-- │ │         │
-- │ │         │ ◄ image
-- │ └────────┬┘
-- └──────────┘  ◄ shadow

local ShadowedImage = Class(Widget, function(self, size, shadow_color)
	Widget._ctor(self, "ShadowedImage")

	self.size = size or 512
	self.offset = 20
	self.shadow_color = shadow_color or UICOLORS.DARK_TEXT

	self.shadow = self:AddChild(Image("images/global/square.tex"))
		:SetName("Shadow")
		:SetSize(self.size + self.offset, self.size + self.offset)
		:SetHiddenBoundingBox(true)
		:SetMultColor(UICOLORS.BLACK)
		:SetAddColor(self.shadow_color)

	self.image = self:AddChild(Image("images/global/square.tex"))
		:SetName("Image")
		:SetSize(self.size, self.size)

	self.shadow:LayoutBounds("center", "center", self.image)
		:Offset(-self.offset*.5, -self.offset)

end)

function ShadowedImage:SetTexture(image)
	self.image:SetTexture(image)
	self.shadow:SetTexture(image)
	return self
end

function ShadowedImage:GetShadowWidget()
	return self.shadow
end

function ShadowedImage:AnimateFloating(speed)
	speed = speed or 0.3
	speed = speed * 4
	local amplitude = 5
	local widgetX, widgetY = self.image:GetPosition()
	self.floating_updater = self.image:RunUpdater(
		Updater.Loop({
			Updater.Ease(function(v) self.image:SetPosition(widgetX, v) end, widgetY, widgetY + amplitude, speed * 0.8, easing.outQuad),
			Updater.Wait(speed * 0.5),
			Updater.Ease(function(v) self.image:SetPosition(widgetX, v) end, widgetY + amplitude, widgetY - amplitude * 1.2, speed * 1.8, easing.inOutQuad),
			Updater.Wait(speed * 0.2),
			Updater.Ease(function(v) self.image:SetPosition(widgetX, v) end, widgetY - amplitude * 1.2, widgetY + amplitude * 1.3, speed * 1.6, easing.inOutQuad),
			Updater.Wait(speed * 0.4),
			Updater.Ease(function(v) self.image:SetPosition(widgetX, v) end, widgetY + amplitude * 1.3, widgetY - amplitude, speed * 1.7, easing.inOutQuad),
			Updater.Wait(speed * 0.3),
			Updater.Ease(function(v) self.image:SetPosition(widgetX, v) end, widgetY - amplitude, widgetY, speed * 0.8, easing.inQuad),
		})
	)
	return self
end


------------------------------------------------------------------------------------------------
-- Displays a popup telling the player they just unlocked a thing!
-- ┌───────────────────────────────────────────────────────────────────────────────┐
-- │ dialog_bg                                                                     │
-- │                                                                               │
-- │                                                                               │
-- │            ▼ image_container                                                  │
-- │           ┌────────────────────┐                                              │
-- │           │                    │  ▼ text_container                            │
-- │           │                    │ ┌─────────────────────────────────┐          │
-- │           │                    │ │ title                           │          │
-- │           │                    │ │ description                     │          │
-- │           │                    │ │                                 │          │
-- │           │                    │ ├─────────────────────────────────┤          │
-- │           │                    │ │ buttons_container               │          │
-- │           │                    │ └─────────────────────────────────┘          │
-- │           │                    │                                              │
-- │           └────────────────────┘                                              │
-- │                                                                               │
-- │                                                                               │
-- │                                                                               │
-- └───────────────────────────────────────────────────────────────────────────────┘
-- Depending on what function you use, more than one image can be shown in the container (like for armor-sets)

local ItemUnlockPopup = Class(PopupDialog, function(self, controller, blocksScreen)
	PopupDialog._ctor(self, "ItemUnlockPopup", controller, blocksScreen)

	self.max_icon_size = 512 * 1.5
	self.gradient_size = self.max_icon_size * 1.3
	self.text_width = 1200

	-- Contains the whole dialog
	self.dialog_container = self:AddChild(Widget())

	self.dialog_bg = self.dialog_container:AddChild(Image("images/ui_ftf_unlock/popup_dialog_bg.tex"))
		:SetName("Dialog background")

	-- Left side
	self.image_gradient = self.dialog_container:AddChild(Image("images/ui_ftf_unlock/popup_dialog_gradient.tex"))
		:SetName("Image gradient")
		:SetSize(self.gradient_size, self.gradient_size)
		:RotateIndefinitely(0.03)
	self.image_container = self.dialog_container:AddChild(Widget())
		:SetName("Image container")

	-- Right side
	self.text_container = self.dialog_container:AddChild(Widget())
		:SetName("Text container")
	self.title = self.text_container:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.CONFIRM_DIALOG_TITLE))
		:SetName("Title")
		:SetGlyphColor(UICOLORS.BLACK)
		:SetHAlign(ANCHOR_LEFT)
		:SetAutoSize(self.text_width)

	self.description = self.text_container:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.CONFIRM_DIALOG_TEXT))
		:SetName("Description")
		:SetGlyphColor(UICOLORS.DARK_TEXT)
		:SetHAlign(ANCHOR_LEFT)
		:SetAutoSize(self.text_width)

	self.buttons_container = self.text_container:AddChild(Widget())
		:SetName("Buttons container")
	self.ok_button = self.buttons_container:AddChild(ActionButton())
		:SetName("Ok button")
		:SetSize(BUTTON_W * 0.8, BUTTON_H)
		:SetPrimary()
		:SetText(STRINGS.UI.BUTTONS.OK)
		:SetOnClick(function()
			self:AnimateOut(function()
				if self.on_done_fn then self.on_done_fn(true) end
				if self.controller then self.controller:NextDialog() end
			end)
		end)

	self:_LayoutDialog()

	self.default_focus = self.ok_button

	return self.dialog_container
end)

function ItemUnlockPopup:SetItemUnlock(item, title, description)

	-- Remove existing images
	self.image_container:RemoveAllChildren()

	-- Add new one
	local item_def = item:GetDef()
	self.image_container:AddChild(ShadowedImage(self.max_icon_size))
		:SetTexture(item_def.unlock_icon or item_def.icon)
		:AnimateFloating()

	-- Update text too
	self.title:SetText(title)
		:SetShown(title)
	self.description:SetText(description)
		:SetShown(description)

	self:_LayoutDialog()

	return self
end

function ItemUnlockPopup:SetArmourSetUnlock(monster_id)

	-- Remove existing images
	self.image_container:RemoveAllChildren()

	-- Get this monster's armor
	local itemutil = require"util.itemutil"
	local armour = itemutil.GetArmourForMonster(monster_id)
	local armour_count = lume.count(armour)

	-- How many items in here?
	if armour_count == 2 then

		local item_1_name, item_2_name
		for slot, item_def in pairs(armour) do

			-- Add an image per slot
			self.image_container:AddChild(ShadowedImage(self.max_icon_size*0.5))
				:SetTexture(item_def.icon)
				:AnimateFloating(item_1_name and 0.45 or 0.3)

			-- Save names
			if not item_1_name then
				item_1_name = item_def.pretty.name
			else
				item_2_name = item_def.pretty.name
			end
		end

		-- Offset the first image
		self.image_container.children[1]:Offset(-self.max_icon_size*0.3, self.max_icon_size*0.2)

		-- Move both shadows behind both icons when they overlap
		for k, item_image in ipairs(self.image_container.children) do
			if item_image.GetShadowWidget then
				-- This is a ShadowedImage, not a reparented shadow
				local item_shadow = item_image:GetShadowWidget()
				item_shadow:Reparent(self.image_container)
					:SendToBack()
			end
		end

		-- Set text
		self.title:SetText(STRINGS.UI.RESEARCHSCREEN.UNLOCK_POPUP_TITLE)
			:Show()
		self.description:SetText(string.format(STRINGS.UI.RESEARCHSCREEN.UNLOCK_POPUP_DESCRIPTION_DOUBLE, item_1_name, item_2_name))
			:Show()

	elseif armour_count == 1 then

		-- Add the image for the item
		local item_name
		for slot, item_def in pairs(armour) do
			self.image_container:AddChild(ShadowedImage(self.max_icon_size))
				:SetTexture(item_def.icon)
				:AnimateFloating()

			item_name = item_def.pretty.name
		end

		-- Set text
		self.title:SetText(STRINGS.UI.RESEARCHSCREEN.UNLOCK_POPUP_TITLE)
			:Show()
		self.description:SetText(string.format(STRINGS.UI.RESEARCHSCREEN.UNLOCK_POPUP_DESCRIPTION_SINGLE, item_name))
			:Show()
	end

	self:_LayoutDialog()

	return self
end

function ItemUnlockPopup:SetIconUnlock(icon, title, description)

	-- Remove existing images
	self.image_container:RemoveAllChildren()

	-- Add new one
	self.image_container:AddChild(ShadowedImage(self.max_icon_size))
		:SetTexture(icon or "images/global/square.tex")
		:AnimateFloating()
		:SetShown(icon)

	-- Update text too
	self.title:SetText(title)
		:SetShown(title)
	self.description:SetText(description)
		:SetShown(description)

	self:_LayoutDialog()

	return self
end

function ItemUnlockPopup:SetOnDoneFn(on_done_fn)
	self.on_done_fn = on_done_fn
	return self
end

function ItemUnlockPopup:SetButtonText(text)
	self.ok_button:SetText(text)
		:SetShown(text)

	self:_LayoutDialog()
	return self
end

function ItemUnlockPopup:_LayoutDialog()

	-- Layout left side
	self.image_gradient:LayoutBounds("center", "center", self.dialog_bg)
		:Offset(-600, 0)
	self.image_container:LayoutBounds("center", "center", self.image_gradient)
		:Offset(0, 40)

	-- Layout right side
	self.text_container:LayoutChildrenInColumn(30, "left")
	self.buttons_container:Offset(0, -30)
	self.text_container:LayoutBounds("left", "center", self.dialog_bg)
		:Offset(1300, 0)

	return self
end

function ItemUnlockPopup:OnBecomeActive()
	ItemUnlockPopup._base.OnBecomeActive(self)

	-- Animate popup in if we're using a controller, meaning this is a conversation dialog sequence
	-- If not, it means this popup was created not using a controller
	if self.controller then
		self:AnimateIn()
	end
end

function ItemUnlockPopup:AnimateIn()

	if self.bg then
		self.bg:SetMultColorAlpha(0)
			:AlphaTo(0.5, 0.4, easing.outQuad)
	end

	local x, y = self.dialog_container:GetPosition()
	self.dialog_container:SetMultColorAlpha(0)
		:AlphaTo(1, 0.25, easing.outQuad)
		:ScaleTo(0.9, 1, 0.65, easing.outElasticUI)
		:SetPosition(x, y - 90)
		:MoveTo(x, y, 0.65, easing.outElasticUI)

	self.default_focus:SetFocus()
	return self
end

function ItemUnlockPopup:AnimateOut(on_done)

	if self.bg then
		self.bg:AlphaTo(0, 0.15, easing.outQuad)
	end

	local x, y = self.dialog_container:GetPosition()
	self.dialog_container:AlphaTo(0, 0.15, easing.outQuad)
		:ScaleTo(1, 0.9, 0.15, easing.outQuad)
		:MoveTo(x, y + 90, 0.15, easing.outQuad,
			function()
				if on_done then on_done() end
			end)

	return self
end

return ItemUnlockPopup
