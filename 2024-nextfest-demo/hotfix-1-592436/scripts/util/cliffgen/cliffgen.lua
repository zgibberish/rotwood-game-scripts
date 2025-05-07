local GroundTiles = require "defs.groundtiles"
local EdgeSet = require "util/cliffgen/edgeset"

local lattice_w = 10
local lattice_h = 5

local overhangs = {} --

local function MirroredMap(inst)
	local mirror = {}
	local width, height = inst.Map:GetSize()
	for y = 0,height-1 do
		local row = {}
		local s = ""
		for x = 0,width-1 do
			local tile = inst.Map:GetTile(x,y)
			table.insert(row, tile)
		end
		table.insert(mirror, 1, row)
	end
	return mirror
end


local function Rotate(point,angle)
	if angle == 0 then
		return Vector2(point.x,point.y)
	elseif angle == 90 then
		return Vector2(point.y, -point.x)
	elseif angle == 180 then
		return Vector2(-point.x,-point.y)
	elseif angle == 270 then
		return Vector2(-point.y, point.x)
	else
		assert(false, "Invalid angle")
	end
	return x,y
end

local function RotateQuad(quad, angle)
	if angle == 0 then
		return {quad[1], quad[2], quad[3], quad[4]}
	elseif angle == 90 then
		return {quad[2], quad[4], quad[1], quad[3]}
	elseif angle == 180 then
		return {quad[4], quad[3], quad[2], quad[1]}
	elseif angle == 270 then
		return {quad[3], quad[1], quad[4], quad[2]}
	else
		assert(false, "Invalid angle")
	end
end

-- Debug draw a diamond shape
local function Diamond(x,y,color, size)
	size = size or 0.5
	AddWorldLine(x-size,y,x,y+size,color)
	AddWorldLine(x+size,y,x,y+size,color)
	AddWorldLine(x-size,y,x,y-size,color)
	AddWorldLine(x+size,y,x,y-size,color)
end

-- Northern edge looked at from the abyss (mask = 12) is 0 degrees, rotations are clockwise
local function Edge(x, y, tilequad, rotation)
	local origin = Vector2(x,y)

	local quad = RotateQuad(tilequad, rotation)
	local t1 = quad[1]
	local t2 = quad[2]
	local o1 = overhangs[t1]
	local o2 = overhangs[t2]

	local p1 = Vector2(-2,-o1)
	local p2 = Vector2(2,-o2)

	if o1 ~= o2 then
		local center = (p1 + p2) / 2
		local od = (o1 - o2) / 2
		local odv = Vector2(math.abs(od),od)
		local centerl = center - odv
		local centerr = center + odv

		p1 = Rotate(p1,rotation)
		p2 = Rotate(p2,rotation)
		centerl = Rotate(centerl, rotation)
		centerr = Rotate(centerr, rotation)
		--	AddWorldLine(x + x1,y + y1,x + x2,y + y2, BGCOLORS.BLUE)
		--	Diamond(x+x1,y+y1,BGCOLORS.YELLOW, 0.25)
		--	Diamond(x+x2,y+y2,BGCOLORS.RED, 0.25)

		p1 = p1 + origin
		p2 = p2 + origin
		centerl = centerl + origin
		centerr = centerr + origin
		return {points = {p1,centerl,centerr,p2}}
	else
		local center = (p1 + p2) / 2
		local od = (o1 - o2) / 2
		local odv = Vector2(od,od)
		local centerl = center - odv
		local centerr = center + odv

		p1 = Rotate(p1,rotation)
		p2 = Rotate(p2,rotation)
		centerl = Rotate(centerr, rotation)
		centerr = Rotate(centerr, rotation)
		--	AddWorldLine(x + x1,y + y1,x + x2,y + y2, BGCOLORS.BLUE)
		--	Diamond(x+x1,y+y1,BGCOLORS.YELLOW, 0.25)
		--	Diamond(x+x2,y+y2,BGCOLORS.RED, 0.25)

		p1 = p1 + origin
		p2 = p2 + origin
		centerl = centerl + origin
		centerr = centerr + origin
		return {points = {p1,p2}}
	end
end


