local fmodtable = require "defs.sound.fmodtable"
local spawnutil = require "util.spawnutil"
require "constants"
require "mathutil"
local prefabutil = require "prefabs.prefabutil"

----------------------------------

local lume = require "util.lume"

local ParticlesAutogenData = require "prefabs.particles_autogen_data"
local ParticleSystem

local ParticleEmitter = Class(function(self, system)
	--ParticleEmitter._base.init(self)
	local inst = CreateEntity()
	if system.inst:HasTag("survives_room_travel") then
		inst:MakeSurviveRoomTravel()
	end
	self.inst = inst

	if system.inst.Transform then
		self.world_space = true
		self.transform = system.inst.Transform
		inst.entity:AddTransform()
	else
		self.transform = system.inst.UITransform
		inst.entity:AddUITransform()
	end
	inst.entity:AddParticleEmitter()

	inst.entity:SetParent(system.inst.entity)

	inst:AddTag("FX")
end)


function ParticleEmitter:OnVizChange(viz)
	--    if viz then
	--        self:StartUpdating()
	--    else
	--        self:StopUpdating()
	--    end
end

function ParticleEmitter:MarkDirty(node)
	-- We need to referesh params whenever we change anything.
	self:SetParams(self.params)
	if node.SetDirty then
		-- Is editing from a proper editor and not just inspecting in a
		-- DebugPanel.
		node:SetDirty()
	end
end

