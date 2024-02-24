local EffectEvents = require "effectevents"

HitPriority = table.invert(table.reverse({
	--Order from highest to lowest priority
	"BOSS_DEFAULT",
	"MOB_DEFAULT",
	"PLAYER_DEFAULT",
	--
	"BOSS_PROJECTILE",
	"MOB_PROJECTILE",
	"PLAYER_PROJECTILE",
}))

HitGroup =
{
	PLAYER =	0x01,
	NPC =		0x02,
	MOB =		0x04,
	BOSS =		0x08,
	NEUTRAL =	0x10,
	RESOURCE =	0x20,
	--
	NONE =		0x00,
	EVERYTHING =0xFF,
}

HitGroup.CREATURES	= HitGroup.MOB
					| HitGroup.BOSS
					| HitGroup.NEUTRAL

HitGroup.CHARACTERS	= HitGroup.PLAYER
					| HitGroup.NPC
					| HitGroup.NEUTRAL

HitGroup.HOSTILES	= HitGroup.MOB
					| HitGroup.BOSS

HitGroup.ALL 		= HitGroup.MOB
					| HitGroup.BOSS
					| HitGroup.NEUTRAL
					| HitGroup.PLAYER
					| HitGroup.NPC
--------------------------------------------------------------------------
--Queue hits until post update so we can process them globally by priority.

local HitBoxQueue = Class(function(self)
	self.queue = {}
	self.swapqueue = {}
	self.guid = 0

	-- bidirectional hitbox name, function lookup tables
	self.fntoname = {}
	self.nametofn = {}
end)

HitBoxManager = HitBoxQueue()

function HitBoxQueue:GetNextGUID()
	self.guid = self.guid + 1
	return self.guid
end

