local kassert = require "util.kassert"
local lume = require "util.lume"
local DebugDraw = require "util.debugdraw"
local prop_data      = require "prefabs.prop_autogen_data"
local Hsb = require "util.hsb"

local fade_defaults = {bottom = -1024, top = -1023}

LastDragProp = nil

function UndoLastPropMove()
	if LastDragProp and LastDragProp.prop:IsValid() then
		LastDragProp.prop.Transform:SetPosition(LastDragProp.position.x, LastDragProp.position.y, LastDragProp.position.z)
	end
	LastDragProp = nil
end

-- The drag anchor is the point clicked on when the drag starts.
-- The y-value is fixed at this time such that the drag will occur on a single xz-plane.
local function ComputeDragAnchor(inst)
	local prop_position = inst:GetPosition()
	local drag_anchor = {}
	local x, y, z
	if inst.AnimState ~= nil then
		x, y, z = inst.AnimState:RayTestBBWorldPosition(TheInput:GetMousePos())
	end
	if y ~= nil then
		drag_anchor.y = y
	else
		drag_anchor.y = prop_position.y
		x, z = TheInput:GetWorldXZWithHeight(drag_anchor.y)
	end
	drag_anchor.x = x
	drag_anchor.z = z
	return drag_anchor
end

local function ComputeDrag(inst, drag_anchor)
	local prop_position = inst:GetPosition()
	local drag = {}

	-- The drag offset is the delta between the drag anchor and the prop position, on the selected xz-plane.
	-- Add the prop's drag.offset to the current drag position (the xz coordinate that our mouse maps to) to
	-- determine the prop's current projected position on that plane.
	drag.offset = {
		x = prop_position.x - drag_anchor.x,
		z = prop_position.z - drag_anchor.z
	}

	-- Remember the prop's y as it will not be changing.
	drag.y = prop_position.y

	-- Preserve the drag height so we can use TheInput:GetWorldXZWithHeight() to translate mouse coordinates to our
	-- chosen xz-plane (as defined by drag.height).
	drag.height = drag_anchor.y

	return drag
end

local function OnStartDragging(inst)
	local prop = inst.components.prop
	if prop.drag then
		return
	end
	LastDragProp = { prop = inst, position = inst:GetPosition() }

	prop.drag = ComputeDrag(inst, ComputeDragAnchor(inst))

	inst:StartWallUpdatingComponent(prop)
	if inst.components.snaptogrid ~= nil then
		inst.components.snaptogrid:SetDebugDrawEnabled(true)
	end
end

local function OnStopDragging(inst)
	local self = inst.components.prop
	if not self.drag then
		return
	end

	self.drag = nil

	inst:StopWallUpdatingComponent(self)
	if inst.components.snaptogrid ~= nil then
		inst.components.snaptogrid:SetDebugDrawEnabled(false)
	end
	self:OnPropChanged()
end

local function FindRoot(inst)
	local root = inst
	while true do
		local parent = root.entity:GetParent()
		if parent then
			root = parent
		else
			return root
		end
	end
end

local function OnStartDraggingHierarchy(inst)
	OnStartDragging(FindRoot(inst))
end

local function OnStopDraggingHierarchy(inst)
	OnStopDragging(FindRoot(inst))
end

local function OnMouseOver(inst)
	if inst.components.prophighlight == nil then
		inst:AddComponent("prophighlight")
	end
end

local function OnMouseOut(inst)
	OnStopDragging(inst)
	if inst.components.prophighlight ~= nil then
		inst:RemoveComponent("prophighlight")
	end
end

local function OnFlipProp(inst)
	local self = inst.components.prop
	self:DoFlipProp()
	self:OnPropChanged()
end

local function OnDeleteProp(inst)
	if inst.components.prophighlight ~= nil then
		inst:Remove()
	end
end

local function OnPlaceAnywhereProp(inst, place_anywhere)
	local self = inst.components.prop
	self.place_anywhere = place_anywhere

	local snaptogrid = inst.components.snaptogrid
	if snaptogrid then
		snaptogrid:SetPlaceAnywhere(place_anywhere)
	end
end