function ParticleEmitter:SetParams(params, forceApplyDefaults)
	forceApplyDefaults = forceApplyDefaults or false
	self.inst.ParticleEmitter:SetEffect((params.erode_bias or 0) > 0 and global_shaders.FX_ERODE or global_shaders.FX)
	self.inst.ParticleEmitter:SetRimEffect((params.erode_bias or 0) > 0 and global_shaders.FX_ERODE_RIM or global_shaders.FX_RIM)
	--self.renderer.model:SetEffect(global_shaders.FX_ERODE)
	self.params = params
	self.reference_params = deepcopy(params)
	self:SetPos(params.x or 0, params.y or 0, params.z or 0)
	--TODO_KAJ this should probably go to the particle system as it's on another axis
	self:SetRotation(params.r or 0)

	self.inst.ParticleEmitter:SetUseLocalReferenceFrame(params.use_local_ref_frame or false)
	self.inst.ParticleEmitter:SetGroundProjected(params.ground_projected or false)

	if params.texture then
		local atlas, region
		if type(params.texture) == "table" then
			atlas, region = table.unpack(params.texture)
		else
			atlas = params.texture
		end
		if self.texture_name ~= atlas or self.region_name ~= region then
			self.texture_name = atlas
			self.region_name = region
			self.inst.ParticleEmitter:SetTexture("images/"..atlas, region)
		end
	end

	--if params.emit_world_space then
	--end

	self.inst.ParticleEmitter:SetMaxParticles(params.max_particles)
	self.inst.ParticleEmitter:SetEmissionRate(params.emit_rate)

	--ParticleEmitter bounds not supported
	--[[if params.xbounds then
		self.inst.ParticleEmitter:SetXBounds(table.unpack(params.xbounds))
	else
		self.inst.ParticleEmitter:SetXBounds()
	end

	if params.ybounds then
		self.inst.ParticleEmitter:SetYBounds(table.unpack(params.ybounds))
	else
		self.inst.ParticleEmitter:SetYBounds()
	end

	if params.zbounds then
		self.inst.ParticleEmitter:SetZBounds(table.unpack(params.zbounds))
	else
		self.inst.ParticleEmitter:SetZBounds()
	end]]

	if params.lod then
		self.inst.ParticleEmitter:SetLevelOfDetail(params.lod)
	else
		self.inst.ParticleEmitter:SetLevelOfDetail(0xFF)
	end

	if params.spawn.box or forceApplyDefaults then
		self.inst.ParticleEmitter:SetSpawnAABB( table.unpack( params.spawn.box or ParticleSystem.default_params.spawn.box ) )
	end
	if params.spawn.random_position or forceApplyDefaults  then
		self.inst.ParticleEmitter:SetSpawnPositionRandomness(params.spawn.random_position or 0)
	end
	if params.spawn.shape_alignment or forceApplyDefaults then
		self.inst.ParticleEmitter:SetSpawnAlignDirectionAmount(params.spawn.shape_alignment or 0)
	end

	if params.spawn.emit_on_grid then
		self.inst.ParticleEmitter:SetSpawnOnGrid( true, self.params.spawn.emit_grid_rows or 1, self.params.spawn.emit_grid_colums or 1)
	else
		self.inst.ParticleEmitter:SetSpawnOnGrid( false )
	end

	if params.spawn.vel or forceApplyDefaults then
		self.inst.ParticleEmitter:SetSpawnVel( table.unpack( params.spawn.vel or ParticleSystem.default_params.spawn.vel ) )
	end

	--[[    -- that doesn't exist
	if params.spawn.circvel then
		self.inst.ParticleEmitter:SetSpawnCircVel( table.unpack( params.spawn.circvel ) )
	end
	]]

	if params.spawn.size or forceApplyDefaults then
		self.inst.ParticleEmitter:SetSpawnSize( table.unpack( params.spawn.size or ParticleSystem.default_params.size ) )
	end

	if params.spawn.rot or forceApplyDefaults then
		self.inst.ParticleEmitter:SetSpawnRot( table.unpack( params.spawn.rot or {0,0} ) )
	end

	if params.spawn.rotvel or forceApplyDefaults then
		self.inst.ParticleEmitter:SetSpawnRotVel( table.unpack( params.spawn.rotvel or {0,0} ) )
	end

	if params.spawn.ttl or forceApplyDefaults then
		self.inst.ParticleEmitter:SetSpawnTTL( table.unpack( params.spawn.ttl or ParticleSystem.default_params.spawn.ttl ) )
	end
	if params.spawn.color or forceApplyDefaults then
		self.inst.ParticleEmitter:SetSpawnColor( HexToRGBFloats( params.spawn.color or ParticleSystem.default_params.color ) )
	end

	if params.spawn.aspect or forceApplyDefaults then
		self.inst.ParticleEmitter:SetSpawnAspect( params.spawn.aspect or 1 )
	end

	if params.spawn.positionMode or forceApplyDefaults then
		self.inst.ParticleEmitter:SetSpawnPositionMode( params.spawn.positionMode or 0 )
	end

	if params.spawn.fps or forceApplyDefaults then
		self.inst.ParticleEmitter:SetFrameRate( params.spawn.fps or 30 )
	end

	if params.spawn.shape or forceApplyDefaults then
		self.inst.ParticleEmitter:SetSpawnShape( params.spawn.shape or 0 )
		if params.spawn.shape == 1 then
			self.inst.ParticleEmitter:SetSpawnArc( params.spawn.emit_arc_vel or 0, params.spawn.emit_arc_phase or 0, params.spawn.emit_arc_min or 0, params.spawn.emit_arc_max or 360, params.spawn.emit_arc_applied_vel_scale or 0 )
		end
	end

	local t = {}
	if params.curves.color and params.curves.color.num then
		if not params.curves.color.time or #params.curves.color.time < params.curves.color.num then
			local time = {}
			local range = math.max(1, params.curves.color.num - 1)
			for k = 1, params.curves.color.num do
				local k_z = k - 1
				table.insert(time, k_z/range)
			end
			params.curves.color.time = time
		end
		for k = 1, params.curves.color.num do
			table.insert(t, params.curves.color.time[k])
			local r,g,b,a = HexToRGBFloats(params.curves.color.data and params.curves.color.data[k] or 0xffffffff)
			table.insert(t, r)
			table.insert(t, g)
			table.insert(t, b)
			table.insert(t, a)
		end
	end
	self.inst.ParticleEmitter:SetCurveColorOverTime(table.unpack(t))

	if params.curves and params.curves.scale and params.curves.scale.enabled then
		self.inst.ParticleEmitter:SetCurveScaleMinMax(params.curves.scale.min or 0, params.curves.scale.max or 1)
		self.inst.ParticleEmitter:SetCurveScaleOverTime(table.unpack(params.curves.scale.data))
	else
		self.inst.ParticleEmitter:SetCurveScaleOverTime()
	end

	if params.curves and params.curves.velocityAspect and params.curves.velocityAspect.enabled then
		self.inst.ParticleEmitter:SetCurveAspectOverVelocityMinMax(params.curves.velocityAspect.min or 0, params.curves.velocityAspect.max or 1)
		self.inst.ParticleEmitter:SetCurveAspectOverVelocity(table.unpack(params.curves.velocityAspect.data))
		self.inst.ParticleEmitter:SetCurveAspectOverVelocitySpeedMax(params.curves.velocityAspect.speedMax or 10)
		self.inst.ParticleEmitter:SetCurveAspectOverVelocityRotationFactor(params.curves.velocityAspect.factor or 1)
	else
		self.inst.ParticleEmitter:SetCurveAspectOverVelocity()
	end

	if self.world_space and (params.spawn.layer or forceApplyDefaults) then
		self.inst.ParticleEmitter:SetLayer(params.spawn.layer or LAYER_WORLD)
		self.inst.ParticleEmitter:SetSortOrder(params.spawn.sort_order or 0)
	end

	if params.blendmode or forceApplyDefaults then
		self.inst.ParticleEmitter:SetBlendMode(params.blendmode or ParticleSystem.default_params.blendmode)
	end

	if params.bloom or forceApplyDefaults then
		self.inst.ParticleEmitter:SetBloom(params.bloom or ParticleSystem.default_params.bloom)
	end

	if params.velocity_inherit or forceApplyDefaults then
		self.inst.ParticleEmitter:SetVelocityInherit(params.velocity_inherit or 0)
	end

	self.inst.ParticleEmitter:SetFriction(self.params.friction_min or 0, self.params.friction_max or 0)

	if params.curves.emission_rate and params.curves.emission_rate.enabled then
		self.inst.ParticleEmitter:SetCurveEmissionRate(table.unpack(self.params.curves.emission_rate.data))
		self.inst.ParticleEmitter:SetEmissionRateLoop(self.params.emission_rate_time, (self.params.emission_rate_loops == true) and true or false)
	else
		self.inst.ParticleEmitter:SetCurveEmissionRate()
	end

	if forceApplyDefaults or (params.gravity_x and params.gravity_y and params.gravity_z) then
		self.inst.ParticleEmitter:SetGravity(params.gravity_x or 0, params.gravity_y or 0, params.gravity_z or 0)
	end

	if params.use_bounce then
		self.inst.ParticleEmitter:SetBounceParameters(true, params.bounce_coeff or 1.0, params.bounce_height or 0.0)
	else
		self.inst.ParticleEmitter:SetBounceParameters(false, -1.0, 0.0)
	end

	self.inst.ParticleEmitter:SetBurst(params.burst_amt or 0, params.burst_time or 0)

	-- TODO_KAJ may want to move this to scenenode instead.
	self.inst.ParticleEmitter:SetErodeBias(params.erode_bias or 1)

	if params.bake_time or forceApplyDefaults then
		self.inst.ParticleEmitter:Update(params.bake_time or 0)
	end

	return self