-- Northeastern corner is outer corner looked at from the abyss (mask = 4) is 0 degrees. Rotations are clockwise.
local function OuterCorner(x, y, tilequad, rotation)
	local rounded = true
	-- rounded creates a chamfered corner, non rounded a hard 90 degree corner.
	-- Visibly they are identical but for collision the rounded one may be nicer.
	-- If we want to differentiate this for colgen and meshgen we can make it a parameter and gen separately
	if rounded then
		-- 4 points
		local origin = Vector2(x,y)

		local quad = RotateQuad(tilequad, rotation)
		local t1 = quad[2]
		local o1 = overhangs[t1]

		local p1 = Vector2(-o1,2)
		local p2 = Vector2(-o1,0)
		local p3 = Vector2(0, -o1)
		local p4 = Vector2(2,-o1)

		p1 = Rotate(p1,rotation)
		p2 = Rotate(p2,rotation)
		p3 = Rotate(p3,rotation)
		p4 = Rotate(p4,rotation)

		--	AddWorldLine(x + x1,y + y1,x + x2,y + y2, BGCOLORS.BLUE)
		--	AddWorldLine(x + x2,y + y2,x + x3,y + y3, BGCOLORS.BLUE)
		--	AddWorldLine(x + x3,y + y3,x + x4,y + y4, BGCOLORS.BLUE)

		--	Diamond(x+x1,y+y1,BGCOLORS.YELLOW, 0.25)
		--	Diamond(x+x3,y+y3,BGCOLORS.RED, 0.25)

		--Diamond(x+x2,y+y2,BGCOLORS.WHITE, 0.5)
		--Diamond(x+x2,y+y2,BGCOLORS.WHITE, 0.25)
		p1 = p1 + origin
		p2 = p2 + origin
		p3 = p3 + origin
		p4 = p4 + origin

		return {points = {p1,p2,p3,p4}}
	else
		-- 3 points
		local origin = Vector2(x,y)

		local quad = RotateQuad(tilequad, rotation)
		local t1 = quad[2]
		local o1 = overhangs[t1]

		local p1 = Vector2(-o1,2)
		local p2 = Vector2(-o1,-o1)
		local p3 = Vector2(2,-o1)

		p1 = Rotate(p1,rotation)
		p2 = Rotate(p2,rotation)
		p3 = Rotate(p3,rotation)

		--	AddWorldLine(x + x1,y + y1,x + x2,y + y2, BGCOLORS.BLUE)
		--	AddWorldLine(x + x2,y + y2,x + x3,y + y3, BGCOLORS.BLUE)
		--	AddWorldLine(x + x3,y + y3,x + x4,y + y4, BGCOLORS.BLUE)

		--	Diamond(x+x1,y+y1,BGCOLORS.YELLOW, 0.25)
		--	Diamond(x+x3,y+y3,BGCOLORS.RED, 0.25)

		--Diamond(x+x2,y+y2,BGCOLORS.WHITE, 0.5)
		--Diamond(x+x2,y+y2,BGCOLORS.WHITE, 0.25)
		p1 = p1 + origin
		p2 = p2 + origin
		p3 = p3 + origin

		return {points = {p1,p2,p3}}
	end
end

