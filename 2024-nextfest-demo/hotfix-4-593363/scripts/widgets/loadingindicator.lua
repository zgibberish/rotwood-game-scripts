local Widget = require "widgets/widget"
local Image = require "widgets/image"
local Text = require "widgets/text"

local easing = require "util.easing"

---------------------------------------------------------------------
-- Displays an animated icon, and a text label next to it

local LoadingIndicator = Class(Widget, function(self, color, icon_size, text_size)
    Widget._ctor(self, "LoadingIndicator")

    self.color = color or UICOLORS.LIGHT_TEXT_TITLE
    self.icon_size = icon_size or 90
    self.text_size = text_size or 60

    self.icon = self:AddChild(Image("images/ui_ftf_icons/loading.tex"))
        :SetName("Icon")
        :SetSize(self.icon_size, self.icon_size)
        :SetMultColor(self.color)

    self.text = self:AddChild(Text(FONTFACE.DEFAULT, self.text_size, STRINGS.UI.LOADINGINDICATOR.LOADING_TEXT))
        :SetName("Text")
        :SetGlyphColor(self.color)
        :LayoutBounds("after", "center", self.icon)
        :Offset(self.icon_size * 0.2, 0)

    -- Animate the icon
    self.icon:RunUpdater(Updater.Series{
        Updater.Wait(math.random() * 0.5 + 0.1),
        Updater.Loop{
            Updater.Ease(function(deg) self.icon:SetRotation(deg) end, 0, 90, 1.25, easing.inElastic),
            Updater.Ease(function(deg) self.icon:SetRotation(deg) end, 270, 360, 1.25, easing.outElastic),
        }
    })

end)

function LoadingIndicator:SetText(text)
    self.icon:SetRotation(0)
    self.text:SetText(text)
        :LayoutBounds("after", "center", self.icon)
        :Offset(self.icon_size * 0.2, 0)
    return self
end

return LoadingIndicator