function HitBoxQueue:PushHitBox(params)
	self.queue[#self.queue + 1] = params
end

local function SortByPriority(a, b)
	return a[#a] > b[#b]
end

function HitBoxQueue:PostUpdate()
	local temp = self.queue
	self.queue = self.swapqueue
	self.swapqueue = temp

	table.sort(temp, SortByPriority)

	for i = 1, #temp do
		local v = temp[i]
		temp[i] = nil

		local hitbox = v[1]
		local inst = hitbox.inst
		dbassert(inst == nil or inst.components.hitbox == hitbox)

		local n = #v
		if inst and inst:IsValid() and
			(inst.sg == nil or inst.sg.statemem[v[n - 1]] or not inst:IsLocalOrMinimal()) then
			--pop triggerfn, guid, and priority from the params
			local triggerfn = v[n - 2]
			local guid = v[n - 1]
			v[n - 2] = nil --triggerfn
			v[n - 1] = nil --guid
			v[n] = nil --priority

			local ents = triggerfn(table.unpack(v))
			if ents ~= nil then
				for x = #ents, 1, -1 do
					if ents[x] ~= nil then
						if ents[x].HitBox:IsInvincible() and not hitbox:IsUtilityHitbox() then -- Utility hitboxes don't care about invincibility
							EffectEvents.MakeNetEventPushHitBoxInvincibleEventOnEntity(hitbox.inst, ents[x])
							-- TheLog.ch.HitBox:printf("[%d] HitBoxQueue:PostUpdate hitbox removed ent %d because invincible", GetTick(), ents[x].GUID)
							table.remove(ents, x)-- do not include this entity in the list of things that were hit
						end
					end
				end
				if #ents > 0 then
					-- TheLog.ch.HitBox:printf("[%d] HitBoxQueue:PostUpdate entity GUID %d (%s) hitboxtriggered with %d entities", GetTick(), inst.GUID, inst.prefab, #ents)
					inst:PushEvent("hitboxtriggered", {
						targets = ents,
						hitbox = {
							triggerfnname = self:LookupFunctionName(triggerfn),
							params = v,
							-- is_utility = hitbox:IsUtilityHitBox(), -- TODO: handle utility hitboxes remotely?
						}
					})
				-- else
					-- TheLog.ch.HitBox:printf("[%d] HitBoxQueue:PostUpdate hitboxtriggered ignored because there are 0 entities that colllided", GetTick())
				end
			end

			if inst.sg ~= nil and inst.sg.statemem[guid] then
				inst.sg.statemem[guid] = nil
			end
		end
	end
end

function HitBoxQueue:AddFunctionLookup(fn, fn_name)
	assert(type(fn) == "function")
	assert(type(fn_name) == "string")
	assert(self.fntoname[fn] == nil)
	assert(self.nametofn[fn_name] == nil)
	self.fntoname[fn] = fn_name
	self.nametofn[fn_name] = fn
end

function HitBoxQueue:LookupFunctionName(fn)
	assert(type(fn) == "function")
	assert(self.fntoname[fn])
	return self.fntoname[fn]
end

function HitBoxQueue:LookupFunction(fn_name)
	assert(type(fn_name) == "string")
	return self.nametofn[fn_name]
end

--------------------------------------------------------------------------
local MaxDelayTicksNrBits = 10
local MaxDelayTicks = (1 << MaxDelayTicksNrBits) - 1

local HitBox = Class(function(self, inst)
	self.inst = inst
	self.snaptofacing = true
	self.padsize = 6 --pad search area so we can detect an entity's physics bounds even when its center is OOR
	self.delay = nil
	self.utilityhitbox = false

	-- because we do remote hit confirmation, this data should not be synced
	self.ignores = {} --k: ent inst, v: ticks to ignore subsequent triggers with this entity
end)

function HitBox:OnNetSerialize()
	local e = self.inst.entity
	e:SerializeUInt(self.delay and math.min(self.delay, MaxDelayTicks) or 0, MaxDelayTicksNrBits)
end

function HitBox:OnNetDeserialize()
	local e = self.inst.entity
	local old_delay = self.delay
	local new_delay = e:DeserializeUInt(MaxDelayTicksNrBits)
	new_delay = new_delay > 0 and (new_delay < MaxDelayTicks and new_delay or math.huge) or nil

	if not new_delay then
		self:StopRepeatTargetDelay()
	elseif new_delay ~= old_delay then
		self:StartRepeatTargetDelayTicks(new_delay)
	end
end

function HitBox:OnRemoveFromEntity()
	self.inst = nil
end

function HitBox:SetSnapToFacing(snap)
	self.snaptofacing = snap
end

function HitBox:SetPadSize(size)
	self.padsize = size
end

function HitBox:SetUtilityHitbox(toggle)
	self.utilityhitbox = toggle
end
function HitBox:IsUtilityHitbox()
	return self.utilityhitbox == true
end

function HitBox:CalculateRotation()
	return self.snaptofacing and self.inst.Transform:GetFacingRotation() or self.inst.Transform:GetRotation()
end

function HitBox:StartRepeatTargetDelay(time)
	self:StartRepeatTargetDelayTicks(time ~= nil and math.ceil(time * SECONDS) or nil)
end

function HitBox:StartRepeatTargetDelayTicks(ticks)
	dbassert(ticks == nil or ticks > 0)
	self.delay = ticks or math.huge
end

function HitBox:StartRepeatTargetDelayAnimFrames(animframes)
	self:StartRepeatTargetDelayTicks(animframes * ANIM_FRAMES)
end

function HitBox:StopRepeatTargetDelay()
	if self.delay ~= nil then
		self.delay = nil
		for k in pairs(self.ignores) do
			self.ignores[k] = nil
		end
	end
end

function HitBox:CopyRepeatTargetDelays(other)
	self.delay = other.components.hitbox.delay
	for k, v in pairs(other.components.hitbox.ignores) do
		self.ignores[k] = v
	end
end

function HitBox:IgnorePass(ents)
	if ents == nil then
		return
	end

	local tick = self.delay ~= nil and GetTick() or nil
	local j = 1
	for i = 1, #ents do
		local v = ents[i]
		local keep = v ~= self.inst
		if keep and tick ~= nil then
			local ignoretick = self.ignores[v]
			if ignoretick ~= nil and ignoretick > tick then
				keep = false
			else
				self.ignores[v] = tick + self.delay
			end
		end

		if v == self.temp_allow_entity then	-- Horrible hack to be able to check if this hitbox would hit an entity that is in the ignore list. Needed for networked projectiles. 
			keep = true
		end

		if keep then
			if j < i then
				ents[j] = v
				ents[i] = nil
			end
			j = j + 1
		else
			ents[i] = nil
		end
	end
	return #ents > 0 and ents or nil
end

function HitBox:TriggerCircle(dist, rot, radius, zoffset, origin_ent)
	zoffset = zoffset or 0
	origin_ent = origin_ent or self.inst
	local scale = origin_ent.Transform:GetScale()

	dist = dist * scale
	radius = radius * scale
	zoffset = zoffset * scale

	local x, z = origin_ent.Transform:GetWorldXZ()
	if dist ~= 0 then
		rot = math.rad(rot + self:CalculateRotation())
		x = x + dist * math.cos(rot)
		z = z - dist * math.sin(rot)
	end
	local ents = self.inst.HitBox:FindHitBoxesInCircle(x, zoffset + z, radius, self.padsize)
	return self:IgnorePass(ents)
end

function HitBox:TriggerBeam(startdist, enddist, thickness, zoffset, origin_ent)
	zoffset = zoffset or 0
	origin_ent = origin_ent or self.inst
	local scale = origin_ent.Transform:GetScale()

	startdist = startdist * scale
	enddist = enddist * scale
	thickness = thickness * scale
	zoffset = zoffset * scale

	local facing = self.inst.Transform:GetFacing()
	-- Now supports up to four-faced entities

	if facing == FACING_LEFT then
		startdist = -startdist
		enddist = -enddist
	elseif facing == FACING_UP or facing == FACING_DOWN then
		local startdist_new = -thickness
		local enddist_new = thickness
		local thickness_new = enddist
		local zoffset_new = startdist + enddist * (facing == FACING_DOWN and -1 or 1)

		startdist = startdist_new
		enddist = enddist_new
		thickness = thickness_new
		zoffset = zoffset_new
	end

	local x, z = origin_ent.Transform:GetWorldXZ()
	local ents = self.inst.HitBox:FindHitBoxesInRect(x + startdist, zoffset + z - thickness, x + enddist, zoffset + z + thickness, self.padsize)
	return self:IgnorePass(ents)
end

--------------------------------------------------------------------------
--Push functions take identical params as their corresponding trigger
--functions, with an additional `priority` param at the end.

local function MakePushFn(triggerfn)
	local fn = function(...)
		local params = { ... }
		--NOTE: params[1] is self
		local inst = params[1].inst
		local guid = "_hitbox_"..tostring(HitBoxManager:GetNextGUID())
		if inst.sg ~= nil then
			--Used to check if we're still in the same state when actually triggering the hit
			inst.sg.statemem[guid] = true
		end

		--insert triggerfn and guid b4 priority
		local n = #params
		params[n + 2] = params[n] --priority
		params[n + 1] = guid
		params[n] = triggerfn

		-- params as submitted to the HitBoxManager (i.e. HitBoxQueue):
		-- 1: table, HitBoxComponent instance
		-- 2~n: params (variable count, mostly numbers)
		-- n+1: function, triggerfn (i.e. TriggerBeam, TriggerCircle, etc.)
		-- n+2: string, hitbox GUID (i.e. "_hitbox_1")
		-- n+3: integer, priority
		HitBoxManager:PushHitBox(params)
	end

	return fn
end

HitBox.PushCircle = MakePushFn(HitBox.TriggerCircle)
HitBox.PushBeam = MakePushFn(HitBox.TriggerBeam)

HitBox.PushOffsetCircle = MakePushFn(HitBox.TriggerCircle)
HitBox.PushOffsetBeam = MakePushFn(HitBox.TriggerBeam)

HitBox.PushCircleFromChild = MakePushFn(HitBox.TriggerCircle)
HitBox.PushOffsetCircleFromChild = MakePushFn(HitBox.TriggerCircle)

HitBox.PushOffsetBeamFromChild = MakePushFn(HitBox.TriggerBeam)

HitBoxManager:AddFunctionLookup(HitBox.TriggerCircle, "TriggerCircle")
HitBoxManager:AddFunctionLookup(HitBox.TriggerBeam, "TriggerBeam")
--------------------------------------------------------------------------

function HitBox:SetHitGroup(group)
	self.inst.HitBox:SetHitGroup(group)
end

function HitBox:GetHitGroup()
	return self.inst.HitBox:GetHitGroup()
end

function HitBox:SetHitFlags(flags)
	self.inst.HitBox:SetHitFlags(flags)
end

function HitBox:GetHitFlags()
	return self.inst.HitBox:GetHitFlags()
end

function HitBox:AddHitFlag(flag)
	self.inst.HitBox:SetHitFlags(self.inst.HitBox:GetHitFlags() | flag)
end

function HitBox:RemoveHitFlag(flag)
	self.inst.HitBox:SetHitFlags(self.inst.HitBox:GetHitFlags() & ~flag)
end

--------------------------------------------------------------------------

return HitBox
