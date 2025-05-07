local DataDumper = require "util.datadumper"
local DebugNodes = require "dbui.debug_nodes"
local DebugSettings = require "debug.inspectors.debugsettings"
local DraggableWorldWidget = require "widgets.ftf.draggableworldwidget"
local EditorBase = require "debug.inspectors.editorbase"
local EventFuncEditor = require "debug.inspectors.eventfunceditor"
local ParticleSystem = require "components.particlesystem"
local ParticleSystemWidget = require "widgets.ftf.particlesystemwidget"
local SaveAlert = require "debug.inspectors.savealert"
local Screen = require "widgets.screen"
local fileutil = require "util.fileutil"
local lume = require "util.lume"
require "consolecommands"
require "constants"
require "prefabs.particles_autogen"


local default_params =
{
	emitters = {},
}

local DraggableEmitter = Class(DraggableWorldWidget, function(self)
	DraggableWorldWidget._ctor(self, "DraggableEmitter")
	self.system_w = self:AddChild(ParticleSystemWidget())
	self.particle_system = self.system_w.inst.components.particlesystem
	self.particle_system.edit_mode = true
end)

function DraggableEmitter:OnUpdateWorldPosition(dt, x,z)
	DraggableEmitter._base.OnUpdateWorldPosition(self, dt, x,z)
	if self.system_ent then
		self.system_ent.Transform:SetPosition(x, 0, z)
	end
end



local _static = EditorBase.MakeStaticData("particles_autogen_data")

local ISDIRTY = false

local TEST_PARTICLE_ATLAS = "particles2.xml"
local TEST_PARTICLE_REGION = "nesw.tex"

local ParticleEditor = Class(EditorBase, function(self, inst)
	EditorBase._ctor(self, _static)

	self.name = "Particle Editor"
	self.groupfilter = ""
	self.param_id = ""

	self.edit_options = DebugSettings("particleeditor.edit_options")
		:Option("prefabname", "")
	self.param_id = self.edit_options.prefabname

	self.funceditor = EventFuncEditor(self)

	self.screen = Screen("ParticleEditorScreen")
		:SetAnchors("center", "center")
		:SetNonInteractive()

	self.gradient_editors = {}

	self.mode_2d = not InGamePlay()

	-- Push a screen to enable dragging of the draggable emitter
	TheFrontEnd:PushScreen(self.screen)

	self:RespawnParticleSystem()

	if self.param_id then
		self:LoadParticlesParams(self.param_id)
	end

	self.undo_stack = {}
	self.undo_ptr = 1

	self.saveAlert = SaveAlert()

	TheSim:LoadPrefabs({"debug_draggable"})
end)

function ParticleEditor:SetDirty()
	EditorBase.SetDirty(self)
	self.particles.particle_system:SetParams(self.particles.particle_system.params)
end

ParticleEditor.PANEL_WIDTH = 660
ParticleEditor.PANEL_HEIGHT = 990

ParticleEditor.world_ranges =
{
	transform = { min = -20, max = 20, step = 0.01 },
	size = { min = 0.0001, max = 50 },
	velocity = { min = -10, max = 10 },
	gravity = { min = -5, max = 5, step = 0.01 },
	emitterpos = { min = -20, max = 20 },
	emittersize = { min = 0, max = 60 },
}

ParticleEditor.frontend_ranges =
{
	transform = { min = -2000, max = 2000, step = 1.0 },
	size = { min = 0.01, max = 5000 },
	velocity = { min = -1000, max = 1000 },
	gravity = { min = -500, max = 500, step = 1 },
	emitterpos = { min = -2000, max = 2000 },
	emittersize = { min = 0, max = 6000 },
}


function ParticleEditor:LoadParticlesParams(id)
	-- ensure its assets are loaded, the level may not have had a dependency on this system
	TheSim:LoadPrefabs({ id })

	self.particles.particle_system:LoadParams(id)
	self.particles.particle_system:Reset()

	if self.use_test_texture then
		for k,emitter in ipairs(self.particles.particle_system.emitters) do
			emitter.inst.ParticleEmitter:SetTexture("images/" .. TEST_PARTICLE_ATLAS, TEST_PARTICLE_REGION)
		end
	end
end



function ParticleEditor:OnRevert()
	self:LoadParticlesParams(self.param_id)
	self:ClearState()
	self:PushState()
end

function ParticleEditor:RemoveTestParticles()
	if not self.particles then
		return
	end
	if self.particles.system_ent then
		self.particles.system_ent:Remove()
	end
	self.particles:Remove()
	self.particles = nil
end

local function CreateTestParticles3d(parent)
	parent.system_ent = SpawnPrefab("particlesystem", TheDebugSource)
	parent.particle_system = parent.system_ent.components.particlesystem
	return parent.system_ent
end

function ParticleEditor:RespawnParticleSystem()
	local x,y
	if self.particles and self.particles.mode_2d == self.mode_2d then
		x,y = self.particles:GetPosition()
	end
	self:RemoveTestParticles()

	if self.has_facing then
		-- Setup an in-world object with the particlesystem on a follower to
		-- match how particles are used in game.
		self.particles = SpawnPrefab("debug_draggable", TheDebugSource)
		self.particles.Transform:SetTwoFaced()
		self.particles.SetFocusColor = function(inst, is_focused)
			local color = is_focused and WEBCOLORS.WHITE or WEBCOLORS.GRAY
			local r,g,b = table.unpack(color)
			inst.AnimState:SetMultColor(r,g,b, 0.5)
		end
		self.particles:SetFocusColor(true) -- prevent flash of red

		CreateTestParticles3d(self.particles)
		self.particles.system_ent.entity:SetParent(self.particles.entity)
		self.particles.system_ent.entity:AddFollower()
		self.particles.system_ent.Follower:FollowSymbol(self.particles.GUID, "mouseover01")

		if self.face_left then
			self.particles.Transform:FlipFacingAndRotation()
		end

		if y then
			-- Ignore 2d positions.
			x = nil
		end
		x = GetDebugPlayer():GetPosition()
		self.particles.Transform:SetPosition(x:unpack())

	else
		self.particles = self.screen:AddChild(DraggableEmitter())
		self.particles.OnRemoved = function(inst)
			self.particles = nil
		end
		if x then
			self.particles:SetPosition(x, y)
			-- else we'll stay at origin
		end

		if not self.mode_2d then
			-- Ignore the widget's particles and use our own.
			CreateTestParticles3d(self.particles)
		end
	end
	self.particles.mode_2d = self.mode_2d
end

function ParticleEditor:SetCurrentEffect( name )
	self.param_id = name
	self:LoadParticlesParams(self.param_id)
	self:ClearState()
	self:PushState()
end

function ParticleEditor:PostFindOrCreateEditor(name)
	ParticleEditor._base.PostFindOrCreateEditor(name)
	if name then
		self:SetCurrentEffect(name)
	end
end

function ParticleEditor:SetCurrentBackground( bgname )
	if bgname then
		self.plax_name = bgname
		self.plax:SetPlaxData(self.plax_name)
	end
end

function ParticleEditor:GetFilename( param_id )
	return string.format( "scripts/content/particles/%s.lua", param_id )
end

function ParticleEditor:GetLoaderComment()
	local prefab_loader = self.static.file:gsub("_data", "")
	return ("loaded by %s.lua"):format(prefab_loader)
end

