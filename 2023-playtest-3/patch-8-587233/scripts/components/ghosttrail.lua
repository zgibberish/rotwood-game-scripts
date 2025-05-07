local color = require "math.modules.color"

local GhostTrail = Class(function(self, inst)
	self.inst = inst
	self.inst:StartUpdatingComponent(self)
	self.ghosts = {}
	self.position_last_frame = nil
	self.ghostcount = 0
	self.createghostiterator = 0

	self.max_count = 0
	self.ticks_between_ghosts = 99999
	self.starting_alpha = 0
	self.multcolor = color.new(0.5, 1, 1, self.starting_alpha)
	self.addcolor = color.new(0/255, 100/255, 200/255, 255/255)
	self.facing = FACING_LEFT
	self.starting_scale = 0.9
	self.permanent = false
end)

-- settings is a table:
-- 	starting_alpha (defaults to 0.0)
--	ticks_between_ghosts (defaults to 99999)
--	max_count (defaults to max_count)
--	permanent (defaults to false)
--	starting_scale (defaults to 0.9)
--	multcolor (type = color) (defaults to color.new(0.5, 1, 1, self.starting_alpha))
--	addcolor (type = color) (defaults to color.new(0/255, 100/255, 200/255, 255/255))
function GhostTrail:Activate( settings )
	self.active = true

	self.position_last_frame = nil
	self.ghostcount = 0
	self.createghostiterator = 0

	self.max_count = settings and settings.max_count or 0
	self.ticks_between_ghosts = settings and settings.ticks_between_ghosts or 99999
	self.starting_alpha = settings and settings.starting_alpha or 0.0
	self.multcolor = settings and settings.multcolor or color.new(0.5, 1, 1, self.starting_alpha)
	self.addcolor = settings and settings.addcolor or color.new(0.0/255.0, 100.0/255.0, 200.0/255.0, 255.0/255.0)
	self.starting_scale = settings and settings.starting_scale or 0.9
	self.permanent = settings and settings.permanent or false
end

function GhostTrail:SetFacing(facing)
	self.facing = facing or FACING_LEFT
end

function GhostTrail:Deactivate()
	self.active = false
end

function GhostTrail:OnRemoveFromEntity()
	for ghost,_ in pairs(self.ghosts) do
		if ghost and ghost:IsValid() then
			ghost:Remove()
		end
		self.ghosts[ghost] = nil
	end
end

function GhostTrail:OnUpdate()
	if self.active and self.position_last_frame ~= nil then
		if self.createghostiterator % self.ticks_between_ghosts == 0 then
			if self.ghostcount <= self.max_count then
				local ghost = CreateEntity()
				ghost.prefabname = "spiked_ghost"
				ghost.entity:AddTransform()
				ghost.Transform:SetPosition(self.position_last_frame.x, self.position_last_frame.y, self.position_last_frame.z+0.1)

				ghost.entity:AddAnimState()
				ghost.AnimState:SetBank(self.inst.AnimState:GetBank())
				ghost.AnimState:SetBuild(self.inst.AnimState:GetBuild())
				ghost.AnimState:PlayAnimation(self.inst.AnimState:GetCurrentAnimationName())
				ghost.AnimState:SetFrame(self.inst.AnimState:GetCurrentAnimationFrame())
				ghost.AnimState:Pause()
				local scale = self.facing == FACING_LEFT and -self.starting_scale or self.starting_scale
				ghost.AnimState:SetScale(scale, math.abs(scale))
				ghost.AnimState:SetMultColor(self.multcolor.r, self.multcolor.g, self.multcolor.b, self.multcolor.a)
				ghost.AnimState:SetAddColor(self.addcolor.r, self.addcolor.g, self.addcolor.b, self.addcolor.a)

				if self.inst:HasTag("player") then
					-- Make the ghost clone the player's appearance
					ghost:AddComponent("charactercreator")
					ghost:AddComponent("inventory")
					ghost:AddComponent("equipmentdyer")
					ghost.components.charactercreator:OnLoad(self.inst.components.charactercreator:OnSave())
					ghost.components.inventory:OnLoad(self.inst.components.inventory:OnSave())

					local dye_data = self.inst.components.equipmentdyer:OnSave()
					if dye_data ~= nil then
						ghost.components.equipmentdyer:OnLoad(dye_data)
					end
				end

				self.ghosts[ghost] = true
				self.ghostcount = self.ghostcount + 1

				ghost:DoTaskInAnimFrames(2, function()
					if ghost ~= nil and ghost:IsValid() then
						ghost.AnimState:SetMultColor(self.multcolor.r, self.multcolor.g, self.multcolor.b, self.multcolor.a / 2)
						local scale = (self.facing == FACING_LEFT and -self.starting_scale or self.starting_scale) * 0.916666	-- Keeping the scale the same as in the sg_projectile_shotput
						ghost.AnimState:SetScale(scale, math.abs(scale))
					end
				end)
				ghost:DoTaskInAnimFrames(4, function()
					if ghost ~= nil and ghost:IsValid() then
						ghost.AnimState:SetMultColor(self.multcolor.r, self.multcolor.g, self.multcolor.b, self.multcolor.a / 4)
						local scale = (self.facing == FACING_LEFT and -self.starting_scale or self.starting_scale) * 0.888888	-- Keeping the scale the same as in the sg_projectile_shotput
						ghost.AnimState:SetScale(scale, math.abs(scale))
					end
				end)
				ghost:DoTaskInAnimFrames(5, function()
					if ghost ~= nil and ghost:IsValid() and not self.permanent then
						ghost:Remove()
						self.ghosts[ghost] = nil
					end
					self.ghostcount = self.ghostcount - 1
				end)
			end
		end
	end

	if self.inst:IsInLimbo() then
		self.position_last_frame = nil
	else
		self.position_last_frame = self.inst:GetPosition()
	end
	self.createghostiterator = self.createghostiterator + 1