-- Northeastern corner is inner corner looked at from the abyss (mask = 13) is 0 degrees. Rotations are clockwise.
local function InnerCorner(x,y,tilequad, rotation)
	local rounded = true

	if rounded then
		local origin = Vector2(x,y)
		local quad = RotateQuad(tilequad, rotation)
		local t1 = quad[1]
		local t2 = quad[2]
		local t3 = quad[4]


		local o1 = overhangs[t1]
		local o2 = overhangs[t2]
		local o3 = overhangs[t3]

		local p1 = Vector2(-2, -o1)

		-- inner chamfer - push out the corner by tileoverhang 2
		local leftinner = -o3 - o2
		-- since this can become so large that we're pushed outside our tile I have to clamp it to the tile edge
		if leftinner < -2 then
			leftinner = -2
		end
		local bottominner = -o1 - o2
		if bottominner < -2 then
			bottominner = -2
		end
		local p2 = Vector2(leftinner, -o1)
		local p3 = Vector2(-o3, bottominner)

		local p4 = Vector2(-o3, -2)

		p1 = Rotate(p1,rotation)
		p2 = Rotate(p2,rotation)
		p3 = Rotate(p3,rotation)
		p4 = Rotate(p4,rotation)

		p1 = p1 + origin
		p2 = p2 + origin
		p3 = p3 + origin
		p4 = p4 + origin

		local p1v = Vector3(p1.x,0,p1.y)
		local p2v = Vector3(p2.x,0,p2.y)
		TheDebugRenderer:WorldLine({p1v:Get()}, {p2v:Get()}, BGCOLORS.BLUE)

		return {points = {p1, p2, p3, p4}}
	else
		local origin = Vector2(x,y)
		local quad = RotateQuad(tilequad, rotation)
		local t1 = quad[1]
		local t2 = quad[2]
		local t3 = quad[4]


		local o1 = overhangs[t1]
		local o2 = overhangs[t2]
		local o3 = overhangs[t3]

		local p1 = Vector2(-2, -o1)
		local p2 = Vector2(-o3, -o1)
		local p3 = Vector2(-o3, -o1)
		local p4 = Vector2(-o3, -2)

		p1 = Rotate(p1,rotation)
		p2 = Rotate(p2,rotation)
		p3 = Rotate(p3,rotation)
		p4 = Rotate(p4,rotation)

		--AddWorldLine(x + x1,y + y1,x + x2,y + y2, BGCOLORS.BLUE)
		--AddWorldLine(x + x2,y + y2,x + x3,y + y3, BGCOLORS.BLUE)
		--AddWorldLine(x + x3,y + y3,x + x4,y + y4, BGCOLORS.BLUE)

		--Diamond(x+x1,y+y1,BGCOLORS.YELLOW, 0.25)
		--Diamond(x+x3,y+y3,BGCOLORS.RED, 0.25)

		--	Diamond(x+x2,y+y2,BGCOLORS.WHITE, 0.5)
		--	Diamond(x+x2,y+y2,BGCOLORS.WHITE, 0.25)
		p1 = p1 + origin
		p2 = p2 + origin
		p3 = p3 + origin
		p4 = p4 + origin

	--	return {{p1.x,p1.y},{p2.x,p2.y},{p3.x,p3.y},{p4.x,p4.y}}
		return {points = {p1, p2, --[[p3,]] p4}}
	end
end

