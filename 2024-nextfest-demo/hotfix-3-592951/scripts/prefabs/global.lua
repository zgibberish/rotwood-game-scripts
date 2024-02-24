local ICON_FRAME_SIZE = 240

local assets = {
        -- Assets used in mainmenu and gameplay.
        --
        -- If it's not used in mainmenu, put it in hud.lua
        -- If you have anything town-specific, put it in deps_town.lua instead.
        -- TODO: Rename this file deps_global.lua and use GroupPrefab.


        Asset("PKGREF", "sound/Master.bank"), -- Master.bank is loaded manually in fromtheforge.cpp
        Asset("PKGREF", "sound/Master.strings.bank"), -- Master.bank.strings is loaded manually in fromtheforge.cpp
        Asset("SOUND", "sound/UI.bank"),
        Asset("SOUND", "sound/Ambiences.bank"),
        Asset("SOUND", "sound/Music.bank"),
        Asset("SOUND", "sound/Creatures.bank"),
        Asset("SOUND", "sound/Powers.bank"),
        Asset("SOUND", "sound/Player_Mvmt.bank"),
        Asset("SOUND", "sound/Skills.bank"),
        Asset("SOUND", "sound/Weapons.bank"),
        Asset("SOUND", "sound/Emote.bank"),

        -- Loading screens
        Asset("DYNAMIC_ATLAS", "images/bg_loading.xml"),
        Asset("PKGREF", "images/bg_loading.tex"),

        Asset("ATLAS", "images/icons_keyboard.xml"),
        Asset("IMAGE", "images/icons_keyboard.tex"),
        Asset("ATLAS", "images/icons_mouse.xml"),
        Asset("IMAGE", "images/icons_mouse.tex"),
        Asset("ATLAS", "images/icons_nxjoycon.xml"),
        Asset("IMAGE", "images/icons_nxjoycon.tex"),
        Asset("ATLAS", "images/icons_nxpro.xml"),
        Asset("IMAGE", "images/icons_nxpro.tex"),
        Asset("ATLAS", "images/icons_ps4.xml"),
        Asset("IMAGE", "images/icons_ps4.tex"),
        Asset("ATLAS", "images/icons_ps5.xml"),
        Asset("IMAGE", "images/icons_ps5.tex"),
        Asset("ATLAS", "images/icons_xbox360.xml"),
        Asset("IMAGE", "images/icons_xbox360.tex"),

        Asset("ATLAS", "images/global.xml"),
        Asset("IMAGE", "images/global.tex"),
        Asset("IMAGE", "images/visited.tex"),

        Asset("IMAGE", "images/circle.tex"),
        Asset("IMAGE", "images/square.tex"),
        Asset("IMAGE", "images/trans.tex"),

        Asset("ATLAS", "images/9slice.xml"),
        Asset("IMAGE", "images/9slice.tex"),

        Asset("ATLAS", "images/masks.xml"),
        Asset("IMAGE", "images/masks.tex"),

        Asset("ATLAS", "images/ui_ftf.xml"),
        Asset("IMAGE", "images/ui_ftf.tex"),

        Asset("ATLAS", "images/ui_ftf_inventory.xml"),
        Asset("IMAGE", "images/ui_ftf_inventory.tex"),

        Asset("ATLAS", "images/ui_ftf_research.xml"),
        Asset("IMAGE", "images/ui_ftf_research.tex"),

        Asset("ATLAS", "images/ui_ftf_multiplayer.xml"),
        Asset("IMAGE", "images/ui_ftf_multiplayer.tex"),

        Asset("ATLAS", "images/ui_ftf_online.xml"),
        Asset("IMAGE", "images/ui_ftf_online.tex"),

        Asset("ATLAS", "images/ui_ftf_notifications.xml"),
        Asset("IMAGE", "images/ui_ftf_notifications.tex"),

        Asset("ATLAS", "images/ui_ftf_gems.xml"),
        Asset("IMAGE", "images/ui_ftf_gems.tex"),

        Asset("ATLAS", "images/slideshow.xml"),
        Asset("IMAGE", "images/slideshow.tex"),

        -- Icons used globally throughout the game (not specific to one screen).
        Asset("ATLAS", "images/ui_ftf_icons.xml"),
        Asset("IMAGE", "images/ui_ftf_icons.tex"),
        Asset("ATLAS", "images/hud_images.xml"), -- exported from flash
        Asset("IMAGE", "images/hud_images.tex"),

        Asset("ATLAS", "images/ui_ftf_shop.xml"),
        Asset("IMAGE", "images/ui_ftf_shop.tex"),

        Asset("ATLAS", "images/ui_ftf_dialog.xml"),
        Asset("IMAGE", "images/ui_ftf_dialog.tex"),

        Asset("ATLAS", "images/ui_ftf_feedback.xml"),
        Asset("IMAGE", "images/ui_ftf_feedback.tex"),

        Asset("ATLAS", "images/ui_ftf_forging.xml"),
        Asset("IMAGE", "images/ui_ftf_forging.tex"),

        Asset("ATLAS", "images/ui_ftf_crafting.xml"),
        Asset("IMAGE", "images/ui_ftf_crafting.tex"),

        Asset("ATLAS", "images/ui_ftf_runsummary.xml"),
        Asset("IMAGE", "images/ui_ftf_runsummary.tex"),

        Asset("ATLAS", "images/ui_ftf_ingame.xml"),
        Asset("IMAGE", "images/ui_ftf_ingame.tex"),

        Asset("ATLAS", "images/fullscreeneffects.xml"),
        Asset("IMAGE", "images/fullscreeneffects.tex"),

        Asset("ATLAS", "images/ui_ftf_skin.xml"),
        Asset("IMAGE", "images/ui_ftf_skin.tex"),

        Asset("ATLAS", "images/ui_ftf_town.xml"),
        Asset("IMAGE", "images/ui_ftf_town.tex"),

        Asset("ATLAS", "images/ui_ftf_unlock.xml"),
        Asset("IMAGE", "images/ui_ftf_unlock.tex"),

        Asset("ATLAS", "images/ui_ftf_roombonus.xml"),
        Asset("IMAGE", "images/ui_ftf_roombonus.tex"),

        Asset("ATLAS", "images/bg_selectpower.xml"),
        Asset("IMAGE", "images/bg_selectpower.tex"),

        Asset("ATLAS", "images/bg_popup_small.xml"),
        Asset("IMAGE", "images/bg_popup_small.tex"),

        Asset("ATLAS", "images/bg_popup_flat.xml"),
        Asset("IMAGE", "images/bg_popup_flat.tex"),

        Asset("ATLAS", "images/bg_popup_flat_inner_mask.xml"),
        Asset("IMAGE", "images/bg_popup_flat_inner_mask.tex"),

        Asset("ATLAS", "images/bg_UI_RelicSelect_MainBG2.xml"),
        Asset("IMAGE", "images/bg_UI_RelicSelect_MainBG2.tex"),

        Asset("ATLAS", "images/bg_feedback_screen_bg.xml"),
        Asset("IMAGE", "images/bg_feedback_screen_bg.tex"),

        Asset("ATLAS", "images/bg_ChooseCharacterBg.xml"),
        Asset("IMAGE", "images/bg_ChooseCharacterBg.tex"),

        Asset("ATLAS", "images/bg_CharacterSelectionBg.xml"),
        Asset("IMAGE", "images/bg_CharacterSelectionBg.tex"),

        Asset("ATLAS", "images/bg_background_panel.xml"),
        Asset("IMAGE", "images/bg_background_panel.tex"),

        Asset("ATLAS", "images/bg_research_screen_left.xml"),
        Asset("IMAGE", "images/bg_research_screen_left.tex"),

        Asset("ATLAS", "images/bg_research_screen_right.xml"),
        Asset("IMAGE", "images/bg_research_screen_right.tex"),

        Asset("ATLAS", "images/bg_CharacterScreenPopupBg.xml"),
        Asset("IMAGE", "images/bg_CharacterScreenPopupBg.tex"),

        Asset("ATLAS", "images/bg_widebanner.xml"),
        Asset("IMAGE", "images/bg_widebanner.tex"),

        Asset("ATLAS", "images/ui_ftf_relic_selection.xml"),
        Asset("IMAGE", "images/ui_ftf_relic_selection.tex"),

        Asset("ATLAS", "images/ui_ftf_pausescreen.xml"),
        Asset("IMAGE", "images/ui_ftf_pausescreen.tex"),

        Asset("ATLAS", "images/ui_ftf_options.xml"),
        Asset("IMAGE", "images/ui_ftf_options.tex"),

        Asset("ATLAS", "images/ui_ftf_minigames.xml"),
        Asset("IMAGE", "images/ui_ftf_minigames.tex"),

        Asset("ATLAS", "images/ui_ftf_character.xml"),
        Asset("IMAGE", "images/ui_ftf_character.tex"),

        Asset("ATLAS", "images/ui_ftf_dungeon_selection.xml"),
        Asset("IMAGE", "images/ui_ftf_dungeon_selection.tex"),

        Asset("ATLAS", "images/ui_ftf_powers.xml"),
        Asset("IMAGE", "images/ui_ftf_powers.tex"),

        Asset("ATLAS", "images/ui_ftf_hud.xml"),
        Asset("IMAGE", "images/ui_ftf_hud.tex"),

        Asset("ATLAS", "images/ui_ftf_segmented_healthbar.xml"),
        Asset("IMAGE", "images/ui_ftf_segmented_healthbar.tex"),

        Asset("ATLAS", "images/ui_ftf_dungeon_progress.xml"),
        Asset("IMAGE", "images/ui_ftf_dungeon_progress.tex"),

        Asset("ATLAS", "images/mapicons_ftf.xml"),
        Asset("IMAGE", "images/mapicons_ftf.tex"),

        Asset("ATLAS", "images/icons_ftf.xml"),
        Asset("IMAGE", "images/icons_ftf.tex"),


        Asset("ATLAS", "images/icons_boss.xml"),
        Asset("IMAGE", "images/icons_boss.tex"),

        Asset("ATLAS", "images/item_images.xml"),
        Asset("IMAGE", "images/item_images.tex"),

        Asset("ATLAS", "images/bg_vignette.xml"),
        Asset("IMAGE", "images/bg_vignette.tex"),

        Asset("IMAGE", "images/color_cubes/identity_cc.tex"),

        Asset("SHADER", "shaders/anim.ksh"),
        Asset("SHADER", "shaders/animbloom.ksh"),
        Asset("SHADER", "shaders/anim_rim.ksh"),
        Asset("SHADER", "shaders/blurh.ksh"),
        Asset("SHADER", "shaders/blurv.ksh"),
        Asset("SHADER", "shaders/creep.ksh"),
        Asset("SHADER", "shaders/debug_line.ksh"),
        Asset("SHADER", "shaders/debug_tri.ksh"),
        Asset("SHADER", "shaders/render_depth.ksh"),
        Asset("SHADER", "shaders/font.ksh"),
        Asset("SHADER", "shaders/font_packed.ksh"),
        Asset("SHADER", "shaders/font_packed_outline.ksh"),
        Asset("SHADER", "shaders/ground.ksh"),
        Asset("SHADER", "shaders/groundshadow.ksh"),
        Asset("SHADER", "shaders/ground_shadow.ksh"),
        Asset("SHADER", "shaders/ground_overlay.ksh"),
        Asset("SHADER", "shaders/ground_lights.ksh"),
        Asset("SHADER", "shaders/ground_underground.ksh"),
        Asset("SHADER", "shaders/ocean.ksh"),
        Asset("SHADER", "shaders/ocean_combined.ksh"),
        Asset("SHADER", "shaders/ceiling.ksh"),
        Asset("SHADER", "shaders/lighting.ksh"),
        Asset("SHADER", "shaders/minimap.ksh"),
        Asset("SHADER", "shaders/minimapocean.ksh"),
        Asset("SHADER", "shaders/minimapfs.ksh"),
        Asset("SHADER", "shaders/particle.ksh"),
        Asset("SHADER", "shaders/vfx_particle.ksh"),
        Asset("SHADER", "shaders/vfx_particle_add.ksh"),
        Asset("SHADER", "shaders/vfx_particle_reveal.ksh"),
        Asset("SHADER", "shaders/road.ksh"),
        Asset("SHADER", "shaders/river.ksh"),
        Asset("SHADER", "shaders/splat.ksh"),
        Asset("SHADER", "shaders/sprite.ksh"),
        Asset("SHADER", "shaders/texture.ksh"),
        Asset("SHADER", "shaders/ui.ksh"),
        Asset("SHADER", "shaders/ui_nomip.ksh"),
        Asset("SHADER", "shaders/ui_cc.ksh"),
        Asset("SHADER", "shaders/ui_mask.ksh"),
        Asset("SHADER", "shaders/ui_alpha_mask.ksh"),
        Asset("SHADER", "shaders/ui_anim_mask.ksh"),
        Asset("SHADER", "shaders/ui_yuv.ksh"),
        Asset("SHADER", "shaders/swipe_fade.ksh"),
        Asset("SHADER", "shaders/ui_anim.ksh"),
        Asset("SHADER", "shaders/combine_color_cubes.ksh"),
        Asset("SHADER", "shaders/zoomblur.ksh"),
        Asset("SHADER", "shaders/postprocess_none.ksh"),
        Asset("SHADER", "shaders/postprocess.ksh"),
        Asset("SHADER", "shaders/postprocessbloom.ksh"),
        Asset("SHADER", "shaders/postprocessrim.ksh"),
        Asset("SHADER", "shaders/postprocessbloomrim.ksh"),
        Asset("SHADER", "shaders/blendoceantexture.ksh"),
        Asset("SHADER", "shaders/model_normal.ksh"),
        Asset("SHADER", "shaders/gradient.ksh"),
        Asset("SHADER", "shaders/textured_unlit_vtxcol.ksh"),
        Asset("SHADER", "shaders/textured_unlit_vtxcol_gradient.ksh"),

        Asset("SHADER", "shaders/particle_new.ksh"),
        Asset("SHADER", "shaders/particle_new_erosion.ksh"),
        Asset("SHADER", "shaders/particle_new_rim.ksh"),
        Asset("SHADER", "shaders/particle_new_erosion_rim.ksh"),

        Asset("ATLAS", "images/uitest.xml"),
        Asset("IMAGE", "images/uitest.tex"),

        Asset("ANIM", "anim/gridplacer.zip"),

        Asset("ANIM", "anim/ui_scroll.zip"),
        Asset("ANIM", "anim/weight_thermometer.zip"),

        Asset("IMAGE", "images/glow.tex"),
        Asset("IMAGE", "images/white.tex"),
        Asset("IMAGE", "images/inkbleed.tex"),
}

