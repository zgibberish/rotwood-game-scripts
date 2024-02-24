local SporemonBouncer = Class(function(self, inst)
	self.inst = inst
    self.current_target = nil -- just one target at a time for testing, should be updated to support multiple targets
    self.bounce_timer = 0
    self.scale_timer = -1
    self.direction = Vector3.zero
    self.starting_scale = Vector3.one
	self.inst:StartUpdatingComponent(self)
end)

local bounce_magnitude = 18
local scale_magnitude = 1.4
local bounce_length = 0.266
local scale_length = 0.166

function SporemonBouncer:OnUpdate(dt)
    if (self.current_target) then
        if (self.bounce_timer > 0) then
            local direction = Vector3.lerp(Vector3.zero, self.direction, self.bounce_timer / bounce_length)
            self.current_target.components.pushforce:AddPushForce("bounced", self.inst, direction, true)
            self.bounce_timer = self.bounce_timer - dt
        else
            self.current_target.components.pushforce:RemovePushForce("bounced", self.inst, true)
            self.current_target = nil
        end
        --self.current_target.components.pushforce:UpdatePushForce()
    else
        local sporemon_pos = Vector3(self.inst.Transform:GetWorldPosition())
        for k, player in pairs(AllPlayers) do
            if (player:IsAlive() and player:IsLocal()) then
                local player_pos = Vector3(player.Transform:GetWorldPosition())
                local distance = Vector3.dist(sporemon_pos, player_pos)
                if (distance < 2) then -- might want to just make this the physics size
                    self.direction = player_pos - sporemon_pos
                    self.direction = self.direction * bounce_magnitude

                    self.starting_scale = Vector3(self.inst.Transform:GetScale())
                    self.current_target = player
                    self.bounce_timer = bounce_length
                    self.scale_timer = scale_length
                    break
                end
            end
        end
    end

    -- Scale the owning entity to visualize the bounce
    if (self.scale_timer > 0) then
        local max_scale = self.starting_scale * Vector3(scale_magnitude, 1, scale_magnitude)
        local scale = Vector3.lerp(self.starting_scale, max_scale, self.scale_timer / scale_length)
        self.inst.Transform:SetScale(scale.x, scale.y, scale.z)
        self.scale_timer = math.max(self.scale_timer - dt, 0)
    elseif (self.scale_timer == 0) then
        self.inst.Transform:SetScale(self.starting_scale.x, self.starting_scale.y, self.starting_scale.z)
        self.scale_timer = -1
    end
end

return SporemonBouncer