local function GetMapEdge(inst)
	local edgeSet = EdgeSet()

	local map = MirroredMap(inst)
	local edgetiles = {}
	local width, height = inst.Map:GetSize()

	local masks = {}
	local tilequads = {}
	for y = 1,height-1 do
		local s = ""
		for x = 1,width-1 do
			local mask = (map[y][x] ~= 1 and 8 or 0)
			mask = mask | (map[y][x+1] ~= 1 and 4 or 0)
			mask = mask | (map[y+1][x] ~= 1 and 2 or 0)
			mask = mask | (map[y+1][x+1] ~= 1 and 1 or 0)

			local tilequad = {}
			tilequad[1] = map[y][x]
			tilequad[2] = map[y][x+1]
			tilequad[3] = map[y+1][x]
			tilequad[4] = map[y+1][x+1]

			local tile = map[y][x] ~= 1 and 'X' or ' '
			s = "\n"..tile
			local tile = map[y][x+1] ~= 1 and 'X' or ' '
			s = s..tile..'\n'
			local tile = map[y+1][x] ~= 1 and 'X' or ' '
			s = s..tile
			local tile = map[y+1][x+1] ~= 1 and 'X' or ' '
			s = s..tile

			--print("mask:",s)
			--for i,v in pairs(tilequad) do
			--	print("",v)
			--end
			-- print("mask:",mask)
			table.insert(masks,{x,y,mask})
			table.insert(tilequads, tilequad)
		end
		-- print("next line")
	end


	local width, height = inst.Map:GetSize()
	local ofx = width % 2 == 0 and 0 or 2
	local ofy = height % 2 == 0 and 0 or 2
	local ypos = 0

	local mapCx,mapCy = inst.Map:GetTileXYAtXZ(0, 0)

	for i,v in pairs(masks) do
		local tilequad = tilequads[i]
		local x = v[1] * 4 - mapCx * 4
		local y = (height - 1 - v[2]) * 4 - mapCy * 4
		local mask = v[3]

		local px = x - 2 + ofx
		local py = y + 2 + ofy

		if mask == 0 then
			--print("skipping cuz no tiles")
		elseif mask == 1 then
			-- 00
			-- 01
			-- outer corner in SE
			local edge = OuterCorner(px,py,tilequad,90)
			edgeSet:Add(edge)
		elseif mask == 2 then
			-- 00
			-- 10
			-- outer corner in SW
			local edge = OuterCorner(px,py,tilequad,180)
			edgeSet:Add(edge)
		elseif mask == 3 then
			-- 00
			-- 11
			-- edge on S
			local edge = Edge(px, py, tilequad, 180)
			edgeSet:Add(edge)
		elseif mask == 4 then
			-- 01
			-- 00
			-- outer corner in NE
			local edge = OuterCorner(px,py,tilequad,0)
			edgeSet:Add(edge)
		elseif mask == 5 then
			-- 01
			-- 01
			-- edge on E
			local edge = Edge(px, py, tilequad, 90)
			edgeSet:Add(edge)
		elseif mask == 6 then
			-- 01
			-- 10
			-- two inner corners. one SE, one NW. Needs specific mesh if we're dipping in
			local edge1 = InnerCorner(px,py,tilequad,270)
			local edge2 = InnerCorner(px,py,tilequad,90)
			edgeSet:Add(edge1, edge2)
		elseif mask == 7 then
			-- 01
			-- 11
			-- inner corner SE
			local edge = InnerCorner(px,py,tilequad,90)
			edgeSet:Add(edge)
		elseif mask == 8 then
			-- 10
			-- 00
			-- outer corner in NW
			local edge = OuterCorner(px,py,tilequad,270)
			edgeSet:Add(edge)
		elseif mask == 9 then
			-- 10
			-- 01
			-- two inner corners. SE and NE. Needs specific mesh if we're dipping in
			local edge1 = InnerCorner(px,py,tilequad,0)
			local edge2 = InnerCorner(px,py,tilequad,180)
			edgeSet:Add(edge1, edge2)
		elseif mask == 10 then
			-- 10
			-- 10
			-- edge on W
			local edge = Edge(px, py, tilequad, 270)
			edgeSet:Add(edge)
		elseif mask == 11 then
			-- 10
			-- 11
			-- inner corner SW
			local edge = InnerCorner(px,py,tilequad,180)
			edgeSet:Add(edge)
		elseif mask == 12 then
			-- 11
			-- 00
			-- edge on N
			local edge = Edge(px, py, tilequad, 0)
			edgeSet:Add(edge)
		elseif mask == 13 then
			-- 11
			-- 01
			-- inner NE
			local edge = InnerCorner(px,py,tilequad,0)
			edgeSet:Add(edge)
		elseif mask == 14 then
			-- 11
			-- 10
			-- inner NW
			local edge = InnerCorner(px,py,tilequad,270)
			edgeSet:Add(edge)
		elseif mask == 15 then
			--print("skipping cuz all tiles")
		else
			assert(false)
		end
	end

	return edgeSet
end

local function SetupOverhangs(inst)
	-- set up the overhangs for this tileset
	overhangs = {}
	for i = 1, #inst.tilegroup.Order do
		local def = GroundTiles.Tiles[inst.tilegroup.Order[i]]
		local overhang
		if def ~= nil then
			overhang = def.overhang
		end
		overhangs[i] = overhang or 0
	end
end

function SimplifyCollision(points)
	-- just two simplified outlines to test with if I modify stuff
	--	local points = {{0,0}, {1,0}, {1,0}, {2,0}, {2,0},{2,2}, {2,2}, {-1,0}, {-1,0}, {0,0}}
	--	local points = {{0,0}, {1,0}, {1,0}, {2,0}, {2,0},{3,0}, {3,0},{2,2}, {2,2},{2,3}, {2,3},{2,5}, {2,5},{-2,0}, {-2,0},{0,0}}

	print("Simplifying collision edges")
	-- convert it back to a list of edges
	local edges = {}
	for i=1,#points,2 do
		local p1 = Vector2(points[i][1], points[i][2])
		local p2 = Vector2(points[i+1][1], points[i+1][2])
		local edge = {p1 = p1, p2 = p2}
		table.insert(edges, edge)
	end

	-- for each edge, check if it is aligned with its neighbor, if so, fuse them
	local _start = 1
	--local _end = _start + 1
	while _start <= #edges do
		local edgecount = #edges


		local e1 = edges[_start]
		-- find the neighbor of this edge
		local i2
		for i,v in pairs(edges) do
			if v.p1 == e1.p2 then
				i2 = i
			end
		end
		assert(i2)

		local e2 = edges[i2]
		local removed = false
		if e1.p2 == e2.p1 then

			local d1 = e1.p2 - e1.p1
			local d2 = e2.p2 - e2.p1
			local angle = d1:AngleTo_Degrees(d2)
			if math.abs(angle) < 1.0 then
				-- they are parralel
				local edge = {p1 = e1.p1:Clone(), p2 = e2.p2:Clone()}
				edges[_start] = edge
				table.remove(edges,i2)
				removed = true
			end
		end
		if not removed then
			_start = _start + 1
		end
	end

	local newpoints = {}
	for i,edge in pairs(edges) do
		table.insert(newpoints, {edge.p1.x, edge.p1.y})
		table.insert(newpoints, {edge.p2.x, edge.p2.y})
	end
	return newpoints
