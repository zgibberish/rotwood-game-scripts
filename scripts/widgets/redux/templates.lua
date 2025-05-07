local Grid = require "widgets/grid"
local Image = require "widgets/image"
local ImageButton = require "widgets/imagebutton"
local Menu = require "widgets/menu"
local NumericSpinner = require "widgets/numericspinner"
local Spinner = require "widgets/spinner"
local Text = require "widgets/text"
local TextEdit = require "widgets/textedit"
local TrueScrollList = require "widgets/truescrolllist"
local UIAnim = require "widgets/uianim"
local Widget = require "widgets/widget"
local Panel = require "widgets/panel"
local fmodtable = require "defs.sound.fmodtable"

require("constants")
--require("skinsutils")

local TEMPLATES = {}

----------------
----------------
--   SCREEN   --
----------------
----------------

function TEMPLATES.ScreenRoot(name)
    local root = Widget(name or "root")
		:SetAnchors("center", "center")
    root:SetScaleMode(SCALEMODE_PROPORTIONAL)
    return root
end

----------------
----------------
-- BACKGROUND --
----------------
----------------

-- All of these backgrounds may require letterboxing to ensure non 16:9 ratios don't reveal
-- what's behind. Mostly necessary in-game to hide the game world, but the
-- frontend sometimes has elements that extend off the edge of the screen.

function TEMPLATES.BackgroundTint(a, rgb)
	local bg = Image("images/square.tex")
	bg:SetVRegPoint(ANCHOR_MIDDLE)
	bg:SetHRegPoint(ANCHOR_MIDDLE)
	bg:SetAnchors("center","center")
	bg:SetScaleMode(SCALEMODE_FILLSCREEN)

	a = a ~= nil and a or 0.75
	rgb = rgb ~= nil and rgb or {0, 0, 0 }

	bg:SetMultColor(rgb[1], rgb[2], rgb[3], a)

	return bg
end

----------------
----------------
--   MENUS    --
----------------
----------------

local rcol = RES_X/2 -170
local lcol = -RES_X/2 +200

local titleX = lcol+65
local titleY = 310
local menuX = lcol-5
local menuY = -130

-- A title for the current screen.
--
-- Drawn in the top left corner. Can have a subtitle that is drawn below it.
function TEMPLATES.ScreenTitle(title_text, subtitle_text)
    local title = Text(FONTFACE.HEADER, 28, title_text or "")
    title:SetGlyphColor(UICOLORS.GOLD_SELECTED)
    title:SetRegionSize(400, 50)
    title:SetHAlign(ANCHOR_LEFT)

    local root = title
    if subtitle_text then
        root = Widget("title root")
        root:AddChild(title)

        -- subtitle accessed with self.title.small
        root.small = root:AddChild(Text(FONTFACE.DEFAULT, 28, subtitle_text))
        root.small:SetGlyphColor(UICOLORS.GREY)
        root.small:SetPosition(0, -35)
        root.small:SetRegionSize(400, 50)
        root.small:SetHAlign(ANCHOR_LEFT)
    end

    root:SetPosition(titleX, titleY)

    -- Don't call Text methods on the return value! Use self.title.big or
    -- self.title.small to ensure code works with subtitles.
    root.big = title

    return root
end

-- The standard menu.
--
-- Drawn on the left size and aligned to the bottom of the screen.
function TEMPLATES.StandardMenu(menuitems, offset, horizontal, style, wrap)
    local menu = Menu(menuitems, offset, horizontal, style, wrap)
    menu:SetPosition(menuX, menuY)
    -- Menus should start from the top as far as users are concerned.
    menu.reverse = true
    return menu
end


-- A screen tooltip.
--
-- For explaining the purpose of the highlighted menu.
function TEMPLATES.ScreenTooltip()
    local tooltip = Text(FONTFACE.DEFAULT, 25)
    tooltip:SetVAlign(ANCHOR_TOP)
    tooltip:SetHAlign(ANCHOR_LEFT)
    tooltip:SetRegionSize(200,100)
    tooltip:EnableWordWrap(true)
    local tooltipX = menuX -25
    local tooltipY = -(RES_Y*.5)+157
    tooltip:SetPosition(tooltipX, tooltipY, 0)
    return tooltip
end


-- A standard menu button.
--
-- Assumes the button's parent is a Menu.
-- Put a bunch of these into a StandardMenu.
function TEMPLATES.MenuButton(text, onclick, tooltip_text, tooltip_widget)
    local btn = ImageButton(
        "images/square.tex", -- never used, hidden
        nil,
        nil,
        nil,
        "images/square.tex",
        {0.6},
        {-10,1})
    btn.scale_on_focus = false
    btn:SetImageNormalColour(1,1,1,0) -- we don't want anything shown for normal.
    btn:SetImageFocusColour(1,1,1,0) -- use focus overlay instead.
    btn:SetImageSelectedColour(1,1,1,1)
    btn:SetFont(FONTFACE.HEADER)
    btn:SetDisabledFont(FONTFACE.HEADER)
    btn:SetTextColour(UICOLORS.GOLD_CLICKABLE)
    btn:SetTextFocusColour(UICOLORS.WHITE)
    btn:SetTextSelectedColour(UICOLORS.GOLD_FOCUS)
    btn:SetText(text, true)
    btn.text:SetRegionSize(250,40)
    btn.text:SetHAlign(ANCHOR_LEFT)
    btn.text_shadow:SetRegionSize(250,40)
    btn.text_shadow:SetHAlign(ANCHOR_LEFT)
    btn:SetTextSize(25)

    btn.bg = btn:AddChild(Image("images/square.tex"))
    local w,h = btn.text:GetRegionSize()
    btn.bg:ScaleToSize(250, h+15)
    btn.bg:SetPosition(-10,1)

	btn:SetOnGainFocus(function()
        if tooltip_widget ~= nil then
            tooltip_widget:SetText(tooltip_text)
        end
    end)

    btn:SetOnLoseFocus(function()
        if btn.parent and not btn.parent.focus and tooltip_widget ~= nil then
            tooltip_widget:SetText("")
        end
    end)
    btn:SetOnClick(onclick)

    return btn
