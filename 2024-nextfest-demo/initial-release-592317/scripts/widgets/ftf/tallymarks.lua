local UIAnim = require "widgets.uianim"
local Widget = require "widgets.widget"
require "class"


local function LastTallyIndexForSum(total_sum)
	return math.ceil(total_sum / 5)
end

local function CountOnLastTallyForSum(total_sum)
	local last_count = total_sum % 5
	if last_count == 0 then
		return 5
	end
	return last_count
end

-- NOTE: Can't run tests in widget files because Widget won't load.
--~ local function test_LastTallyIndexForSum()
--~ 	assert(LastTallyIndexForSum(1) == 1)
--~ 	assert(LastTallyIndexForSum(4) == 1)
--~ 	assert(LastTallyIndexForSum(5) == 1)
--~ 	assert(LastTallyIndexForSum(6) == 2)
--~ 	assert(LastTallyIndexForSum(7) == 2)
--~ 	assert(LastTallyIndexForSum(9) == 2)
--~ 	assert(LastTallyIndexForSum(10) == 2)
--~ 	assert(LastTallyIndexForSum(11) == 3)
--~ end
--~ local function test_CountOnLastTallyForSum()
--~ 	assert(CountOnLastTallyForSum(1) == 1)
--~ 	assert(CountOnLastTallyForSum(4) == 4)
--~ 	assert(CountOnLastTallyForSum(5) == 5)
--~ 	assert(CountOnLastTallyForSum(6) == 1)
--~ 	assert(CountOnLastTallyForSum(7) == 2)
--~ 	assert(CountOnLastTallyForSum(9) == 4)
--~ 	assert(CountOnLastTallyForSum(10) == 5)
--~ 	assert(CountOnLastTallyForSum(11) == 1)
--~ end




-- Show those line marks to count from 1 (|) to 5 (-||||-).
local TallyMarks = Class(Widget, function(self, max_count)
	Widget._ctor(self, "TallyMarks")
	if max_count then
		self:_CreateTally(max_count)
	end
end)

function TallyMarks:_CreateTally(max_count)
	dbassert(max_count)
	self.max_sum = max_count
	local n_tally = math.ceil(max_count / 5)
	self.tally = {}
	for i=1,n_tally do
		local w = self:AddChild(UIAnim())
			:SetBank("dungeon_map_tally_marks")
			:SetName("Tally index ".. i)
		table.insert(self.tally, w)
	end
	self:LayoutChildrenInGrid(n_tally, 122)
		:CenterChildren()
end

function TallyMarks:SetCount(count)
	dbassert(count)
	self.current_sum = count
	for _,w in ipairs(self.tally) do
		w:Show()
		if count >= 5 then
			w:GetAnimState():SetPercent("mark_5", 1)
			count = count - 5
		elseif count > 0 then
			w:GetAnimState():SetPercent("mark_".. count, 1)
			count = 0
		else
			w:Hide()
		end
	end
	return self
end

function TallyMarks:Increment()
	local new_sum = self.current_sum + 1
	local next_tally_idx = LastTallyIndexForSum(new_sum)
	local w = self.tally[next_tally_idx]
	if w then
		local count = CountOnLastTallyForSum(new_sum)
		w:Show()
		w:GetAnimState():PlayAnimation("mark_".. count)
		self.current_sum = new_sum
	else
		TheLog.ch.UI:printf("Tried to increment past our max (%d). current_sum=%d next_tally_idx=%d", self.max_sum, self.current_sum, next_tally_idx)
	end
end


function TallyMarks:SetToRoomsSeen(nav)
	local room_visited, room_total = nav:GetRoomCount_SeenAndMaximum()
	if not self.tally
		or self.max_sum ~= room_total
	then
		if self.tally then
			self:RemoveChildren()
		end
		self:_CreateTally(room_total)
	end

	self:SetCount(room_visited - 1)
	return self
end


function TallyMarks:DebugDraw_AddSection(ui, panel)
	TallyMarks._base.DebugDraw_AddSection(self, ui, panel)
	ui:Spacing()
	ui:Text("TallyMarks")
	ui:Indent() do
		if ui:Button("Set to 0") then
			self:SetCount(0)
		end
		ui:SameLineWithSpace()
		if ui:Button("Set to 5") then
			self:SetCount(5)
		end
		if ui:Button("Increment") then
			self:Increment()
		end
	end
	ui:Unindent()
end

return TallyMarks
