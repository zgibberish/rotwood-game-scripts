local Equipment = require("defs.equipment")
local Power = require "defs.powers"


local FoodEater = Class(function(self, inst)
	self.inst = inst

    inst:ListenForEvent("start_gameplay", function()
		if TheWorld:HasTag("town") then
			return
		end

		local food = self.inst.components.inventoryhoard:GetEquippedItem(Equipment.Slots["FOOD"])
		local progress = TheDungeon:GetDungeonMap().nav:GetProgressThroughDungeon()
		if food and progress == 0 then
			inst:PushEvent("on_start_eating")
		end
	end)

	inst:ListenForEvent("on_done_eating", function()
		local food = self.inst.components.inventoryhoard:GetEquippedItem(Equipment.Slots["FOOD"])
		if food then
			local usage_data = food:GetUsageData()

			local def = Power.FindPowerByName(usage_data.power)
			local power = self.inst.components.powermanager:CreatePower(def)
			self.inst.components.powermanager:AddPower(power)
			if usage_data.stacks then
				self.inst.components.powermanager:DeltaPowerStacks(def, usage_data.stacks)
			end

			self.inst.components.inventoryhoard:RemoveStackable(food:GetDef(), 1)
		end
	end)
end)

return FoodEater
