local DebugNodes = require "dbui.debug_nodes"
local fxprefabs = require("prefabs.fx_autogen_data")
local particlesystems = require("prefabs.particles_autogen_data")
require "consolecommands"
require "constants"
require "util"
require("prefabs.fx_hits")	-- to pull in legacy fx


local legacy_fx = GetLegacyHitFX()


local DebugFX = Class(DebugNodes.DebugNode, function(self)
	DebugNodes.DebugNode._ctor(self, "Debug FX")

    --jcheng: this could be set to true if we want the filter to be in focus immediately after launching this window
    --however until the bug where modifiers are stuck when clicking imgui widgets, this is a bad idea
    self.wants_focus = false

    self.recent_fx_filter = nil
    self.recent_particles_filter = nil
end)

DebugFX.maxRecents = 16  --max recent events to listen for per category

DebugFX.fx = RingBuffer(DebugFX.maxRecents)
DebugFX.particles = RingBuffer(DebugFX.maxRecents)

DebugFX.PANEL_WIDTH = 600
DebugFX.PANEL_HEIGHT = 600


function DebugFX.SpawnEffect(effect, inst)
	if effect and effect.prefab then
		local info = {name = effect.prefab, prefab = inst and inst.prefab, count = DebugFX.fx:GetWriteCount() + 1, debugstack = _FULLSTACK()}
		DebugFX.fx:Add(info)

		inst = inst or effect
		inst:DoTaskInTime(0,function()
				local debugText = SpawnPrefab("sounddebugicon", TheDebugSource)
				if debugText then
					local pos = inst:GetPosition()
					debugText.Transform:SetPosition(pos:Get() )
					debugText.Transform:SetScale(.05, .05, .05)

					debugText.Label:SetColor(table.unpack(WEBCOLORS.YELLOW))
					debugText.Label:SetText(tostring(info.count))
				end
			end)
	end
end

function DebugFX.SpawnParticles(effect, inst)
	if effect and effect.components and effect.components.particlesystem and effect.components.particlesystem.param_id then
		local info = {name = effect.components.particlesystem.param_id, prefab = inst and inst.prefab, count = DebugFX.particles:GetWriteCount() + 1, debugstack = _FULLSTACK()}
		DebugFX.particles:Add(info)

		inst = inst or effect
		inst:DoTaskInTime(0,function()
				local debugText = SpawnPrefab("sounddebugicon", TheDebugSource)
				if debugText then
					local pos = Vector3(inst.Transform:GetWorldPosition() )
					debugText.Transform:SetPosition(pos:Get() )
					debugText.Transform:SetScale(.05, .05, .05)

					debugText.Label:SetColor(table.unpack(WEBCOLORS.WHITE))
					debugText.Label:SetText(tostring(info.count))
				end
		        end)
	end
end

function DebugFX.DisableTracking()
    DebugFX.fx:Clear()
    DebugFX.particles:Clear()

    TheTrackers.DebugSpawnEffect = nil
    TheTrackers.DebugSpawnParticles = nil
end

function DebugFX.EnableTracking()
	TheTrackers.DebugSpawnEffect = DebugFX.SpawnEffect
	TheTrackers.DebugSpawnParticles = DebugFX.SpawnParticles
end

function DebugFX:OnActivate()
    DebugFX.EnableTracking()
end
function DebugFX:OnDeactivate()
    DebugFX.DisableTracking()
end