end

-- To be added as a child of the root. onclick should be whatever cancel/back
-- fn is appropriate for your screen.
function TEMPLATES.BackButton(onclick, txt, shadow_offset, scale)
    local btn = ImageButton("images/frontend/turnarrow_icon.tex", "images/frontend/turnarrow_icon_over.tex", nil, nil, nil, {1,1}, {0,0})
    btn.scale = scale or 1
    btn.image:SetScale(.7)

    btn:SetTextColour(UICOLORS.GOLD)
    btn:SetTextFocusColour(PORTAL_TEXT_COLOR)
    btn:SetFont(FONTFACE.DEFAULT)
    btn:SetDisabledFont(FONTFACE.DEFAULT)
    btn:SetTextDisabledColour(UICOLORS.GOLD)

    -- Make a clickable area and scale to actual text size.
    btn.bg = btn.text:AddChild(Image("images/ui_dst/blank.tex"))

	-- Override the SetText function so that the text, drop shadow, and mouse region (bg) can be positioned correctly
	local _oldsettext = btn.SetText
	btn.SetText = function(btn_inst, msg, dropShadow, dropShadowOffset)
		_oldsettext(btn_inst, msg, dropShadow, dropShadowOffset)

		local w,h = btn.text:GetRegionSize()
		btn.bg:ScaleToSize(w+50, h+15)
		
		local function ConfigureText(text_widget, x, offset)
			-- Make text region large and fixed position so it aligns against image.
			-- Offset to align region to image.
			text_widget:SetPosition(x + offset.x, offset.y)
			text_widget:SetHAlign(ANCHOR_LEFT)
		end
		-- Align text so left of region is against image.
		local text_x = w / 2 + 30
		ConfigureText(btn.text, text_x, {x=0,y=0})
		ConfigureText(btn.text_shadow, text_x, shadow_offset or {x=2,y=-1})
	end

    btn:SetText(txt or STRINGS.UI.HELP.BACK, true)

    btn:SetOnGainFocus(function()
        btn:SetScale(btn.scale + .05)
    end)
    btn:SetOnLoseFocus(function()
        btn:SetScale(btn.scale)
    end)

    btn:SetOnClick(onclick)

    btn:SetScale(btn.scale)

	btn:SetAnchors("left","bottom")
		:SetPosition(100,100)
	return btn
end


-- Common button.
-- icon_data allows a square button that's sized relative to label. Doesn't
-- behave well with changing button labels.
function TEMPLATES.StandardButton(onclick, txt, size, icon_data)
    local btn = ImageButton()
    btn:SetOnClick(onclick)
    btn:SetText(txt)
    btn:SetFont(FONTFACE.BUTTON)
    btn:SetDisabledFont(FONTFACE.BUTTON)
    if size then
        btn:ForceImageSize(table.unpack(size))
        btn:SetTextSize(math.ceil(size[2]*.45))
    end
    if icon_data then
        local width = btn.text.size
        btn.icon = btn.text:AddChild(Image(table.unpack(icon_data)))
        btn.icon:ScaleToSize(width, width)
        local icon_x = 1
        if btn.text:GetText():len() > 0 then
            local offset = width/2
            local padding = 5
            icon_x = -btn.text:GetRegionSize()/2 - offset - padding
            btn.text:SetPosition(offset,0)
        else
            -- If there's no text, btn.text is probably hidden. Parent to button
            -- instead. Placing icon relative to text is much easier as a child
            -- of text, so only parent to button if there's no text to align
            -- against.
            btn.icon = btn:AddChild(btn.icon)
        end
        btn.icon:SetPosition(icon_x,0)
    end
    return btn
end