local Prop = Class(function(self, inst)
	self.inst = inst
	self.drag = nil
	self.flip = nil

	self.numvariations = nil
	self.variation = nil
	self.looping = nil
	self.randomstartframe = nil
	self.basehsb = nil

	self.basefade = deepcopy(fade_defaults)
	self.fade = nil

	inst:AddTag("prop")

	if TheWorld.components.propmanager ~= nil then
		if TheDungeon:GetDungeonMap():IsDebugMap() then
			inst:AddTag("editable")
			self:ListenForEdits()
		end

		self.data = TheWorld.components.propmanager:RegisterProp(inst)
	end
end)

function Prop:DoFlipProp()
	self.flip = not self.flip or nil
	local xscale = self.flip and -1 or 1
	if self.inst.AnimState ~= nil then
		self.inst.AnimState:SetScale(xscale, 1)
	end
	if self.inst.highlightchildren ~= nil then
		for i = 1, #self.inst.highlightchildren do
			local child = self.inst.highlightchildren[i]
			if child.AnimState ~= nil then
				child.AnimState:SetScale(xscale, 1)
			end
			local xp, yp, zp = child.Transform:GetLocalPosition()
			child.Transform:SetPosition(xp * -1, yp, zp)
		end
	end
end

function Prop:OnNetSerialize()
	local e = self.inst.entity
	e:SerializeBoolean(self.variation ~= nil)
	if self.variation then
		e:SerializeUInt(self.variation, 4)
	end
end

function Prop:OnNetDeserialize()
	local e = self.inst.entity
	local has_variation = e:DeserializeBoolean()
	if has_variation then
		local old_variation = self.variation
		self.variation = e:DeserializeUInt(4)
		if old_variation ~= self.variation then
			assert(self.numvariations)
			self:SetVariationInternal(self.variation)
		end
	end
end

function ForEachInHierarchy(inst, prop_fn, BeginBatch, EndBatch)
	local props = {inst}
	local parent = inst.entity:GetParent()
	if parent then
		table.insert(props, parent.child_prop)
	end
	if BeginBatch then
		BeginBatch(props)
	end
	for _, prop in ipairs(props) do
		prop_fn(prop)
	end
	if EndBatch then
		EndBatch(props)
	end
end

function Prop:FlipProp()
	OnFlipProp(self.inst)
	if not self.data then
		self.data = {}
	end
	self.data.flip = self.flip
end

-- Prop clusters/hierarchies/assemblies are treated differently depending on whether or
-- not we are editing in the context of the PropEditor or the EditableEditor.
function Prop:ListenForEdits(break_hierarchy)
	self:StopListeningForEdits()
	if break_hierarchy then
		self.edit_listeners = {
			["propmouseover"] = OnMouseOver,
			["propmouseout"] = OnMouseOut,
			["startdraggingprop"] = OnStartDragging,
			["stopdraggingprop"] = OnStopDragging,
			["flipprop"] = OnFlipProp,
			["deleteprop"] = OnDeleteProp,
		}
	else
		self.edit_listeners = {
			["propmouseover"] = function(inst) ForEachInHierarchy(inst, OnMouseOver) end,
			["propmouseout"] = function(inst) ForEachInHierarchy(inst, OnMouseOut) end,
			["startdraggingprop"] = OnStartDraggingHierarchy,
			["stopdraggingprop"] = OnStopDraggingHierarchy,
			["flipprop"] = function(inst) ForEachInHierarchy(inst, OnFlipProp) end,
			["deleteprop"] = function(inst) ForEachInHierarchy(inst, OnDeleteProp) end,
		}
	end
	for event, listener in pairs(self.edit_listeners) do
		self.inst:ListenForEvent(event, listener)
	end
end

function Prop:IgnoreEdits()
	-- Clear editing state if it was active.
	OnMouseOut(self.inst)
	self:StopListeningForEdits()
end

function Prop:StopListeningForEdits()
	if not self.edit_listeners then
		return
	end
	for event, listener in pairs(self.edit_listeners) do
		self.inst:RemoveEventCallback(event, listener)
	end
	self.edit_listeners = nil
end

function Prop:SetPropType(proptype)
	self.proptype = proptype
end

function Prop:GetPropType()
	return self.proptype or PropType.Grid
end

