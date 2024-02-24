local soundutil = require "util.soundutil"
local fmodtable = require "defs.sound.fmodtable"

local GroundTargetWarning = Class(function(self, inst)
	self.inst = inst
	self.warning_sounddata = nil
	self.inst:StartUpdatingComponent(self)
end)

local function IsPointInAABB(pointx, pointy, pointz, xmin, ymin, zmin, xmax, ymax, zmax)
	return (pointx >= xmin and pointx <= xmax) and (pointy >= ymin and pointy <= ymax) and (pointz >= zmin and pointz <= zmax)
end

function GroundTargetWarning:IsAPlayerInTheTarget(circle, projectile)
	local is_player_in_trap = false
	local projectile_distance_to_player = 0
	for k, player in pairs(AllPlayers) do
		if (player:IsAlive() and player:IsLocal() and not player.HitBox:IsInvincible()) then
			local x, y, z = player.Transform:GetWorldPosition()
			local in_bounds = IsPointInAABB(x, y, z, circle.entity:GetWorldAABB())
			if (in_bounds) then
				is_player_in_trap = true
				if (projectile) then
					projectile_distance_to_player = projectile:GetDistanceSqTo(player) / 10
				end
				break
			end
		end
	end
	return is_player_in_trap, projectile_distance_to_player
end

function GroundTargetWarning:OnUpdate()
	if (not self.warning_sounddata) then
		local params = {}
		params.fmodevent = self.inst.warning_sound or fmodtable.Event.sporemon_projectile_warning
		params.sound_max_count = 1
		self.warning_sounddata = soundutil.PlayLocalSoundData(self.inst, params)
	else
		local is_local_player_in_trap, projectile_distance_to_player = self:IsAPlayerInTheTarget(self.inst, self.inst.owner)
		if (is_local_player_in_trap) then
			--sound
			soundutil.SetLocalInstanceParameter(self.inst, self.warning_sounddata, "isLocalPlayerInTrap", 1)
			soundutil.SetLocalInstanceParameter(self.inst, self.warning_sounddata, "distanceToNearestPlayer", projectile_distance_to_player)
		else
			soundutil.SetLocalInstanceParameter(self.inst, self.warning_sounddata, "isLocalPlayerInTrap", 0)
		end
	end
end

return GroundTargetWarning