end

function ParticleEmitter:SetLightOverride(value)
	self.inst.ParticleEmitter:SetLightOverride(value)
	return self
end

function ParticleEmitter:SetBloom(b)
	self.inst.ParticleEmitter:SetBloom(b)
	return self
end

-- Pass a mode id: SetBlendMode(BlendMode.id.Additive)
function ParticleEmitter:SetBlendMode(b)
	self.inst.ParticleEmitter:SetBlendMode(b)
	return self
end

function ParticleEmitter:SetLayer(value)
	self.inst.ParticleEmitter:SetLayer(value)
	return self
end

function ParticleEmitter:SetSortOrder(b)
	self.inst.ParticleEmitter:SetSortOrder(b)
	return self
end

function ParticleEmitter:SetFinalOffset(b)
	self.inst.ParticleEmitter:SetFinalOffset(b)
	return self
end

function ParticleEmitter:SetDeltaTimeMultiplier(mult)
	self.inst.ParticleEmitter:SetDeltaTimeMultiplier(mult)
	return self
end

function ParticleEmitter:SetLevelOfDetail(lod)
	self.inst.ParticleEmitter:SetLevelOfDetail(lod)
	return self
end

function ParticleEmitter:SetManualMode(val)
	self.manual_mode = val
end

function ParticleEmitter:UpdateSystem(dt)
	local x, y = self:GetWorldPos()
	local vx = self.old_x and (x - self.old_x)/dt or 0
	local vy = self.old_y and (y - self.old_y)/dt or 0
	--print (vx, vy)
	self.old_x, self.old_y = x, y

	if self.renderer.model then
		self.renderer.model:SetEmitterVelocity(vx, vy, 0)
		self.renderer.model:Update(dt)
	end
end

function ParticleEmitter:OnUpdate(dt)
	ParticleEmitter._base.OnUpdate(self, dt)
	if not self.manual_mode then
		self:UpdateSystem(dt)
	end
end

function ParticleEmitter:SetTexture(atlas, region)
	self.inst.ParticleEmitter:SetTexture(atlas, region)
	return self
end


