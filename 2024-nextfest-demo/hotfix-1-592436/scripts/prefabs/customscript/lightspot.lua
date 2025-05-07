--local lume = require "util.lume"
local prefabutil = require "prefabs.prefabutil"


local lightspot = {
	default = {},
}

local PREFIX = "lightspot_"

--Treat nil CONFIGURATION as "PRODUCTION" during updateprefabs
local DEV = CONFIGURATION ~= nil and CONFIGURATION ~= "PRODUCTION"

local function shape_to_texture(prefab, variation)
	local shape = prefab:gsub(PREFIX, "")
	return string.format("images/lightcookies_%s_%02d.tex", shape, tonumber(variation))
end

function lightspot:GetTypeName()
	return "LightSpot"
end

local lightspot_textures = {
	"images/lightcookies_angular_01.tex",
	"images/lightcookies_angular_02.tex",
	"images/lightcookies_angular_03.tex",
	"images/lightcookies_angular_04.tex",

	"images/lightcookies_leafy_01.tex",
	"images/lightcookies_leafy_02.tex",
	"images/lightcookies_leafy_03.tex",
	"images/lightcookies_leafy_04.tex",

	"images/lightcookies_branchleafy_01.tex",
	"images/lightcookies_branchleafy_02.tex",
	"images/lightcookies_branchleafy_03.tex",
	"images/lightcookies_branchleafy_04.tex",

	"images/lightcookies_circle_01.tex",
	"images/lightcookies_circle_02.tex",

	"images/lightcookies_solid_01.tex",
	"images/lightcookies_solid_02.tex",

	"images/lightcookies_lrgleafy_01.tex",

	"images/lightcookies_bubbly_01.tex",
	"images/lightcookies_bubbly_02.tex",
	"images/lightcookies_bubbly_03.tex",

	"images/lightcookies_smlbubbly_01.tex",
	"images/lightcookies_smlbubbly_02.tex",
	"images/lightcookies_smlbubbly_03.tex",
	"images/lightcookies_smlbubbly_04.tex",
}

local lookup

local function getvariations(prefab)
	if not lookup then
		lookup = {}
		for i,v in pairs(lightspot_textures) do
			lookup[v] = true
		end
	end
	local i = 0
	local shape = prefab:gsub(PREFIX, "")
	while true do
		local key = string.format("images/lightcookies_%s_%02d.tex", shape, tonumber(i+1))
		if not lookup[key] then
			return i
		end
		i = i + 1
	end
end

function lightspot.default.CollectAssets(assets, args)
	for i,v in pairs(lightspot_textures) do
		local texture = v
		prefabutil.TryAddAsset(assets, "IMAGE", texture)
	end
	if DEV then
		table.insert(assets, Asset("ANIM", "anim/fx_lightspot_mouseover.zip"))
	end
end

local function OnRemoveEntity(inst)
	if TheWorld then
		TheWorld.components.lightcoordinator:UnregisterLight(inst)
	end
end

lightspot.Defaults = 
{
	light_color = "ffffffff",	

	intensity = 1,
	animate = false,
	rotation = 0,
	scale = 10,
	
	rot_speed = 1 / 1.5,
	trans_speed = 1 / 2.0,
	max_rotation = 20,
	max_translation = 0.5,

	shimmer = false,
	shimmer_strength = 0.5,
	shimmer_speed = 3,
}


function lightspot.default.CustomInit(inst, opts)
	assert(opts.prefab:find(PREFIX) == 1, "lightspots must be named starting with 'lightspot_'")

	inst:AddTag("FX")
	assert(inst:HasTag("NOCLICK"), "Why did you make this Clickable?")

	assert(inst.persists)
	-- Allow lightspot to persist so it will appear when we load a saved
	-- room or town. Eventually we might want to load immutable entities
	-- from propdata.

	local old_SetVariationInternal = inst.components.prop.SetVariationInternal
	inst.components.prop.SetVariationInternal = function(prop, variation)
		old_SetVariationInternal(prop, variation)
		if inst.AnimState then
			-- Go back to our selection anim.
			inst.AnimState:PlayAnimation("anim")
		end
		local texture = shape_to_texture(opts.prefab, tonumber(variation))
		inst.Light:SetCookie(texture)
	end

	inst.entity:AddLight()

	if opts.light_color then
		inst.Light:SetColor(HexToRGBFloats(StrToHex(opts.light_color)))
	else
		inst.Light:SetColor(1, 1, 1, 1)
	end
	inst.Light:SetScale(opts.scale or lightspot.Defaults.scale)
	inst.Light:SetIntensity(opts.intensity or lightspot.Defaults.intensity)
	inst.Light:SetLightLayer(LightLayer.CanopyLight)

	local spot = inst:AddComponent("lightspot")

	spot:SetAnimate(opts.animate)
	spot:SetShimmer(opts.shimmer)

	spot:SetRotSpeed(opts.rot_speed or lightspot.Defaults.rot_speed)                                                   
	spot:SetTransSpeed(opts.trans_speed or lightspot.Defaults.trans_speed)
	spot:SetMaxTranslation(opts.max_translation or lightspot.Defaults.max_translation)

	local maxrot = opts.max_rotation or lightspot.Defaults.max_rotation
	local rot = opts.rotation or lightspot.Defaults.rotation
	spot:SetMaxRotation(opts.max_rotation or lightspot.Defaults.max_rotation)
	local angle = rot + math.random() * maxrot * 2 - maxrot
	spot:SetRotation(rot + math.random() * maxrot * 2 - maxrot)

	local variation = inst.components.prop.variation
	if variation then
		local texture = shape_to_texture(opts.prefab, tonumber(variation))
		inst.Light:SetCookie(texture)
	end

	if DEV and TheDungeon:GetDungeonMap():IsDebugMap() then
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

	TheWorld.components.lightcoordinator:RegisterLight(inst)
	inst.OnRemoveEntity = OnRemoveEntity

	return inst
