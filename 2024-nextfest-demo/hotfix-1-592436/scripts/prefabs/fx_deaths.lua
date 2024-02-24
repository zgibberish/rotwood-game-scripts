local ParticleSystemHelper = require "util.particlesystemhelper"
local monsterutil = require "util.monsterutil"

local fx_types =
{
	"_frnt",
	"_grnd",
}

local function OnChildFxRemoved(child)
	local inst = child.entity:GetParent()
	local num = #inst.highlightchildren
	for i = 1, num do
		if inst.highlightchildren[i] == child then
			if num > 1 then
				inst.highlightchildren[i] = inst.highlightchildren[num]
				inst.highlightchildren[num] = nil
			else
				inst.highlightchildren[i] = nil
				inst:DoTaskInTicks(0, inst.Remove)
			end
			break
		end
	end
end

local function SetRotationOnAllLayers(inst, rot)
	for i = 1, #inst.highlightchildren do
		local fx = inst.highlightchildren[i]
		-- we don't want this to happen for ground projected fx
		local ao = fx.AnimState and fx.AnimState:GetOrientation()
		local is_on_ground = ao == ANIM_ORIENTATION.OnGround or ao == ANIM_ORIENTATION.OnGroundFixed
		if not is_on_ground then
			fx.Transform:SetRotation(rot)
		end
	end
end

local function SetupDeathFxFor(inst, target)
	local x, z = target.Transform:GetWorldXZ()
	inst.Transform:SetPosition(x, 0, z)
	SetRotationOnAllLayers(inst, target.Transform:GetFacingRotation() + 180)
	inst.target = target
	if target.components.coloradder ~= nil then
		target.components.coloradder:AttachChild(inst)
	end
	if target.components.hitstopper ~= nil then
		target.components.hitstopper:AttachChild(inst)
	end

	local function OnSetDir(xtarget, data)
		if data ~= nil and data.attack ~= nil and data.attack:GetDir() ~= nil then
			local dir = DiffAngle(0, data.attack:GetDir())
			if dir < 90 then
				dir = 0
			elseif dir > 90 then
				dir = 180
			else
				dir = xtarget.Transform:GetFacingRotation() + 180
			end
			inst.Transform:SetRotation(dir)
		end
	end
	inst:ListenForEvent("attacked", OnSetDir, target)
	inst:ListenForEvent("knockdown", OnSetDir, target)
	inst:ListenForEvent("knockback", OnSetDir, target)
end

local MonsterSize_to_Particle =
{
	[monsterutil.MonsterSize.SMALL] = "hit_focus_kill_burst_stationary",
	[monsterutil.MonsterSize.MEDIUM] = "hit_focus_kill_burst_med",
	[monsterutil.MonsterSize.LARGE] = "hit_focus_kill_burst_large",
	[monsterutil.MonsterSize.GIANT] = "hit_focus_kill_burst_large",
}

local function SpawnFocusDeathParticles(inst, isFocusAttack, attackTarget, particlesname)
	if attackTarget == nil or not isFocusAttack then
		return
	end

	if not particlesname and inst.target and inst.target.monster_size then
		particlesname = MonsterSize_to_Particle[inst.target.monster_size]
	elseif not particlesname and (not inst.target or not inst.target.monster_size) then
		TheLog.ch.Effects:printf("SpawnFocusDeathParticles: Tried to spawn on invalid target or one without a monster size")
		return
	end

	local pfx = ParticleSystemHelper.MakeOneShot(inst, particlesname)
	pfx:AddComponent("hitstopper")

	local hitstopper = attackTarget.components.hitstopper
	if hitstopper ~= nil then
		hitstopper:AttachChild(pfx)
	end
end

local function Setup(inst, fxname, offsets)
	for i, fxtype in ipairs(fx_types) do
		local prefabname = fxname .. fxtype
		if PrefabExists(prefabname) then
			local fx = SpawnPrefab(prefabname, inst)
			fx.entity:SetParent(inst.entity)
			inst.components.coloradder:AttachChild(fx)
			inst.components.hitstopper:AttachChild(fx)

			inst.highlightchildren[i] = fx

			inst:ListenForEvent("onremove", OnChildFxRemoved, fx)

			if offsets then
				local x_offset = offsets.x or 0
				local y_offset = i ~= 2 and offsets.y or 0 -- Do not apply y-offset to '_grnd' FX
				local z_offset = offsets.z or 0
				local pos = fx:GetPosition()
				fx.Transform:SetPosition(pos.x + x_offset, pos.y + y_offset, pos.z + z_offset)
			end
		end
	end
end

-- Create a root prefab for spawning in front, ground death FX prefabs; call Setup() after creating this prefab!
local function fn(prefabname)
	local inst = CreateEntity()
	inst:SetPrefabName(prefabname)

	inst.entity:AddTransform()

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")
	inst.persists = false

	inst:AddComponent("coloradder")
	inst:AddComponent("hitstopper")

	inst.highlightchildren = {}

	inst.SetupDeathFxFor = SetupDeathFxFor
	inst.SpawnFocusDeathParticles = SpawnFocusDeathParticles
	inst.Setup = Setup

	return inst
end

return Prefab("fx_deaths", fn)
