local Constructable = require "defs.constructable"
local emotion = require "defs.emotion"
local DebugDraw = require "util.debugdraw"
local Enum = require "util.enum"
local recipes = require "defs.recipes"
local ParticleSystemHelper = require "util.particlesystemhelper"


local Npc = Class(function(self, ...)
	return self:init(...)
end)

function Npc:init(inst)
	self.inst = inst
	self.home = nil
	self.onhomechangedfn = nil

	-- TODO: Load personality from npc tuning.
	self.text_personality = Npc.BuildDefaultTextPersonality()

	--This is for hiding/showing Npc's when the player is placing buildings
	self._onstartplacing = function()
		inst.sg:GoToState("idle")
		inst:RemoveFromScene()
	end
	self._onstopplacing = function(world, hasplaced)
		if hasplaced and self.home ~= nil then
			local x, z = self.home.components.npchome:GetSpawnXZ()
			inst.Transform:SetPosition(x, 0, z)
		end
		inst:ReturnToScene()
	end
	inst:ListenForEvent("startplacing", self._onstartplacing, TheWorld)
	inst:ListenForEvent("stopplacing", self._onstopplacing, TheWorld)

	inst:ListenForEvent("startcustomizing", self._onstartplacing, TheWorld)
	inst:ListenForEvent("stopcustomizing", self._onstopplacing, TheWorld)

	TheWorld:UnlockFlag(string.format("wf_seen_%s", self.inst.prefab))
end

Npc.Role = Enum{
	"visitor", -- pseudo role for newcomers

	"apothecary",
	"armorsmith",
	"blacksmith",
	"cook",
	"hunter",
	"konjurist",
	"refiner",
	"scout",
	"specialeventhost",
	"travelling_salesman",
	"dungeon_armorsmith",
}

function Npc.BuildDefaultTextPersonality() -- no args!
	-- For the structure of personality, see Text:SetPersonalityText.
	local personality = {
		character_delay = 0.035,
		spool_by_character = true,
		separator = {
			["!"] = {
				delay = 0.5,
			},
			["?"] = {
				delay = 0.5,
			},
			[","] = {
				delay = 0.2,
			},
			["."] = {
				delay = 0.3,
			},
			[" "] = {
				delay = 100, -- see below
			},
		},
		feeling = emotion.feeling.neutral,
	}
	personality.separator[" "].delay = personality.spool_by_character and personality.character_delay*0.5 or 0.15
	return personality
end

function Npc:GetTextPersonality()
	-- TODO: Listen to event to set their current feeling.
	self.text_personality.feeling = emotion.feeling.neutral
	return self.text_personality
end

function Npc:OnRemoveEntity()
	if self.home ~= nil then
		local old_home = self.home
		self.home = nil
		old_home.components.npchome:RemoveNpc(self.inst)
	end
end

function Npc:OnRemoveFromEntity()
	self.inst:RemoveEventCallback("startplacing", self._onstartplacing, TheWorld)
	self.inst:RemoveEventCallback("stopplacing", self._onstopplacing, TheWorld)

	self.inst:RemoveEventCallback("startcustomizing", self._onstartplacing, TheWorld)
	self.inst:RemoveEventCallback("stopcustomizing", self._onstopplacing, TheWorld)

	self:OnRemoveEntity()
end

-- Should be one of Npc.Role
function Npc:GetRole()
	return self.role
end

function Npc:SetOnHomeChangedFn(fn)
	self.onhomechangedfn = fn
end

function Npc:SetDesiredHomeData(home, placer_id)
	self.desired_home_key = home
	self.desired_placer_id = placer_id
end

-- A permanent home building.
function Npc:HasDesiredHome()
	local home = self:GetHome()
	return home ~= nil and home.prefab == self.desired_home_key
end

-- TODO(dbriscoe): Rework into next home and pass recipes to StartCraftingHome:
-- Rename to GetNextHomeRecipe and handle no home as well as upgrading existing home.
function Npc:DesiredHomeRecipe()
	assert(self.desired_home_key)
	local recipe = recipes.ForSlot[Constructable.Slots.BUILDINGS][self.desired_home_key]
	return recipe
end

function Npc:CanCraftDesiredHome(player)
	assert(self.desired_home_key)
	local recipe = self:DesiredHomeRecipe()
	return recipe and recipe:CanPlayerCraft(player)