local monster_pictures = require "gen.atlas.monster_pictures"
for _,atlas in ipairs(monster_pictures.atlases) do
        table.insert(assets, Asset("ATLAS", atlas ..".xml"))
        table.insert(assets, Asset("IMAGE", atlas ..".tex"))
end

local icons_inventory = require "gen.atlas.icons_inventory"
for _,atlas in ipairs(icons_inventory.atlases) do
        table.insert(assets, Asset("ATLAS", atlas ..".xml"))
        table.insert(assets, Asset("IMAGE", atlas ..".tex"))
end

local icons_emotes = require"gen.atlas.icons_emotes"
for _,atlas in ipairs(icons_emotes.atlases) do
        table.insert(assets, Asset("ATLAS", atlas ..".xml"))
        table.insert(assets, Asset("IMAGE", atlas ..".tex"))
end

local ui_ftf_power_icons = require "gen.atlas.ui_ftf_power_icons"
for _,atlas in ipairs(ui_ftf_power_icons.atlases) do
        table.insert(assets, Asset("ATLAS", atlas ..".xml"))
        table.insert(assets, Asset("IMAGE", atlas ..".tex"))

        table.insert(assets, Asset("ATLAS_BUILD", atlas ..".xml", ICON_FRAME_SIZE, 0, -0.8))