function DebugFX:RenderPanel( ui, panel )

    if ui:CollapsingHeader("Recent FX", ui.TreeNodeFlags.DefaultOpen) then

        self.recent_fx_filter = ui:_FilterBar(self.recent_fx_filter, "Filter##filter_fx", "Filter fx...")

        local colw = ui:GetColumnWidth()
        ui:Columns(3, "recent fx")
        ui:SetColumnOffset(1, 60)
        ui:SetColumnOffset(2, colw * 0.7)

        ui:Text("Actions")
        ui:NextColumn()
        ui:Text("Effect")
        ui:NextColumn()
        ui:Text("From Prefab")
        ui:NextColumn()

        for index=DebugFX.fx.entries,1,-1 do
            local info = DebugFX.fx:Get(index)
            if info then
                if not self.recent_fx_filter
					or string.find( info.prefab or "", self.recent_fx_filter )
					or string.find( info.name, self.recent_fx_filter )
				then
                    ui:PushStyleColor(ui.Col.Text, WEBCOLORS.YELLOW)
                    ui:Text(info.count)
                    ui:PopStyleColor()
                    ui:NextColumn()

                    if ui:SmallTooltipButton(ui.icon.edit .. "##edit_fx" .. index, "Edit FX") then
                        DebugNodes.FxEditor:FindOrCreateEditor(info.name)
                    end
                    ui:SameLine(nil,5)
                    if ui:SmallButton("Copy##copy_fx" .. index, "Copy") then
                        ui:SetClipboardText(info.name)
                    end
                    ui:SameLine(nil,5)
                    ui:PushStyleColor(ui.Col.Text, WEBCOLORS.YELLOW)
                    ui:Text(info.name)
                    if ui:IsItemHovered() then
                        ui:SetTooltip(info.name)
                    end
                    ui:PopStyleColor()
                    ui:NextColumn()

                    if info.prefab then
                        if ui:SmallButton("Copy##copy_fx_prefb" .. index, "Copy") then
                            ui:SetClipboardText(info.prefab)
                        end
                    else
                        ui:Dummy(40,0)
                    end
                    ui:SameLine(nil,5)
                    ui:PushStyleColor(ui.Col.Text, WEBCOLORS.YELLOW)
                    ui:Text(info.prefab or "Not Set")
                    ui:PopStyleColor()
                    if ui:IsItemHovered() then
                        ui:SetTooltip(info.debugstack)
                    end
                    ui:NextColumn()
                end
            end
        end

        ui:Columns(1)
    end

    if ui:CollapsingHeader("Recent Particles") then

        self.recent_particles_filter = ui:_FilterBar(self.recent_particles_filter, "Filter##filter_particles", "Filter particles...")

        local colw = ui:GetColumnWidth()
        ui:Columns(3, "recent particles")
        ui:SetColumnOffset(1, 60)
        ui:SetColumnOffset(2, colw * 0.7)

        ui:Text("Actions")
        ui:NextColumn()
        ui:Text("Particles")
        ui:NextColumn()
        ui:Text("From prefab")
        ui:NextColumn()

        for index=DebugFX.particles.entries,1,-1 do
            local info = DebugFX.particles:Get(index)
            if info then
                if not self.recent_particles_filter
					or string.find( info.prefab or "", self.recent_particles_filter )
					or string.find( info.name, self.recent_particles_filter )
				then
                    ui:Text(info.count)
                    ui:NextColumn()

                    if ui:SmallTooltipButton(ui.icon.edit .. "##edit_particles" .. index, "Edit Particles") then
                        DebugNodes.ParticleEditor:FindOrCreateEditor(info.name)
                    end
                    ui:SameLine(nil,5)
                    if ui:SmallButton("Copy##copy_particles" .. index, "Copy") then
                        ui:SetClipboardText(info.name)
                    end
                    ui:SameLine(nil,5)
                    ui:Text(info.name)
                    if ui:IsItemHovered() then
                        ui:SetTooltip(info.name)
                    end
                    ui:NextColumn()

                    if info.prefab then
                        if ui:SmallButton("Copy##copy_particles_prefab" .. index, "Copy") then
                            ui:SetClipboardText(info.prefab)
                        end
                    else
                        ui:Dummy(40, 0)
                    end
                    ui:SameLine(nil,5)
                    ui:Text(info.prefab or "Not Set")
                    ui:NextColumn()
                    if ui:IsItemHovered() then
                        ui:SetTooltip(info.debugstack)
                    end
                end
            end
        end

        ui:Columns(1)

    end
end

DebugNodes.DebugFX = DebugFX

DebugFX.DisableTracking()

return DebugFX
