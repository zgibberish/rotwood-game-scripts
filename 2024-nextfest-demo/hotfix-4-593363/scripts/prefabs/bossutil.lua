local bossutil = {}

-- Helper function to check for state transitions via event handlers.
function bossutil.DoEventTransition(inst, newstate, data)
	if inst and inst:IsValid() and not inst:IsDead() then
		inst.sg:GoToState(newstate, data)
	end
end

-- Prevent the boss from dying if it takes damage after all players are dead.
function bossutil.SetupLastPlayerDeadEventHandlers(inst)
	TheWorld:ListenForEvent("lastplayerdead", function()
		inst.components.combat:SetDamageReceivedMult("all_players_dead", 0)
		inst.sg.mem.all_players_dead = true
	end)
	TheWorld:ListenForEvent("playerdeathrevived", function()
		-- Reset damage mod because the last alive player revived.
		if inst.sg.mem.all_players_dead then
			inst.components.combat:RemoveDamageReceivedMult("all_players_dead")
			inst.sg.mem.all_players_dead = nil
		end
	end)
end

return bossutil