-- Standard-style square button with a custom icon on the button.
-- Text label is not intended to be on the button! (It's beside, below, or hovertext.)
-- Text label offset can be specified, as well as whether or not it always shows.
-- For buttons containing both icon and text, see StandardButton's icon_data.
function TEMPLATES.IconButton(iconAtlas, iconTexture, labelText, sideLabel, alwaysShowLabel, onclick, textinfo, defaultTexture)
    local btn = TEMPLATES.StandardButton(onclick, nil, {70,70}, {iconAtlas, iconTexture})

    if not textinfo then
        textinfo = {}
    end

    if sideLabel then
        -- A label to the left of the button.
        btn.label = btn:AddChild(Text(textinfo.font or FONTFACE.DEFAULT, textinfo.size or 25, labelText, textinfo.colour or UICOLORS.GOLD_CLICKABLE))
        btn.label:SetRegionSize(150,70)
        btn.label:EnableWordWrap(true)
        btn.label:SetHAlign(ANCHOR_RIGHT)
        btn.label:SetPosition(-115, 2)

    elseif alwaysShowLabel then
        -- A label below the button.
        btn:SetTextSize(25)
        btn:SetText(labelText, true)
        btn.text:SetPosition(1, -38)
        btn.text_shadow:SetPosition(-1, -40)
        btn:SetFont(textinfo.font or FONTFACE.DEFAULT)
        btn:SetTextColour(textinfo.colour or UICOLORS.GOLD_CLICKABLE)
        btn:SetTextFocusColour(textinfo.focus_colour or UICOLORS.GOLD_FOCUS)

    else
        -- Only show hovertext.
        btn:SetToolTip(labelText, {
                font = textinfo.font or FONTFACE.DEFAULT,
                offset_x = textinfo.offset_x or 2,
                offset_y = textinfo.offset_y or -45,
                colour = textinfo.colour or UICOLORS.WHITE,
                bg = textinfo.bg
            })
    end

    return btn
end

function TEMPLATES.StandardCheckbox(onclick, size, init_checked, helptext, hovertext_info)
	local checkbox = ImageButton()
    checkbox:ForceImageSize(size, size)
	checkbox.scale_on_focus = false
    checkbox.move_on_click = false

	local function SetChecked(checked)
        if checked then
            checkbox:SetTextures("images/global_redux/checkbox_normal_check.tex", "images/global_redux/checkbox_focus_check.tex", "images/global_redux/checkbox_normal.tex", nil, nil, {1,1}, {0,0})
        else
            checkbox:SetTextures("images/global_redux/checkbox_normal.tex", "images/global_redux/checkbox_focus.tex", "images/global_redux/checkbox_normal_check.tex", nil, nil, {1,1}, {0,0})
        end
	end
	SetChecked(init_checked)

	checkbox:SetOnClick(function()
		local checked = onclick()
		SetChecked(checked)
	end)

	if helptext ~= nil then
		checkbox:SetHelpTextMessage(helptext)
	end

        -- Only show hovertext.
	if hovertext_info ~= nil then
        checkbox:SetToolTip(hovertext_info.text, {
                font = hovertext_info.font or FONTFACE.DEFAULT,
                offset_x = hovertext_info.offset_x or 2,
                offset_y = hovertext_info.offset_y or -45,
                colour = hovertext_info.colour or UICOLORS.WHITE,
                bg = hovertext_info.bg
            })
    end

    return checkbox
end

local normal_list_item_bg_tint = { 1,1,1,0.5 }
local function GetListItemPrefix(row_width, row_height)
    local prefix = "listitem_thick" -- 320 / 90 = 3.6
    local ratio = row_width / row_height
    if ratio > 6 then
        -- Longer texture will look better at this aspect ratio.
        prefix = "serverlist_listitem" -- 1220.0 / 50 = 24.4
    end
    return prefix
end

-- A list item backing that shows focus.
--
-- May want to call OnWidgetFocus if using with TrueScrollList or
-- ScrollingGrid:
--   row:SetOnGainFocus(function() self.scroll_list:OnWidgetFocus(row) end)
function TEMPLATES.ListItemBackground(row_width, row_height, onclick_fn)
    local prefix = "images/frontend_redux/".. GetListItemPrefix(row_width, row_height)
    local focus_list_item_bg_tint  = { 1,1,1,0.7 }

    local row = ImageButton(prefix .."_normal.tex", -- normal
        nil, -- focus
        nil,
        nil,
        prefix .."_selected.tex" -- selected
        )
    row:ForceImageSize(row_width,row_height)
    row:SetImageNormalColour(  table.unpack(normal_list_item_bg_tint))
    row:SetImageFocusColour(   table.unpack(focus_list_item_bg_tint))
    row:SetImageSelectedColour(table.unpack(normal_list_item_bg_tint))
    row:SetImageDisabledColour(table.unpack(normal_list_item_bg_tint))
    row.scale_on_focus = false
    row.move_on_click = false

    if onclick_fn then
        row:SetOnClick(onclick_fn)
        -- FocusOverlay caused incorrect scaling on morgue screen, but it
        -- wasn't clickable. Related?
        row:UseFocusOverlay(prefix .."_hover.tex")
    else
        row:SetHelpTextMessage("") -- doesn't respond to clicks
    end
    return row
end

-- For list items that contain a single focusable widget.
--
-- Instead of a button that changes colour (or has a hover border) when the
-- list item is focused, just set a similar-looking background.
function TEMPLATES.ListItemBackground_Static(row_width, row_height)
    local prefix = GetListItemPrefix(row_width, row_height)
    local row = Image("images/frontend_redux.xml"..prefix .."_normal.tex"
        )
    row:SetSize(row_width,row_height)
    row:SetMultColor(table.unpack(normal_list_item_bg_tint))
    return row
end

-- A widget that displays info about a mod. To be used in scroll lists etc.
function TEMPLATES.ModListItem(onclick_btn, onclick_checkbox, onclick_setfavorite)
    local opt = Widget("option")

    local item_width,item_height = 340, 90
    opt.backing = opt:AddChild(TEMPLATES.ListItemBackground(item_width,item_height,onclick_btn))
    opt.backing.move_on_click = true

    opt.Select = function(_)
        opt.name:SetGlyphColour(UICOLORS.GOLD_SELECTED)
        opt.backing:Select()
    end

    opt.Unselect = function(_)
        opt.name:SetGlyphColour(UICOLORS.GOLD_CLICKABLE)
        opt.backing:Unselect()
    end

    opt.checkbox = opt.backing:AddChild(ImageButton())
    opt.checkbox:SetPosition(140, -22, 0)
    opt.checkbox:SetOnClick(onclick_checkbox)
    opt.checkbox:SetHelpTextMessage("") -- button nested in a button doesn't need extra helptext

    opt.setfavorite = opt.backing:AddChild(ImageButton())
    opt.setfavorite:SetPosition(100, -22, 0)
    opt.setfavorite:SetOnClick(onclick_setfavorite)
    opt.setfavorite:SetHelpTextMessage("") -- button nested in a button doesn't need extra helptext
    opt.setfavorite.scale_on_focus = false

    opt.image = opt.backing:AddChild(Image())
    opt.image:SetPosition(-120,0,0)
    opt.image:SetClickable(false)

    opt.out_of_date_image = opt.backing:AddChild(Image("images/frontend/circle_red.tex"))
    opt.out_of_date_image:SetScale(.65)
    opt.out_of_date_image:SetPosition(25, -22)
    opt.out_of_date_image:SetClickable(false)
    opt.out_of_date_image.icon = opt.out_of_date_image:AddChild(Image("images/button_icons/update.tex"))
    opt.out_of_date_image.icon:SetPosition(-1,0)
    opt.out_of_date_image.icon:SetScale(.15)
    opt.out_of_date_image:Hide()

    opt.configurable_image = opt.backing:AddChild(Image("images/button_icons/configure_mod.tex"))
    opt.configurable_image:SetScale(.1)
    opt.configurable_image:SetPosition(60, -20)
    opt.configurable_image:SetClickable(false)
    opt.configurable_image:Hide()

    opt.name = opt.backing:AddChild(Text(FONTFACE.DEFAULT, 26))
    opt.name:SetVAlign(ANCHOR_MIDDLE)

    opt.status = opt.backing:AddChild(Text(FONTFACE.BODYTEXT, 23))
    opt.status:SetVAlign(ANCHOR_MIDDLE)
    opt.status:SetHAlign(ANCHOR_LEFT)

    opt.SetModStatus = function(_, modstatus)
        if modstatus == "WORKING_NORMALLY" then
            opt.status:SetGlyphColour(59/255, 222/255, 99/255, 1)
            opt.status:SetText(STRINGS.UI.MODSSCREEN.STATUS.WORKING_NORMALLY)
        elseif modstatus == "DISABLED_ERROR" then
            opt.status:SetGlyphColour(242/255, 99/255, 99/255, 1)--0.9,0.3,0.3,1)
            opt.status:SetText(STRINGS.UI.MODSSCREEN.STATUS.DISABLED_ERROR)
        elseif modstatus == "DISABLED_MANUAL" then
            opt.status:SetGlyphColour(.6,.6,.6,1)
            opt.status:SetText(STRINGS.UI.MODSSCREEN.STATUS.DISABLED_MANUAL)
        else
            -- We should probably never hit this line.
            opt.status:SetText(modname)
        end
    end

    opt.status:SetPosition(25, -20, 0)
    opt.status:SetRegionSize( 200, 50 )

    opt.SetModReadOnly = function(_, should_be_readonly)
        if should_be_readonly then
            -- We still allow configuration! We just don't want to show
            -- enable/disable options or state.
            opt.image_disabled_tint = UICOLORS.WHITE
            opt.checkbox:Hide()
            opt.status:Hide()
        else
            opt.image_disabled_tint = {1.0,0.5,0.5,1} -- reddish
            opt.checkbox:Show()
            opt.status:Show()
        end
    end

    opt.SetModConfigurable = function(_, should_enable)
        if should_enable then
            opt.configurable_image:Show()
        else
            opt.configurable_image:Hide()
        end
    end

    opt.SetModEnabled = function(_, should_enable)
        if should_enable then
            opt.image:SetMultColor(table.unpack(UICOLORS.WHITE))
            opt.checkbox:SetTextures("images/global_redux/checkbox_normal_check.tex", "images/global_redux/checkbox_focus_check.tex", "images/global_redux/checkbox_normal.tex", nil, nil, {1,1}, {0,0})
        else
            opt.image:SetMultColor(table.unpack(opt.image_disabled_tint))
            opt.checkbox:SetTextures("images/global_redux/checkbox_normal.tex", "images/global_redux/checkbox_focus.tex", "images/global_redux/checkbox_normal_check.tex", nil, nil, {1,1}, {0,0})
        end
    end

    opt.SetModFavorited = function(_, should_favorite)
        if should_favorite then
            opt.setfavorite:SetTextures("images/global_redux/star_checked.tex", nil, "images/global_redux/star_uncheck.tex", nil, nil, {0.75,0.75}, {0, 0})
        else
            opt.setfavorite:SetTextures("images/global_redux/star_uncheck.tex", nil, "images/global_redux/star_checked.tex", nil, nil, {0.75,0.75}, {0, 0})
        end
    end

    opt.SetMod = function(_, modname, modinfo, modstatus, isenabled, isfavorited)
        if modinfo and modinfo.icon_atlas and modinfo.icon then
            opt.image:SetTexture(modinfo.icon_atlas, modinfo.icon)
        else
            opt.image:SetTexture("images/ui_dst/portrait_bg.tex")
        end
        -- SetTexture clobbers our previously set size.
        opt.image:SetSize(70 * HACK_FOR_4K,70)

        local nameStr = (modinfo and modinfo.name) and modinfo.name or modname
        opt.name:SetTruncatedString(nameStr, 235, 51, true)
        -- I think this is manually left-aligning (since SetRegionSize doesn't
        -- work with SetTruncatedString).
        local w, h = opt.name:GetRegionSize()
        opt.name:SetPosition(w * .5 - 75, 17, 0)

        opt:SetModStatus(modstatus)
        opt:SetModEnabled(isenabled)
        opt:SetModFavorited(isfavorited)
    end

    opt:SetModReadOnly(false) -- sets up some initial values
    opt:Unselect()

    opt.focus_forward = opt.backing

    return opt