end

-- TODO: Net Serialize/Deserialize?




function GhostTrail:OnNetSerialize()
	local e = self.inst.entity

	e:SerializeBoolean(self.active)

	if self.active then
		local maxc = math.clamp(self.max_count or 0, 0, 15)
		e:SerializeUInt(maxc, 4)

		local ticks = math.clamp(self.ticks_between_ghosts or 0, 0, 3)
		e:SerializeUInt(ticks, 2)

		e:SerializeDouble(self.starting_alpha, 6, 0.0, 1.0)

		local multcolor = self.multcolor or color.new(0.5, 1, 1, self.starting_alpha)
		e:SerializeDouble(multcolor.r, 8, 0.0, 1.0)
		e:SerializeDouble(multcolor.g, 8, 0.0, 1.0)
		e:SerializeDouble(multcolor.b, 8, 0.0, 1.0)
		e:SerializeDouble(multcolor.a, 8, 0.0, 1.0)

		local addcolor = self.addcolor or color.new(0.0/255.0, 100.0/255.0, 200.0/255.0, 255.0/255.0)
		e:SerializeDouble(addcolor.r, 8, 0.0, 1.0)
		e:SerializeDouble(addcolor.g, 8, 0.0, 1.0)
		e:SerializeDouble(addcolor.b, 8, 0.0, 1.0)
		e:SerializeDouble(addcolor.a, 8, 0.0, 1.0)

		e:SerializeDouble(self.starting_scale or 0.9, 8, 0.0, 1.0)

		e:SerializeBoolean(self.permanent or false)
		e:SerializeBoolean(self.facing and self.facing == FACING_RIGHT or false)
	end
end

function GhostTrail:OnNetDeserialize()
	local e = self.inst.entity

	if e:DeserializeBoolean() then
		if not self.active then		-- or different settings?
			self:Activate({})	-- Activate with default settings and overwrite:
		end

		-- read the settings
		self.max_count = e:DeserializeUInt(4) or 0
		self.ticks_between_ghosts = e:DeserializeUInt(2) or 0
		self.starting_alpha = e:DeserializeDouble(6, 0.0, 1.0) or 0.9

		self.multcolor.r = e:DeserializeDouble(8, 0.0, 1.0) or 0.5
		self.multcolor.g = e:DeserializeDouble(8, 0.0, 1.0) or 1.0
		self.multcolor.b = e:DeserializeDouble(8, 0.0, 1.0) or 1.0
		self.multcolor.a = e:DeserializeDouble(8, 0.0, 1.0) or 0.9

		self.addcolor.r = e:DeserializeDouble(8, 0.0, 1.0) or 0
		self.addcolor.g = e:DeserializeDouble(8, 0.0, 1.0) or 100.0/255.0
		self.addcolor.b = e:DeserializeDouble(8, 0.0, 1.0) or 200.0/255.0
		self.addcolor.a = e:DeserializeDouble(8, 0.0, 1.0) or 255.0/255.0

		self.starting_scale = e:DeserializeDouble(8, 0.0, 1.0) or 0.9
		self.permanent = e:DeserializeBoolean() or false
		self.facing = e:DeserializeBoolean() and FACING_RIGHT or FACING_LEFT
	else
		if self.active then
			self:Deactivate()
		end
	end

end

function GhostTrail:OnEntityBecameLocal()
	self:OnRemoveFromEntity()
end



return GhostTrail
