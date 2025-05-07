require "class"
local FollowPrompt = require "widgets.ftf.followprompt"
local Lume = require "util.lume"
local Image = require "widgets.image"
local Text = require "widgets.text"
local Panel = require "widgets.panel"

-- A component for entities that interact with interactable component.
local Interactor = Class(function(self, inst)
	self.inst = inst
	self.status_texts = {}
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

function Interactor:MakeFullText()
	if Lume(self.status_texts):count():result() == 0 then
		return
	end
	return Lume(self.status_texts):reduce(function(current, text)
		return current.."\n"..text
	end):result()
end

function Interactor:StretchBgToFitText()
	local x1, y1, x2, y2 = self.status_text:GetBoundingBox()
	self.bg:SetInnerSize(x2 - x1, y2 - y1 + 15)
end

function Interactor:ManifestUi()
	dbassert(TheDungeon.HUD ~= nil)

	local WIDTH <const> = 240
	local HEIGHT <const> = 90

	self.ui_root = TheDungeon.HUD:AddWorldWidget(FollowPrompt(self.inst))
		:SetName("Interactor")
		:SetTarget(self.inst)
		:SetRegistration("right", "center")
		:SetOffsetFromTarget(Vector3(-0.6, 2, 0))

	self.bg = self.ui_root:AddChild(Panel("images/ui_ftf_ingame/interact_bg.tex"))
		:SetName("Background")
		:SetNineSliceCoords(25, 0, 175, 95)
		:SetMultColorAlpha(0.6)
		:SetSize(WIDTH, HEIGHT)

	self.status_text = self.ui_root:AddChild(Text(
			FONTFACE.DEFAULT, 
			FONTSIZE.NOTIFICATION_TITLE, 
			"", 
			self.inst.playercolor
		))
		:SetName("Text")
		:SetShadowColor(UICOLORS.BLACK)
		:SetOutlineColor(UICOLORS.BLACK)
		:EnableShadow()
		:EnableOutline()
		:SetShadowOffset(1, -1)

	-- When the input mode changes, update the text in case we have controls embedded..
	self.status_text.OnInputModeChanged = function(_status_text_widget, _old_device_type, _new_device_type)
		self.status_text:ForceSetText(self:MakeFullText())
		self:StretchBgToFitText()
	end
end

function Interactor:SetStatusText(key, status_text)
	self.status_texts[key] = status_text

	-- Only show status text over the local players.
	if not self.inst:IsLocal() then
		return
	end

	-- We need to wait until TheDungeon.HUD appears as the status widget will parented to it.
	if not self.ui_root then
		if not TheDungeon.HUD then
			return
		end
		self:ManifestUi()
	end

	if Lume(self.status_texts):count():result() == 0 then
		self.ui_root:Hide()
	else
		self.ui_root:Show()
		self.status_text:SetText(self:MakeFullText())
		self:StretchBgToFitText()
	end
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
