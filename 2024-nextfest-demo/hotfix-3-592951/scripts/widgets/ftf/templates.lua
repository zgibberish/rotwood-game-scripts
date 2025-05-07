local ActionButton = require "widgets.actionbutton"
local Image = require "widgets.image"
local ImageButton = require "widgets.imagebutton"
local Panel = require "widgets.panel"
local Text = require "widgets.text"
local Widget = require "widgets.widget"
local easing = require "util.easing"
local krandom = require "util.krandom"


local templates = {}

function templates.Button(text)
	return ActionButton()
		:SetText(text)
end

local shrink = 50 * HACK_FOR_4K

-- Navigation: Return to a previous screen.
function templates.BackButton()
	return ActionButton()
		:SetSecondary()
		:SetSize(BUTTON_W - shrink, BUTTON_H)
		:SetText(STRINGS.UI.BUTTONS.CLOSE)
end

-- Undo changes or interaction.
function templates.CancelButton()
	return ActionButton()
		:SetSecondary()
		:SetSize(BUTTON_W - shrink, BUTTON_H)
		:SetText(STRINGS.UI.BUTTONS.CANCEL)
end

function templates.AcceptButton(label)
	return ActionButton()
		:SetPrimary()
		:SetSize(BUTTON_W - shrink, BUTTON_H)
		:SetText(label)
end

-- A tint to make your dialog stand out.
function templates.BackgroundTint()
	return Image("images/square.tex")
		:SetAnchors("fill", "fill")
		:SetMultColor(0,0,0,0.75)
end

function templates.BackgroundImage(texture)
	return Image(texture or "images/square.tex")
		:SetAnchors("fill", "fill")
end

function templates.BackgroundVignette()
	return templates.BackgroundImage("images/fullscreeneffects/halo.tex")
end

function templates._CreateBackgroundPlate(image)
	local root = Widget("bg_plate_root")
		:SetAnchors("center", "center")

	root.plate = root:AddChild(image)
		:SetAnchors("center", "center")

	local w = root.plate:GetSize()
	root.plate:SetScale(RES_X / w)

	root.image = image

	return root
end

function templates.TitleBackground()
	local bg = Widget("background")
	bg.bgplate = bg:AddChild(templates._CreateBackgroundPlate(Image("images/bg_title/title.tex")))
	bg:SetCanFadeAlpha(false)
	return bg
end

function templates.SmallOverlayBackground()
	return Panel("images/ui_ftf_dialog/dialog_requirement_bg.tex")
		:SetNineSliceCoords(32, 32, 68, 68)
		:SetNineSliceBorderScale(0.5)
		:SetMultColor(UICOLORS.BACKGROUND_OVERLAY)
end

-- When you want clicking the background to close the dialog.
function templates.ClickableBackgroundTint(onclick_fn, texture)
	local black = ImageButton(texture or "images/square.tex")
		:SetAnchors("fill", "fill")
		:SetOnClick(onclick_fn)
		:SetHelpTextMessage("")
		:SetNavFocusable(false)
		:SetScaleOnFocus(false)
	if not texture then
		black.image:SetMultColor(0,0,0,0.5) -- clickable background!
	end
	return black
end

function templates.LargeButton(text)
	return templates.Button(text)
		:SetNormalScale(1.5)
		:SetFocusScale(1.5 * 1.2)
end

function templates.SolidBackground(color_hex)
	color_hex = color_hex or 0x111111ff
	return Image("images/square.tex")
		:SetAnchors("fill", "fill")
		:SetMultColor(HexToRGB(color_hex))
end


--------------------
-- Panels


-- A bg panel that fits a paper style.
function templates.PaperLabelBox()
	local w = Panel("images/ui_dungeonmap/title_3slice.tex")
		:SetName("PaperLabelBox")
		:SetNineSliceCoords(120, 0, 949, 130)
	return w
end


-- /Panels
--------------------


function templates.PowerSelectionBrackets(player, width, height)
	assert(height, "Must pass width/height now so we can setup scaling properly.")
	local focus_bracket = Panel("images/ui_ftf_roombonus/bonus_selection.tex")
		:SetNineSliceCoords(100, 60, 110, 70)
		:SetNineSliceBorderScale(0.5)
		:SetMultColor(player.uicolor)
		:SetSize(width, height)
		:SetMultColorAlpha(0)
		:ScaleTo(0.9, 1, 0.1, easing.outQuad)
		:AlphaTo(1, 0.1, easing.outQuad)

	-- Animate it in and out
	local speed = 0.6
	local amplitude = krandom.Float(6, 20)
	local w, h = focus_bracket:GetSize()
	focus_bracket:RunUpdater(
		Updater.Loop({
				Updater.Ease(function(v) focus_bracket:SetSize(w + v, h + v) end, 0, amplitude, speed * 0.5, easing.inOutQuad),
				Updater.Ease(function(v) focus_bracket:SetSize(w + v, h + v) end, amplitude, 0, speed, easing.inOutQuad),
				Updater.Wait(speed * 2),
			})
		)

	return focus_bracket
end

return templates