-- Params is the table for this prop as seen in prefabs.autogen.prop.XXX.lua.
function Prop:SetupParams(params, rng)
	--Anim configuration
	self.numvariations = params.variations ~= nil and params.variations > 0 and params.variations or nil
	self.looping = params.looping or nil
	self.randomstartframe = self.looping and params.randomstartframe or nil

	--Set initial animation (picks random variation)
	local variation = self.numvariations ~= nil
		and rng:Integer(self.numvariations)
		or nil
	self:SetVariationInternal(variation, rng)

	self.basehsb = Hsb.FromRawTable(params)
	self.basefade = deepcopy(params.fade or fade_defaults)
end

function Prop:SetFade(fadebottom, fadetop)
	self:SetFadeInternal(fadebottom, fadetop)
	self:OnPropChanged()
end

function Prop:GetVariation()
	return self.variation
end

function Prop:SetVariation(variation)
	self:SetVariationInternal(variation)
	self:OnPropChanged()
end

function Prop:SetVariationOverride(num)
	self:SetVariation(num)
	if not self.data then
		self.data = {}
	end
	self.data.variation = self.variation
end

function Prop:SetVariationInternal(variation, rng)
	if not self.numvariations then
		-- Ignore legacy variation data if we removed them.
		variation = nil
	elseif variation > self.numvariations then
		-- Fallback to last variation rather than using an invalid one.
		--~ TheLog.ch.Prop:printf("Invalid variation %i on '%s' placement in '%s'.", variation, self.inst.prefab, TheWorld.prefab)
		variation = self.numvariations
	end
	self.variation = variation
	rng = rng or TheWorld.prop_rng
	local frame
	if self.inst.AnimState ~= nil then
		local anim = "idle_".. self.inst.baseanim
		if self.inst.use_baseanim_for_idle then
			anim = self.inst.baseanim
		end
		if variation ~= nil then
			anim = anim..tostring(variation)
		end
		self.inst.AnimState:PlayAnimation(anim, self.looping)
		if self.looping and self.randomstartframe then
			-- When we play an invalid anim, GetCurrentAnimationNumFrames will
			-- assert in native. dbassert earlier to identify the prop, but
			-- only in debug builds.
			dbassert(kassert.assert_fmt(self.inst.AnimState:HasAnimation(), "Prop '%s' has invalid animation.", self.inst.prefab))
			frame = rng:Integer(self.inst.AnimState:GetCurrentAnimationNumFrames()) - 1
			self.inst.AnimState:SetFrame(frame)
		end
	end
	if self.inst.highlightchildren ~= nil then
		for i = 1, #self.inst.highlightchildren do
			local child = self.inst.highlightchildren[i]
			if child.AnimState ~= nil then
				local anim = "idle_".. child.baseanim
				if child.use_baseanim_for_idle then
					anim = child.baseanim
				end
				if variation ~= nil then
					anim = anim..tostring(variation)
				end
				child.AnimState:PlayAnimation(anim, self.looping)
				if frame ~= nil then
					child.AnimState:SetFrame(frame)
				elseif self.looping and self.randomstartframe then
					frame = rng:Integer(child.AnimState:GetCurrentAnimationNumFrames()) - 1
					child.AnimState:SetFrame(frame)
				end
			end
		end
	end
end

function Prop:SetFadeInternal(fadebottom, fadetop)
	local fade = {bottom = fadebottom, top = fadetop}
	if  deepcompare(fade, self.basefade) then
		self.fade = nil
	else
		self.fade = deepcopy(fade)
	end
	if self.inst.AnimState ~= nil then
		self.inst.AnimState:SetFadeValues(fade.bottom, fade.top)
	end
	if self.inst.highlightchildren ~= nil then
		for i = 1, #self.inst.highlightchildren do
			local child = self.inst.highlightchildren[i]
			if child.AnimState ~= nil then
				child.AnimState:SetFadeValues(fade.bottom, fade.top)
			end
		end
	end
end

function Prop:SetHsb(hsb)
	hsb:Set(self.inst)
	if self.inst.highlightchildren then
		for _, child in ipairs(self.inst.highlightchildren) do
			hsb:Set(child)
		end
	end
end

function Prop:ShiftHsb(hsb)
	hsb:Shift(self.inst)
	if self.inst.highlightchildren then
		for _, child in ipairs(self.inst.highlightchildren) do
			hsb:Shift(child)
		end
	end
