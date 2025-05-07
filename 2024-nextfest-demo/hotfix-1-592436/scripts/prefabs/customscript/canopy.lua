local prefabutil = require "prefabs.prefabutil"

local PREFIX = "canopy_"

local CANOPY_STRENGTH = 0.5
local CANOPY_SCALE = 5
local ROT_SPEED = 1 / 1.5		-- 1.5 seconds per rotation
local TRANS_SPEED = 1 / 2.0		-- 2.0 seconds per translation
local MAX_ROTATION = 20			-- max 20 degrees from base rotation
local MAX_TRANSLATION = 0.5		-- max 1 world unit from base position

local canopy = {
	default = {},
}

--Treat nil CONFIGURATION as "PRODUCTION" during updateprefabs
local DEV = CONFIGURATION ~= nil and CONFIGURATION ~= "PRODUCTION"

function canopy:GetTypeName()
	return "Canopy"
end


function canopy.default.CollectAssets(assets, args)
	local texname = args.texture or "shadows_tree.tex"
	local texture = "images/"..texname
	prefabutil.TryAddAsset(assets, "IMAGE", texture)
	if DEV then
		table.insert(assets, Asset("ANIM", "anim/fx_lightspot_mouseover.zip"))
	end
end


--[[
-- don't think this is needed at the moment?
local function OnRemoveEntity(inst)
	if TheWorld then
		TheWorld.components.lightcoordinator:UnregisterLight(inst)
	end
end
]]

function canopy.default.CustomInit(inst, opts)

	inst:AddTag("FX")
	assert(inst:HasTag("NOCLICK"), "Why did you make this Clickable?")

	assert(inst.persists)
	-- Allow lightspot to persist so it will appear when we load a saved
	-- room or town. Eventually we might want to load immutable entities
	-- from propdata.

--[[ No variations yet 
	local old_SetVariationInternal = inst.components.prop.SetVariationInternal
	inst.components.prop.SetVariationInternal = function(prop, variation)
		old_SetVariationInternal(prop, variation)
		if inst.AnimState then
			-- Go back to our selection anim.
			inst.AnimState:PlayAnimation("anim")
		end
		local texture = "images/shadows_tree.tex"
		inst.Light:SetCookie(texture)
	end
]]
	inst.entity:AddLight()
	inst.Light:SetIsShadow(true)

	local texname = opts.texture or "shadows_tree.tex"
	local texture = "images/"..texname
	inst.Light:SetCookie(texture)
	inst.Light:SetColor(1, 1, 1, 1)
	inst.Light:SetScale(5)
	inst.Light:SetIntensity(1)
	inst.Light:SetIsShadow(true)
	inst.Light:SetLightLayer(LightLayer.CanopyShadow)

	if DEV then
		inst.entity:AddAnimState()
		inst.baseanim = "anim"
		inst.AnimState:SetBank("fx_lightspot_mouseover")
		inst.AnimState:SetBuild("fx_lightspot_mouseover")
		inst.AnimState:PlayAnimation("anim")
		inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
		inst.AnimState:HideLayer("MOUSEOVER")

		inst.Transform:SetScale(2.6, 2.6, 2.6)
	end

	inst.components.prop:SetPropType(PropType.Lighting)
	inst:AddComponent("canopy")

	if opts.canopy_animate then
		inst:StartUpdatingComponent(inst.components.canopy)
	end
	if opts.canopy_rotation then
		inst.Light:SetRotation(opts.canopy_rotation)
	end
	if opts.canopy_scale then
		inst.Light:SetScale(opts.canopy_scale)
	end
	if opts.canopy_strength then
		inst.components.canopy:SetStrength(opts.canopy_strength)
	end
	if opts.canopy_rotspeed then
		inst.components.canopy:SetRotSpeed(opts.canopy_rotspeed)                                                   
	end
	if opts.canopy_transspeed then
		inst.components.canopy:SetTransSpeed(opts.canopy_transspeed)                                                   
	end
	if opts.canopy_maxrotation then
		inst.components.canopy:SetMaxRotation(opts.canopy_maxrotation)                                                   
	end
	if opts.canopy_maxtranslation then
		inst.components.canopy:SetMaxTranslation(opts.canopy_maxtranslation)                                                   
	end

	return inst
