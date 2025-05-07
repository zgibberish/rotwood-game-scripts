local flat_shaded = false	-- just here for debugging

local Lattice = Class(function(self, edge, w, h)
	self.w = w
	self.h = h
	self.edge = edge
	-- initialize the uvs
	--self:InitializeUVs()
	self:FromEdge()
end)

function Lattice:EvaluateBezier(t)
	local points = {}

	local verts = self.edge.verts
	for i,v in pairs(verts) do
		points[i] = {x = v.x, y=v.z}
	end

	assert((t>=0 and t<=1), "ratio out of range")
	assert(#points >= 2, "not enough control points")

	-- de casteljau
	for step = 1,#points-1 do
		for i = 1,#points-step do
			points[i].x = points[i].x * (1-t) + points[i+1].x * t
			points[i].y = points[i].y * (1-t) + points[i+1].y * t
		end
	end

	return Vector2(points[1].x, points[1].y)
end

function Lattice:EdgePointSmooth(ratio)
	local verts = self.edge.verts
	if #verts == 2 then
		local p1 = verts[1]
		local p2 = verts[2]
		local delta = p2 - p1
		return p1 + delta * ratio
	elseif #verts == 3 then
		local p = self:EvaluateBezier(ratio)
		return Vector3(p.x, 0, p.y)
	elseif #verts == 4 then
		local p = self:EvaluateBezier(ratio)
		return Vector3(p.x, 0, p.y)
	end
	assert(false, "Edge can't have more than 4 vertices")
end


function Lattice:FromEdge()
	-- distribute based on bezier interpolation
	local verts = self.edge.verts
	local totlen = 0
	for i=1,#verts-1 do
		local delta = verts[i+1] - verts[i]
		totlen = totlen + delta:Length()
	end
	local seglen = totlen / (self.w - 1)
	local curlen = 0

	self.positions = {}

	assert(#verts >= 1 and #verts <= 4)
	self.positions[1] = verts[1]
	for i=2,self.w - 1 do
		local ratio = (i-1)/(self.w-1)
		self.positions[i] = self:EdgePointSmooth(ratio)
	end
	self.positions[self.w] = verts[#verts]
end

function Lattice:GenerateVerts()
	self.verts = {}
	for y = 1,self.h do
		self.verts[y] = {}
		for x=1,self.w do
			local p1 = deepcopy(self.positions[x])
			p1.y = (y-1) * -0.5
			self.verts[y][x] = Vector3(p1.x, p1.y, p1.z)
		end
	end
end

-- calculate the normals of the horizontal edges only (like, normals don't really have edges)
function Lattice:CalcEdgeNormals(edges)
	local up = Vector3(0,1,0)
	local verts = self.verts
	self.edgenormals = {}
	for y=1,self.h do
		self.edgenormals[y] = {}
		for x=1,self.w-1 do
			local e1 = verts[y][x+1] - verts[y][x]
			local cross = e1:Cross(up)
			self.edgenormals[y][x] = cross:Normalize();
		end
	end
end

-- These are the normals in the y=0 plane, not the normals of a plane in the lattice
function Lattice:CalcPlaneNormals(edges)
	local prevedge = self.edge.prevedge
	local nextedge = self.edge.nextedge
	local prevlattice = edges[prevedge].lattice
	local nextlattice = edges[nextedge].lattice
	self.vertexnormals = {}
	for y=1,self.h do
		self.vertexnormals[y] = {}
		-- the first one needds the last edge from the previous edge
		local n1 = prevlattice.edgenormals[y][self.w-1]
		local n2 = self.edgenormals[y][1]
		local normal = (n1 + n2) / 2
		self.vertexnormals[y][1] = normal
		--self.vertexnormals[y][1] = Vector3(0,0,2)

		for x=2,self.w-1 do
			local n1 = self.edgenormals[y][x-1]
			local n2 = self.edgenormals[y][x]
			local normal = (n1 + n2) / 2
			self.vertexnormals[y][x] = normal
		end
		-- the last one needs the first edge from the next mesh
		local n1 = self.edgenormals[y][self.w-1]
		local n2 = nextlattice.edgenormals[y][1]
		local normal = (n1 + n2) / 2
		self.vertexnormals[y][self.w] = normal
	end
end

function Lattice:Displace(edges, index, d)
	local prevedge = self.edge.prevedge
	--print("noise:prevedge:",prevedge)
	local prevedge = edges[prevedge]
	local prevlattice = prevedge.lattice

	if type(index) ~= "table" then
		index = {index}
	end

	local disp = (type(d) == "function" and d() or d)
	for _,y in pairs(index) do
		local normal = self.vertexnormals[y][1] * disp
		local p1 = self.verts[y][1]
		prevlattice.verts[y][self.w] = p1 + normal
		self.verts[y][1] = p1 + normal
	end

	for x=2,self.w-1 do
		local disp = (type(d) == "function" and d() or d)
		for _,y in pairs(index) do
			local p1 = self.verts[y][x]
			local normal = self.vertexnormals[y][x] * disp
			self.verts[y][x] = p1 + normal
		end
	end
end

function Lattice:SetHeight(edges, index, d)
	local normal = Vector3(0,d,0)
	for y = index, index do
		for x=1,self.w do
			local p1 = self.verts[y][x]
			self.verts[y][x] = Vector3(p1.x, d, p1.z)
		end
	end
end

-- this can all be optimized a bit, the rightmost row of a lattice need not be processed
-- it's normal will match the leftmost row of it's nextedge
function Lattice:GetVert(edges, x, y)
	if y >= 1 and y<= self.h then
		if x < 1 then
			-- get prev to last one from previous lattice (last one matches my first)
			assert(x==0)
			local prevedge = self.edge.prevedge
			local prevlattice = edges[prevedge].lattice
			local vert = prevlattice:GetVert(edges, self.w-1, y)
			--assert(vert ~= self.verts[y][1])
			return vert
		elseif x > self.w then
			-- get second one from next lattice (first one matches my last)
			assert(x == self.w + 1)
			local nextedge = self.edge.nextedge
			local nextlattice = edges[nextedge].lattice
			local vert = nextlattice:GetVert(edges, 2, y)
			--assert(vert ~= self.verts[y][self.w])
			return vert
		else
			return self.verts[y][x]
		end
	end
end

function Lattice:TriangleNormal(p1,p2,p3)
	if p1 == nil or p2 == nil or p3 == nil then
		return nil
	end
	-- just kept separate for readability
	if p3 == p1 or p3 == p2 then
		return nil
	end
	local e1 = p2 - p1
	local e2 = p3 - p1
	local normal = e1:Cross(e2)
	return normal:Normalize()
end

function Lattice:CalculateSurfaceArea(p1,p2,p3,p4,p5,p6,p7)
	-- not implemented, seems not needed
end

function Lattice:CalculateSurfaceAreaAndAngle(p1,p2,p3,p4,p5,p6,p7)
	-- not implemented, seems not needed
end

function Lattice:CalculateNormalSum(p1,p2,p3,p4,p5,p6,p7)
	local count = 0
	local sum = Vector3(0,0,0)
	local n = self:TriangleNormal(p4,p1,p2)
	if n then
		count = count + 1
		sum = sum + n
	end
	local n = self:TriangleNormal(p4,p2,p5)
	if n then
		count = count + 1
		sum = sum + n
	end
	local n = self:TriangleNormal(p4,p5,p7)
	if n then
		count = count + 1
		sum = sum + n
	end
	local n = self:TriangleNormal(p4,p7,p6)
	if n then
		count = count + 1
		sum = sum + n
	end
	local n = self:TriangleNormal(p4,p6,p3)
	if n then
		count = count + 1
		sum = sum + n
	end
	local n = self:TriangleNormal(p4,p3,p1)
	if n then
		count = count + 1
		sum = sum + n
	end
	if count ~= 0 then
		return sum:Normalize()
	end
	return Vector3(0,0,1)
end

function Lattice:CalculateNormal(edges,x,y)
	-- get the 2 vertices above me
	local p1 = self:GetVert(edges, x-1,y-1)
	local p2 = self:GetVert(edges, x,y-1)
	-- get 3 vertices on my tier
	local p3 = self:GetVert(edges, x-1,y)
	local p4 = self:GetVert(edges, x,y)
	local p5 = self:GetVert(edges, x+1,y)
	-- and get the 2 vertices below me
	local p6 = self:GetVert(edges, x,y+1)
	local p7 = self:GetVert(edges, x+1,y+1)

	local normal = self:CalculateNormalSum(p1, p2, p3, p4, p5, p6, p7)
	return normal
end

function Lattice:GenerateVertNormals(edges)
	self.normals = {}
	for y = 1,self.h do
		self.normals[y] = {}
		for x=1,self.w do
			local normal = self:CalculateNormal(edges,x,y)
			self.normals[y][x] = normal
		end
	end
end

function Lattice:GenerateUVs(edges, atlasuvs)
	local uvind = math.random(#atlasuvs)
	local u1 = atlasuvs[uvind].u1
	local u2 = atlasuvs[uvind].u2
	local v1 = atlasuvs[uvind].v2
	local v2 = atlasuvs[uvind].v1

	local delta_u = u2 - u1
	local delta_v = v2 - v1

	local verts = self.verts

	self.uvs = {}
	for y = 1,self.h do
		self.uvs[y] = {}
		for x=1, self.w do
			self.uvs[y][x] = Vector2(0,0)
		end
	end
	-- the u
	for y = 1,self.h do
		local totlength = 0
		local lengths = {}
		for x=1, self.w-1 do
			lengths[x] = totlength
			local delta = verts[y][x+1] - verts[y][x]
			totlength = totlength + delta:Length()
		end
		lengths[self.w] = totlength

		for x=1,self.w do
			local u = u1 + delta_u * (lengths[x]/totlength)
			self.uvs[y][x].x = u
		end
	end
	-- the v
	for x = 1,self.w do
		local totlength = 0
		local lengths = {}
		for y=1, self.h-1 do
			lengths[y] = totlength
			local delta = verts[y+1][x] - verts[y][x]
			totlength = totlength + delta:Length()
		end
		lengths[self.h] = totlength
		for y=1, self.h do
			local v = v1 + delta_v * (lengths[y]/totlength)
			self.uvs[y][x].y = v
		end
	end
end

function Lattice:RenderQuad(v1,v2,v3,v4,uv1,uv2,uv3,uv4, meshdata)

	local vertices = meshdata.vertices
	local normals = meshdata.normals
	local uvs = meshdata.uvs

	local function Vert(p)
		table.insert(vertices, p.x)
		table.insert(vertices, p.y)
		table.insert(vertices, p.z)
	end
	local function Normal(n)
		table.insert(normals, n.x)
		table.insert(normals, n.y)
		table.insert(normals, n.z)
	end
	local function UV(v)
		table.insert(uvs, v.x)
		table.insert(uvs, v.y)
	end

	local edge1 = v2 - v1
	local edge2 = v3 - v1
	local normal1 = edge1:Cross(edge2)
	normal1:Normalize()

	Vert(v1)
	Normal(normal1)
	UV(uv1)

	Vert(v2)
	Normal(normal1)
	UV(uv2)

	Vert(v3)
	Normal(normal1)
	UV(uv3)

	local edge1 = v2 - v3
	local edge2 = v4 - v2
	local normal2 = edge1:Cross(edge2)
	normal2:Normalize()

	Vert(v3)
	Normal(normal2)
	UV(uv3)

	Vert(v2)
	Normal(normal2)
	UV(uv2)

	Vert(v4)
	Normal(normal2)
	UV(uv4)
end

function Lattice:RenderQuadWithNormals(v1,v2,v3,v4,uv1,uv2,uv3,uv4,n1,n2,n3,n4, meshdata)

	local vertices = meshdata.vertices
	local normals = meshdata.normals
	local uvs = meshdata.uvs

	local function Vert(p)
		table.insert(vertices, p.x)
		table.insert(vertices, p.y)
		table.insert(vertices, p.z)
	end
	local function Normal(n)
		table.insert(normals, n.x)
		table.insert(normals, n.y)
		table.insert(normals, n.z)
	end
	local function UV(v)
		table.insert(uvs, v.x)
		table.insert(uvs, v.y)
	end

	Vert(v1)
	Normal(n1)
	UV(uv1)

	Vert(v2)
	Normal(n2)
	UV(uv2)

	Vert(v3)
	Normal(n3)
	UV(uv3)

	Vert(v3)
	Normal(n3)
	UV(uv3)

	Vert(v2)
	Normal(n2)
	UV(uv2)

	Vert(v4)
	Normal(n4)
	UV(uv4)
end

function Lattice:RenderToMesh(meshdata)
	for y = 1,self.h-1 do
		for x=1,self.w-1 do
			local p1 = self.verts[y][x]
			local p2 = self.verts[y][x+1]
			local p3 = self.verts[y+1][x]
			local p4 = self.verts[y+1][x+1]
			local uv1 = self.uvs[y][x]
			local uv2 = self.uvs[y][x+1]
			local uv3 = self.uvs[y+1][x]
			local uv4 = self.uvs[y+1][x+1]
			local n1 = self.normals[y][x]
			local n2 = self.normals[y][x+1]
			local n3 = self.normals[y+1][x]
			local n4 = self.normals[y+1][x+1]
			if flat_shaded then
				self:RenderQuad(p1, p2, p3, p4, uv1, uv2, uv3, uv4, meshdata, x % 2 == y % 2)
			else
				self:RenderQuadWithNormals(p1, p2, p3, p4, uv1, uv2, uv3, uv4, n1,n2,n3,n4,meshdata)
			end
		end
	end
end

return Lattice