end

function Prop:IsDragging()
	return self.drag ~= nil
end

function Prop:OnPropChanged(force_dirty)
	if TheWorld.components.propmanager == nil then
		return
	end

	if not self.data then
		print("Warning: Prop will not be saved.")
		self.inst:PushEvent("propchanged")
		return
	end

	local x, y, z = self.inst.Transform:GetWorldPosition()
	if self.inst.components.snaptogrid ~= nil then
		local snapped_x, snapped_y, snapped_z = self.inst.components.snaptogrid:MoveToNearestGridPos(x, y, z, false)
		if snapped_x ~= nil then
			x, y, z = snapped_x, snapped_y, snapped_z
		end
	else
		x = lume.round(x, 0.01)
		y = lume.round(y, 0.01)
		z = lume.round(z, 0.01)
	end
	self.inst.Transform:SetWorldPosition(x, y, z)

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

	local r = self.inst.Transform:GetRotation()
	r = lume.round(r, 0.01)
	if (self.data.r or 0) ~= r then
		self.data.r = r ~= 0 and r or nil
		dirty = true
	end
	if (not self.data.flip) ~= (not self.flip) then
		self.data.flip = self.flip or nil
		dirty = true
	end
	if (not self.data.place_anywhere) ~= (not self.place_anywhere) then
		self.data.place_anywhere = self.place_anywhere or nil
		dirty = true
	end
	if self.data.variation ~= self.variation then
		self.data.variation = self.variation
		dirty = true
	end
	if self.data.hue ~= self.hue then
		self.data.hue = self.hue
		dirty = true
	end
	if self.data.saturation ~= self.saturation then
		self.data.saturation = self.saturation
		dirty = true
	end
	if self.data.brightness ~= self.brightness then
		self.data.brightness = self.brightness
		dirty = true
	end
	if deepcompare(self.data.fade, self.fade) == false then
		self.data.fade = deepcopy(self.fade)
		if self.data.fade then
			self.data.fade.bottom = lume.round(self.data.fade.bottom, 0.01)
			self.data.fade.top = lume.round(self.data.fade.top, 0.01)
		end

		dirty = true
	end

	if not deepcompare(self.data.script_args, self.script_args) then
		self.data.script_args = deepcopy(self.script_args)
		dirty = true
	end

	if dirty or force_dirty then
		TheWorld.components.propmanager:SetDirty()
	end

	self.inst:PushEvent("propchanged")
end

function Prop:OnSave()
	if self.data ~= nil then
		local data = deepcopy(self.data)
		data.x, data.y, data.z, data.r = nil, nil, nil, nil
		return next(data) ~= nil and data or nil
	end
end

function Prop:OnLoad(data)
	self.data = data
	self:OnLoadInternal()
end

--Only called by PropManager
function Prop:OnLoadProp()
	assert(self.data, self.inst.prefab)
	local x = self.data.x or 0
	local y = self.data.y or 0
	local z = self.data.z or 0
	local r = self.data.r or 0
	if self.inst.components.snaptogrid ~= nil then
		x, y, z = self.inst.components.snaptogrid:SetNearestGridPos(x, y, z, true)
	end
	self.inst.Transform:SetWorldPosition(x, y, z)
	if r ~= 0 then
		self.inst.Transform:SetRotation(r)
	end
	self:OnLoadInternal()
end

local function run_script_fn(script, params, fn)
	if script then
		local require_succeeded, script_module = pcall(function()
			return require("prefabs.customscript.".. script)
		end)
		if not require_succeeded then
			error(("Unknown prefab customscript file: %s"):format(script))
			return false
		end
		return fn(script_module, params)
	end
end

