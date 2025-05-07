---------------------------------------------------------------------------------------
--Custom script for auto-generated prop prefabs
---------------------------------------------------------------------------------------

local function SpawnHitLeaves(inst, right)
	local fx = CreateEntity()

	fx.entity:AddTransform()
	fx.entity:AddAnimState()

	fx:AddTag("FX")
	fx:AddTag("NOCLICK")
	fx.persists = false

	fx.AnimState:SetBank("tree")
	fx.AnimState:SetBuild("tree")
	fx.AnimState:PlayAnimation("leaves_"..(right and "r" or "l")..tostring(math.random(2)))
	fx.AnimState:SetFinalOffset(1)
	fx.AnimState:SetShadowEnabled(true)

	fx:AddComponent("bloomer")
	fx:AddComponent("colormultiplier")
	fx:AddComponent("coloradder")
	fx:AddComponent("hitstopper")

	inst.components.bloomer:AttachChild(fx)
	inst.components.colormultiplier:AttachChild(fx)
	inst.components.coloradder:AttachChild(fx)
	inst.components.hitstopper:AttachChild(fx)

	local x, y, z = inst.Transform:GetWorldPosition()
	for i = 1, #inst.highlightchildren do
		local child = inst.highlightchildren[i]
		if child.baseanim ~= nil then
			local x1, y1, z1 = child.Transform:GetWorldPosition()
			if z1 <= z then
				x, y, z = x1, y1, z1
			end
		end
	end
	fx.Transform:SetPosition(x, y, z)

	fx:ListenForEvent("animover", fx.Remove)
end

local function CustomInit(inst, args)
	-- inst.entity:AddHitBox()
	-- inst.HitBox:SetHitGroup(HitGroup.RESOURCE)

	inst:AddComponent("hitstopper")
	for i = 1, #inst.highlightchildren do
		inst.components.hitstopper:AttachChild(inst.highlightchildren[i])
	end

	-- inst:AddComponent("combat")
	-- inst.components.combat:SetHasKnockback(true)
	-- inst.components.combat:SetHasKnockdown(false)

	inst:AddComponent("timer")
	if TheDungeon:GetDungeonMap():IsDebugMap() then
		inst.components.timer:StartPausedTimer("twig_cd", 1)
	end

	inst:SetStateGraph("sg_tree")

	inst.SpawnHitLeaves = SpawnHitLeaves
	inst:AddTag("large")
end

return
{
	tree =
	{
		CustomInit = CustomInit,
	},
}