function ParticleEditor:GetLoaderCategory()
	return self.static.file:gsub("_autogen_data", "")
end

function ParticleEditor:Save(force)
	if self.static.dirty then
		local prefix = ("-- Generated by %s and loaded by %s\n"):format(
			self:_GetNodeClassName_Unsafe() or "<unknown editor>",
			self.static.file)

		-- remove any entries that existed before but don't anymore
		local name = self:GetLoaderCategory()
		for i,v in pairs(self.static.originaldata) do
			if not self.static.data[i] then
				TheSim:DevRemoveDataFile("scripts/prefabs/autogen/"..name.."/"..i:lower()..".lua")
			end
		end
		-- and save the entries that changed
		for i,v in pairs(self.static.data) do
			if force or not deepcompare(v, self.static.originaldata[i]) then
				v.__displayName = i
				-- Trailing newline to match editorconfig.
				local str = DataDumper(v, nil, false) .. "\n"
				TheSim:DevSaveDataFile("scripts/prefabs/autogen/"..name.."/"..i:lower()..".lua", prefix .. str)
			end
		end

		self.static.originaldata = deepcopy(self.static.data)
		self.static.dirty = false
	end
end

function ParticleEditor:SwitchScreens(fn)
	self:Save()
	fn()
end

function ParticleEditor:OnActivate()
	-- Avoid selecting lighting props.
	DebugNodes.EditableEditor.EnableLayer_PrefabName("debug_draggable")
	-- Would this be more useful? DebugNodes.EditableEditor.EnableLayer_Grid()
end

function ParticleEditor:OnDeactivate( panel )
	self:RemoveTestParticles()
	TheFrontEnd:PopScreen(self.screen)
	DebugNodes.EditableEditor.EnableLayer_All()
end

function ParticleEditor:OnParticleEffectChanged(param_id)
	self.has_facing = nil
	self.face_left = nil

	self:RespawnParticleSystem()
	self:ClearState()

	self.param_id = param_id
	self.edit_options:Set("prefabname", param_id)
	self.edit_options:Save()

	if string.len(param_id) > 0 then
		self:LoadParticlesParams(self.param_id)
		self:PushState()
	end
end