function Prop:OnLoadInternal()
	if (not self.data.flip) ~= (not self.flip) then
		self:DoFlipProp()
	end
	if (not self.data.place_anywhere) ~= (not self.place_anywhere) then
		OnPlaceAnywhereProp(self.inst, self.data.place_anywhere)
	end

	if self.data.variation ~= nil then
		self:SetVariationInternal(self.data.variation, TheWorld.prop_rng)
	end

	-- Transfer save data to runtime data.
	if self.data.color_variant then
		self:ShiftHsb(Hsb.FromRawTable(self.data.color_variant))
	end

	if self.data.fade ~= nil then
		self:SetFadeInternal(self.data.fade.bottom, self.data.fade.top)
	end

	-- do I have custom prop settings?
	if self.data.script_args then
		self.script_args = deepcopy(self.data.script_args)
		local prop_settings = prop_data[self.inst.prefab]
		local script = prop_settings and prop_settings.script
		if script then
			run_script_fn(script, {}, function(scriptclass, _)
						if scriptclass.Apply then

							local prop_params = deepcopy(scriptclass.Defaults)
							for i,v in pairs(prop_settings.script_args or {}) do
								prop_params[i] = v
							end
							-- make our merged params
							for i,v in pairs(self.script_args or {}) do
								prop_params[i] = v
							end

							scriptclass.Apply(self.inst, prop_params)
						elseif self.inst.LoadScriptArgs ~= nil then
							-- Load data from objects that don't have prop_settings (e.g. spawners)
							self.inst:LoadScriptArgs(self.script_args)
						end
					end)
		elseif self.inst.LoadScriptArgs ~= nil then
			-- Load data from objects that don't have prop_settings (e.g. spawners)
			self.inst:LoadScriptArgs(self.script_args)
		end
	end
end

-- Copied from debugdraw.GroundPoint and modified to accept a y.````
local function DebugDrawPoint(x, y, z, radius, color, thickness, lifetime)
	local p1 = { x - radius, y, z }
	local p2 = { x + radius, y, z }
	TheDebugRenderer:WorldLine(p1, p2, color, thickness, lifetime)
	p1 = { x, y, z - radius }
	p2 = { x, y, z + radius }
	TheDebugRenderer:WorldLine(p1, p2, color, thickness, lifetime)
end

function Prop:OnWallUpdate(dt)
	local POINT_SIZE = 0.5

	local x, z = TheInput:GetWorldXZWithHeight(self.drag.height)

	-- Cursor location.
	DebugDrawPoint(x, self.drag.height, z, POINT_SIZE, WEBCOLORS.GREEN)

	-- Cursor projected onto the drag plane.
	DebugDraw.GroundPoint(x, z, POINT_SIZE, WEBCOLORS.BLUE)

	x = x + self.drag.offset.x
	z = z + self.drag.offset.z
	local y = self.drag.y

	-- Ideal prop location.
	DebugDrawPoint(x,y, z, POINT_SIZE, WEBCOLORS.PURPLE)

	if self.inst.components.snaptogrid ~= nil then
		x, y, z = self.inst.components.snaptogrid:MoveToNearestGridPos(x, y, z, false)
	end
	self.inst.Transform:SetWorldPosition(x, y, z)

	-- Resultant (i.e. maybe snapped) prop location.
	DebugDraw.GroundPoint(x, z, POINT_SIZE, WEBCOLORS.RED)
end

--------------------------------------------------------------------------

