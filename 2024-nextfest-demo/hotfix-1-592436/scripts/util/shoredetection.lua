local WallLocation_Left = 1
local WallLocation_Right = 2
local WallLocation_Up = 3
local WallLocation_Down = 4
local WallLocation_UpLeft = 5
local WallLocation_UpRight = 6
local WallLocation_DownLeft = 7
local WallLocation_DownRight = 8

local WallLocation_COUNT = 8

local TILE_SIZE = 4

local function SortUpDown(segA, segB)
	-- Sort on Y first, so that all segments that could possibly be combined are together:
	-- If the Y coords are the same, sort on X in ascending order

	if (segA.m_y == segB.m_y) then
		if (segA.m_x == segB.m_x) then
			-- x and Y are the same!
			-- Sort on the Y coordinate in the same direction as we'd do with the coordinate:
			return segA.m_segment.mStart.x > segB.m_segment.mStart.x
		end
		return segA.m_x > segB.m_x
	end

	return segA.m_y < segB.m_y
end

local function SortLeftRight(segA, segB) 
	-- Sort on X first, so that all segments that could possibly be combined are together:
	-- If the X coords are the same, sort on Y in ascending order

	if (segA.m_x == segB.m_x) then
		if (segA.m_y == segB.m_y) then
			-- x and Y are the same!
			-- Sort on the Y coordinate in the same direction as we'd do with the coordinate:
			return segA.m_segment.mStart.y > segB.m_segment.mStart.y
		end
		return segA.m_y > segB.m_y
	end

	return segA.m_x < segB.m_x
end

local Segment2d = Class(function(self,_start,_end)
	self.mStart = _start
	self.mEnd = _end
end)


local SegmentInfo = Class(function(self, x, y, segment)
	self.m_x = x
	self.m_y = y
	self.m_segment = segment
end)

local SegmentBucket = Class(function(self)
	self.m_segments = {}
end)

function SegmentBucket:AddSegment(x, y, _start, _end)
	table.insert(self.m_segments, SegmentInfo(x, y, Segment2d(_start, _end)))
end

