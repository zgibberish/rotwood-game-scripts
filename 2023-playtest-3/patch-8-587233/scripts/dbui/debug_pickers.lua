-- Fancy pickers to simplify exposing data types.
--
-- Expose new pickers here to reduce intrusive changes to imgui.
--
-- General interface is to accept:
--  ui (imgui), label, data
-- And to return:
--  data

require("constants")
require("fonts")
require("util")


local DebugPickers = {}

function DebugPickers.Font(ui, label_prefix, font_face, font_size)
    local changed, size = ui:SliderInt(label_prefix.."font size", font_size or 0, 10, 200)
    if changed then
        font_size = size
    end

    if ui:TreeNode(label_prefix .."font: pick by name") then
        local current_font_idx = 1
        local available_fonts = {}
        for i,font in ipairs(FONTS) do
            table.insert(available_fonts, font.alias)
            if font.alias == font_face then
                current_font_idx = i
            end
        end
        local changed_face, font_idx = ui:ListBox(label_prefix.."font face", available_fonts, current_font_idx, 10)
        if changed_face then
            font_face = available_fonts[font_idx]
            changed = true
        end
        ui:TreePop()
    end

    if changed then
        return font_face, font_size
    end
end

function DebugPickers.Colour(ui, label, colour)
    local new_colour = nil
    local changed, r,g,b,a = ui:ColorEdit4(label, table.unpack(colour))
    -- Can't set a tooltip here because it clobbers the color button tooltip!
    if changed then
        new_colour = {r, g, b, a}
    end

    if ui:TreeNode(label ..": pick by name") then
        local colour_groups = {
            WEBCOLORS = WEBCOLORS,
            UICOLORS = UICOLORS,
        }
        local available_colours = {}
        for group_name,group in pairs(colour_groups) do
            for name,c in pairs(group) do
                table.insert(available_colours, group_name..'.'..name)
            end
        end
        table.sort(available_colours)
        local colour_idx
        changed, colour_idx = ui:ListBox(label, available_colours, -1, 10)
        if changed then
            local group,name = table.unpack(available_colours[colour_idx]:split('.'))
            new_colour = colour_groups[group][name]
        end
        ui:TreePop()
    end
    return new_colour
end

return DebugPickers