function Prop:EditEditable(ui)

	local is_on_ground = false
	if self.inst.AnimState then
		local ao = self.inst.AnimState:GetOrientation()
		is_on_ground = ao == ANIM_ORIENTATION.OnGround or ao == ANIM_ORIENTATION.OnGroundFixed
	end

	local pos = self.inst:GetPosition()
	if ui:DragVec3f("Position", pos, 0.5, -100, 100) then
		self.show_grid_warning = (is_on_ground or self.inst.components.snaptogrid) and pos.y ~= 0 or nil
		if self.show_grid_warning then
			pos.y = 0
		end
		self.inst.Transform:SetPosition(pos:unpack())
		-- Snaps grid props but not ground projected props.
		self:OnPropChanged()
	end
	if self.show_grid_warning then
		ui:TextColored(WEBCOLORS.YELLOW, "Warning: Grid props must have y = 0")
	end

	if is_on_ground and self.inst.AnimState then
		local rot = self.inst.Transform:GetRotation()
		local rotationChanged = false
		rotationChanged, rot = ui:DragFloat( "Rotation##Transform", rot, .1, -360, 360, "%.1fº")
		if rotationChanged then
			self.inst.Transform:SetRotation(rot)
			self:OnPropChanged()
		end
	end

	local flip = ui:Checkbox("Flipped", self.flip or false)
	if flip then
		OnFlipProp(self.inst)
	end

	local place_anywhere_changed, place_anywhere = ui:Checkbox("Place Anywhere", self.place_anywhere or nil)
	if place_anywhere_changed then
		OnPlaceAnywhereProp(self.inst, place_anywhere)
		self:OnPropChanged()
	end
	if ui:IsItemHovered() then
		ui:SetTooltip("Allows you to place this prop on non-ground areas.")
	end

	if self.numvariations ~= nil then
		local resize = ui:GetColumnWidth() > 210
		if resize then
			ui:PushItemWidth(150)
		end
		local _, variation = ui:InputInt("Variations ("..tostring(self.numvariations).." total)", self.variation or 1, 1, self.numvariations)
		if resize then
			ui:PopItemWidth()
		end
		if variation ~= nil then
			variation = math.clamp(variation, 1, self.numvariations)
			if variation ~= self.variation then
				self:SetVariation(variation)
			end
		end
	end

	ui:Separator()
	ui:Text("Colorize - HSB Shift")

	self:HsbUi(ui)

	ui:Separator()
	ui:Text("Fade")

	local total_width = ui:GetContentRegionAvail()
	local width = total_width * 0.7
	ui:PushItemWidth(width) do
		if ui:Button("Reset to default##fade") then
			self:SetFade(self.basefade.bottom, self.basefade.top)
		end
		local fade = self.fade or self.basefade
		local hasfade = deepcompare(fade, fade_defaults) == false
		local changed, newfade = ui:Checkbox("Fade", hasfade)
		if newfade then
			if not hasfade then
				if deepcompare(fade, fade_defaults) then
					fade = {bottom = -1, top = 3}
				end
			end
			local bottomchanged, newbottom = ui:SliderFloat("Bottom (full black)", fade.bottom, -10, 20, "%.2f")
			local topchanged, newtop = ui:SliderFloat("Top (full color)", fade.top, -10, 20,"%.2f")
			if not hasfade or bottomchanged or topchanged then
				self:SetFade(newbottom, newtop)
			end
		else
			self:SetFade(fade_defaults.bottom, fade_defaults.top)
		end

		if newfade then
			local fade = self.fade or self.basefade
			self.edit_fade = ("%.2f|%.2f"):format(fade.bottom, fade.top)

			local value = ui:CopyPasteButtons("++fade", "##fade", self.edit_fade)
			if value then
				self:_TrySetFadeFromString(value)
			end
			ui:SameLineWithSpace()

			local button_width = total_width - ui:GetContentRegionAvail()
			ui:PushItemWidth(width - button_width) do
				local changed, value = ui:InputText("Copyable Fade", self.edit_fade, ui.InputTextFlags.AutoSelectAll)
				if changed then
					self:_TrySetFadeFromString(value)
				end
				ui:PopItemWidth()
			end
		end

		ui:PopItemWidth()
	end
end

function Prop:HsbUi(ui)
	if not self.data then
		self.data = {}
	end
	local color_variant = self.data.color_variant or {}
	if Hsb.RawUi(ui, "##hsb", color_variant) then
		self:SetHsb(self.basehsb)
		self:ShiftHsb(Hsb.FromRawTable(color_variant))
		self.data.color_variant = color_variant

		if TheWorld and TheWorld.components.propmanager then
			TheWorld.components.propmanager:SetDirty()
		end
		self.inst:PushEvent("propchanged")
	end
end

function Prop:_TrySetFadeFromString(value)
	local fade = lume.split(value, "|")
	fade = lume.map(fade, tonumber)
	if fade[1] and fade[2] then
		self:SetFade(fade[1], fade[2])
	end
end

Prop.EditableName = "Prop Settings"


function Prop:DebugDrawEntity(ui, panel, colors)
	if ui:CollapsingHeader("Children", ui.TreeNodeFlags.DefaultOpen) then
		ui:Indent()
		local children = self.inst.highlightchildren or {}
		for i,child in ipairs(children) do
			panel:AppendTable(ui, child, ("layer[%s] -- %s"):format(child.baseanim, child))
			if ui:IsItemHovered() then
				DebugDraw.GroundHex(child:GetPosition(), nil, 1, WEBCOLORS.YELLOW)
			end
		end
		ui:Unindent()
	end
end

return Prop
