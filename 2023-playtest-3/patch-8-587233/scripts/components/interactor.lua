require "class"

-- A component for entities that interact with interactable component.
local Interactor = Class(function(self, inst)
	self.inst = inst
end)


function Interactor:StartSafetyTask(interactable)
	-- The forcedwalk fires on PerformInteract, so we don't need to
	-- wait for that and the 1 second is about enough to cover that.
	self.interact_safety_task = self.inst:DoTaskInTime(1, function(_inst)
		if interactable.inst:IsValid()
			and interactable:IsPlayerInteracting(self.inst) -- so ClearInteract doesn't fail
		then
			-- Something must have interrupted our interaction and we
			-- never called PerformInteract. Cancel.
			TheLog.ch.Interact:printf("interact_safety_task: ClearInteract(<%s>) on <%s>", self.inst, interactable.inst)
			interactable:ClearInteract(self.inst)
		end
		self.interact_safety_task = nil
	end)
end

function Interactor:CancelSafetyTask(interactable)
	if self.interact_safety_task then
		self.interact_safety_task:Cancel()
		self.interact_safety_task = nil
	end
end


-- Do not allow new interactions when currently in an existing interaction to
-- ensure we can't switch interactions mid way.
function Interactor:LockInteraction(interactable)
	-- We don't listen to onremove because the interactable will clear us on destroy.
	self.current_interactable_ent = interactable.inst
end

function Interactor:UnlockInteraction(interactable)
	self.current_interactable_ent = nil
end

-- The action that's currently taking place. May be nil.
function Interactor:GetCurrentInteraction()
	return self.current_interactable_ent
end






------------------------------
-- Debug api {{{1

function Interactor:DebugDrawEntity(ui, panel, colors)
	ui:Value("Current Interaction Entity", self.current_interactable_ent or "<none>")
	ui:Text("interact_safety_task:")
	ui:SameLineWithSpace()
	panel:AppendValue(ui, self.interact_safety_task)
end


return Interactor