end

function Npc:OnPlaceHome(player, placer, building, cb)
	building.components.npchome:AddNpc(self.inst)

	--Reposition player to continue interacting with npc
	local x0, z0 = building.Transform:GetWorldXZ()
	local x, z = building.components.npchome:GetSpawnXZ()


	if x < x0 or (x == x0 and player.Transform:GetFacing() == FACING_LEFT) then
		x = x0 + player.Physics:GetSize()
	else
		x = x0 - player.Physics:GetSize()
	end
	player.Transform:SetPosition(x, 0, z)

	self.inst:Face(player)
	player:Face(self.inst)

	local plot = placer.components.placer:GetPlotInPos(x0, z0)
	plot.components.plot:SetBuilding(building)
	player.components.playercontroller:StopPlacer()

	ParticleSystemHelper.MakeOneShot(self.home, "building_upgrade", nil, 1)

	if cb then
		cb(true)
	end
end

function Npc:OnHomePlacerCancel(cb)
	if cb then
		cb(false)
	end
end

function Npc:StartMovingHome(home, player, cb)
	player.components.playercontroller:StartPlacer(
		home.prefab.."_placer",
		function(placer, prefab) return true end,
		
		function(placer, building)
			self:OnPlaceHome(player, placer, building, cb)
			home:Remove()
		end,

		function(placer) self:OnHomePlacerCancel(cb) end,
	true)
end

function Npc:StartCraftingHome(player, cb)
	assert(self.desired_placer_id)
	local recipe = self:DesiredHomeRecipe()
	assert(recipe, self.desired_home_key)

	player.components.playercontroller:StartPlacer(
		self.desired_placer_id,
		function(placer, prefab)
			-- Validate:
			assert(recipe.def.name == prefab)
			return recipe:CanPlayerCraft(player)
		end,
		function(placer, building) self:OnPlaceHome(player, placer, building, cb) end,
		function(placer) self:OnHomePlacerCancel(cb) end,
		true
	)
end

function Npc:SetHome(home)
	if home ~= self.home then
		dbassert(self:_HasHome() == not self.inst.persists)
		if self.home ~= nil then
			local old_home = self.home
			self.home = nil
			old_home.components.npchome:RemoveNpc(self.inst)
		end
		if home ~= nil then
			self.home = home
			home.components.npchome:AddNpc(self.inst)
		end
		self.inst.persists = home == nil
		if self.onhomechangedfn ~= nil then
			self.onhomechangedfn(self.inst, home)
		end
	end
end

function Npc:GetHome()
	return self.home
end

-- Initial spawn point (not a building) counts as a "home".
function Npc:_HasHome()
	return self.home ~= nil
end

function Npc:CanUpgradeHome()
	return self.home and self.home.components.npchome ~= nil and self.home.components.npchome:HasUpgrade()
end

function Npc:StartUpgradingHome(player, cb)
	assert(self.home)
	self.home.components.buildingupgrader:StartUpgrading(player, cb)
	ParticleSystemHelper.MakeOneShot(self.home, "building_upgrade", nil, 1)
end

function Npc:OnSave()
	return
	{
		desired_home_key  = self.desired_home_key,
		desired_placer_id = self.desired_placer_id,
		role = self.role,
	}
end

function Npc:OnLoad(data)
	if data.desired_home_key ~= nil and data.desired_placer_id ~= nil then
		self:SetDesiredHomeData(data.desired_home_key, data.desired_placer_id)
	end

	self.role = data.role
end

function Npc:DebugDrawEntity(ui, panel, colors)
	local home = self:GetHome()
	if home then
		local maxdist = self.inst.tuning.wander_dist
		ui:ColorButton("Wander Radius", WEBCOLORS.GREEN)
		ui:SameLineWithSpace()
		-- Value lives inside brain, so it's nontrivial to live edit so just show it.
		ui:Value("Wander Radius", maxdist)
		local x,z = home.Transform:GetWorldXZ()
		DebugDraw.GroundCircle(x, z, maxdist, WEBCOLORS.GREEN)
	else
		ui:Text("No home")
	end

	ui:Value("role", self.role)
end

function Npc:GetDebugString()
	return "Home: "..tostring(self.home)
end



return Npc
