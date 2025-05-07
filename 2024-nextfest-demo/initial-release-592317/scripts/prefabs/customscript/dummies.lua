---------------------------------------------------------------------------------------
--Custom script for auto-generated prop prefabs
---------------------------------------------------------------------------------------

local function CustomInit(inst, args)
	inst.entity:AddHitBox()
	inst.HitBox:SetHitGroup(HitGroup.NEUTRAL)

	inst:AddTag("dummy")

	inst:AddComponent("hitstopper")
	if inst.highlightchildren ~= nil then
		for i = 1, #inst.highlightchildren do
			inst.components.hitstopper:AttachChild(inst.highlightchildren[i])
		end
	end

	inst:AddComponent("combat")
	--inst.components.combat:SetHurtFx()
	inst.components.combat:SetHasKnockback(true)
	inst.components.combat:SetHasKnockdown(false)

	local powermanager = inst:AddComponent("powermanager")
	inst:AddComponent("timer") -- used for some power stuff that can happen to a dummy

	inst:AddComponent("health")
	inst.components.health:SetMax(1, true)

	powermanager:EnsureRequiredComponents()


	inst:SetStateGraph("sg_dummy")

	if args.prefab == "dummy_crit" then
		local Power = require "defs.powers.power"
		local def = Power.Items.CHEAT.crit_all_incoming
		local power = powermanager:CreatePower(def)
		powermanager:AddPower(power)

		inst:AddComponent("damagebonus")
	end
end

local function EventInit(inst, args)
	CustomInit(inst, args)
	inst.AnimState:SetScale(3, 3)

	inst.components.health:SetMax(5000, true)

	inst:SetStateGraph("sg_event_dummy")
end

return
{
	default =
	{
		CustomInit = CustomInit,
	},
}
