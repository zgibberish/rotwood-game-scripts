local OffScreenIndicatorWidget = require("widgets/ftf/offscreenindicatorwidget")
local fmodtable = require "defs.sound.fmodtable"

local SOUND_EVENTS =
{
	["SHOW"] = fmodtable.Event.ui_offscreenIndicator_show,
	["HIDE"] = fmodtable.Event.ui_offscreenIndicator_hide,
}

-- This is mostly a wrapper for the off-screen indicator widget
local OffScreenIndicator = Class(function(self, inst)
    self.inst = inst

	self._onentityoffscreenchanged_fn = function(_inst, data)
		TheLog.ch.UI:printf("entityoffscreenchanged - %s, %s", tostring(data.entity), tostring(data.isVisible))
		self.inst.Transform:SetPosition(data.entity.Transform:GetWorldPosition())
		self:SetTargetEntity(data.entity, data.isVisible)
		if not data.entity.offscreen or not data.entity.offscreen.silent then
			-- play the sound diagetically so it is panned
			self.inst.SoundEmitter:PlaySound(data.isVisible and SOUND_EVENTS.HIDE or SOUND_EVENTS.SHOW)
		end
	end
	inst:ListenForEvent("entityoffscreenchanged", self._onentityoffscreenchanged_fn)
end)

function OffScreenIndicator:_RemoveWidget()
	if self.widget then
		self.widget:Remove()
		self.widget = nil
	end

	self.inst:RemoveEventCallback("entityoffscreenchanged", self._onentityoffscreenchanged_fn)
end

function OffScreenIndicator:OnRemoveEntity()
	self:_RemoveWidget()
end

function OffScreenIndicator:OnRemoveFromEntity()
	self:_RemoveWidget()
end

function OffScreenIndicator:SetTargetEntity(target, isVisible)
	if target == nil then
		self:ClearTargetEntity()
		return
	end

	if TheDungeon.HUD then
		local offscreen_options = target.offscreen or {
			-- defaults
			urgent = true,
		}

		if not self.widget then
			self.widget = TheDungeon.HUD:OverlayElement(OffScreenIndicatorWidget(offscreen_options))
		end

		self.widget:SetTargetEntity(self.inst, target, isVisible)
	end
end

function OffScreenIndicator:ClearTargetEntity()
	if not self.widget then
		return
	end
	self.widget:ClearTargetEntity()
end

return OffScreenIndicator
