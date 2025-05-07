local PatternSpawner = Class(function(self, inst)
	self.inst = inst

	self.spawn_symbol = "x"
	self.blank_symbol = "-"

	self.pattern_spacing = 1.9
	self.pattern_height = 11
	self.check_pattern = nil
	self:_BuildCheckPattern()
end)

function PatternSpawner:SetPatternHeight(height)
	self.pattern_height = height
	self:_BuildCheckPattern()
	return self
end

function PatternSpawner:_BuildCheckPattern()
	local base = "0x"

	self.check_pattern = {}

	for i = 1, self.pattern_height do
		local str = base
		for char = 1, self.pattern_height do
			if char == i then
				str = str.."1"
			else
				str = str.."0"
			end
		end
		table.insert(self.check_pattern, tonumber(str))
	end
end

function PatternSpawner:_LineToNum(line)
	local num = string.gsub(line, self.spawn_symbol, "1")
	num = string.gsub(num, self.blank_symbol, "0")
	num = "0x"..num
	num = tonumber(num)
	return num
end

function PatternSpawner:GetSpawnPositionsForLine(line)
	local spawn_offsets = {}

	for i, check in ipairs(self.check_pattern) do
		if (line & check ~= 0) then -- should spawn something
			table.insert(spawn_offsets, Vector3(0, 0, (i-1) * self.pattern_spacing))
		end
	end

	return spawn_offsets
end

function PatternSpawner:GetSpawnPositionsForPattern(pattern)
	local pattern_offsets = {}

	for _, line_str in ipairs(pattern) do
		local line_num = self:_LineToNum(line_str)
		local offsets = self:GetSpawnPositionsForLine(line_num)
		table.insert(pattern_offsets, offsets)
	end

	return pattern_offsets
end

return PatternSpawner