local function ValidateParams(params)
	params.emission_rate_time = params.emission_rate_time or 5
	params.curves = params.curves or {}

	params.curves.color = params.curves.color or {}
	params.curves.color.num = params.curves.color.num or 0
	params.curves.color.data = params.curves.color.data or {}
	params.curves.color.time = params.curves.color.time or {}

	params.curves.scale = params.curves.scale or {enabled = false}
	params.curves.scale.data = params.curves.scale.data or CreateCurve()

	params.curves.emission_rate = params.curves.emission_rate or {enabled = false}
	params.curves.emission_rate.data = params.curves.emission_rate.data or CreateCurve()

	params.curves.velocityAspect = params.curves.velocityAspect or {enabled = false}
	params.curves.velocityAspect.data = params.curves.velocityAspect.data or CreateCurve()
end

function ParticleEmitter:Reset()
	self.inst.ParticleEmitter:Reset()

	if self.params.bake_time then
		self.inst.ParticleEmitter:Update(self.params.bake_time)
	end

end

function ParticleEmitter:GetPos()
	if self.inst.UITransform then
		local x, y, z = self.inst.UITransform:GetLocalPosition()
		return x,y, 0
	else
		local x, y, z = self.inst.Transform:GetLocalPosition()
		return x,y,z
	end
end

function ParticleEmitter:SetPos(x,y,z)
	if self.inst.UITransform then
		self.inst.UITransform:SetPosition(x,y)
	else
		self.inst.Transform:SetPosition(x,y,z)
	end
end

function ParticleEmitter:SetShown(shown)
	self.inst.ParticleEmitter:SetShown(shown)
end

function ParticleEmitter:IsShown()
	return self.inst.ParticleEmitter:IsShown()
end

-- return value is in degrees
function ParticleEmitter:GetRotation()
	if self.inst.UITransform then
		return self.inst.UITransform:GetRotation()
	else
		return self.inst.ParticleEmitter:GetWorldEmitterRotation()
	end
end

-- angle is in degrees
function ParticleEmitter:SetRotation(angle)
	if self.inst.UITransform then
		self.inst.UITransform:SetRotation(angle)
	else
		self.inst.ParticleEmitter:SetWorldEmitterRotation(angle)
	end
end

function ParticleEmitter:Remove()
	self.inst:Remove()
end

function ParticleEmitter:SetName(name)
	self.params.name = name
end

function ParticleEmitter:GetName()
	return self.params.name
end

function ParticleEmitter:IsDone(ignoreLooping)
	ignoreLooping = ignoreLooping or false
	return self.inst.ParticleEmitter:IsDone(ignoreLooping)
end

function ParticleEmitter:Stop()
	self.inst.ParticleEmitter:SetEmissionRate(0)
end

function ParticleEmitter:IsStopped()
	return self.inst.ParticleEmitter:GetEmissionRate() == 0
end

function ParticleEmitter:Restart()
	self.inst.ParticleEmitter:SetEmissionRate(self.params.emit_rate * (self.params.emit_rate_mult or 1))
end

function ParticleEmitter:SetEmitRateMult(mult)
	self.params.emit_rate_mult = mult
	self.inst.ParticleEmitter:SetEmissionRate(self.params.emit_rate * (self.params.emit_rate_mult or 1))
end

function ParticleEmitter:SetScaleMult(mult)
	self.params.scalemult = mult
	self.inst.ParticleEmitter:SetScaleMult(self.params.scalemult)
end

function ParticleEmitter:GetBurstAmount()
	return self.params.burst_amt
end
function ParticleEmitter:GetBurstTime()
	return self.params.burst_time
end

function ParticleEmitter:SetupBurstOnce(amount, time)
	self.inst.ParticleEmitter:SetBurst(amount or 0, time or 0)
end

function ParticleEmitter:SetEmitterBounds(x,y,w,h)
	local x1, x2 = x - w/2, x + w/2
	local y1, y2 = y - h/2, y + h/2
	self.params.spawn.box = {x1, x2, y1, y2}
	self.renderer.model:SetSpawnAABB( table.unpack( self.params.spawn.box ) )
	return self
end

function ParticleEmitter:SetEmitterSpawnOnGrid(enabled, rows, columns)
	self.renderer.model:SetSpawnOnGrid( enabled, rows, columns )
	return self
end

function ParticleEmitter:GetBoundingBox()
	local x1, x2, y1, y2 = table.unpack(self.params.spawn.box) -- For some reason the coords are stored X1, X2, and then Y1, Y2.. ?
	return x1, y1, x2, y2
end


--------------------------------------------------------------------------------------------

