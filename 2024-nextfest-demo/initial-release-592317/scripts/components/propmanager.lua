local DataDumper = require "util.datadumper"
local DebugNodes = require "dbui.debug_nodes"
local kassert = require "util.kassert"
local ParticleSystem = require "components/particlesystem"
local iterator = require "util.iterator"
local allpropdata = require "prefabs.prop_autogen_data"
local Canopy = require "prefabs.customscript.canopy"
local LightSpot = require "prefabs.customscript.lightspot"
local Hsb = require "util.hsb"

require "util.tableutil"
require "constants"

-- PropManager is for saving/loading props when editing levels. It may not
-- exist in runtime levels.
local PropManager = Class(function(self, inst)
	self.inst = inst
	self.data = nil
	self.filenames = nil
	self.temploading = nil

	self.dirty = false
	self.originaldata = nil
end)

PropManager.CollectPrefabs = function(prefabs, filename)
	local mod_name = "map.propdata."..filename
	if not kleimoduleexists(mod_name) then
		return
	end
	local data = require(mod_name)
	if type(data) == "table" then
		for prefab in pairs(data) do
			prefabs[#prefabs + 1] = prefab
		end
	end
end

function PropManager:SetDataFiles(filenames)
	assert(self.data == nil, "PropManager already initialized.")
	self.filenames = filenames
end

local function UnregisterProp(prop, allow_missing)
	if prop._propmanagertask ~= nil then
		prop._propmanagertask:Cancel()
		prop._propmanagertask = nil
	end

	local savefile = prop.components.prop.savefile
	-- TODO @chrisp #scenegen - I got a bad feeling I am abusing PropManager, using
	-- it at runtime when I should not be
	if not savefile then
		return
	end
	assert(savefile or allow_missing, prop.prefab)

	local self = TheWorld.components.propmanager
	local filedata = self.data[savefile]
	local t = filedata and filedata[prop.prefab]
	kassert.assert_fmt(t or allow_missing, "Unregistering unknown prop '%s'.", prop.prefab)
	if t then
		table.removearrayvalue(t, prop.components.prop.data)
		if #t <= 0 then
			filedata[prop.prefab] = nil
		end
	end
	self:SetDirty()
end

local function SaveNewProp(prop, self)
	prop._propmanagertask = nil
	local savefile = DebugNodes.EditableEditor.GetCurrentSaveFile()
	assert(savefile, "Failed to determine save file?")
	prop.components.prop.savefile = savefile
	local filedata = self.data[savefile]
	if not filedata then
		TheLog.ch.Prop:print("Creating new filedata for file:", savefile)
		filedata = {}
		self.data[savefile] = filedata
		table.insert(self.filenames, savefile)
	end
	local t = filedata[prop.prefab] or {}
	filedata[prop.prefab] = t
	t[#t + 1] = prop.components.prop.data
	local force_dirty = true -- new, but maybe nothing changed since creation.
	prop.components.prop:OnPropChanged(force_dirty)
end

function PropManager:RegisterProp(prop)
	if self.data == nil or not prop.persists then
		return
	end

	local prop_data = self.temploading or {}

	-- Only track if we're in edit mode. No reason to track props during
	-- gameplay.
	if TheInput:IsEditMode() then
		self.inst:ListenForEvent("onremove", UnregisterProp, prop)
		if not self.temploading then
			-- Spawned a new prop
			self:SetDirty()

			--Create new blank data when debug spawning and save it next
			--frame after its prefab and position have been initialized.
			prop._propmanagertask = prop:DoTaskInTicks(0, SaveNewProp, self)
		end
	end
	return prop_data
end

function PropManager:Debug_ForceUnregisterProp(prop)
	UnregisterProp(prop, true)
	self.inst:RemoveEventCallback("onremove", UnregisterProp, prop)
end

function PropManager:RandomizePropData(prop, random_displace, force_randomize)
	local data = prop.components.prop.data

	local prefab = prop.prefab

	local propdata = allpropdata[prefab]
	if propdata then
		if propdata.randomize or force_randomize then
			-- select a random variation?
			if propdata.variations then
				data.variation = TheWorld.prop_rng:Integer(1, propdata.variations)
			end
			-- to visalize what props are affected for debugging
			-- data.brightness = 500
			-- data.saturation = 500
		end
		if propdata.randomflip or force_randomize then
			data.flip = TheWorld.prop_rng:Float() < 0.5
			-- to visalize what props are affected for debugging
			-- data.brightness = 500
			-- data.saturation = 500
		end
		if random_displace then
			if data.x then
				data.x = data.x + TheWorld.prop_rng:Float(random_displace) - random_displace / 2
			end
			if data.z then
				data.z = data.z + TheWorld.prop_rng:Float(random_displace) - random_displace / 2
			end
		end
	end
end

function PropManager:SpawnProp(prefab_name, placement, savefile, force_randomize)
	local spawned_props = {}

	--Prop will attempt to register itself when spawned in order to get
	--a link to its data table.  Since we're loading, we want to return
	--this table rather than creating a new one.
	self.temploading = placement
	local prop = SpawnPrefab(prefab_name, self.inst)
	if prop == nil then
		self.temploading = nil
		TheLog.ch.Prop:printf("Warning: failed to load prop '%s'", prefab_name)
		return spawned_props
	end
	table.insert(spawned_props, prop)

	-- if it's a particlesystem, then make it a prop
	if prop.components.particlesystem then
		ParticleSystem.MakeProp(prop)
		if placement.particle_system then
			ParticleSystem.SetLayerOverride(prop, placement.particle_system.layer_override)
		end
	end

	if prop:HasTag("FX") then
		prop.Transform:SetWorldPosition(placement.x or 0, placement.y or 0, placement.z or 0)
	end

	self.temploading = nil

	-- Translate old data (hsb) into new data (color_variant) on the fly (because I am too lazy to track down and change
	-- all the data).
	placement.color_variant = placement.color_variant or placement.hsb

	if prop.components.prop ~= nil then
		prop.components.prop.savefile = savefile

		if not TheDungeon:GetDungeonMap():IsDebugMap() then
			self:RandomizePropData(prop, nil, force_randomize)
		end

		prop.components.prop:OnLoadProp()
	else
		-- OnLoadProp() will effect the color shift, but if we are loading from a save game, we need to do it explicitly.
		if placement.color_variant then
			prop.components.prop:ShiftHsb(Hsb.FromRawTable(placement.color_variant))
		end
	end

	if placement.canopy then
		Canopy.Apply(prop, placement.canopy.script_args)
	end

	if placement.light_spot then
		LightSpot.Apply(prop, placement.light_spot.script_args)
	end

	-- Inherit all the placement's tags.
	if placement.tags then
		for _, tag in ipairs(placement.tags) do
			prop:AddTag(tag)
		end
	end

	return spawned_props
end

function PropManager:SpawnStaticProps(layout)
	assert(self.data == nil, "PropManager already initialized.")
	assert(self.filenames, "PropManager data filenames not set.")
	dbassert(not self.dirty)
	dbassert(self.originaldata == nil)

	self.data = {}
	for _, savefile in ipairs(self.filenames) do
		print("PropManager:SpawnStaticProps " .. savefile)
		local mod_name = "map.propdata." .. savefile
		if kleimoduleexists(mod_name) then
			self.data[savefile] = {}
			local filedata = self.data[savefile]
			local data = require(mod_name)
			kassert.typeof("table", data)
			-- Each prefab is used as a key of the filedata table, with the associated type being an array of placements.
			for prefab, placements in pairs(data) do
				filedata[prefab] = table.appendarrays(filedata[prefab] or {}, placements)
			end
		else
			TheLog.ch.Prop:printf("Failed to load module: %s for world '%s'.", mod_name, TheWorld.prefab)
		end
	end

	local spawned_props = {}
	for savefile, filedata in iterator.sorted_pairs(self.data) do -- @chrisp #proc_rng - sort for determinism
		for prefab, placements in iterator.sorted_pairs(filedata) do -- @chrisp #proc_rng - sort for determinism
			for i = 1, #placements do
				spawned_props = table.appendarrays
					(spawned_props
					, self:SpawnProp(prefab, placements[i], savefile, false)
					)
			end
		end
	end

	if TheDungeon:GetDungeonMap():IsDebugMap() then
		self.originaldata = deepcopy(self.data)
	end

	return spawned_props
end

function PropManager:SpawnDynamicProps(dynamic_props)
	local spawned_props = {}
	for prefab, placements in iterator.sorted_pairs(dynamic_props) do -- @chrisp #proc_rng - sort for determinism
		for i = 1, #placements do
			spawned_props = table.appendarrays
				(spawned_props
				, self:SpawnProp(prefab, placements[i], nil, false)
				)
		end
	end
	return spawned_props
end

function PropManager:SaveAllProps()
	assert(self.data ~= nil, "PropManager not initialized.")

	if self.dirty then
		for savefile, filedata in pairs(self.data) do
			local filepath = "scripts/map/propdata/"..savefile..".lua"
			TheLog.ch.Prop:print("Saving:", filepath)
			TheSim:DevSaveDataFile(filepath, DataDumper(filedata, nil, false))
		end
		self.originaldata = deepcopy(self.data)
		self.dirty = false
	end
end

function PropManager:SetDirty()
	if self.originaldata ~= nil then
		self.dirty = not deepcompare(self.originaldata, self.data)
	else
		self.dirty = true
	end
end

function PropManager:IsDirty()
	return self.dirty
end

return PropManager