end

-- A widget that displays a mod that is currently being downloaded.
function TEMPLATES.ModListItem_Downloading()
    local opt = Widget("option")

    local item_width,item_height = 340, 90
    opt.backing = opt:AddChild(TEMPLATES.ListItemBackground(item_width,item_height))

    opt.name = opt:AddChild(Text(FONTFACE.DEFAULT, 30))
    opt.name:SetVAlign(ANCHOR_MIDDLE)
    opt.name:SetHAlign(ANCHOR_MIDDLE)
    opt.name:SetGlyphColour(UICOLORS.GOLD)
    opt.name:SetRegionSize(item_width,item_height)

    opt.SetMod = function(_, mod)
        opt.name:SetText(kstring.subfmt(STRINGS.UI.MODSSCREEN.DOWNLOADINGMOD, {name = mod.fancy_name}))
    end

    opt.Select = function(_)
    end

    opt.Unselect = function(_)
    end

    return opt
end

-- Unlabelled text entry box
--
-- height and following arguments are optional.
function TEMPLATES.StandardSingleLineTextEntry(fieldtext, width_field, height, font, font_size, prompt_text)
    height = height or 40
    local textbox_font_ratio = 0.8
    local wdg = Widget("singleline textentry")
    wdg.textbox_bg = wdg:AddChild( Image("images/global_redux/textbox3_gold_normal.tex") )
    wdg.textbox_bg:ScaleToSize(width_field, height)
    wdg.textbox = wdg:AddChild(TextEdit( font or FONTFACE.DEFAULT, (font_size or 25)*textbox_font_ratio, fieldtext, UICOLORS.BLACK ) )
    wdg.textbox:SetForceEdit(true)
    wdg.textbox:SetRegionSize(width_field-30, height) -- this needs to be slightly narrower than the BG because we don't have margins
    wdg.textbox:SetHAlign(ANCHOR_LEFT)

    if prompt_text then
        wdg.textbox:SetTextPrompt(prompt_text, UICOLORS.GREY)
    end

    wdg:SetOnGainFocus(function()
        wdg.textbox:OnGainFocus()
    end)
    wdg:SetOnLoseFocus(function(self)
        wdg.textbox:OnLoseFocus()
    end)
    wdg.GetHelpText = function(self)
        local controller_id = TheInput:GetControllerID()
        local t = {}
        if not self.textbox.editing and not self.textbox.focus then
            table.insert(t, TheInput:GetLocalizedControl(controller_id, Controls.Digital.ACCEPT, false, false ) .. " " .. STRINGS.UI.HELP.CHANGE_TEXT)   
        end
        return table.concat(t, "  ")
    end
    return wdg