ParticleSystem = Class(function (self, inst)
	self.inst = inst
	self.emitters = {}
	inst.entity:AddSoundEmitter()

	inst:ListenForEvent("paused", function() inst.components.particlesystem:SetDeltaTimeMultiplier(0) end)
	inst:ListenForEvent("resumed", function() inst.components.particlesystem:SetDeltaTimeMultiplier(1) end)
end)

ParticleSystem.default_params =
{

	blendmode = BlendMode.id.AlphaBlended,
	bloom = 0,
	emit_rate = 4.0,
	--emit_world_space = true,
	max_particles = 100,
	curves = {},
	spawn = {
		box = { 0,0,0,0 },
		color = 0xffffff,
		size = {1,1},
		ttl = {4,4},
		vel = {0,0,10,10,0,0},
	},
	texture = {"particles.xml","bubble_2_256.tex"},
}

function ParticleSystem:OnParticleSystemChanged()
	--[[
--	if self.inst.Transform then -- TODO_KAJ this should become an editable and only on spawned 3 systems
		if self.data ~= nil then
			local x, y, z = self.inst.Transform:GetWorldPosition()
			x = lume.round(x, 0.01)
			y = lume.round(y, 0.01)
			z = lume.round(z, 0.01)
			self.inst.Transform:SetPosition(x, y, z)

			if (self.data.x or 0) ~= x then
				self.data.x = x ~= 0 and x or nil
				TheWorld.components.particlefx:SetDirty()
			end
			if (self.data.y or 0) ~= y then
				self.data.y = y ~= 0 and y or nil
				TheWorld.components.particlefx:SetDirty()
			end
			if (self.data.z or 0) ~= z then
				self.data.z = z ~= 0 and z or nil
				TheWorld.components.particlefx:SetDirty()
			end
			if not self.data.flip ~= not self.flip then
				self.data.flip = self.flip or nil
				TheWorld.components.particlefx:SetDirty()
			end
			if (self.data.param_id) ~= self.param_id then
				self.data.param_id = self.param_id
				TheWorld.components.particlefx:SetDirty()
			end
		else
			print("Warning: ParticleSystem will not be saved.")
		end
		self.inst:PushEvent("particlesystemchanged")
--	end
]]
end

function ParticleSystem:Reset()
	for k,v in ipairs(self.emitters) do
		v:Reset()
	end
end

-- There seems to be some latent state in emitters so force recreate them as needed
function ParticleSystem:Invalidate()
	for i=1,#self.emitters do
		table.remove(self.emitters):Remove()		
	end
end

function ParticleSystem:AddEmitter()
	local emitter = ParticleEmitter(self)
	table.insert( self.emitters, emitter)

	return emitter
end

function ParticleSystem:IsDone(ignoreLooping)
	ignoreLooping = ignoreLooping or false
	for k,v in ipairs(self.emitters) do
		if not v:IsDone(ignoreLooping) then
			return false
		end
	end

	return true
end

function ParticleSystem:Stop()
	for _k,v in ipairs(self.emitters) do
		v:Stop()
	end
	-- Event: We're no longer emitting particles, but some may still be visible.
	self.inst:PushEvent("particles_stopemit")
end

function ParticleSystem:IsStopped()
	for _k,v in ipairs(self.emitters) do
		if not v:IsStopped() then
			return false
		end
	end
	return true
end

-- pushes "particles_stopcomplete" event to instance when complete
function ParticleSystem:StopAndNotify()
	self:Stop()
	self.inst:StartUpdatingComponent(self)
end

-- pushes "particles_stopcomplete" event to instance when complete
function ParticleSystem:StopThenRemoveEntity()
	self:Stop()

	local OnComplete = function(source, data)
		if source == self.inst then
			source:Remove()
		end
	end

	self.inst:ListenForEvent("particles_stopcomplete", OnComplete)
	self.inst:StartUpdatingComponent(self)
end


function ParticleSystem:Restart()
	for k,v in ipairs(self.emitters) do
		v:Restart()
	end
end

function ParticleSystem:GetParams()
	return self.params
end

