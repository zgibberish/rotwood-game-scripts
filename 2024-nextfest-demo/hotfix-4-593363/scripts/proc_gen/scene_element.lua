-- Base class for elements placed in a scene by a SceneGen.
-- TODO @chrisp #scenegen - rename to DecorElement...and subclasses too!

local DungeonProgress = require "proc_gen.dungeon_progress"
local Enum = require "util.enum"

local RADIUS_MAXIMUM = 5
local COUNT_MAXIMUM = 10
local HEIGHT_MAXIMUM = 10.0

DecorType = Enum {
	"Unknown",
	"Prop",
	"Spacer",
	"ParticleSystem",
	"Fx"
}

local SceneElement = Class(function(self)
	self.dungeon_progress_constraints = DungeonProgress.DefaultConstraints()
	self.enabled = true
	self.name = nil
end)

SceneElement.PLACEMENT_CONTEXT = "++PLACEMENT_CONTEXT"

function SceneElement:GetDecorType()
	return DecorType.s.Unknown
end

function SceneElement:CanPlaceOnTile(_)
	return true
end

-- Placement radius is the effective size of the prop when it is being placed. By setting the buffer to be
-- larger than zero, you can prevent other props from being placed too close to this prop in THIS
-- ZoneGen pass. In subsequent passes, the prop will be represented using only its un-buffered radius.

function SceneElement:GetCount()
	return (self.placement and self.placement.count or self.count) or 1
end

function SceneElement:GetHeight()
	return (self.placement and self.placement.height or self.height) or 0
end

function SceneElement:GetPersistentRadius()
	return (self.placement and self.placement.radius or self.radius) or 1
end

function SceneElement:GetBufferRadius()
	return (self.placement and self.placement.buffer or self.buffer) or 0
end

function SceneElement:GetPlacementRadius()
	return self:GetPersistentRadius() + self:GetBufferRadius()
end

function SceneElement:GetLabel()
	return self.name
end

function SceneElement:GetDungeonProgressConstraints()
	return self.dungeon_progress_constraints
end

function SceneElement:Ui(ui, id)
	self.name = ui:_InputTextWithHint("Name"..id, self:GetLabel(), self.name)
	ui:SetTooltipIfHovered("Override the generated label for this element")
	if self.name == "" then
		self.name = nil
	end

	-- Move data into 'placement' table so we can copy/paste.
	if not self.placement then
		self.placement = {
			count = self.count or 1,
			radius = self.radius or 1,
			buffer = self.buffer or 0,
			height = self.height or 0
		}
		self.count = nil
		self.radius = nil
		self.buffer = nil
		self.height = nil
	end

	if ui:CollapsingHeader("Placement"..id) then
		local id = id .. "Placement"

		local new_placement = ui:CopyPasteButtons(SceneElement.PLACEMENT_CONTEXT, id, self.placement)
		if new_placement then
			self.placement = new_placement
		end

		local changed, count = ui:DragInt("Count"..id, self.placement.count or 1, 1, 1, COUNT_MAXIMUM)
		ui:SetTooltipIfHovered("Number of elements in this ZoneGen, relative to other element Counts")
		if changed then
			self.placement.count = count
		end

		self.placement.radius = ui:_DragFloat("Radius"..id, self.placement.radius or 1, 0.1, 0, RADIUS_MAXIMUM)
		ui:SetTooltipIfHovered("Effective placement size")

		self.placement.buffer = ui:_DragFloat("Buffer Radius"..id, self.placement.buffer or 0, 0.1, 0, RADIUS_MAXIMUM)
		ui:SetTooltipIfHovered("Additional space occupied for this generation phase only")

		self.placement.height = ui:_DragFloat("Height"..id, self.placement.height or 0, 0.1, -HEIGHT_MAXIMUM, HEIGHT_MAXIMUM)
		ui:SetTooltipIfHovered("Offset in y")
	end

	DungeonProgress.Ui(ui, id.."DungeonProgressConstraintsUi", self)
end

return SceneElement