end

-- Text box with a label beside it
--
-- font and following arguments are optional.
function TEMPLATES.LabelTextbox(labeltext, fieldtext, width_label, width_field, height, spacing, font, font_size, horiz_offset)
    local offset = horiz_offset or 0
    local total_width = width_label + width_field + spacing
    local wdg = TEMPLATES.StandardSingleLineTextEntry(fieldtext, width_field, height, font, font_size)
    wdg.label = wdg:AddChild(Text(font or FONTFACE.DEFAULT, font_size or 25))
    wdg.label:SetText(labeltext)
    wdg.label:SetHAlign(ANCHOR_RIGHT)
    wdg.label:SetRegionSize(width_label,height)
    wdg.label:SetPosition((-total_width/2)+(width_label/2)+offset,0)
    wdg.label:SetGlyphColour(UICOLORS.GOLD)
    -- Reposition relative to label
    wdg.textbox_bg:SetPosition((total_width/2)-(width_field/2)+offset, 0)
    wdg.textbox:SetPosition((total_width/2)-(width_field/2)+offset, 0)
    return wdg
end

-- Spinner with a label beside it
function TEMPLATES.LabelSpinner(labeltext, spinnerdata, width_label, width_spinner, height, spacing, font, font_size, horiz_offset, onchanged_fn, colour)
    width_label = width_label or 220
    width_spinner = width_spinner or 150
    height = height or 40
    spacing = spacing or 5
    font = font or FONTFACE.DEFAULT
    font_size = font_size or 25

    local offset = horiz_offset or 0
    local total_width = width_label + width_spinner + spacing
    local wdg = Widget("labelspinner")
    wdg.label = wdg:AddChild( Text(font, font_size, labeltext) )
    wdg.label:SetPosition( (-total_width/2)+(width_label/2) + offset, 0 )
    wdg.label:SetRegionSize( width_label, height )
    wdg.label:SetHAlign( ANCHOR_RIGHT )
    wdg.label:SetGlypColour(colour or UICOLORS.GOLD)
    wdg.spinner = wdg:AddChild(TEMPLATES.StandardSpinner(spinnerdata, width_spinner, height, font, font_size, onchanged_fn, colour))
    wdg.spinner:SetPosition((total_width/2)-(width_spinner/2) + offset, 0)

    wdg.focus_forward = wdg.spinner

    return wdg
end

-- Spinner of numbers with a label beside it
function TEMPLATES.LabelNumericSpinner(labeltext, min, max, width_label, width_spinner, height, spacing, font, font_size, horiz_offset)
    width_label = width_label or 220
    width_spinner = width_spinner or 150
    height = height or 40
    spacing = spacing or -50 -- why negative?
    font = font or FONTFACE.DEFAULT
    font_size = font_size or 25

    local offset = horiz_offset or 0
    local total_width = width_label + width_spinner + spacing
    local wdg = Widget("labelspinner")
    wdg.label = wdg:AddChild( Text(font, font_size, labeltext) )
    wdg.label:SetPosition( (-total_width/2)+(width_label/2) + offset, 0 )
    wdg.label:SetRegionSize( width_label, height )
    wdg.label:SetHAlign( ANCHOR_RIGHT )
    wdg.label:SetGlyphColour(UICOLORS.GOLD)
    wdg.spinner = wdg:AddChild(TEMPLATES.StandardNumericSpinner(min, max, width_spinner, height, font, font_size))
    wdg.spinner:SetPosition((total_width/2)-(width_spinner/2) + offset, 0)
    wdg.spinner:SetTextColour(UICOLORS.GOLD)

    wdg.focus_forward = wdg.spinner

    return wdg