end

function GenerateCliffCollision(inst)
	SetupOverhangs(inst)

	local edgeSet = GetMapEdge(inst)

	local points = {}
	local edges = edgeSet.edges
	edgeSet:Validate()
	--edgeSet:ToVerts()
	for i,edge in pairs(edges) do
		-- Hmmm, the collision mesh shouldn't use non-rounded corners...
		-- and joy, we're pointing the wrong way
		for i = 1,#edge.points - 1 do
			table.insert(points, {edge.points[i+1].x, edge.points[i+1].y})
			table.insert(points, {edge.points[i].x, edge.points[i].y})
		end
	end
	points = SimplifyCollision(points)
	return points
end

--[[local]] function GenerateCliffMesh(inst, params)
	inst.Map:RenderSkirt(false)

	local underground_atlas
	local underground_texture
	for i = 1, #inst.tilegroup.Order do
		local def = GroundTiles.Tiles[inst.tilegroup.Order[i]]
		if def ~= nil then
			if def.underground then
				underground_atlas = def.tileset_atlas
				underground_texture = def.tileset_image
			end
		end
	end

	if params.cliffskirt then
		underground_atlas = "levels/tiles/"..params.cliffskirt..".xml"
		underground_texture = "levels/tiles/"..params.cliffskirt..".tex"
	end
	if params.cliffskirt then
			print("atlas: ","levels/tiles/"..params.cliffskirt..".xml")
			print("texture: ","levels/tiles/"..params.cliffskirt..".tex")
	end

	if not underground_atlas or not underground_texture then
		print("No underground tile defined")
	end

	SetupOverhangs(inst)

	local edgeSet = GetMapEdge(inst)

	local mesh = SpawnPrefab("cliffedge", inst)
	mesh.Transform:SetScale(1,1,1)

	local atlasuvs = {}
	local regions = TheSim:GetAtlasRegions(underground_atlas)
	for i,v in pairs(regions) do
		local u1,v1,u2,v2 = TheSim:GetAtlasRegionUVs(underground_atlas, v)
		atlasuvs[i] = {u1 = u1,v1 = v1, u2 = u2,v2 = v2}
	end
	mesh.Model:SetTexture(underground_texture)

	edgeSet:Validate()
	edgeSet:ToVerts()
	edgeSet:Connect()
	edgeSet:CreateLattices(lattice_w, lattice_h)
	edgeSet:GenerateVerts()
	edgeSet:CalcEdgeNormals()
	edgeSet:CalcPlaneNormals()

	-- start the deform
	local factor = 1.5
	edgeSet:SetHeight(1, 0 * 0.4)
	edgeSet:Displace(1, 1 * factor * 0.4)

	edgeSet:SetHeight(2, 0 * 0.4)
	edgeSet:Displace(2, 0 * factor * 0.4)

	edgeSet:SetHeight(3, -1.5 * 0.4)
	edgeSet:Displace(3, -1.8 * factor * 0.4)

	edgeSet:SetHeight(4, -1.9 * 0.4)
	edgeSet:Displace(4, -1.8 * factor * 0.4)

	edgeSet:SetHeight(5, -10 * 0.4)
	edgeSet:Displace(5, -0.4 * factor * 0.4)

	edgeSet:Displace({3,4},function() return math.random() * 0.1 end)

	edgeSet:GenerateVertNormals()
	edgeSet:GenerateUVs(atlasuvs)

	local meshdata = {vertices = {}, normals = {}, uvs = {}}
	edgeSet:RenderToMesh(meshdata)

	if #meshdata.vertices > 0 then
		mesh.Model:SetVertexData(meshdata.vertices, meshdata.normals, meshdata.uvs)
	end
	return mesh
end