-- This will reduce the segments by looking which ones are overlapping and which ones are connected.
function SegmentBucket:CalculateSimplifiedRepresentation(wallLocation)
	
	if wallLocation == WallLocation_Left or wallLocation == WallLocation_Right then
		if (#self.m_segments > 0) then
			
			table.sort(self.m_segments, SortLeftRight)
			local newSegments = {}

			local it_c, it = next(self.m_segments, nil)
			local si = SegmentInfo()

			si.m_segment = it.m_segment
			si.m_x = it.m_x
			si.m_y = it.m_y
			it_c, it = next(self.m_segments, it_c)

			while it_c do
				local currentSegment = it
				if ((si.m_x ~= currentSegment.m_x) or (si.m_y > currentSegment.m_y + 1)) then
					table.insert(newSegments,si)
					-- Store the old segment and start a new one:
					si = currentSegment
				else
					-- This segment is connected!
					if (wallLocation == WallLocation_Left) then
						si.m_segment.mEnd = currentSegment.m_segment.mEnd
					else
						si.m_segment.mStart = currentSegment.m_segment.mStart
					end
					si.m_y = currentSegment.m_y
				end

				it_c, it = next(self.m_segments, it_c)
			end
			table.insert(newSegments, si)
			-- Copy the new segments back into the segments list:
			self.m_segments = newSegments
		end
	elseif wallLocation == WallLocation_Up or wallLocation == WallLocation_Down then
		if (#self.m_segments > 0) then
			table.sort(self.m_segments, SortUpDown)
			local newSegments = {}

			local it_c, it = next(self.m_segments, nil)

			local si = SegmentInfo()
			si.m_segment = it.m_segment
			si.m_x = it.m_x
			si.m_y = it.m_y

			it_c, it = next(self.m_segments, it_c)

			while it_c do
				local currentSegment = it
				if ((si.m_y ~= currentSegment.m_y) or (si.m_x > currentSegment.m_x + 1)) then
					table.insert(newSegments,si)
					-- Store the old segment and start a new one:
					si = currentSegment
				else
					-- This segment is connected!
					if (wallLocation == WallLocation_Up) then
						si.m_segment.mEnd = currentSegment.m_segment.mEnd
					else
						si.m_segment.mStart = currentSegment.m_segment.mStart
					end
					si.m_x = currentSegment.m_x
				end
				it_c, it = next(self.m_segments, it_c)
			end
			table.insert(newSegments, si)	
			-- Copy the new segments back into the segments list:
			self.m_segments = newSegments
		end
	else
		return	-- Don't simplify diagonal segments because they are not combinable anyway. (only used to round off the edges)
	end
end

local function DetectShoreSegments(buckets, tile_grid, is_not_land, cut_distance, invertCut)
	local width, height = tile_grid:GetSize()

	local cut = cut_distance
	local sz = TILE_SIZE
	local xoff = -TILE_SIZE * width * .5 - TILE_SIZE * .5
	local zoff = -TILE_SIZE * height * .5 - TILE_SIZE * .5

	for y = 0,height-1 do
		for x = 0, width-1 do
			local tile = tile_grid:GetTile(x, y) or 0
			if (is_not_land(tile_grid,x,y) ~= invertCut) then
			
				local left = x > 0 and (not is_not_land(tile_grid, x - 1, y) ~= invertCut)
				local right = x < width - 1 and (not is_not_land(tile_grid, x + 1, y) ~= invertCut)
				local down = y > 0 and (not is_not_land(tile_grid, x, y - 1) ~= invertCut)
				local up = y < height - 1 and (not is_not_land(tile_grid, x, y + 1) ~= invertCut)

				local downleft = x > 0 and y > 0 and (not is_not_land(tile_grid, x - 1, y - 1) ~= invertCut)
				local downright = x < width - 1 and y > 0 and (not is_not_land(tile_grid, x + 1, y - 1) ~= invertCut)
				local upleft = x > 0 and y < height - 1 and (not is_not_land(tile_grid, x - 1, y + 1) ~= invertCut)
				local upright = x < width - 1 and y < height - 1 and (not is_not_land(tile_grid, x + 1, y + 1) ~= invertCut)
	
				local noadj = not up and not down and not left and not right

				if left then
					if not up then
						local p1 = Vector2((x + cut)*sz + xoff, (y + .5)*sz + zoff)
						local p2 = Vector2((x + cut)*sz + xoff, (y + 1 - cut)*sz + zoff)
						buckets[WallLocation_Left]:AddSegment(x, y, p2, p1)
					end

					if not down then
						local p1 = Vector2((x + cut)*sz + xoff, (y + .5)*sz + zoff)
						local p2 = Vector2((x + cut)*sz + xoff, (y + cut)*sz + zoff)
						buckets[WallLocation_Left]:AddSegment(x, y, p1, p2)
					end
				end

				if right then
					if not up then
						local p1 = Vector2((x + 1 - cut)*sz + xoff, (y + .5)*sz + zoff)
						local p2 = Vector2((x + 1 - cut)*sz + xoff, (y + 1 - cut)*sz + zoff)
						buckets[WallLocation_Right]:AddSegment(x, y, p1, p2)
					end

					if not down then
						local p1 = Vector2((x + 1 - cut)*sz + xoff, (y + .5)*sz + zoff)
						local p2 = Vector2((x + 1 - cut)*sz + xoff, (y + cut)*sz + zoff)
						buckets[WallLocation_Right]:AddSegment(x, y, p2, p1)
					end
				end


				if up then
					if not left then
						local p1 = Vector2((x + cut)*sz + xoff, (y + 1 - cut)*sz + zoff)
						local p2 = Vector2((x + .5)*sz + xoff, (y + 1 - cut)*sz + zoff)
						buckets[WallLocation_Up]:AddSegment(x, y, p2, p1)
					end

					if not right then
						local p1 = Vector2((x + .5)*sz + xoff, (y + 1 - cut)*sz + zoff)
						local p2 = Vector2((x + 1 - cut)*sz + xoff, (y + 1 - cut)*sz + zoff)
						buckets[WallLocation_Up]:AddSegment(x, y, p2, p1)
					end
				end

				if down then
					if not left then
						local p1 = Vector2((x + cut)*sz + xoff, (y + cut)*sz + zoff)
						local p2 = Vector2((x + .5)*sz + xoff, (y + cut)*sz + zoff)
						buckets[WallLocation_Down]:AddSegment(x, y, p1, p2)
					end

					if not right then
						local p1 = Vector2((x + .5)*sz + xoff, (y + cut)*sz + zoff)
						local p2 = Vector2((x + 1 - cut)*sz + xoff, (y + cut)*sz + zoff)
						buckets[WallLocation_Down]:AddSegment(x, y, p1, p2)
					end

				end

				if left and up then
					local p1 = Vector2((x + cut)*sz + xoff, (y + .5)*sz + zoff)
					local p2 = Vector2((x + .5)*sz + xoff, (y + 1 - cut)*sz + zoff)
					buckets[WallLocation_UpLeft]:AddSegment(x, y, p2, p1)
				end

				if left and down then
					local p1 = Vector2((x + cut)*sz + xoff, (y + .5)*sz + zoff)
					local p2 = Vector2((x + .5)*sz + xoff, (y + cut)*sz + zoff)
					buckets[WallLocation_DownLeft]:AddSegment(x, y, p1, p2)
				end

				if right and up then
					local p1 = Vector2((x + 1 - cut)*sz + xoff, (y + .5)*sz + zoff)
					local p2 = Vector2((x + .5)*sz + xoff, (y + 1 - cut)*sz + zoff)
					buckets[WallLocation_UpRight]:AddSegment(x, y, p1, p2)
				end

				if right and down then
					local p1 = Vector2((x + 1 - cut)*sz + xoff, (y + .5)*sz + zoff)
					local p2 = Vector2((x + .5)*sz + xoff, (y + cut)*sz + zoff)
					buckets[WallLocation_DownRight]:AddSegment(x, y, p2, p1)
				end


				if not up and not left and upleft then
					local p1 = Vector2((x)*sz + xoff, (y + 1 - cut)*sz + zoff)
					local p2 = Vector2((x + cut)*sz + xoff, (y + 1)*sz + zoff)
					buckets[WallLocation_UpLeft]:AddSegment(x, y, p2, p1)
				end

				if not up and not right and upright then
					local p1 = Vector2((x + 1 - cut)*sz + xoff, (y + 1)*sz + zoff)
					local p2 = Vector2((x + 1)*sz + xoff, (y + 1 - cut)*sz + zoff)
					buckets[WallLocation_UpRight]:AddSegment(x, y, p2, p1)
				end

				if not down and not right and downright then
					local p1 = Vector2((x + 1 - cut)*sz + xoff, (y)*sz + zoff)
					local p2 = Vector2((x + 1)*sz + xoff, (y + cut)*sz + zoff)
					buckets[WallLocation_DownRight]:AddSegment(x, y, p1, p2)
				end

				if not down and not left and downleft then
					local p1 = Vector2((x)*sz + xoff, (y + cut)*sz + zoff)
					local p2 = Vector2((x + cut)*sz + xoff, (y)*sz + zoff)
					buckets[WallLocation_DownLeft]:AddSegment(x, y, p1, p2)
				end

				if left and not up then
					local p1 = Vector2((x + cut)*sz + xoff, (y + 1 - cut)*sz + zoff)
					local p2 = Vector2((x + cut)*sz + xoff, (y + 1)*sz + zoff)
					buckets[WallLocation_Left]:AddSegment(x, y, p2, p1)
				end

				if left and not down then
					local p1 = Vector2((x + cut)*sz + xoff, (y + cut)*sz + zoff)
					local p2 = Vector2((x + cut)*sz + xoff, (y)*sz + zoff)
					buckets[WallLocation_Left]:AddSegment(x, y, p1, p2)
				end

				if right and not up then
					local p1 = Vector2((x + 1 - cut)*sz + xoff, (y + 1 - cut)*sz + zoff)
					local p2 = Vector2((x + 1 - cut)*sz + xoff, (y + 1)*sz + zoff)
					buckets[WallLocation_Right]:AddSegment(x, y, p1, p2)
				end

				if right and not down then
					local p1 = Vector2((x + 1 - cut)*sz + xoff, (y + cut)*sz + zoff)
					local p2 = Vector2((x + 1 - cut)*sz + xoff, (y)*sz + zoff)
					buckets[WallLocation_Right]:AddSegment(x, y, p2, p1)
				end

				if up and not left then
					local p1 = Vector2((x)*sz + xoff, (y + 1 - cut)*sz + zoff)
					local p2 = Vector2((x + cut)*sz + xoff, (y + 1 - cut)*sz + zoff)
					buckets[WallLocation_Up]:AddSegment(x, y, p2, p1)
				end

				if up and not right then
					local p1 = Vector2((x + 1 - cut)*sz + xoff, (y + 1 - cut)*sz + zoff)
					local p2 = Vector2((x + 1)*sz + xoff, (y + 1 - cut)*sz + zoff)
					buckets[WallLocation_Up]:AddSegment(x, y, p2, p1)
				end

				if down and not left then
					local p1 = Vector2((x)*sz + xoff, (y + cut)*sz + zoff)
					local p2 = Vector2((x + cut)*sz + xoff, (y + cut)*sz + zoff)
					buckets[WallLocation_Down]:AddSegment(x, y, p1, p2)
				end

				if down and not right then
					local p1 = Vector2((x + 1 - cut)*sz + xoff, (y + cut)*sz + zoff)
					local p2 = Vector2((x + 1)*sz + xoff, (y + cut)*sz + zoff)
					buckets[WallLocation_Down]:AddSegment(x, y, p1, p2)
				end
			end
		end
	end
end

local function AddWallSegment(vertPairs, p_1, p_2)
 	table.insert(vertPairs, {p_1.x, p_1.y})
 	table.insert(vertPairs, {p_2.x, p_2.y})
end

-- find the point that is the endpoint of the edge connecting to this point
-- and remove said edge for future consideration
function GetNextPoint(verts, edges, index)
	local p = verts[index]
	for i,v in pairs(edges) do
		local p1 = verts[v.first]
		local p2 = verts[v.second]
		if p == p1 then
			-- don't consider this edge again
			edges[i] = nil
			-- and return the other end of this segment
			return v.second
		end
		if p == p2 then
			-- don't consider this edge again
			edges[i] = nil
			-- return the other end of this segment
			return v.first
		end
	end
	assert(false)
end

local function Loopify(verts)
	local outverts = {1, 2}

	-- convert our point pairs to vector2, just so we can use compare
	local vertices = {}
	for i=1,#verts do
		local pt = Vector2(verts[i][1], verts[i][2])
		table.insert(vertices, pt)
	end
	-- build a list of edges
	local edges = {}
	for i=1,#verts,2 do
		table.insert(edges, {first = i, second = i+1})
	end
	local loop = {}
	local curedge = table.remove(edges)	                                                                                       
	local startindex = curedge.first
	local curindex = curedge.second

	table.insert(loop, curindex)
	local startpoint = vertices[startindex]
	-- from the second point onwards find the connected edge and get its outgoing vert. 
	for i=1,#edges do
		curindex = GetNextPoint(vertices, edges, curindex)
		table.insert(loop, curindex)
	end
	local endpoint = vertices[curindex]
	assert(endpoint == startpoint)
	-- write the list of points
	local outpoints = {}
	for i,vertindex in ipairs(loop) do
		table.insert(outpoints,verts[vertindex])
	end
	return outpoints
end

function GetShore(tile_grid, shore_test, cut_distance, invert_cut, loopify)
	local vertPairs = {}

	local buckets = {}
	for i=1,WallLocation_COUNT do
		buckets[i] = SegmentBucket()
	end

	DetectShoreSegments(buckets, tile_grid, shore_test, cut_distance, invert_cut)

	for i=1, WallLocation_COUNT do
		if ( i < WallLocation_UpLeft ) then	-- Only simplify the left, right, up and down segments. The diagonal ones are not usually connected together anyway.
			buckets[i]:CalculateSimplifiedRepresentation(i)
		end

		for i,v in pairs(buckets[i].m_segments) do
			local seg = v.m_segment
			AddWallSegment(vertPairs, seg.mStart, seg.mEnd)
		end
	end
	if loopify then
		return Loopify(vertPairs)
	end
	return vertPairs
end

