local DebugDraw = require "util.debugdraw"
local Lattice = require "util/cliffgen/lattice"

local function DoWorldLine(edge, color, width)
	color = color or BGCOLORS.WHITE
	width = width or 3
	for i=1,#edge.points-1 do
		local p1 = edge.points[i]
		local p2 = edge.points[i+1]
		-- We have Vec2, so we can't use GroundLine_Vec.
		DebugDraw.GroundLine(p1.x,p1.y,p2.x,p2.y, color, width)
	end
end

local EdgeSet = Class(function(self)
	self.edges = {}
end)

-- Remove any zero length segments
function EdgeSet:SimplifyEdge(edge)
	local points = {points = {}}
	points[1] = edge.points[1]
	for i = 2,#edge.points do
		local point = edge.points[i]
		local len = (point - points[#points]):Length()
		if len ~= 0 then
			table.insert(points, point)
		end
	end
	edge.points = points
end

function EdgeSet:Add(...)
	local edges = {...}
	for _,edge in pairs(edges) do
		EdgeSet:SimplifyEdge(edge)
		table.insert(self.edges, edge)
	end
end

function EdgeSet:CreateLattices(lattice_w, lattice_h)
	for i,edge in pairs(self.edges) do
		edge.lattice = Lattice(edge, lattice_w, lattice_h)
	end
end

function EdgeSet:GenerateVerts()
	local edges = self.edges
	for _,edge in pairs(edges) do
		edge.lattice:GenerateVerts()
	end
end

function EdgeSet:PrintAngles()
	local edges = self.edges
	local i = 1
	while i < #edges do
		local edge = edges[i]
		local nextedge = edges[edge.nextedge]
		local d1 = edge.p2 - edge.p1
		local d2 = nextedge.p2 - nextedge.p1
		local angle = d1:AngleTo_Degrees(d2)
		TheLog.ch.Cliffs:print("angle to next:",angle)
	end
end

function EdgeSet:ToVerts()
	for _,edge in pairs(self.edges) do
		edge.verts = {}
		for i=1,#edge.points do
			edge.verts[i] = Vector3(edge.points[i].x, 0, edge.points[i].y)
		end
	end
end

function EdgeSet:Validate()
	TheLog.ch.Cliffs:print("Validating edges")
	local edges = self.edges
	-- make sure each edge butts up to exactly one other edge
	for i,baseedge in pairs(edges) do
		local points = baseedge.points
		local startpoint = points[1]
		local endpoint = points[#points]
		local outedge = nil
		local inedge = nil
		for j,testedge in pairs(edges) do
			local points = testedge.points
			local mystartpoint = points[1]
			local myendpoint = points[#points]
			if mystartpoint == endpoint then
				assert(not outedge, "Multiple outgoing edges")
				outedge = testedge
				--TheLog.ch.Cliffs:print("equal out",testedge,j)
			end
			if myendpoint == startpoint then
				assert(not inedge, "Multiple incoming edges")
				inedge = testedge
				--TheLog.ch.Cliffs:print("equal in",testedge,j)
			end
		end
		assert(inedge ~= outedge, "Incoming edge can't be outgoing edge")
		assert(inedge, "No incoming edge found. You must leave a gap around world edges in Tiled.")
		assert(outedge, "No outgoing edge found")
	end
end

-- TODO: This doesn't actually simplify yet
function EdgeSet:Simplify()
	-- for each edge, if it connects with its neighbor then combine them
	local edges = self.edges
	local simplified = false
	local outedges = {}
	local startedge = 1
	for i=1,#edges do
		local edge = edges[i]
		local nextedge = edges[edge.nextedge]
	end
end

-- Yes, this duplicates the work of validate. I still prefer them separate
function EdgeSet:Connect()
	local edges = self.edges
	TheLog.ch.Cliffs:print("Connecting edges")
	-- make sure each edge butts up to exactly one other edge
	for i,baseedge in pairs(edges) do
		local points = baseedge.points
		local startpoint = points[1]
		local endpoint = points[#points]
		local outedge = nil
		local inedge = nil
		for j,testedge in pairs(edges) do
			local points = testedge.points
			local mystartpoint = points[1]
			local myendpoint = points[#points]
			if mystartpoint == endpoint then
				assert(not outedge, "Multiple outgoing edges")
				--outedge = testedge
				outedge = j
				--TheLog.ch.Cliffs:print("equal out",testedge,j)
			end
			if myendpoint == startpoint then
				assert(not inedge, "Multiple incoming edges")
				--inedge = testedge
				inedge = j
				--TheLog.ch.Cliffs:print("equal in",testedge,j)
			end
		end
		assert(inedge ~= outedge, "Incoming edge can't be outgoing edge")
		assert(inedge, "No incoming edge found")
		assert(outedge, "No outgoing edge found")
		baseedge.nextedge = outedge
		baseedge.prevedge = inedge
	end
end

function EdgeSet:DebugRender()
	for i,edge in pairs(self.edges) do
		DoWorldLine(edge)
	end
end

function EdgeSet:CalcEdgeNormals()
	local edges = self.edges
	for _,edge in pairs(edges) do
		edge.lattice:CalcEdgeNormals(edges)
	end
end

function EdgeSet:CalcPlaneNormals()
	local edges = self.edges
	for _,edge in pairs(edges) do
		edge.lattice:CalcPlaneNormals(edges)
	end
end

function EdgeSet:SetHeight(tier, height)
	local edges = self.edges

	for i,edge in pairs(edges) do
		edge.lattice:SetHeight(edges,tier, height)
	end
end

function EdgeSet:Displace(tier, displacement)
	local edges = self.edges
	for _,edge in pairs(edges) do
		edge.lattice:Displace(edges, tier, displacement)
	end
end

function EdgeSet:GenerateVertNormals()
	local edges = self.edges
	for _,edge in pairs(edges) do
		edge.lattice:GenerateVertNormals(edges)
	end
end

function EdgeSet:GenerateUVs(atlasuvs)
	local edges = self.edges
	for _,edge in pairs(edges) do
		edge.lattice:GenerateUVs(edges,atlasuvs)
	end
end

function EdgeSet:RenderToMesh(meshdata)
	local edges = self.edges
	for _,edge in pairs(edges) do
		edge.lattice:RenderToMesh(meshdata)
	end
end

return EdgeSet
