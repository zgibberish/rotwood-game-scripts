local DebugNodes = require "dbui.debug_nodes"
local spawnutil = require "util.spawnutil"
local stacktrace = require "stacktrace"
require "consolecommands"
require "constants"
require "util"


local max_recents = 32

local DebugAnimation = Class(DebugNodes.DebugNode, function(self, inst)
	DebugNodes.DebugNode._ctor(self, "Debug Animation")
	self.autoselect = inst == nil
	if inst then
		self:StartTracking(inst)
	end
	self.anim_history = RingBuffer(max_recents)
end)



DebugAnimation.PANEL_WIDTH = 600
DebugAnimation.PANEL_HEIGHT = 600





function DebugAnimation:StopTracking()
    self.anim_history:Clear()
	if self.inst then
		self.inst.animation_label:Remove()
		self.inst.AnimState:UnwrapNativeComponent()
		self.inst = nil
	end
end

function DebugAnimation:StartTracking(target)
	self.error_msg = nil
	if self.inst then
		self:StopTracking()
	end
	if target.AnimState.UnwrapNativeComponent then
		self.inst = nil
		self.error_msg = "Cannot track entities that are already using Debug_WrapNativeComponent."
		return
	end
	self.inst = target
	self.inst:Debug_WrapNativeComponent("AnimState")
	local function CreateFnWrapper(fn_name)
		return function(this, anim, ...)
			self.inst.animation_label.Label:SetText(anim)
			self.anim_history:Add({
					name = anim,
					fn = fn_name,
					debugstack = stacktrace.FullStack(),
				})
			return this._original[fn_name](this._original, anim, ...)
		end
	end
	for _,fn_name in ipairs({ "PlayAnimation", "PushAnimation", }) do
		self.inst.AnimState[fn_name] = CreateFnWrapper(fn_name)
	end
	self.inst.animation_label = spawnutil.SpawnWorldLabel("", Vector3.zero)
	-- Can't use SetParent because the text would rotate and be unreadable.
	self.inst.animation_label:AddComponent("glue")
		:FollowTarget(self.inst, nil, 4)
end

function DebugAnimation:OnDeactivate()
	self:StopTracking()
end

function DebugAnimation:RenderPanel(ui, panel)
	local debug_entity = GetDebugEntity()
	if self.autoselect
		and debug_entity
		and self.inst ~= debug_entity
		and debug_entity.AnimState
	then
		self:StartTracking(GetDebugEntity())
	end

	ui:Value("Target Entity", self.inst)

	if self.error_msg then
		ui:TextColored(WEBCOLORS.YELLOW, self.error_msg)
	end

	if not self.inst then
		return
	end

	if ui:CollapsingHeader("Recent Animation", ui.TreeNodeFlags.DefaultOpen) then

		self.filter_anim = ui:_FilterBar(self.filter_anim, nil, "Filter anims...")

		local colw = ui:GetColumnWidth()

		ui:Columns(3, "Recent Animation")

		ui:SetColumnOffset(1, colw * 0.55)
		ui:SetColumnOffset(2, colw * 0.90)

		ui:TextColored(self.colorscheme.header, "Anim")
		ui:NextColumn()
		ui:TextColored(self.colorscheme.header, "How")
		ui:NextColumn()
		ui:TextColored(self.colorscheme.header, "Where")
		ui:NextColumn()

		for index=self.anim_history.entries,1,-1 do
			local info = self.anim_history:Get(index)
			if info then
				if not self.filter_anim
					or info.name:find(self.filter_anim)
				then
					if ui:Selectable(info.name, false) then
						ui:SetClipboardText(info.name)
						self.filter_anim = info.name
					end
					if ui:IsItemHovered() then
						ui:SetTooltip(info.name)
					end
					ui:NextColumn()

					ui:Text(info.fn)
					ui:NextColumn()

					if ui:SmallButton(ui.icon.copy .."##copy_animation" .. index) then
						ui:SetClipboardText(info.debugstack)
					end
					if ui:IsItemHovered() then
						ui:SetTooltip(info.debugstack)
					end
					ui:NextColumn()
				end
			end
		end

		ui:Columns(1)
	end
end

DebugNodes.DebugAnimation = DebugAnimation

return DebugAnimation