end

-- Text button with a label beside it
function TEMPLATES.LabelButton(onclick, labeltext, buttontext, width_label, width_button, height, spacing, font, font_size, horiz_offset)
    local offset = horiz_offset or 0
    local total_width = width_label + width_button + spacing
    local wdg = Widget("labelbutton")
    wdg.label = wdg:AddChild( Text(font or FONTFACE.DEFAULT, font_size or 25, labeltext) )
    wdg.label:SetPosition( (-total_width/2)+(width_label/2) + offset, 0 )
    wdg.label:SetRegionSize( width_label, height )
    wdg.label:SetHAlign( ANCHOR_RIGHT )
    wdg.label:SetGlyphColour(UICOLORS.GOLD)
    wdg.button = wdg:AddChild(TEMPLATES.StandardButton(nil, buttontext, {width_button, height}))
    wdg.button:SetPosition((total_width/2)-(width_button/2) + offset, 0)
    wdg.button:SetOnClick(onclick)

    wdg.focus_forward = wdg.button

    return wdg
end

-- checkbox button with a label beside it
function TEMPLATES.OptionsLabelCheckbox(onclick, labeltext, checked, width_label, width_button, height, checkbox_size, spacing, font, font_size, horiz_offset)
    local offset = horiz_offset or 0
    local total_width = width_label + width_button + spacing
    local wdg = Widget("labelbutton")
    wdg.label = wdg:AddChild( Text(font or FONTFACE.DEFAULT, font_size or 25, labeltext) )
    wdg.label:SetPosition( (-total_width/2)+(width_label/2) + offset, 0 )
    wdg.label:SetRegionSize( width_label, height )
    wdg.label:SetHAlign( ANCHOR_RIGHT )
    wdg.label:SetGlyphColour(UICOLORS.GOLD)
    wdg.button = wdg:AddChild(TEMPLATES.StandardCheckbox(onclick, checkbox_size, checked))
    wdg.button:SetPosition((total_width/2)-(width_button/2) + offset, 0)

    wdg.focus_forward = wdg.button

    return wdg
end

function TEMPLATES.LabelCheckbox(onclick, checked, text)
    local checkbox = ImageButton()
	checkbox._text_offset = 20
    checkbox:SetTextColour(UICOLORS.GOLD)
    checkbox:SetTextFocusColour(UICOLORS.GOLD_SELECTED)
    checkbox:SetFont(FONTFACE.DEFAULT)
    checkbox:SetDisabledFont(FONTFACE.DEFAULT)
    checkbox:SetTextDisabledColour(UICOLORS.GOLD)
    checkbox:SetText(text)
    checkbox:SetTextSize(25)
    checkbox.text:SetHAlign(ANCHOR_LEFT)

	local text_width = checkbox.text:GetRegionSize()
    checkbox.text:SetPosition(checkbox._text_offset + text_width/2, 0)

    checkbox.clickoffset = Vector3(0,0,0)

    checkbox.checked = checked
    checkbox:SetOnClick(function() onclick(checkbox) end)

	checkbox.Refresh = function(self)
		if self.checked then
			self:SetTextures("images/global_redux/checkbox_normal_check.tex", "images/global_redux/checkbox_focus_check.tex", "images/global_redux/checkbox_normal_check.tex", nil, nil, {1,1}, {0,0})
		else
			self:SetTextures("images/global_redux/checkbox_normal.tex", "images/global_redux/checkbox_focus.tex", "images/global_redux/checkbox_normal.tex", nil, nil, {1,1}, {0,0})
		end
	end

	checkbox:Refresh()
	return checkbox
end

-- Spinner
function TEMPLATES.StandardSpinner(spinnerdata, width_spinner, height, font, font_size, onchanged_fn, colour)
    local atlas = "images/global_redux.xml"
    local lean = true
    local wdg = Spinner(spinnerdata, width_spinner, height, {font = font or FONTFACE.DEFAULT, size = font_size or 25}, nil, atlas, nil, lean)
    wdg:SetTextColour(colour or UICOLORS.GOLD)
	wdg:SetOnChangedFn(onchanged_fn)
    return wdg
end

-- Spinner
function TEMPLATES.StandardNumericSpinner(min, max, width_spinner, height, font, font_size)
    local atlas = "images/global_redux.xml"
    local lean = true
    local wdg = NumericSpinner(min, max, width_spinner, height, {font = font or FONTFACE.DEFAULT, size = font_size or 25}, atlas, nil, nil, lean)
    wdg:SetTextColour(UICOLORS.GOLD)
    return wdg
end

function TEMPLATES.LargeScissorProgressBar(name)
	local bar = Widget(name or "LargeScissorProgressBar")

    local frame = bar:AddChild(Image("images/global_redux/progressbar_wxplarge_frame.tex"))
    frame:SetPosition(-2, 0)
   
    local fill = bar:AddChild(Image("images/global_redux/progressbar_wxplarge_fill.tex"))
	local width, hieght = fill:GetSize()
    fill:SetScissor(-width*.5,-hieght*.5, math.max(0, width), math.max(0, hieght))
	bar.SetPercent = function(self, percent)
	    fill:SetScissor(-width*.5,-hieght*.5, math.max(0, width * percent), math.max(0, hieght))
	end

	return bar
