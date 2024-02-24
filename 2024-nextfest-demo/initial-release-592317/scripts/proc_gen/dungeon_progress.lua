local Easing = require "util.easing"
local Lume = require "util.lume"

local mod = {}

local NEAR_BOSS_PROGRESS_THRESHOLD = 0.75
local END_RUN_PROGRESS_THRESHOLD = 1.0

-- An array of events ordered by when they occur as dictated by progress through the dungeon.
mod.EVENTS = {
	{ name = "start_run", progress_threshold = 0.0 },
	{ name = "midway",    progress_threshold = 0.5 },
	{ name = "near_boss", progress_threshold = NEAR_BOSS_PROGRESS_THRESHOLD },
	{ name = "end_run",   progress_threshold = END_RUN_PROGRESS_THRESHOLD },
}

-- Return the effective likelihood if the specified progress satisfies all constraints, 0 otherwise.
function mod.ComputeLikelihood(progress, constraints)
	for i, event in ipairs(mod.EVENTS) do
		if i == #mod.EVENTS then
			break
		end
		local next_event = mod.EVENTS[i + 1]
		if event.progress_threshold <= progress and progress < next_event.progress_threshold then
			local constraint = constraints[event.name]
			local time = progress - event.progress_threshold
			local delta = constraint.likelihood.to - constraint.likelihood.from
			local duration = next_event.progress_threshold - event.progress_threshold
			return Easing[constraint.easing](time, constraint.likelihood.from, delta, duration)
		end
	end
	local DURATION = END_RUN_PROGRESS_THRESHOLD - NEAR_BOSS_PROGRESS_THRESHOLD
	return Easing[constraints.near_boss.easing](
		END_RUN_PROGRESS_THRESHOLD
		, constraints.near_boss.likelihood.from
		, constraints.near_boss.likelihood.to
		, DURATION
	)
end

function mod.DefaultConstraints()
	local dungeon_progress_constraints = {}
	for i, event in ipairs(mod.EVENTS) do
		if i == #mod.EVENTS then
			break
		end
		dungeon_progress_constraints[event.name] = {
			easing = "linear",
			likelihood = {from = 1, to = 1}
		}
	end
	return dungeon_progress_constraints
end

function mod.Ui(ui, id, context)
	if not ui:CollapsingHeader("Dungeon Progress Modulated Likelihoods"..id) then
		return
	end

	if not context.dungeon_progress_constraints then
		context.dungeon_progress_constraints = mod.DefaultConstraints()
	end
	local constraints = context.dungeon_progress_constraints

	local dirty = false

	local pasted_constraints = ui:CopyPasteButtons("++dungeon_progress_constraints", id.."dungeon_progress_constraints", constraints)
	if pasted_constraints then
		constraints = pasted_constraints
		dirty = true
	end

	local STEP = 0.001
	local likelihoods = {}
	local progress = 0
	while progress < 1 do
		table.insert(likelihoods, mod.ComputeLikelihood(progress, constraints))
		progress = progress + STEP
	end
	ui:PlotLines(id.."Graph", "Likelihoods", likelihoods, 0, 0, 1, 100)

	local changed
	local easings = Lume(Easing):keys():sort():result()
	ui:PushItemWidth(ui:GetContentRegionAvail() / 5)
	for i, event in ipairs(mod.EVENTS) do
		if i == #mod.EVENTS then
			break
		end

		local constraint = constraints[event.name]			
		
		local new_easing
		changed, new_easing = ui:ComboAsString(id..event.name.."Easing", constraint.easing, easings)
		if changed then
			constraint.easing = new_easing
			dirty = true
		end
		
		ui:SameLineWithSpace()
		local new_from
		changed, new_from = ui:DragFloat("From "..event.name..id, constraint.likelihood.from, 0.001, 0, 1)
		if changed then
			constraint.likelihood.from = new_from
			dirty = true
		end

		ui:SameLineWithSpace()
		local next_event = mod.EVENTS[i + 1]
		local new_to
		changed, new_to = ui:DragFloat("To "..next_event.name..id, constraint.likelihood.to, 0.001, 0, 1)
		if changed then
			constraint.likelihood.to = new_to
			dirty = true
		end
	end
	ui:PopItemWidth()
	if dirty then
		context.dungeon_progress_constraints = constraints
	end
end

return mod