end


canopy.Defaults = 
{
	canopy_animate = false
}


function canopy.LivePropEdit(editor, ui, params, defaults)
	local args = params.script_args

	-- (KAJ) I decided these are not live editable. If we want that we have to make asset collection aware of per-instance data
	--local changed, newvalue = ui:InputText("Texture", args.texture or "shadows_tree.tex", imgui.InputTextFlags.CharsNoBlank)
	--if changed then
	--	args.texture = newvalue
	--end
	local changed, newvalue = ui:Checkbox("Animate",args.canopy_animate==nil and defaults.canopy_animate or args.canopy_animate)
	if changed then
		args.canopy_animate = newvalue and true or false 
	end
	local changed, rotation = ui:SliderFloat("Rotation", args.canopy_rotation or 0, 0, 360)
	if changed then
		args.canopy_rotation = rotation ~= 0 and rotation or nil
	end
        local changed,scale = ui:SliderFloat("Scale", args.canopy_scale or CANOPY_SCALE, 1, 10)
        if changed then
		args.canopy_scale = scale ~= CANOPY_SCALE and scale or nil
	end
        local changed,strength = ui:SliderFloat("Strength", args.canopy_strength or CANOPY_STRENGTH, 0, 1)
        if changed then
		args.canopy_strength = strength ~= CANOPY_STRENGTH and strength or nil
	end
        local changed,rotspeed = ui:SliderFloat("Rotation Speed", args.canopy_rotspeed or ROT_SPEED, 0, 2)
        if changed then
		args.canopy_rotspeed = rotspeed ~= ROT_SPEED and rotspeed or nil
	end
        local changed,transspeed = ui:SliderFloat("Translation Speed", args.canopy_transspeed or TRANS_SPEED, 0, 2)
        if changed then
		args.canopy_transspeed = transspeed ~= TRANS_SPEED and transspeed or nil
	end
        local changed,maxrotation = ui:SliderFloat("Max Rotation", args.canopy_maxrotation or MAX_ROTATION, 0, 50)
        if changed then
		args.canopy_maxrotation = maxrotation ~= MAX_ROTATION and maxrotation or nil
	end
        local changed,maxtranslation = ui:SliderFloat("Max Translation", args.canopy_maxtranslation or MAX_TRANSLATION, 0, 2)
        if changed then
		args.canopy_maxtranslation = maxtranslation ~= MAX_TRANSLATION and maxtranslation or nil
	end

	if ui:SmallButton("Reset to defaults") then
		args = {}
	end

	params.script_args = args
end

function canopy.PropEdit(editor, ui, params)
	local args = params.script_args
	local changed, newvalue = ui:InputText("Texture", args.texture or "shadows_tree.tex", imgui.InputTextFlags.CharsNoBlank)
	if changed then
		args.texture = newvalue
	end

	params.script_args = args
end

function canopy.Apply(inst, args)
	if args.canopy_animate then
		inst:StartUpdatingComponent(inst.components.canopy)
	else
		inst:StopUpdatingComponent(inst.components.canopy)
	end
	inst.Light:SetRotation(args.canopy_rotation or 0)
	inst.Light:SetScale(args.canopy_scale or CANOPY_SCALE)
	inst.components.canopy:SetStrength(args.canopy_strength or CANOPY_STRENGTH)
	inst.components.canopy:SetRotSpeed(args.canopy_rotspeed or ROT_SPEED)                                                   
	inst.components.canopy:SetTransSpeed(args.canopy_transspeed or TRANS_SPEED)
	inst.components.canopy:SetMaxRotation(args.canopy_maxrotation or MAX_ROTATION)
	inst.components.canopy:SetMaxTranslation(args.canopy_maxtranslation or MAX_TRANSLATION)                                                   
end

return canopy
