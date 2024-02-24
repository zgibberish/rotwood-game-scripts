local lume = require "util.lume"
local SGCommon = require "stategraphs.sg_common"
local ParticleSystemHelper = require "util.particlesystemhelper"

local HEALING_PULSE_PERIOD <const> = 1 -- seconds
local HEALING_PULSE_DURATION <const> = 12 -- ticks
local EMITTER_NAME <const> = "healing_fountain_heal_emitter"

local function HealingPulseFX(player)
	-- TODO @chrisp #heal - copypasta from revive.lua
	SGCommon.Fns.BlinkAndFadeColor(player, { 102/255, 204/255, 51/255, 0.5 }, HEALING_PULSE_DURATION)
end

local HealingFountain = Class(function(self, inst)
	self.inst = inst

	-- Bind the "healthchanged" event to VendingMachine:UpdatePlayerStatus while in interaction focus.
	-- Whenever a player's health changes, inform the healing fountain's VendingMachine component to allow it to
	-- alter the Interactor Ui. The player's health functions as a kind of "inverse currency" and affects the result of
	-- VendingMachine:CanDeposit.
	-- That is, if a player is "bound" to a healing fountain entity by being in interaction proximity to it, then the
	-- VendingMachine component of the healing fountain needs to UpdatePlayerStatus when receiving the "healthchanged"
	-- event.		
	self.on_player_health_changed_fn = function(player) 
		local vending_machine = self.inst.components.vendingmachine
		if vending_machine then
			vending_machine:UpdatePlayerStatus(player)
		end
	end
	self.on_gain_interact_focus_fn = function(_, player)	
		self.inst:ListenForEvent("healthchanged", self.on_player_health_changed_fn, player)
	end
	self.on_lose_interact_focus_fn = function(_, player)	
		self.inst:RemoveEventCallback("healthchanged", self.on_player_health_changed_fn, player)
	end	
	self.inst:ListenForEvent("gain_interact_focus", self.on_gain_interact_focus_fn)
	self.inst:ListenForEvent("lose_interact_focus", self.on_lose_interact_focus_fn)

	-- Play healing pulse effects on players that are drinking from the cauldron.
	self.pulse_tasks = {}
	self.on_depositing_currency_changed = function(inst, params)
		if params.is_depositing then	
			HealingPulseFX(params.player)
			self.pulse_tasks[params.player] = inst:DoPeriodicTask(HEALING_PULSE_PERIOD, function(_) 
				HealingPulseFX(params.player) 
			end)
			ParticleSystemHelper.MakeEventSpawnParticles(params.player, {
				name = EMITTER_NAME,
				particlefxname = "heal_over_time_healingfountain",
				use_entity_facing = true,
				ischild = true,
				render_in_front = true,
				offy = 1
			})
		else
			self.pulse_tasks[params.player]:Cancel()
			self.pulse_tasks[params.player] = nil
			ParticleSystemHelper.MakeEventStopParticles(params.player, {
				name = EMITTER_NAME,
			})
		end
	end
	self.inst:ListenForEvent("depositing_currency_changed", self.on_depositing_currency_changed)
end)

function HealingFountain:OnRemoveFromEntity()
	if self.inst.components.interactable then
		lume(self.inst.components.interactable.focused_players):each(function(player) 
			self.inst:RemoveEventCallback("healthchanged", self.on_player_health_changed_fn, player)
		end)
	end

	self.inst:RemoveEventCallback("lose_interact_focus", self.on_lose_interact_focus_fn)
	self.inst:RemoveEventCallback("gain_interact_focus", self.on_gain_interact_focus_fn)

	self.inst:RemoveEventCallback("depositing_currency_changed", self.on_depositing_currency_changed)
	for player, pulse_task in pairs(self.pulse_tasks) do
		pulse_task:Cancel()
		ParticleSystemHelper.MakeEventStopParticles(player, {
			name = EMITTER_NAME,
		})
	end
end

return HealingFountain
