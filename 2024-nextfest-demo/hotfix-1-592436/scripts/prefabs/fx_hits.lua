local fmodtable = require "defs.sound.fmodtable"

local FX =
{
	-- Legacy fx. Should build these in FxEditor instead.

	-- Only used by rotwood
	["fx_hit_player_horizontal"] =
	{
		lit = true,
		tint = RGB(51, 51, 51, 0),
		snaptotarget = true,
		build = "fx_hit_player",
		anim = "horizontal",
		fx_sound = fmodtable.Event.Hit_player_base,
	},

	["fx_hit_player_round"] =
	{
		lit = true,
		tint = RGB(51, 51, 51, 0),
		snaptotarget = true,
		build = "fx_hit_player",
		anim = "round",
		fx_sound = fmodtable.Event.Hit_player,
	},

	-- Only used by rotwood
	["fx_hit_player_side"] =
	{
		variations = 2,
		lit = true,
		tint = RGB(51, 51, 51, 0),
		snaptotarget = true,
		build = "fx_hit_player",
		anim = "side",
		fx_sound = fmodtable.Event.Hit_player,
	},

	["fx_hurt_sweat"] =
	{
		variations = 2,
		randomflip = true,
	},

	["fx_hurt_woodchips"] =
	{
		randomflip = true,
	},
}

--------------------------------------------------------------------------
--Setup target blinking during hitstop

local function DoFadeBlink(inst, i, numsteps)
	if inst.target:IsValid() then
		if i < numsteps then
			local r, g, b, a = table.unpack(inst.target_tint)
			local k = 1 - i / numsteps
			inst.target.components.coloradder:PushColor(inst, r * k, g * k, b * k, a * k)
			inst:DoTaskInTicks(0, DoFadeBlink, i + 1, numsteps)
		else
			inst.target.components.coloradder:PopColor(inst)
		end
	end
end

local function OnResumed(inst)
	inst:RemoveEventCallback("resumed")
	DoFadeBlink(inst, 1, 3)
end

local function OnPaused(inst)
	inst:RemoveEventCallback("paused", OnPaused)
	if inst.target:IsValid() then
		inst:ListenForEvent("resumed", OnResumed)
		inst.target.components.coloradder:PushColor(inst, table.unpack(inst.target_tint))
	end
end

--------------------------------------------------------------------------

function SpawnHitFx(prefab, attacker, target, x_offset, y_offset, dir, hitstoplevel)
	-- it is okay to spawn hit effects for local entities
	-- however, no one else will see them
	if attacker.Network and target.Network then
		local entGUID = TheNetEvent:FXHit(prefab, attacker.GUID, target.GUID, x_offset, y_offset, dir, hitstoplevel, false)
		return entGUID ~= 0 and Ents[entGUID] or nil
	else
		return HandleSpawnHitFx(prefab, attacker, target, x_offset, y_offset, dir, hitstoplevel)
	end
end

function HandleSpawnHitFx(prefab, attacker, target, x_offset, y_offset, dir, hitstoplevel)
	-- instigator is entity initiating the attack, but attacker is thing that
	-- actually attacked (projectile). They are often the same.
	local instigator = attacker.owner or attacker
	local x1, z1 = attacker.Transform:GetWorldXZ()
	local x2, z2 = target.Transform:GetWorldXZ()
	local x3
	local z3 = math.min(z1, z2)
	if attacker.highlightchildren ~= nil then
		for i = 1, #attacker.highlightchildren do
			local x4, z4 = attacker.highlightchildren[i].Transform:GetWorldXZ()
			z3 = math.min(z3, z4)
		end
	end
	if target.highlightchildren ~= nil then
		for i = 1, #target.highlightchildren do
			local x4, z4 = target.highlightchildren[i].Transform:GetWorldXZ()
			z3 = math.min(z3, z4)
		end
	end

	local params = FX[prefab]
	if params ~= nil and params.snaptotarget then
		x3 = x2
	else
		--offset to the impact point of the attacker's animation
		local facing1 = attacker.Transform:GetFacing()
		x3 = facing1 == FACING_RIGHT and x1 + x_offset or x1 - x_offset

		--left and right edges of the target
		local size2 = target.HitBox:GetSize() * (target.sg ~= nil and target.sg:HasStateTag("knockdown") and .75 or .9)
		local x2l = x2 - size2
		local x2r = x2 + size2

		if z1 > z2 then
			--attacker is behind target
			if x3 < x2l then
				x3 = x3 * .1 + x2l * .9
			elseif x3 > x2r then
				x3 = x3 * .1 + x2r * .9
			elseif x3 > x2l and x3 < x2r then
				local minl = math.min(x3 - x2l, math.abs(x1 - x2l))
				local minr = math.min(x2r - x3, math.abs(x1 - x2r))
				if minl < minr or (minl == minr and facing1 == FACING_RIGHT) then
					x3 = math.min(x3, x2) * .4 + x2l * .6
				else
					x3 = math.max(x3, x2) * .4 + x2r * .6
				end
			end
		elseif x3 < x2l then
			x3 = x3 * .3 + x2l * .7
		elseif x1 > x2r then
			x3 = x3 * .3 + x2r * .7
		end
	end

	local fx = SpawnPrefab(prefab, instigator)
	fx.Transform:SetPosition(x3, y_offset, z3)
	fx.Transform:SetRotation(dir or attacker:GetAngleToXZ(x2, z2))

	if target.components.coloradder ~= nil then
		fx.target_tint = params ~= nil and params.tint or fx.target_tint
		if fx.target_tint == nil then
			fx.target_tint = {1, 0.392, 0, 0} --Use the default red color for hits
		end
		fx.target = target
		fx:ListenForEvent("paused", OnPaused)
	end
	if hitstoplevel ~= nil and fx.components.hitstopper ~= nil then
		fx.components.hitstopper:PushHitStop(hitstoplevel)
	end

	if params ~= nil and params.fx_sound ~= nil then
		fx.SoundEmitter:PlaySound(params.fx_sound)
	end

	return fx