function ParticleSystem:SetParams(params, forceApplyDefaults)
	forceApplyDefaults = forceApplyDefaults or false
	self.params = params
	self.reference_params = deepcopy(params)
	params.emitters = params.emitters or {}

	assert(#self.emitters == 0 or #self.emitters == #params.emitters)
	if #self.emitters ~= #params.emitters then
		for i = 1,#params.emitters do
			self:AddEmitter()
		end
	end

	for k, v in ipairs(params.emitters) do
		self.emitters[k]:SetParams(v, forceApplyDefaults)
	end

	return self
end

function ParticleSystem:LoadParams(id)
	assert(id)

	self:Invalidate()

	local isNew = self.param_id == nil or self.param_id == ''
	self.param_id = id
	local params = ParticlesAutogenData[id]
	-- we can be reverting on a newly cloned system, so it wouldn't exist
	if params then
		if self.edit_mode
			and params.texture
			and params.texture[1]
		then
			TheSim:LoadAtlas("images/"..params.texture[1])
		end
		self:SetParams(params, not isNew)
	end

	return self
end

function ParticleSystem:GetEmitter(idx)
	return self.emitters[idx]
end

function ParticleSystem:SetManualMode(val)
	for k,emitter in ipairs(self.emitters) do
		emitter:SetManualMode(val)
	end
end

function ParticleSystem:SetAllEmitRateMult(mult)
	for k,emitter in ipairs(self.emitters) do
		emitter:SetEmitRateMult(mult)
	end
end

function ParticleSystem:SetLightOverride(value)
	for k,emitter in ipairs(self.emitters) do
		emitter:SetLightOverride(value)
	end
end

function ParticleSystem:SetLayer(newLayer)
	for k,emitter in ipairs(self.emitters) do
		emitter:SetLayer(newLayer)
	end
end

function ParticleSystem:SetSortOrder(val)
	for k,emitter in ipairs(self.emitters) do
		emitter:SetSortOrder(val)
	end
end

function ParticleSystem:SetDeltaTimeMultiplier(mult)
	for k,emitter in ipairs(self.emitters) do
		emitter:SetDeltaTimeMultiplier(mult)
	end
end

function ParticleSystem:SetFinalOffset(val)
	for k,emitter in ipairs(self.emitters) do
		emitter:SetFinalOffset(val)
	end
end

function ParticleSystem:OnMakeSurviveRoomTravel()
	for k,emitter in ipairs(self.emitters) do
		emitter.inst:MakeSurviveRoomTravel()
	end
	return self
end

-- this is normally not called except when an event handler is needed
-- see StopAndNotify
function ParticleSystem:OnUpdate(dt)
	if self:IsDone(true) then
		self.inst:StopUpdatingComponent(self)
		-- Event: We have no more visible particles and aren't emitting more.
		self.inst:PushEvent("particles_stopcomplete")
	end
end

function ParticleSystem:GetBoundingBox()
	local x1, y1, x2, y2

	for k,emitter in ipairs(self.emitters) do
		local ex1, ey1, ex2, ey2 = emitter:GetBoundingBox()

		if x1 then
			x1 = math.min(x1, ex1)
			y1 = math.min(y1, ey1)
			x2 = math.max(x2, ex2)
			y2 = math.max(y2, ey2)
		else
			x1 = ex1
			y1 = ey1
			x2 = ex2
			y2 = ey2
		end
	end

	if not x1 then
		x1 = -10
		y1 = -10
		x2 = 10
		y2 = 10
	else
		-- enforce a minimum size of 20 pixels:
		local dx = math.max((20 - (x2-x1)) * 0.5, 0)
		local dy = math.max((20 - (y2-y1)) * 0.5, 0)
		x1 = x1 - dx
		y1 = y1 - dy
		x2 = x2 + dx
		y2 = y2 + dy
	end

	return x1, y1, x2, y2
end

function ParticleSystem:DebugDrawEntity(ui, panel, colors)
	if ui:Button("Stop") then
		self:Stop()
	end
	ui:SameLineWithSpace()
	if ui:Button("Restart") then
		self:Restart()
	end
	ui:SameLineWithSpace()
	panel:AppendTable(ui, self:GetParams(), "Inspect params")

	for i,v in ipairs(self.emitters) do
		local emittername = v:GetName() or "Emitter_"..i
		ui:TextColored(colors.header, emittername)
		ui:Value("IsDone", v:IsDone())
		ui:Value("IsDone (ignoreLooping)", v:IsDone(true))
		ui:Value("IsShown", v:IsShown())
	end
end

function ParticleSystem:OnWallUpdate(dt)
	local x, z = TheInput:GetWorldXZWithHeight(self.dragoffset.height)
	self.inst.Transform:SetPosition(self.dragoffset.x + x, self.dragoffset.y, self.dragoffset.z + z)
end

--------------------------------------------------------------------------------------
-- Helper functions to allow particle systems to act as props
--------------------------------------------------------------------------------------

function ParticleSystem.CollectAssets(assets, params)
	prefabutil.CollectAssetsForParticleSystem(assets, params)
end

local function particlesPropSnapToGrid(self, snaptogrid)
	if snaptogrid and self.inst.components.snaptogrid == nil then
		self.inst:AddComponent("snaptogrid")
		self.inst.components.snaptogrid:SetDimensions(1, 1)
	elseif not snaptogrid and self.inst.components.snaptogrid then
		self.inst.components.snaptogrid = nil
	end
end

function ParticleSystem.SetLayerOverride(inst, layerName)
	local RENDER_LAYERS = {
		bg = LAYER_BACKGROUND,
		backdrop = LAYER_BACKDROP
	}
	local layer = RENDER_LAYERS[layerName] or LAYER_WORLD
	inst.components.particlesystem:SetLayer(layer)
	inst.layer = layerName
	local sortorder = layerName == "bg" and 2 or 0
	inst.components.particlesystem:SetSortOrder(sortorder)
end

local function particlesPropSetLayerOverride(self, layerName)
	ParticleSystem.SetLayerOverride(self.inst, layerName)
end

local function particlesPropLoadParamsInternal(self, param_id)
	self.inst.components.particlesystem:LoadParams(param_id)
	self.inst.param_id = param_id
end

local LAYERS = { 
	{
		id = nil,
		label = "Foreground"
	},
	{
		id = "bg",
		label = "Background"
	},
	{
		id = "backdrop",
		label = "Backdrop"
	}
}

local function particlesPropEditable(self, ui)
	local ui = require "dbui.imgui"

	ui:Text("Position")

	ui:PushItemWidth(100)

	local hasSnapToGrid = self.inst.components.snaptogrid ~= nil
	local transformFormat = hasSnapToGrid and "%1.f" or "%1.2f"
	local transformThrow = hasSnapToGrid and 1.0 or 0.05
	local x, y, z = self.inst.Transform:GetWorldPosition()
	local changedX, valueX = ui:DragFloat("x\t", x, transformThrow, -50, 50, transformFormat)
	if changedX then
		self.inst.Transform:SetPosition(valueX, y, z)
		self:OnPropChanged()
	end
	ui:SameLine()
	local changedY, valueY = ui:DragFloat("y\t", y, transformThrow, -50, 50, transformFormat)
	if changedY then
		self.inst.Transform:SetPosition(x, valueY, z)
		self:OnPropChanged()
	end
	ui:SameLine()
	local changedZ, valueZ = ui:DragFloat("z", z, transformThrow, -50, 50, transformFormat)
	if changedZ then
		self.inst.Transform:SetPosition(x, y, valueZ)
		self:OnPropChanged()
	end

	ui:PopItemWidth()

	if ui:Checkbox("Snap to Grid", hasSnapToGrid) then
		particlesPropSnapToGrid(self, not hasSnapToGrid)
		self:OnPropChanged()
	end

	ui:Separator()
	ui:Text("Particles")

	-- setup self data sufficiently to trick Particle Editor functions
	-- into working as intended on non-screen data
	self.mode_2d = false

	if ParticleSystem.LayerOverrideUi(ui, "##EditableLayerOverride", self.inst) then		
		particlesPropSetLayerOverride(self, self.inst.layer)
		self:OnPropChanged()
	end
end

function ParticleSystem.LayerOverrideUi(ui, id, particle_system)
	if not ui:CollapsingHeader("Layer Override") then
		return
	end
	ui:Indent()
	local _, layer_index = lume.match(LAYERS, function(layer) 
			return layer.id == particle_system.layer 
		end)
	local changed = false
	lume(LAYERS):enumerate(function(i, layer)
		local id = id..i
		local clicked, new_layer_index = ui:RadioButton(layer.label.."\t"..id, layer_index, i)
		if clicked then
			layer_index = new_layer_index
			particle_system.layer = LAYERS[layer_index].id
			changed = true
		end
	end)
	ui:Unindent()
	return changed
end

local function particlesPropOnLoadInternal(self)
	if self.data.param_id ~= nil and string.len(self.data.param_id) > 0 then
		particlesPropLoadParamsInternal(self, self.data.param_id)
	end
	if self.data.snaptogrid ~= nil and self.data.snaptogrid then
		particlesPropSnapToGrid(self, self.data.snaptogrid)
	end
	if self.data.layer ~= nil then
		particlesPropSetLayerOverride(self, self.data.layer)
	end
end

local function particlesPropOnPropChanged(self)
	if TheWorld.components.propmanager == nil then
		return
	elseif self.data ~= nil then
		local x, y, z = self.inst.Transform:GetWorldPosition()
		if self.inst.components.snaptogrid ~= nil then
			local x1, y1, z1 = self.inst.components.snaptogrid:MoveToNearestGridPos(x, y, z, false)
			if x1 ~= nil then
				x, y, z = x1, y1, z1
			end
		else
			x = lume.round(x, 0.01)
			y = lume.round(y, 0.01)
			z = lume.round(z, 0.01)
			self.inst.Transform:SetPosition(x, y, z)
		end

		local dirty = false
		if (self.data.x or 0) ~= x then
			self.data.x = x ~= 0 and x or nil
			dirty = true
		end
		if (self.data.y or 0) ~= y then
			self.data.y = y ~= 0 and y or nil
			dirty = true
		end
		if (self.data.z or 0) ~= z then
			self.data.z = z ~= 0 and z or nil
			dirty = true
		end

		local snaptogrid = self.inst.components.snaptogrid ~= nil
		if self.data.snaptogrid ~= snaptogrid then
			self.data.snaptogrid = snaptogrid and true or nil
			dirty = true
		end

		if self.data.param_id ~= self.inst.param_id then
			self.data.param_id = self.inst.param_id
			dirty = true
		end

		if self.data.layer ~= self.inst.layer then
			self.data.layer = self.inst.layer
			dirty = true
		end

		if dirty then
			TheWorld.components.propmanager:SetDirty()
		end
	else
		print("Warning: Prop will not be saved.")
	end
	self.inst:PushEvent("propchanged")
end

-- EditableEditor calls this.
function ParticleSystem.AppendPrefabAsset(prefab, asset)
	if softresolvefilepath(asset.file) == nil then
		return false
	end

	prefab = Prefabs[prefab]

	if #prefab.assets > 0 then
		for i = 1, #prefab.assets do
			if deepcompare(prefab.assets[i], asset) then
				--Already exists, don't need to append
				return
			end
		end
		prefab.assets[#prefab.assets + 1] = asset
	else
		--Must replace the EMPTY table (see prefabs.lua)
		prefab.assets = { asset }
	end

	if not ShouldIgnoreResolve(asset.file, asset.type) then
		RegisterPrefabsResolveAssets(prefab, asset)
	end
	TheSim:DevAppendPrefabAsset(prefab.name, asset)
	return true
end

function ParticleSystem.SpawnParticleSystem(prefab, params, dest_pos, instigator)
	assert(params)
	assert(dest_pos)

	dest_pos.y = 0
	if PrefabExists(prefab) then
		local assets = {}
		local prefabs = {}

		--local build = params.build or prefab
		--local bank = params.bank or prefab

		ParticleSystem.CollectAssets(params, debug)
		for _,a in ipairs(assets) do
			ParticleSystem.AppendPrefabAsset(prefab, a)
		end
		for _,p in ipairs(prefabs) do
			ParticleSystem.AppendPrefabDep(prefab, p)
		end
	else
		RegisterPrefabs(MakeAutogenParticles(prefab, params, true))
	end

	TheSim:LoadPrefabs({ prefab })
	local ent = SpawnPrefab(prefab, instigator)
	if ent == nil then
		return
	end
	
	SetDebugEntity(ent)
	return ent
end

function ParticleSystem.MakeProp(ent, force_edit_mode)
	-- and editable if needed
	local edit_mode
	if force_edit_mode then
		edit_mode = force_edit_mode
	else
		local EditableEditor = require("debug/inspectors/editableeditor")
		edit_mode = EditableEditor:IsEditMode()
	end
	if edit_mode then
		spawnutil.MakeEditable(ent, "square")
		ent.AnimState:SetMultColor(table.unpack(WEBCOLORS.BLUE))
	end

	ent.persists = true

	-- Make it a prop
	ent:AddComponent("prop")
	ent.components.prop:SetPropType(PropType.Particles)
	-- we override rather than amend the prop because we want different default behavior
	ent.components.prop.EditEditable = particlesPropEditable
	ent.components.prop.OnPropChanged = particlesPropOnPropChanged
	ent.components.prop.OnLoadInternal = particlesPropOnLoadInternal
end

function ParticleSystem.SpawnParticleSystemAsProp(prefab, params, dest_pos, instigator)
	local newprop = ParticleSystem.SpawnParticleSystem(prefab, params, dest_pos, instigator)
	ParticleSystem.MakeProp(newprop)	
	SetDebugEntity(newprop)
	return newprop
end

return ParticleSystem