end

-------------------
-------------------
-- PANELS/FRAMES --
-------------------
-------------------

-- Ornate black dialog with gold border (nine-slice)
-- title (optional) is anchored to top.
-- buttons (optional) are anchored to bottom.
function TEMPLATES.CurlyWindow(sizeX, sizeY, title_text, bottom_buttons, button_spacing, body_text)
    -- Ensure we're within the bounds of looking good and fitting on screen.
    sizeX = math.clamp(sizeX or 200, 190, 1000)
    sizeY = math.clamp(sizeY or 200, 90, 500)
    local w = Panel("images/9slice/toast_bg.tex")
    		:SetNineSliceBorderScale(0.7, 0.7)
    		:SetInnerSize(sizeX, sizeY)

    if title_text then                                                                                              
        w.title = w:AddChild(Text(FONTFACE.HEADER, FONTSIZE.SCREEN_TITLE, title_text, UICOLORS.GOLD_SELECTED))
		:SetText(title_text)
        	:SetHAlign(ANCHOR_MIDDLE)
		:LayoutBounds("center","top",w)
		:Offset(0,-20)

        if JapaneseOnPS4() then
            w.title:SetSize(40)
        end
    end

    if bottom_buttons then
        -- If plain text widgets are passed in, then Menu will use this style.
        -- Otherwise, the style is ignored. Use appropriate style for the
        -- amount of space for buttons. Different styles require different
        -- spacing.
        if button_spacing == nil then
            -- 1,2,3,4 buttons can be big at 210,420,630,840 widths.
            local space_per_button = sizeX / #bottom_buttons
            local has_space_for_big_buttons = space_per_button > 209
            if has_space_for_big_buttons then
                button_spacing = 320
            else
                button_spacing = 230
            end
        end
        local button_height = 50
        local button_area_width = button_spacing / 2 * #bottom_buttons
        local is_tight_bottom_fit = button_area_width > sizeX * 2/3
        if is_tight_bottom_fit then
            button_height = 60
        end

        -- Does text need to be smaller than 30 for JapaneseOnPS4()?
        w.actions = w:AddChild(Menu(bottom_buttons, button_spacing, true, nil, nil, 30))
		:LayoutBounds("center","bottom",w)
		:Offset(0,20)
        w.focus_forward = w.actions
    end

    if body_text then
        local height_reduction = 0
        if bottom_buttons then            
            height_reduction = 30
        end
        w.body = w:AddChild(Text(FONTFACE.DEFAULT, 28, body_text, UICOLORS.WHITE))
        	:EnableWordWrap(true)
        	:SetRegionSize(sizeX, sizeY - height_reduction)
        	:SetVAlign(ANCHOR_MIDDLE)
		:Offset(0,20)
    end

    return w
end