end

local ui_ftf_skill_icons = require "gen.atlas.ui_ftf_skill_icons"
for _,atlas in ipairs(ui_ftf_skill_icons.atlases) do
        table.insert(assets, Asset("ATLAS", atlas ..".xml"))
        table.insert(assets, Asset("IMAGE", atlas ..".tex"))

        table.insert(assets, Asset("ATLAS_BUILD", atlas ..".xml", ICON_FRAME_SIZE, 0, -0.8))
end

local ui_ftf_mastery_icons = require "gen.atlas.ui_ftf_mastery_icons"
for _,atlas in ipairs(ui_ftf_mastery_icons.atlases) do
        table.insert(assets, Asset("ATLAS", atlas ..".xml"))
        table.insert(assets, Asset("IMAGE", atlas ..".tex"))
end

local ui_ftf_food_icons = require "gen.atlas.ui_ftf_food_icons"
for _,atlas in ipairs(ui_ftf_food_icons.atlases) do
        table.insert(assets, Asset("ATLAS", atlas ..".xml"))
        table.insert(assets, Asset("IMAGE", atlas ..".tex"))

        table.insert(assets, Asset("ATLAS_BUILD", atlas ..".xml", ICON_FRAME_SIZE, 0, -0.8))
end

local ui_ftf_reward_group_icons = require "gen.atlas.ui_ftf_reward_group_icons"
for _,atlas in ipairs(ui_ftf_reward_group_icons.atlases) do
        table.insert(assets, Asset("ATLAS", atlas ..".xml"))
        table.insert(assets, Asset("IMAGE", atlas ..".tex"))
end

-- Not currently using the beta (programmer art) versions.
--~ local ui_ftf_power_icons_beta = require "gen.atlas.ui_ftf_power_icons_beta"
--~ for _,atlas in ipairs(ui_ftf_power_icons_beta.atlases) do
--~     table.insert(assets, Asset("ATLAS", atlas ..".xml"))
--~     table.insert(assets, Asset("IMAGE", atlas ..".tex"))
--~ end

require("fonts")
for i, font in ipairs(FONTS) do
        table.insert(assets, Asset("FONT", font.filename))
end


return Prefab("global", function() end, assets)