function ParticleEditor:GetGroupList()
	local groupmap = { [""] = true }
	for _, params in pairs(self.static.data) do
		if (params.mode_2d == true) == self.mode_2d then
			if params.group ~= nil then
				groupmap[params.group] = true
			end
		end
	end
	local grouplist = {}
	for groupname in pairs(groupmap) do
		grouplist[#grouplist + 1] = groupname
	end
	table.sort(grouplist)
	groupmap[""] = nil
	return grouplist, groupmap
end

function ParticleEditor:GetParticlesList(groupfilter)
	local param_list = { "" }
	for name, params in pairs(self.static.data) do
		if (params.mode_2d == true) == self.mode_2d then
			if string.len(groupfilter) == 0 or params.group == groupfilter then
				param_list[#param_list + 1] = name
			end
		end
	end
	table.sort(param_list)
	return param_list
end

-- File scope so it's shared between editors.
local pasteboard = {}

function ParticleEditor:RenderEmitterBegin(ui, label, index)
	if self.use_windows then
		local w = ParticleEditor.PANEL_WIDTH
		ui:SetNextWindowSize(w, ParticleEditor.PANEL_HEIGHT - 50, ui.Cond.Appearing)
		local x = w * (index - 1)
		local y = 0
		local max_w = TheSim:GetScreenSize()
		if x > max_w then
			-- -1 defaults don't do anything clever so just stack them up in the way.
			x = 50 + (index * 10)
			y = x
		end
		ui:SetNextWindowPos(x, y, ui.Cond.Appearing)
		return ui:Begin(label)
	else
		self.had_tree = ui:TreeNode(label, ui.TreeNodeFlags.DefaultOpen)
		return self.had_tree
	end
end

function ParticleEditor:RenderEmitterEnd(ui, label)
	if self.use_windows then
		ui:End()
	elseif self.had_tree then
		ui:TreePop()
	end
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



local function Curve_HexToGradient(hex_curve, time_curve)
	local res = {}
	for i = 1,#time_curve do
		local t = time_curve[i]
		local c = hex_curve[i]
		table.insert(res, {t,c})
	end
	return res
end

local function Curve_GradientToHex(gradient_curve)
	local len = #gradient_curve-1
	assert(len > 0)


	local time = {}
	local colors = {}
	for i,c in ipairs(gradient_curve) do
		local t = c[1]
		table.insert(time, t)
		table.insert(colors, c[2])
	end
	return colors, time
end

function ParticleEditor:RenderEmitter( ui, index, emitter )
	local params = emitter.params
	local reference_params = emitter.reference_params
	if params then
		local ranges = self.mode_2d and ParticleEditor.frontend_ranges or ParticleEditor.world_ranges

		ValidateParams(params)

		ui:TextColored(self.colorscheme.header, "How Particles Are Created")

		local lod = params.lod or 0xFF

		if ui:Checkbox("Visible on Low Detail", CheckBits(lod, LEVEL_OF_DETAIL_LOW)) then
			params.lod = ToggleBits(lod, LEVEL_OF_DETAIL_LOW)
		end

		if ui:Checkbox("Visible on High Detail", CheckBits(lod, LEVEL_OF_DETAIL_HIGH) ) then
			params.lod = ToggleBits(lod, LEVEL_OF_DETAIL_HIGH)
		end

		local changed, new_bake = ui:SliderFloat("Bake Time", params.bake_time or 0, 0, 5)
		if changed then
			params.bake_time = new_bake
			emitter:Reset()
		end

		if ui:CollapsingHeader("Transform") then
			local ox, oy, oz = params.x or 0, params.y or 0, params.z or 0
			local rot = params.r or 0

			local transformChanged, x, y, z = ui:DragFloat3( "Offset", ox, oy, oz, ranges.transform.step, ranges.transform.min, ranges.transform.max)

			local rotationChanged, rdeg = ui:DragFloat( "Rotation##Transform", rot, .1, -360, 360, "%.2f")
			if transformChanged then
				emitter:SetPos(x,y,z)
				params.x, params.y, params.z = x, y, z
			end

			if rotationChanged then
				emitter:SetRotation(rdeg)
				params.r = rdeg
			end

			local use_local_ref_frame = ui:_Checkbox("Use Local Reference Frame", params.use_local_ref_frame or false)
			params.use_local_ref_frame = use_local_ref_frame and true or nil
		end

		if ui:CollapsingHeader("Emission") then
			--params.emit_world_space = ui:_Checkbox("Emit in World Space", params.emit_world_space)

			params.max_particles = ui:_SliderInt("Max Particles", params.max_particles, 1, 4096)

			local emitRateChanged, emitRate = ui:SliderFloat("Emit Rate", params.emit_rate, 0, 100)
			if emitRateChanged then
				params.emit_rate = emitRate
			end

			params.burst_amt = ui:_SliderInt("Burst Particles", params.burst_amt or 0 , 0, 4096)

			local burstTimeChanged, burstTime = ui:SliderFloat("Burst Time", params.burst_time or 0, 0, 60)
			if burstTimeChanged then
				params.burst_time = burstTime
			end

			local timeToLiveMinChanged, timeToLiveMin = ui:SliderFloat("Time To Live Min", params.spawn.ttl[1] or 0 , 0, 60)
			if timeToLiveMinChanged then
				params.spawn.ttl[1] = timeToLiveMin
			end

			local timeToLiveMaxChanged, timeToLiveMax = ui:SliderFloat("TTL Max", params.spawn.ttl[2] or 0, 0, 60)
			if timeToLiveMaxChanged then
				params.spawn.ttl[2] = timeToLiveMax
			end

			local positionModeText =
			{
				"No Offset (Default)",
				"Offset for +Y Emission",
				"Offset for -Y Emission",
			}
			local currentPositionMode = params.spawn.positionMode or 0
			local newPositionMode = ui:_Combo("Initial Position Mode", currentPositionMode + 1, positionModeText) - 1

			if currentPositionMode ~= newPositionMode then
				if newPositionMode == 0 then
					emitter.inst.ParticleEmitter:SetSpawnPositionMode(0)
					newPositionMode = nil
				end
				params.spawn.positionMode = newPositionMode
			end

			if ui:CollapsingHeader("Emit Curve") then
				params.curves.emission_rate.enabled = ui:_Checkbox("Enabled##EMIT_CURVE_ENABLED", params.curves.emission_rate.enabled)
				ui:CurveEditor("Curve##EMIT_CURVE", params.curves.emission_rate.data)

				local emissionRateTimeChanged, emissionRateTime = ui:SliderFloat("Time:##EMITCURVETIME", params.emission_rate_time or 5 , .01, 10)
				if emissionRateTimeChanged then
					params.emission_rate_time = emissionRateTime
				end

				params.emission_rate_loops = ui:_Checkbox("Loops##EMITCURVELOOPS", params.emission_rate_loops)
				ui:Separator()
			end

			ui:Separator()
		end

		-------------------------------------------------------

		ui:TextColored(self.colorscheme.header, "How Particles Behave")

		if ui:CollapsingHeader("Size") then
			local sizeMinChanged, sizeMin = ui:SliderFloat("Size Min", params.spawn.size[1] or 0, ranges.size.min, ranges.size.max)
			if sizeMinChanged then
				params.spawn.size[1] = sizeMin
			end

			local sizeMaxChanged, sizeMax = ui:SliderFloat("Size Max", params.spawn.size[2] or 0, ranges.size.min, ranges.size.max)
			if sizeMaxChanged then
				params.spawn.size[2] = sizeMax
			end

			ui:Separator()

			local aspectRatioChanged, aspectRatio = ui:SliderFloat("Aspect Ratio", params.spawn.aspect or 1 , .1, 10)
			if aspectRatioChanged then
				params.spawn.aspect = aspectRatio
			end

			ui:Separator()
		end

		if ui:CollapsingHeader("Rendering") then
			if self.all_atlases == nil then
				self.all_atlases = {}
				for k, filename in pairs(TheSim:ListFiles( 'images', '*.xml')) do
					table.insert( self.all_atlases, string.format( "%s", filename ))
				end
				table.sort(self.all_atlases, function (k1, k2) return string.lower(k1) < string.lower(k2) end)
			end

			if type(params.texture) ~= "table" then
				params.texture = {}
			end
			params.texture = params.texture or {}

			local texture_idx = table.arrayfind(self.all_atlases, params.texture[1]) or 1
			local atlas_idx = ui:_Combo("Atlas", texture_idx or 1, self.all_atlases)
			params.texture[1] = self.all_atlases[atlas_idx]

			-- We need to load this atlas in case it isn't loaded
			local atlas = "images/"..params.texture[1]
			TheSim:LoadAtlas(atlas)

			local atlasregions = TheSim:GetAtlasRegions(atlas)
			table.sort(atlasregions, function (k1, k2) return string.lower(k1) < string.lower(k2) end)
			local region = params.texture[2]
			region = ui:_ComboAsString("Region", region, atlasregions)
			if ui:IsItemHovered(ui.HoveredFlags.AllowWhenBlockedByPopup) then
				ui:BeginTooltip()
				ui:Value("Atlas", atlas)
				ui:Value("Tex", region)
				ui:AtlasImage(atlas, region, 300,300)
				ui:EndTooltip()
			end
			params.texture[2] = region

			params.spawn.color = params.spawn.color or 0xffffffff
			params.spawn.color = ui:_ColorHex4_Int("Colour", params.spawn.color)

			local bloomChanged, bloom = ui:SliderFloat("Bloom", params.bloom, 0, 5)
			if bloomChanged then
				params.bloom = bloom
			end

			local lifetimeErosionChanged, lifetimeErosion = ui:SliderFloat("Lifetime Erosion", params.erode_bias or 1, 0, 1)
			if lifetimeErosionChanged then
				params.erode_bias = lifetimeErosion
			end

			--Layer override for non-UI/frontend emitters
			if not self.mode_2d then
				local ground_projected = ui:_Checkbox("Ground Projected", params.ground_projected or false)
				ground_projected = ground_projected and true or nil
				if ground_projected ~= params.ground_projected then
					if ground_projected then
						params.spawn.layer = LAYER_WORLD_BACKGROUND
					else
						params.spawn.layer = nil
					end
				end
				params.ground_projected = ground_projected

				local LAYER_NO_OVERRIDE = -1
				local overrideLayer = { LAYER_NO_OVERRIDE, LAYER_BACKDROP, LAYER_BACKGROUND, LAYER_WORLD_BACKGROUND, LAYER_WORLD }
				local overrideLayerText = { "No Override", "Backdrop", "Background", "World Background", "World" }
				local currentLayerIdx = table.arrayfind(overrideLayer, params.spawn.layer or LAYER_NO_OVERRIDE)
				local newLayer = overrideLayer[ui:_Combo("Override Layer", currentLayerIdx or 1, overrideLayerText)]
				if params.spawn.layer ~= newLayer then
					if newLayer == LAYER_NO_OVERRIDE then
						-- reset to default non-override immediately
						-- see ParticleEmitterComponent::OnSetEntity
--						self.inst.ParticleEmitter:SetLayer(LAYER_WORLD)
						emitter.inst.ParticleEmitter:SetLayer(LAYER_WORLD)
						newLayer = nil
					end
					params.spawn.layer = newLayer
				end

				--Sort order
				local sortorderlist =
				{
					"+3   (Most in front for layer)",
					"+2   (Background default)",
					"+1",
					"+0   (Foreground default)",
					"-1",
					"-2",
					"-3   (Most behind for layer)",
				}
				local defaultsortorderidx = math.ceil(#sortorderlist / 2)
				local sortorderidx = defaultsortorderidx - (params.spawn.sort_order or 0)
				local newsortorderidx = ui:_Combo("Sort Order", math.clamp(sortorderidx, 1, #sortorderlist), sortorderlist)
				if newsortorderidx ~= sortorderidx then
					local newsortorder = defaultsortorderidx - newsortorderidx
					if newsortorder == 0 then
						newsortorder = nil
					end
					if params.spawn.sort_order ~= newsortorder then
						params.spawn.sort_order = newsortorder
					end
				end
			end

			-- Only support a subset of blendmodes.
			local blendmodes = {BlendMode.id.Disabled, BlendMode.id.AlphaBlended, BlendMode.id.Additive, BlendMode.id.Premultiplied, BlendMode.id.InverseAlpha, BlendMode.id.AlphaAdditive, BlendMode.id.VFXTest}
			local blendmodes_txt = lume.map(blendmodes, function(id) return BlendMode:FromId(id) end)
			local blend_idx = table.arrayfind(blendmodes, params.blendmode) or BlendMode.id.AlphaBlended
			params.blendmode = blendmodes[ui:_Combo("Blend Mode", blend_idx, blendmodes_txt)]

			-- Particles use sim update not wall update, so they cap at 30.
			local fpsChanged, fps = ui:SliderInt("Frame Rate", params.spawn.fps or 30, 1, 30)
			if fpsChanged then
				params.spawn.fps = fps
			end

			ui:Separator()
		end


		if ui:CollapsingHeader("Velocity / Physics") then
			local xVelMinChanged, xVelMin =	ui:SliderFloat("X Velocity Min", params.spawn.vel[1] or 0 , ranges.velocity.min, ranges.velocity.max)
			if xVelMinChanged then
				params.spawn.vel[1] = xVelMin
			end

			local xVelMaxChanged, xVelMax = ui:SliderFloat("X Velocity Max", params.spawn.vel[2] or 0, ranges.velocity.min, ranges.velocity.max)
			if xVelMaxChanged then
				params.spawn.vel[2] = xVelMax
			end

			local yVelMinChanged, yVelMin = ui:SliderFloat("Y Velocity Min", params.spawn.vel[3] or 0 , ranges.velocity.min, ranges.velocity.max)
			if yVelMinChanged then
				params.spawn.vel[3] = yVelMin
			end

			local yVelMaxChanged, yVelMax = ui:SliderFloat("Y Velocity Max", params.spawn.vel[4] or 0, ranges.velocity.min, ranges.velocity.max)
			if yVelMaxChanged then
				params.spawn.vel[4] = yVelMax
			end

			params.spawn.vel[5], params.spawn.vel[6] = 0, 0

			local velInheritChanged, velInherit = ui:SliderFloat("Velocity Inherit", params.velocity_inherit or 0, 0, 1)
			if velInheritChanged then
				params.velocity_inherit = velInherit
			end

			local frictionsChanged, fmin, fmax = ui:DragFloat2( "Friction Min/Max", params.friction_min or 0, params.friction_max or 0, ranges.gravity.step, ranges.gravity.min, ranges.gravity.max)
			if frictionsChanged then
				if fmax ~= params.friction_max and fmax < fmin then
					fmin = fmax
				end
				if fmin ~= params.friction_min and fmin > fmax then
					fmax = fmin
				end
				params.friction_min, params.friction_max = fmin, fmax
			end

			local gravityChanged, gx, gy, gz = ui:DragFloat3( "Gravity", params.gravity_x or 0, params.gravity_y or 0, params.gravity_z or 0, ranges.gravity.step, ranges.gravity.min, ranges.gravity.max)
			if gravityChanged then
				params.gravity_x, params.gravity_y, params.gravity_z = gx, gy, gz
			end

			ui:Separator()

			params.use_bounce = ui:_Checkbox("Use Bounce Collision Plane", params.use_bounce or false)
			if params.use_bounce then
				-- Show a warning if we can end up spawning particles below the bounce plane
				if params.spawn.box[3] <= (params.bounce_height or 0) and params.spawn.positionMode ~= 1 then
					ui:PushStyleColor(ui.Col.Text, { 0.7, 0, 0, 1 })
					ui:Text("Warning: Particles can spawn below bounce plane.\nConsider setting Initial Position Mode to Offset for +Y Emission")
					ui:PopStyleColor()
				end

				if not params.spawn.positionMode then
					ui:TextColored(UICOLORS.GOLD, "Non-default Emission / Initial Position Mode required.")
					ui:TextColored(UICOLORS.GOLD, "Using \"Offset for +Y Emission\"")
				end

				local bounceCoeffChanged, bounceCoeff = ui:SliderFloat("Restitution (Bounce Ratio)", params.bounce_coeff or 1, 0, 1)
				if bounceCoeffChanged then
					params.bounce_coeff = bounceCoeff
				end

				local bounceHeightChanged, bounceHeight = ui:SliderFloat("Ground Plane Offset", params.bounce_height or 0, -10, 10)
				if bounceHeightChanged then
					params.bounce_height = bounceHeight
				end
			end
		end

		if ui:CollapsingHeader("Rotation") then
			params.spawn.rot = params.spawn.rot or {0,0}
			local rot = params.spawn.rot[1] or 0
			local rotationMinChanged, rotationMin = ui:SliderFloat("Rotation Min", math.deg(rot), -360, 360, "%.2f")
			if rotationMinChanged then
				params.spawn.rot[1] = math.rad(rotationMin)
			end

			rot = params.spawn.rot[2] or 0
			local rotationMaxChanged, rotationMax = ui:SliderFloat("Rotation Max", math.deg(rot), -360, 360, "%.2f")
			if rotationMaxChanged then
				params.spawn.rot[2] = math.rad(rotationMax)
			end

			params.spawn.rotvel = params.spawn.rotvel or {0,0}

			rot = params.spawn.rotvel[1] or 0
			local rotationVelMinChanged, rotationVelMin = ui:SliderFloat("Rotation Velocity Min", math.deg(rot), -360, 360, "%.2f/s")
			if rotationVelMinChanged then
				params.spawn.rotvel[1] = math.rad(rotationVelMin)
			end

			rot = params.spawn.rotvel[2] or 0
			local rotationVelMaxChanged, rotationVelMax = ui:SliderFloat("Rotation Velocity Max", math.deg(rot), -360, 360, "%.2f/s")
			if rotationVelMaxChanged then
				params.spawn.rotvel[2] = math.rad(rotationVelMax)
			end
		end

		local x1,x2, y1, y2 = table.unpack( params.spawn.box)

		if ui:CollapsingHeader("Emitter Shape") then
			local shapeText =
			{
				"Rectangle (Default)",
				"Ellipse",
			}

			local currentShape = params.spawn.shape or 0
			local newShape = ui:_Combo("Shape", currentShape + 1, shapeText) - 1
			if currentShape ~= newShape then
				if newShape == 0 then
					emitter.inst.ParticleEmitter:SetSpawnShape(0)
					newShape = nil
				end
				params.spawn.shape = newShape
			end


			local emitWidthChanged, w = ui:SliderFloat("Emit Width", x2-x1, ranges.emittersize.min, ranges.emittersize.max)
			local emitHeightChanged, h = ui:SliderFloat("Emit Height", y2-y1, ranges.emittersize.min, ranges.emittersize.max)
			local r = params.spawn.random_position
			local emitRandomChanged, rand = ui:SliderFloat("Position Randomness",r and r or 0 , 0, ranges.emittersize.max*0.5)
			local x = (x1+x2)/2
			local y = (y1+y2)/2

			local emitXChanged, emitX = ui:SliderFloat("Emit X", x, ranges.emitterpos.min, ranges.emitterpos.max)
			if emitXChanged then
				x = emitX
			end

			local emitYChanged, emitY = ui:SliderFloat("Emit Y", y, ranges.emitterpos.min, ranges.emitterpos.max)
			if emitYChanged then
				y = emitY
			end

			if emitWidthChanged or emitHeightChanged or emitXChanged or emitYChanged then
				x1, x2 = x - w/2, x + w/2
				y1, y2 = y - h/2, y + h/2
				params.spawn.box = {x1, x2, y1, y2}
			end

			if emitRandomChanged then
				params.spawn.random_position = rand
			end
			local alignment = params.spawn.shape_alignment or 0
			local alignmentChanged, alignment = ui:SliderFloat("Direction Alignment", alignment, 0, 1, "%.2f")
			if alignmentChanged then
				params.spawn.shape_alignment = alignment
			end
			ui:Separator()

			if not params.spawn.shape then
				params.spawn.emit_on_grid = ui:_Checkbox("Emit on a Grid", params.spawn.emit_on_grid)

				if params.spawn.emit_on_grid then
					params.spawn.emit_grid_rows = ui:_SliderInt("Emit Rows", params.spawn.emit_grid_rows or 10, 2, 30)
					params.spawn.emit_grid_colums = ui:_SliderInt("Emit Columns", params.spawn.emit_grid_colums or 10, 2, 30)
				end
			elseif params.spawn.shape == 1 then
				-- always shut this off for ellipses
				params.spawn.emit_on_grid = false

				local arcVal = params.spawn.emit_arc_min or 0
				local arcMinChanged, arcMin = ui:SliderFloat("Emit Arc Min Angle", arcVal, -360, 360, "%.2f")
				arcVal = params.spawn.emit_arc_max or 360
				local arcMaxChanged, arcMax = ui:SliderFloat("Emit Arc Max Angle", arcVal, -360, 360, "%.2f")
				arcVal = params.spawn.emit_arc_vel or 0
				local arcVelChanged, arcVel = ui:SliderFloat("Emit Arc Velocity", arcVal, -1440, 1440, "%.2f/s")

				local arcPhaseChanged, arcPhase
				if arcVel ~= 0 then
					local arcActualMin = math.min(arcMin, arcMax)
					local arcActualMax = math.max(arcMin, arcMax)
					local arcSweep = arcActualMax - arcActualMin
					arcVal = params.spawn.emit_arc_phase or 0
					arcVal = math.clamp(arcVal, -arcSweep/2, arcSweep/2)
					arcPhaseChanged, arcPhase = ui:SliderFloat("Emit Arc Phase", arcVal, -arcSweep/2, arcSweep/2, "%.2f")

					local arcApplyVel = ui:_Checkbox("Apply Arc Velocity to Particles", params.spawn.emit_arc_applied_vel_scale)
					if not arcApplyVel then
						params.spawn.emit_arc_applied_vel_scale = nil
					else
						params.spawn.emit_arc_applied_vel_scale = params.spawn.emit_arc_applied_vel_scale or 1
						arcVal = params.spawn.emit_arc_applied_vel_scale or 1
						local arcAppliedVelScaleChanged, arcAppliedVelScale = ui:SliderFloat("Emit Arc Velocity Scale", arcVal, -5.0, 5.0, "%.2f")
						if arcAppliedVelScaleChanged then
							params.spawn.emit_arc_applied_vel_scale = arcAppliedVelScale
						end
					end
				else
					params.spawn.emit_arc_applied_vel_scale = nil
				end

				if arcVelChanged then
					params.spawn.emit_arc_vel = arcVel
				end
				if arcPhaseChanged then
					params.spawn.emit_arc_phase = arcPhase
				end
				if arcMinChanged then
					params.spawn.emit_arc_min = arcMin
				end
				if arcMaxChanged then
					params.spawn.emit_arc_max = arcMax
				end
			end
		end

		if emitter.shouldDrawShape then
			-- this is in world space but emitter's view matrix is billboarded
			-- there will be deviation as the emitter is further away from the
			-- screen origin
			local debugEmitterColors =
			{
				WEBCOLORS.SPRINGGREEN,
				WEBCOLORS.MEDIUMPURPLE,
				WEBCOLORS.CORAL,
				WEBCOLORS.BISQUE,
				WEBCOLORS.LIGHTSKYBLUE,
				WEBCOLORS.CRIMSON,
				WEBCOLORS.KHAKI,
			}

			local colorIndex = (index - 1) % (#debugEmitterColors) + 1

			if params.use_bounce then
				if not emitter.inst.UITransform then
					local wx, wy, wz = emitter.inst.Transform:GetWorldPosition()
					local tr = {wx, wy, wz}
					local rot = math.rad(emitter:GetRotation())

					-- draw bounce plane threshold
					local r0 = TheDebugRenderer:transformPoint({-1.5, (params.bounce_height or 0), 0}, tr, rot)
					local r1 = TheDebugRenderer:transformPoint({1.5, (params.bounce_height or 0), 0}, tr, rot)
					local color = deepcopy(debugEmitterColors[colorIndex])
					color[1] = color[1] * 0.7
					color[2] = color[2] * 0.7
					color[3] = color[3] * 0.7
					TheDebugRenderer:WorldLine(r0, r1, color, 2)
				end
			end

			local shape = params.spawn.shape or 0
			if shape == 0 then
				local drawFunc, drawSelf
				local p = { {x1, y1, 0}, {x1, y2, 0}, {x2, y1, 0}, {x2, y2, 0} }
				local pp = {}

				if not emitter.inst.UITransform then
					drawFunc = TheDebugRenderer.WorldLine
					drawSelf = TheDebugRenderer
					local wx, wy, wz = emitter.inst.Transform:GetWorldPosition()
					local tr = {wx, wy, wz}
					local rot = math.rad(emitter:GetRotation())
					local emitX = (x1 + x2) / 2
					local emitY = (y1 + y2) / 2

					-- draw direction
					local r0 = TheDebugRenderer:transformPoint({emitX, emitY, 0}, tr, rot)
					local r1 = TheDebugRenderer:transformPoint({emitX + 1, emitY, 0}, tr, rot)
					TheDebugRenderer:WorldLine(r0, r1, debugEmitterColors[colorIndex])

					for i = 1, 4 do
						pp[i] = TheDebugRenderer:transformPoint(p[i], tr, rot)
					end
				else
					drawFunc = ui.ScreenLine
					drawSelf = ui
					local wx, wy = emitter.inst.UITransform:GetWorldPosition()
					local screen_x, screen_y = TheSim:GetScreenSize()
					local tr = {wx+screen_x/2, -wy+screen_y/2, 0}
					local rot = 0 -- not yet supported by 2D emitters
					local scale = {screen_x/RES_X, -screen_y/RES_Y, 1}

					for i = 1, 4 do
						pp[i] = TheDebugRenderer:transformPoint(p[i], tr, rot, scale)
					end
				end

				if drawFunc and drawSelf then
					-- draw bounds
					drawFunc(drawSelf, pp[1], pp[2], debugEmitterColors[colorIndex])
					drawFunc(drawSelf, pp[1], pp[3], debugEmitterColors[colorIndex])
					drawFunc(drawSelf, pp[4], pp[2], debugEmitterColors[colorIndex])
					drawFunc(drawSelf, pp[4], pp[3], debugEmitterColors[colorIndex])
				end
			elseif shape == 1 then
				if not emitter.inst.UITransform then
					local wx, wy, wz = emitter.inst.Transform:GetWorldPosition()
					local rot = math.rad(emitter:GetRotation())
					local emitX = (x1 + x2) / 2
					local emitY = (y1 + y2) / 2

					-- draw direction
					local r0 = TheDebugRenderer:transformPoint({emitX, emitY, 0}, {wx, wy, wz}, rot)
					local r1 = TheDebugRenderer:transformPoint({emitX + 1, emitY, 0}, {wx, wy, wz}, rot)
					TheDebugRenderer:WorldLine(r0, r1, debugEmitterColors[colorIndex])
					-- draw bounds
					local a = 0.5 * (x2 - x1)
					local b = 0.5 * (y2 - y1)
					TheDebugRenderer:WorldEllipse(a, b, {wx,wy,wz}, {emitX,emitY,0}, rot, debugEmitterColors[colorIndex])
				else
					local wx, wy = emitter.inst.UITransform:GetWorldPosition()
					local rot = 0 -- not yet supported by 2D emitters
					local emitX = (x1 + x2) / 2
					local emitY = (y1 + y2) / 2
					-- draw bounds
					local a = 0.5 * (x2 - x1)
					local b = 0.5 * (y2 - y1)
					TheDebugRenderer:ScreenEllipse(a, b, {wx,wy,0}, {emitX,emitY,0}, rot, debugEmitterColors[colorIndex])
				end
			end
		end

		if ui:CollapsingHeader("Colour Curve") then
			local max_colors = 8

			-- One gradient editor per emitter to avoid repeatedly loading data
			-- which breaks editing: the editor does fixup every frame which
			-- messes with its internal curve.
			local gradient_editor = self.gradient_editors[self]
			if gradient_editor == nil then
				local BackgroundGradientEditorPane = require "debug.inspectors.panes.backgroundgradient"
				gradient_editor = BackgroundGradientEditorPane(max_colors, true)
				self.gradient_editors[self] = gradient_editor
			end

			if 0 == params.curves.color.num then
				if ui:Button("Add Colour Curve") then
					params.curves.color.num = 2
					params.curves.color.data = { 0xffffffff, 0xffffff00, }
					params.curves.color.time = { 0, 1, }
				end
			elseif ui:Button("Delete Colour Curve") then
				params.curves.color.num = 0
				lume.clear(params.curves.color.data)
				lume.clear(params.curves.color.time)
				gradient_editor.loaded_curve_source = nil
			end

			if params.curves.color.num > 1 then
				local hex_curve = params.curves.color.data
				local time_curve = params.curves.color.time
				if #hex_curve > params.curves.color.num then
					-- LEGACY: Old data may have unused color values, but
					-- BackgroundGradientEditorPane assumes all input data is
					-- valid. Trim off the old data.
					hex_curve = lume.first(hex_curve, params.curves.color.num)
				end

				local rgbat_curve = Curve_HexToGradient(hex_curve, time_curve)
				local gradient_changed, new_curve = gradient_editor:OnRender(ui, rgbat_curve)
				if gradient_changed then
					local data,time = Curve_GradientToHex(new_curve)
					params.curves.color.data = data
					params.curves.color.time = time
					params.curves.color.num = lume.count(params.curves.color.data)
				end
			end

			--~ -- For debugging, it's useful to see the current RGBA.
			--~ ui:Indent()
			--~ if ui:CollapsingHeader("Colour Curve Alpha") then
			--~ 	local count = params.curves.color.num
			--~ 	for k = 1, count do
			--~ 		local color = params.curves.color.data[k] or 0xffffffff
			--~ 		params.curves.color.data[k] = ui:_ColorHex4_Int( "Colour##COLORCURVE"..k, color )
			--~ 	end
			--~ end
			--~ ui:Unindent()

		end

		if ui:CollapsingHeader("Scale Curve") then
			params.curves.scale.enabled = ui:_Checkbox("Enabled##SCALE_CURVE_ENABLED", params.curves.scale.enabled)

			if params.curves.scale.enabled then

				local scaleMinChanged, scaleMin = ui:SliderFloat("Scale Min", params.curves.scale.min or 0, 0, 10)
				if scaleMinChanged then
					params.curves.scale.min = scaleMin
				end

				local scaleMaxChanged, scaleMax = ui:SliderFloat("Scale Max", params.curves.scale.max or 1, 0, 10)
				if scaleMaxChanged then
					params.curves.scale.max = scaleMax
				end

				ui:CurveEditor("Curve##SCALECURVE", params.curves.scale.data)
			end
		end

		if ui:CollapsingHeader("Velocity-Dependent Aspect Curve") then
			params.curves.velocityAspect.enabled = ui:_Checkbox("Enabled##VELOCITY_ASPECT_ENABLED", params.curves.velocityAspect.enabled)

			if params.curves.velocityAspect.enabled then
				local aspectMinChanged, aspectMin = ui:SliderFloat("Aspect Min", params.curves.velocityAspect.min or 0, 0, 10)
				if aspectMinChanged then
					params.curves.velocityAspect.min = aspectMin
				end

				local aspectMaxChanged, aspectMax = ui:SliderFloat("Aspect Max", params.curves.velocityAspect.max or 1, 0, 10)
				if aspectMaxChanged then
					params.curves.velocityAspect.max = aspectMax
				end

				local speedMaxChanged, speedMax = ui:SliderFloat("Speed Max", params.curves.velocityAspect.speedMax or 10, 0.001, 60)
				if speedMaxChanged then
					params.curves.velocityAspect.speedMax = speedMax
				end

				local rotationFactorChanged, rotationFactor = ui:SliderFloat("Rotation Factor", params.curves.velocityAspect.factor or 1, -1, 1)
				if rotationFactorChanged then
					params.curves.velocityAspect.factor = rotationFactor
				end

				ui:CurveEditor("Curve##VELOCITY_ASPECT_CURVE", params.curves.velocityAspect.data)
			end
		end

	end

	if not deepcompare(params, reference_params) then
		self:SetDirty()
	end

	ui:Separator()
	return true
end

function ParticleEditor:RenderParticleSystem( ui, particlesystem )
	local delete_emitter = nil
	local duplicate_emitter = nil
	local move_up_emitter = nil
	local move_down_emitter = nil

	--TODO_KAJ    if not TheGame:GetDebug():IsDebugFlagged(DBG_FLAGS.RENDER) then
	--TODO_KAJ        TheGame:GetDebug():ToggleDebugFlags( DBG_FLAGS.RENDER )
	--TODO_KAJ    end

	if ui:CollapsingHeader("Sound") then
		self.funceditor:SoundData(ui, particlesystem.params, true, "sound")
		self:SetDirty()
	end
	self:AddSectionEnder(ui)

	if ui:Button("Add emitter") then
		table.insert( particlesystem.params.emitters, deepcopy(ParticleSystem.default_params))
		particlesystem:Invalidate()
		self:SetDirty()
	end
	ui:SameLineWithSpace()
	if ui:Button("Paste Emitter", nil, nil, pasteboard.copied_emitter == nil) then
		table.insert(particlesystem.params.emitters, deepcopy(pasteboard.copied_emitter))
		particlesystem:Invalidate()
		self:SetDirty()
	end

	self.use_windows = ui:_Checkbox("Draw emitters in separate windows", self.use_windows)

	for k,emitter in ipairs(particlesystem.emitters) do
		local emittername = emitter:GetName() or "Emitter_"..k
		if self:RenderEmitterBegin(ui, emittername.."##"..k, k) then
			local totalWidth = ui:GetContentRegionAvail();
			local buttonColumnWidth = 200
			ui:Columns(2, "", false)    -- false to turn off manual resizing
			ui:SetColumnWidth(0, totalWidth-buttonColumnWidth) -- hack to make the left column resize with the window, but the right column be fixed
			ui:PushItemWidth(-70)   -- Use full column width

			if ui:Checkbox("Visible", emitter:IsShown()) then
				emitter:SetShown(not emitter:IsShown())
				self:SetDirty()
			end

			emitter.shouldDrawShape = ui:_Checkbox("Draw Emitter Shape", emitter.shouldDrawShape)

			local use_test_texture_changed, use_test_texture = ui:Checkbox("Use Test Texture", self.use_test_texture)
			if use_test_texture_changed then
				self.use_test_texture = use_test_texture
				local atlas, region
				local params = particlesystem.params
				local texture = params.emitters[k].texture

				if use_test_texture then
					atlas = TEST_PARTICLE_ATLAS
					region = TEST_PARTICLE_REGION
				elseif texture then
					if type(texture) == "table" then
						atlas, region = table.unpack(texture)
					else
						atlas = texture
					end
				end

				emitter.inst.ParticleEmitter:SetTexture("images/"..atlas, region)
			end

			ui:PopItemWidth()

			ui:NextColumn()

			if ui:Button("Delete", buttonColumnWidth) then
				delete_emitter = k
			end

			if ui:Button("Duplicate", buttonColumnWidth) then
				duplicate_emitter = k
			end

			if ui:Button("Copy", buttonColumnWidth) then
				pasteboard.copied_emitter = particlesystem.params.emitters[k]
			end

			if ui:Button("Move Up", buttonColumnWidth, nil, k == 1) then
				move_up_emitter = k
			end

			if ui:Button("Move Down", buttonColumnWidth, nil, k == #particlesystem.emitters) then
				move_down_emitter = k
			end

			if ui:Button("Rename", buttonColumnWidth) then
				self.new_emitter_name = emittername
				ui:OpenPopup("Rename Particle Emitter")
			end
			if ui:BeginPopup("Rename Particle Emitter") then
				ui:Text("New Name...")
				local hit_enter, new_name = ui:InputText("##new_name", self.new_emitter_name, ui.InputTextFlags.CharsNoBlank | ui.InputTextFlags.EnterReturnsTrue | ui.InputTextFlags.AutoSelectAll)
				if new_name ~= nil then
					self.new_emitter_name = new_name
				end
				if hit_enter and string.len(self.new_emitter_name) > 0 then
					emitter:SetName(self.new_emitter_name)
					--self:ClearState()
					--self:PushState()
					self:SetDirty()
					self.new_emitter_name = nil
					ui:CloseCurrentPopup()
				end
				ui:EndPopup()
			else
				self.new_emitter_name = nil
			end

			ui:Columns(1)

			ui:PushItemWidth(-(buttonColumnWidth + 5) - 20) -- Use full column width
			--ui:Indent( 20 )
			ui:PushID( "EMITTER_" .. k )
			self:RenderEmitter(ui, k, emitter)
			ui:PopID()
			--ui:Unindent( 20 )
		end
		self:RenderEmitterEnd(ui)
	end

	if delete_emitter then
		table.remove(particlesystem.params.emitters, delete_emitter)
		particlesystem:Invalidate()
		self:SetDirty()
	end

	if duplicate_emitter then
		table.insert( particlesystem.params.emitters, deepcopy(particlesystem.params.emitters[duplicate_emitter]))
		particlesystem:Invalidate()
		self:SetDirty()
	end

	if move_down_emitter then
		if move_down_emitter < #particlesystem.params.emitters then
			particlesystem.params.emitters[move_down_emitter], particlesystem.params.emitters[move_down_emitter + 1] = particlesystem.params.emitters[move_down_emitter + 1], particlesystem.params.emitters[move_down_emitter]
			particlesystem:Invalidate()
			self:SetDirty()
		end
	end

	if move_up_emitter then
		if move_up_emitter > 1 then
			particlesystem.params.emitters[move_up_emitter], particlesystem.params.emitters[move_up_emitter - 1] = particlesystem.params.emitters[move_up_emitter - 1], particlesystem.params.emitters[move_up_emitter]
			particlesystem:Invalidate()
			self:SetDirty()
		end
	end

	return true

end


function ParticleEditor:RenderPanel( ui )
	if ISDIRTY then
		self:SetDirty()
	end

	-- Push the particle emitter to the front if this editor panel has focus
	local screenAtFront = TheFrontEnd:IsScreenAtFront(self.screen)
	if ui:IsWindowFocused() and not screenAtFront then
		TheFrontEnd:MoveScreenToFront(self.screen)
	end

	-- Set the color of the particle emitter depending on the panel's focus
	self.particles:SetFocusColor(screenAtFront)

	if InGamePlay() then
		if ui:Checkbox("2D Mode", self.mode_2d) then
			self.mode_2d = not self.mode_2d
			self.has_facing = nil
			self.face_left = nil
			self:RespawnParticleSystem()
		end

		if not self.mode_2d then
			ui:SameLineWithSpace(50)
			local changed, face_left = ui:Checkbox("Face Left", self.face_left)
			if ui:IsItemHovered() then
				ui:SetTooltipMultiline({
						"Switch to a worldspace handle that can change facing.",
						"Allows you to preview how the effects behave when their parent changes facing,",
						"but some features don't work (draw emitter shape).",
					})
			end
			if changed then
				self.has_facing = true
				self.face_left = face_left
				self:RespawnParticleSystem()
				-- Not sure why load is necessary, but without it sometimes
				-- there are no emitters after switching between widget and
				-- worldspace handles.
				self:LoadParticlesParams(self.param_id)
			end
		end

		self:AddSectionEnder(ui)
	end

	--Group filter selection
	local grouplist, groupmap = self:GetGroupList()
	local groupidx = table.arrayfind(grouplist, self.groupfilter)
	local newgroupidx = ui:_Combo("Group Filter", groupidx or 1, grouplist)
	if newgroupidx ~= groupidx then
		self.groupfilter = grouplist[newgroupidx] or ""
	end

	self:AddSectionEnder(ui)

	if ui:Button("New") then
		self.new_title = "Name of new system..."
		self.new_btn = "Create"
		self.new_name = ""
		self.new_action = "new"
		ui:OpenPopup("NEW_PARTY_POPUP")
	end

	ui:SameLineWithSpace()

	--Save/Load
	self:PushRedButtonColor(ui)
	if ui:Button("Revert All", nil, nil, not self:IsDirty()) then
		self:Revert()
	end
	ui:SameLineWithSpace()
	if ui:Button("Save All", nil, nil, not self:IsDirty()) then
		self:Save()
	end
	self:PopButtonColor(ui)

	self:AddSectionEnder(ui)

	local param_list = self:GetParticlesList(self.groupfilter)
	local idx = table.arrayfind(param_list, self.param_id)

	local new_idx = ui:_Combo("Particle System", idx or 1, param_list)
	if new_idx ~= idx then
		local new_param_id = param_list[new_idx]
		if new_param_id ~= self.param_id then
			-- Show save alert if dirty, otherwise change category
			if self:IsDirty() then
				self.saveAlert:Activate(ui, self, self.name, function() self:OnParticleEffectChanged(new_param_id) end)
			else
				self:OnParticleEffectChanged(new_param_id)
			end
		end
	end

	local params = self.static.data[self.param_id]
	if params ~= nil then
		ui:Spacing()

		if ui:Button("Clone...") then
			self.new_title = "Name of clone system..."
			self.new_btn = "Create"
			self.new_name = self.param_id.."_copy"
			self.new_action = "clone"
			ui:OpenPopup("NEW_PARTY_POPUP" )
		end

		ui:SameLineWithSpace()

		if ui:Button("Rename...") then
			self.new_title = "Rename system..."
			self.new_btn = "Rename"
			self.new_name = self.param_id
			self.new_action = "rename"
			ui:OpenPopup("NEW_PARTY_POPUP")
		end

		ui:SameLineWithSpace()

		if ui:Button("Delete") then
			ui:OpenPopup(" Confirm delete?")
		end
		if ui:BeginPopupModal(" Confirm delete?", false, ui.WindowFlags.AlwaysAutoResize) then
			ui:Spacing()
			self:PushRedButtonColor(ui)
			ui:Dummy(20, 0)
			ui:SameLine()
			if ui:Button("Delete##confirm") then
				ui:CloseCurrentPopup()
				self.static.data[self.param_id] = nil
				self.param_id = ""
				self:SetDirty()
				self:ClearState()
				self:PushState()
			end
			self:PopButtonColor(ui)
			ui:SameLineWithSpace()
			if ui:Button("Cancel##delete") then
				ui:CloseCurrentPopup()
			end
			ui:SameLine()
			ui:Dummy(20, 0)
			ui:Spacing()
			ui:EndPopup()
		end

		ui:Spacing()

		self:PushGreenButtonColor(ui)
		if ui:Button("Restart") then
			self.particles.particle_system:Reset()
		end
		self:PopButtonColor(ui)

		ui:Spacing()

		if ui:TreeNode("Group (optional)") then
			--Group name
			local groupnameused = self.static.data[params.group] ~= nil
			if groupnameused then
				self:PushRedFrameColor(ui)
			end
			local _, newgroup = ui:InputText("##group", params.group, ui.InputTextFlags.CharsNoBlank)
			if newgroup ~= nil then
				if string.len(newgroup) == 0 then
					newgroup = nil
				end
				if params.group ~= newgroup then
					params.group = newgroup
					self:SetDirty()
					if string.len(self.groupfilter) > 0 and newgroup ~= nil then
						self.groupfilter = newgroup
					end
				end
			end
			if groupnameused then
				self:PopFrameColor(ui)
				ui:Dummy(5, 0)
				ui:SameLine()
				ui:PushStyleColor(ui.Col.Text, { 1, 0, 0, 1 })
				ui:Text("This name is already in use by a particle system")
				ui:PopStyleColor(1)
			end

			self:AddTreeNodeEnder(ui)
		end

		self:AddSectionEnder(ui)

		self:RenderParticleSystem(ui, self.particles.particle_system)
	end

	if ui:BeginPopup("NEW_PARTY_POPUP", ui.WindowFlags.AlwaysAutoResize) then
		ui:Text(self.new_title)
		ui:SetDefaultKeyboardFocus()
		local hit_enter, new_name = ui:InputText("##new_name", self.new_name, ui.InputTextFlags.CharsNoBlank | ui.InputTextFlags.EnterReturnsTrue | ui.InputTextFlags.AutoSelectAll)
		if new_name ~= nil then
			self.new_name = string.lower(new_name)
		end
		local newnameused = self.static.data[self.new_name] ~= nil or groupmap[self.new_name]
		if self.new_action == "rename" then
			newnameused = newnameused and self.new_name ~= self.param_id
		end
		local invalidName = not fileutil.IsValidFilename(self.new_name)
		local newbtndisabled = newnameused or invalidName or string.len(self.new_name) <= 0
		if ui:Button(self.new_btn, nil, nil, newbtndisabled) or (hit_enter and not newbtndisabled) then
			if self.new_action == "new" then
				params = deepcopy(default_params)
				params.mode_2d = self.mode_2d
				if string.len(self.groupfilter) > 0 then
					params.group = self.groupfilter
				end
				self.static.data[self.new_name] = params
				self.param_id = self.new_name
				self:LoadParticlesParams(self.param_id)
				self:SetDirty()
				self:ClearState()
				self:PushState()
			elseif self.new_action == "clone" then
				params = deepcopy(params)
				self.static.data[self.new_name] = params
				self.param_id = self.new_name
				self:LoadParticlesParams(self.param_id)
				self:SetDirty()
				self:ClearState()
				self:PushState()
			elseif self.new_action == "rename" then
				if self.new_name ~= self.param_id then
					self.static.data[self.new_name] = params
					self.static.data[self.param_id] = nil
					self.param_id = self.new_name
					self:SetDirty()
					self:PushState()
				end
			end

			self.new_title = nil
			self.new_btn = nil
			self.new_name = nil
			self.new_action = nil

			ui:CloseCurrentPopup()
		end

		if newnameused then
			ui:SameLineWithSpace()
			ui:PushStyleColor(ui.Col.Text, { 1, 0, 0, 1 })
			ui:Text("This name is already in use")
			ui:PopStyleColor(1)
		end
		if invalidName and string.len(self.new_name) > 0 then
			ui:SameLineWithSpace()
			ui:PushStyleColor(ui.Col.Text, { 1, 0, 0, 1 })
			ui:Text("Invalid name - only Alphanumeric characters, spaces, dashes, underscores, and dots are allowed")
			ui:PopStyleColor(1)
		end

		if ui:Button("Cancel") then
			self.new_title = nil
			self.new_btn = nil
			self.new_name = nil
			self.new_action = nil

			ui:CloseCurrentPopup()
		end

		ui:EndPopup()
	else
		self.new_title = nil
		self.new_btn = nil
		self.new_name = nil
		self.new_action = nil
	end

	local pending = false

	-- Save alert when switching categories
	if self.saveAlert:IsActive() then
		self.saveAlert:Render(ui)
	end
--[[
TODO_KAJ
	for k,v in ipairs(self.particles.particle_system.emitters) do
		if v.pending then
			pending = true
		end
	end
	local mouse_down = ui:IsMouseDown(0)
	if not mouse_down and pending then
		for k,v in ipairs(self.particles.particle_system.emitters) do
			v.pending = false
		end
		self:PushState()
	end
]]
end

function ParticleEditor:ClearState( )
	self.undo_stack = {}
	self.undo_ptr = 1
end

function ParticleEditor:PushState( )
	local old_sz = #self.undo_stack
	local params = deepcopy(self.particles.particle_system.params)
	self.undo_stack[self.undo_ptr] = params
	self.undo_ptr = self.undo_ptr + 1
	for k = self.undo_ptr, old_sz do
		self.undo_stack[k] = nil
	end
end

function ParticleEditor:Undo()
	if self.undo_ptr > 2 then
		self.undo_ptr = self.undo_ptr - 1
		local params = self.undo_stack[self.undo_ptr-1]
		self.particles.particle_system:SetParams(deepcopy(params))
	end
end

function ParticleEditor:Redo()

	if self.undo_ptr < #self.undo_stack +1 then

		local params = self.undo_stack[self.undo_ptr]
		self.particles.particle_system:SetParams(deepcopy(params))
		self.undo_ptr = self.undo_ptr + 1
	end
end


function ParticleEditor:HandleControlDown(controls)

	if controls:Has( Controls.Digital.PLAX_EDIT_REDO ) then
		self:Redo()
		return true

	elseif controls:Has( Controls.Digital.PLAX_EDIT_UNDO ) then
		self:Undo()
		return true
	end
end

DebugNodes.ParticleEditor = ParticleEditor

return ParticleEditor