-- Grey-bounded dialog with grey border (nine-slice)
-- title (optional) is anchored to top.
-- buttons (optional) are anchored to bottom.
-- Almost exact copy of CurlyWindow.
function TEMPLATES.RectangleWindow(sizeX, sizeY, title_text, bottom_buttons, button_spacing, body_text)
    -- Background overlaps behind and foreground overlaps in front.
    -- Ensure we're within the bounds of looking good and fitting on screen.
    sizeX = math.clamp(sizeX or 200, 90, 1190)
    sizeY = math.clamp(sizeY or 200, 50, 620)
    local w = Panel("images/9slice/toast_bg.tex")
    		:SetNineSliceBorderScale(0.7, 0.7)
    		:SetInnerSize(sizeX, sizeY)
    		:SetInnerSize(sizeX, sizeY)
    		:SetNineSliceBorderScale(0.7, 0.7)

    if title_text then
        w.title = w:AddChild(Text(FONTFACE.HEADER, FONTSIZE.SCREEN_TITLE, title_text, UICOLORS.GOLD_SELECTED))
        	:SetPosition(0, -50)
        	:SetRegionSize(600, 50)
        	:SetHAlign(ANCHOR_MIDDLE)
        if JapaneseOnPS4() then
            w.title:SetSize(40)
        end
    end

    if bottom_buttons then
        -- If plain text widgets are passed in, then Menu will use this style.
        -- Otherwise, the style is ignored. Use appropriate style for the
        -- amount of space for buttons. Different styles require different
        -- spacing.
        if button_spacing == nil then
            -- 1,2,3,4 buttons can be big at 210,420,630,840 widths.
            local space_per_button = sizeX / #bottom_buttons
            local has_space_for_big_buttons = space_per_button > 209
            if has_space_for_big_buttons then
                button_spacing = 320
            else
                button_spacing = 230
            end
        end
        local button_height = -30 -- cover bottom crown

        -- Does text need to be smaller than 30 for JapaneseOnPS4()?
        w.actions = w:AddChild(Menu(bottom_buttons, button_spacing, true, nil, nil, 30))
        w.actions:SetPosition(-(button_spacing*(#bottom_buttons-1))/2, button_height) 

        w.focus_forward = w.actions
    end

    if body_text then
        local height_reduction = 0
        if bottom_buttons then
            height_reduction = 30
        end
        w.body = w:AddChild(Text(FONTFACE.DEFAULT, 28, body_text, UICOLORS.WHITE))
	        :EnableWordWrap(true)
        	:SetPosition(0, -20)
        	:SetRegionSize(sizeX, sizeY - height_reduction)
        	:SetVAlign(ANCHOR_MIDDLE)
    end

    w.HideBackground = function(self)
        for i=4,5 do
            self.elements[i]:Hide()
        end
        self.mid_center:Hide()
    end

    w.InsertWidget = function(self, widget)
		w:AddChild(widget)
		for i=1,3 do
            self.elements[i]:MoveToFront()
        end
        for i=6,8 do
            self.elements[i]:MoveToFront()
        end
        w.bottom:MoveToFront()
		return widget
    end

    -- Default to our standard background.
    local r,g,b = table.unpack(UICOLORS.BACKGROUND_MID)
    w:SetMultColor(r,g,b,1.0)

    return w
end

-- Build controller input functions from buttons passed to Menu (or
-- CurlyWindow, etc). Screens can call these functions to support the button
-- inputs from anywhere.
-- Each element in buttons should contain:
-- {
--      text = string,
--      cb = function,
--      controller_control = number,
-- }
-- Avoid Controls.Digital.ACCEPT unless you're hiding the buttons (since the focused
-- button takes that input).
function TEMPLATES.ControllerFunctionsFromButtons(buttons)
    if buttons == nil or #buttons <= 0 then
        return function() return false end, function() return "" end
    end

    local has_controls_specified = false
    for i,v in ipairs(buttons) do
        if v.controller_control then
            has_controls_specified = true
            break
        end
    end
    if not has_controls_specified then
        -- If there are multiple options, assume the far right one is cancel.
        -- If there's only one option, it's likely to have the focus so don't
        -- create two inputs for the same option.
        local last_button = buttons[#buttons]
        if #buttons > 1 and last_button then
            last_button.controller_control = Controls.Digital.CANCEL
        end
    end

    local function OnControl(controls, down)
        if down then
            return false
        -- Hitting Esc fires both Pause and Cancel, so we can only handle pause
        -- when coming from gamepads.
        elseif not controls:Has(Controls.Digital.PAUSE) or TheInput:ControllerAttached() then 
            for i,v in ipairs(buttons) do
                if controls:Has(v.controller_control) then
                    TheFrontEnd:GetSound():PlaySound(fmodtable.Event.input_down)
                    v.cb()
                    return true
                end
            end
        end

        return false
    end
    local function GetHelpText()
        local controller_id = TheInput:GetControllerID()
        local t = {}

        for i,v in ipairs(buttons) do
            if v.controller_control then
                table.insert(t, TheInput:GetLocalizedControl(controller_id, v.controller_control) .. " " .. v.text)
            end
        end
        return table.concat(t, "  ")
    end

    return OnControl, GetHelpText
end

function TEMPLATES.ScrollingGrid(items, opts)
    local peek_height = opts.widget_height * 0.25 -- how much of row to see at the bottom.
    if opts.peek_percent then
        -- Caller can force a peek height if they will add items to the list or
        -- have hidden empty widgets.
        peek_height = opts.widget_height * opts.peek_percent
    elseif not opts.force_peek and #items < math.floor(opts.num_visible_rows) * opts.num_columns then
        -- No peek if we won't scroll.
        -- This won't work if we later update the items in the grid. Would be
        -- nice if TrueScrollList could handle this but I think we'd need to
        -- update the scissor region or change the show widget threshold?
        peek_height = 0
    end
    local function ScrollWidgetsCtor(context, parent, scroll_list)
        local NUM_ROWS = opts.num_visible_rows + 2

        local widgets = {}
        for y = 1,NUM_ROWS do
            for x = 1,opts.num_columns do
                local index = ((y-1) * opts.num_columns) + x
                table.insert(widgets, parent:AddChild(opts.item_ctor_fn(context, index)))
            end
        end

        parent.grid = parent:AddChild(Grid())
        parent.grid:FillGrid(opts.num_columns, opts.widget_width, opts.widget_height, widgets)
        -- Centre grid position so scroll widget is more easily positioned and
        -- scissor automatically calculated.
        parent.grid:SetPosition(-opts.widget_width * (opts.num_columns-1)/2, opts.widget_height * (opts.num_visible_rows-1)/2 + peek_height/2)
        -- Give grid focus so it can pass on to contained widgets. It sets up
        -- focus movement directions.
        parent.focus_forward = parent.grid

        -- Higher up widgets are further to front so their hover text can
        -- appear over the widget beneath them.
        for i,w in ipairs(widgets) do
            w:MoveToBack()
        end

        -- end_offset helps ensure last item can scroll into view. It's a
        -- percent of a row height. 1 ensures that scrolling to the bottom puts
        -- a fully-displayed widget at the top. 0.75 prevents the next (empty)
        -- row from being visible.
        local end_offset = 0.75
        if opts.allow_bottom_empty_row then
            end_offset = 1
        end
        return widgets, opts.num_columns, opts.widget_height, opts.num_visible_rows, end_offset
    end

    local scissor_pad = opts.scissor_pad or 0
    local scissor_width  = opts.widget_width  * opts.num_columns      + scissor_pad
    local scissor_height = opts.widget_height * opts.num_visible_rows + peek_height
    local scissor_x = -scissor_width/2
    local scissor_y = -scissor_height/2
    local scroller = TrueScrollList(
        opts.scroll_context,
        ScrollWidgetsCtor,
        opts.apply_fn,
        scissor_x,
        scissor_y,
        scissor_width,
        scissor_height,
        opts.scrollbar_offset,
        opts.scrollbar_height_offset,
		opts.scroll_per_click
        )
    scroller:SetItemsData(items)
    scroller.GetScrollRegionSize = function(self)
        return scissor_width, scissor_height
    end
    return scroller
end

return TEMPLATES