end

function lightspot.LivePropEdit(editor, ui, params, defaults)
	local args = params.script_args

	local dirty, newval = ui:ColorHexEdit4("Light Color", args.light_color, defaults.light_color)
	if dirty then
		args.light_color = newval ~= defaults.light_color and newval or nil
	end
	local changed, intensity = ui:SliderFloat("Intensity", args.intensity or defaults.intensity, 0, 2)
	if changed then
		args.intensity = intensity ~= defaults.intensity and intensity or nil
	end

	local changed, newvalue = ui:Checkbox("Animate",args.animate==nil and defaults.animate or args.animate)
	if changed then
		args.animate = newvalue and true or false 
	end
	local changed, rotation = ui:SliderFloat("Rotation", args.rotation or defaults.rotation, 0, 360)
	if changed then
		args.rotation = rotation ~= defaults.rotation and rotation or nil
	end
        local changed,scale = ui:SliderFloat("Scale", args.scale or defaults.scale, 1, 10)
        if changed then
		args.scale = scale ~= defaults.scale and scale or nil
	end
        local changed,rot_speed = ui:SliderFloat("Rotation Speed", args.rot_speed or defaults.rot_speed, 0, 2)
        if changed then
		args.rot_speed = rot_speed ~= defaults.rot_speed and rot_speed or nil
	end
        local changed,trans_speed = ui:SliderFloat("Translation Speed", args.trans_speed or defaults.trans_speed, 0, 2)
        if changed then
		args.trans_speed = trans_speed ~= defaults.trans_speed and trans_speed or nil
	end
        local changed,max_rotation = ui:SliderFloat("Max Rotation", args.max_rotation or defaults.max_rotation, 0, 50)
        if changed then
		args.max_rotation = max_rotation ~= defaults.max_rotation and max_rotation or nil
	end
        local changed,max_translation = ui:SliderFloat("Max Translation", args.max_translation or defaults.max_translation, 0, 2)
        if changed then
		args.max_translation = max_translation ~= defaults.max_translation and max_translation or nil
	end

	local changed, newvalue = ui:Checkbox("Shimmer",args.shimmer==nil and defaults.shimmer or args.shimmer)
	if changed then
		args.shimmer = newvalue and true or false 
	end
        local changed,shimmer_speed = ui:SliderFloat("Shimmer Speed", args.shimmer_speed or defaults.shimmer_speed, 0, 20)
        if changed then
		args.shimmer_speed = shimmer_speed ~= defaults.shimmer_speed and shimmer_speed or nil
	end
        local changed,shimmer_strength = ui:SliderFloat("Shimmer Strength", args.shimmer_strength or defaults.shimmer_strength, 0, 1)
        if changed then
		args.shimmer_strength = shimmer_strength ~= defaults.shimmer_strength and shimmer_strength or nil
	end


	if ui:SmallButton("Reset to defaults") then
		args = {}
	end

	params.script_args = args
end

function lightspot.Apply(inst, args)
	inst.Light:SetColor(HexToRGBFloats(StrToHex(args.light_color or lightspot.Defaults.light_color)))
	inst.components.lightspot:SetIntensity(args.intensity or lightspot.Defaults.intensity)

	inst.components.lightspot:SetAnimate(args.animate or lightspot.Defaults.animate)
	inst.components.lightspot:SetShimmer(args.shimmer or lightspot.Defaults.shimmer)

	inst.components.lightspot:SetRotation(args.rotation or lightspot.Defaults.rotation)
	inst.Light:SetScale(args.scale or lightspot.Defaults.scale)

--	inst.components.canopy:SetStrength(args.canopy_strength or CANOPY_STRENGTH)

	inst.components.lightspot:SetRotSpeed(args.rot_speed or lightspot.Defaults.rot_speed)                                                   
	inst.components.lightspot:SetTransSpeed(args.trans_speed or lightspot.Defaults.trans_speed)
	inst.components.lightspot:SetMaxRotation(args.max_rotation or lightspot.Defaults.max_rotation)
	inst.components.lightspot:SetMaxTranslation(args.max_translation or lightspot.Defaults.max_translation)                                                   
	inst.components.lightspot:SetShimmerSpeed(args.shimmer_speed or lightspot.Defaults.shimmer_speed)                                                   
	inst.components.lightspot:SetShimmerStrength(args.shimmer_strength or lightspot.Defaults.shimmer_strength)                                                   

end

function lightspot.Validate(editor, ui, params, prefabname)
	params.variations = getvariations(prefabname)
end

return lightspot