end

function SpawnPowerHitFx(prefab, attacker, target, x_offset, y_offset, hitstoplevel)
	if attacker.Network and target.Network then
		return TheNetEvent:FXHit(prefab, attacker.GUID, target.GUID, x_offset, y_offset, 0, hitstoplevel, true)
	else
		return HandleSpawnPowerHitFx(prefab, attacker, target, x_offset, y_offset, hitstoplevel)
	end
end

function HandleSpawnPowerHitFx(prefab, attacker, target, x_offset, y_offset, hitstoplevel)
	-- instigator is entity initiating the attack, but attacker is thing that
	-- actually attacked (projectile). They are often the same.
	local instigator = attacker.owner or attacker -- probably a player
	local pos = target:GetPosition()
	local fx = SpawnPrefab(prefab, instigator)

	-- possible option: place it at the center of the bounding box?
	-- local minx, miny, minz, maxx, maxy, maxz = target.entity:GetWorldAABB()
	-- pos.x = (minx + maxx) / 2
	-- pos.y = (miny + maxy) / 2

	-- TODO: target tint

	if x_offset ~= 0 then
		local facing = target.Transform:GetFacing()
		x_offset = x_offset * (facing == FACING_LEFT and 1 or -1)
	end
	fx.Transform:SetPosition(pos.x + x_offset, pos.y + y_offset, pos.z)

	if hitstoplevel ~= nil then
		fx.components.hitstopper:PushHitStop(hitstoplevel)
		if target.components.hitstopper ~= nil then
			target.components.hitstopper:PushHitStop(hitstoplevel)
		end
	end
	return fx
end

function SpawnHurtFx(attacker, target, x_offset, dir, hitstoplevel)
	local prefab = target.components.combat:GetHurtFx()
	if prefab ~= nil then
		return SpawnHitFx(prefab, attacker, target, x_offset, 0, dir, hitstoplevel) --TODO: if we want to y-offset  these HurtFx, must change all places they are called
	end
end

local function OnSetSpawnInstigator(inst, instigator)
	TheTrackers.DebugSpawnEffect(inst, instigator)
end

--------------------------------------------------------------------------

local function MakeFx(name, params)
	local build = params.build or name
	local assets =
	{
		Asset("ANIM", "anim/"..build..".zip"),
	}

	local function fn(prefabname)
		local inst = CreateEntity()
		inst:SetPrefabName(prefabname)

		inst.entity:AddTransform()
		inst.entity:AddAnimState()
		inst.entity:AddSoundEmitter()

		inst:AddTag("FX")
		inst:AddTag("NOCLICK")
		inst.persists = false

		inst.AnimState:SetBank(build)
		inst.AnimState:SetBuild(build)
		inst.AnimState:PlayAnimation((params.anim or "anim")..tostring(math.random(params.variations or 1)))
		inst.AnimState:SetFinalOffset(7)

		if params.lit then
			inst.AnimState:SetLightOverride(1)
		end

		if not params.randomflip then
			inst.Transform:SetTwoFaced()
		elseif math.random() < .5 then
			inst.AnimState:SetScale(-1, 1)
		end

		inst:AddComponent("hitstopper")

		inst:ListenForEvent("animover", inst.Remove)

		inst.OnSetSpawnInstigator = OnSetSpawnInstigator

		return inst
	end

	return Prefab(name, fn, assets)
end

local ret = {}
for name, params in pairs(FX) do
	ret[#ret + 1] = MakeFx(name, params)
end

-- KAJ: hacky, but returning table.unpack from a require will only return the first element and I need this list
function GetLegacyHitFX()
	return FX		
end

return table.unpack(ret)
