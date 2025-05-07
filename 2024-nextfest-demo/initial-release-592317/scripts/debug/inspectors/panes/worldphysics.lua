local DebugDraw = require "util.debugdraw"
local Enum = require "util.enum"
local color = require "math.modules.color"
local ui = require "dbui.imgui"

-- Constructs a sequence of line segments defining the physics bounds of the
-- world.
local WorldPhysicsEditorPane = Class(function(self, id, constraint)
	self.id = id
	assert(self.Constraint:Contains(constraint), "Invalid enum value.")
	self.constrain_to_blockers = constraint == self.Constraint.s.ByBlockers
end)

WorldPhysicsEditorPane.Constraint = Enum{
	"Unconstrained",
	"ByBlockers",
}


-- Draw the physics bounds created by this editor so you can see what the final
-- result looks like (as opposed to the edit view). Takes the list of points
-- you get from GetPoints.
-- points = WorldAutogenData[TheWorld.prefab].worldCollision.points
function WorldPhysicsEditorPane:DrawBounds(points)
	for i=1,#points,2 do
		local pt = circular_index(points, i)
		local next_pt = circular_index(points, i+1)
		local x1, z1 = table.unpack(pt)
		local x2, z2 = table.unpack(next_pt)
		local c = color.hue(WEBCOLORS.BLUE, (i-1) / #points)
		DebugDraw.GroundLine(x1, z1, x2, z2, c)
	end
end

function WorldPhysicsEditorPane:StartEditing(loopdata)
	if not self.editing then
		self.editing = true
		self.handler = TheInput:AddMouseButtonHandler(function(button, down, x, y) self:OnMouseButton(button, down, x, y) end)
		local pointdata = loopdata or GenerateCollisionEdge(TheWorld, self.constrain_to_blockers)
		self:SetData(pointdata)
		self:Connect()
		self.pristine = loopdata == nil
		TheInput:SetEditingBlocksGameplay(true)
	end
end

function WorldPhysicsEditorPane:SetData(points)
	self.edges = {}
	for i=1, #points,2 do
		local edge = {}
		edge.p1 = Vector2(points[i][1], points[i][2])
		edge.p2 = Vector2(points[i+1][1], points[i+1][2])
		table.insert(self.edges, edge)
	end
	self:Connect()
end

function WorldPhysicsEditorPane:Connect()
	local edges = self.edges
	-- make sure each edge butts up to exactly one other edge
	for i,baseedge in pairs(edges) do
		local startpoint = baseedge.p1
		local endpoint = baseedge.p2
		local outedge = nil
		local inedge = nil
		for j,testedge in pairs(edges) do
			local mystartpoint = testedge.p1
			local myendpoint = testedge.p2
			if mystartpoint == endpoint then
				assert(not outedge, "Multiple outgoing edges")
				--outedge = testedge
				outedge = j
				--print("equal out",testedge,j)
			end
			if myendpoint == startpoint then
				assert(not inedge, "Multiple incoming edges")
				--inedge = testedge
				inedge = j
				--print("equal in",testedge,j)
			end
		end
		assert(inedge ~= outedge, "Incoming edge can't be outgoing edge")
		assert(inedge, "No incoming edge found")
		assert(outedge, "No outgoing edge found")
		baseedge.nextedge = outedge
		baseedge.prevedge = inedge
	end
end

function WorldPhysicsEditorPane:StopEditing()
	if self.editing then
		self.editing = false
		self.handler:Remove()
		self.handler = nil
		self.points = nil
		self.pristine = nil
		TheInput:SetEditingBlocksGameplay(false)
	end
end

-- Returns points which are pairs of line segments. Segments are not guaranteed
-- to be consecutive and don't share verticies (so vertices may appear twice).
function WorldPhysicsEditorPane:GetPoints()
	local points = {}
	local edges = self.edges
	for i,edge in pairs(edges) do
		table.insert(points, {edge.p1.x, edge.p1.y})
		table.insert(points, {edge.p2.x, edge.p2.y})
	end
	return points
end

function WorldPhysicsEditorPane:Refresh()
	local points = self:GetPoints()
	TheWorld.Map:SetCollisionEdges(points, false)
end

function WorldPhysicsEditorPane:DoDeleteHoveredPoint()
	if self.deleteHoveredPoint then
		self.deleteHoveredPoint = nil

		if self.hoverpoint then
			-- okay, we're deleting p1 from edge self.hoverpoint
			-- which means that the prevedge's next becomes my next and the nextedges prev becomes my prev
			-- also, only do that if at least 3 edges remain
			local startedge = self.hoverpoint
			local curedge = startedge
			for i=1, 3 do
				local edge = self.edges[curedge]
				curedge = edge.nextedge
				if curedge == startedge then
					print("can't delete, would make the loop smaller than 3 points")
					return
				end
			end

			-- fix up surrounding edges
			local edge = self.edges[self.hoverpoint]
			local prevedge = self.edges[edge.prevedge]
			prevedge.p2 = edge.p2
			-- remove current edge
			table.remove(self.edges, self.hoverpoint)
			-- reconnect everything
			self:Connect()
			self.pristine = false
			self:Refresh()
		end
		self.hoverpoint = nil
	end
end

function WorldPhysicsEditorPane:DeleteHoveredPoint()
	self.deleteHoveredPoint = true
end

function WorldPhysicsEditorPane:GetClosesSegment()
	-- find the closest line segment and insert between its start and end
	local mousepos = TheInput:GetWorldPosition()
	local smallestdist = 1000000
	local smallestindex
	local edges = self.edges
	for i,edge in pairs(edges) do
		local p1 = edge.p1
		local p2 = edge.p2
		local v1 = Vector3(p1.x, 0, p1.y)
		local v2 = Vector3(p2.x, 0, p2.y)

		-- get distance between mouse point and this line segment
		local dist = VecUtil_DistancePointToLineSeg(mousepos, v1, v2)
		if dist < smallestdist then
			smallestdist = dist
			smallestindex = i
		end
	end


	return smallestindex
end

function WorldPhysicsEditorPane:DoAddCurvePoint()
	if self.addCurvePoint then
		self.addCurvePoint = nil

		local mousepos = TheInput:GetWorldPosition()
		local point = Vector2(mousepos.x, mousepos.z)
		local index = self:GetClosesSegment()
		-- insert an edge
		local edge = self.edges[index]

		-- insert next neighbor
		local newedge = {}
		newedge.p1 = point:Clone()
		newedge.p2 = edge.p2:Clone()
		table.insert(self.edges,newedge)

		-- fix me up
		edge.p2 = point:Clone()
		-- reconnect everything
		self:Connect()

		self.pristine = false
		self:Refresh()

	end
end

function WorldPhysicsEditorPane:AddCurvePoint()
	self.addCurvePoint = true
end

function WorldPhysicsEditorPane:DoReleasePoint()
	if self.releasePoint then
		self.releasePoint = nil

		self.activepoint = nil
		self:Refresh()
	end
end

function WorldPhysicsEditorPane:ReleasePoint()
	self.releasePoint = true
end

function WorldPhysicsEditorPane:OnMouseButton(button, down, x, y)
	if down then
		if button == InputConstants.MouseButtons.LEFT then
			if TheInput:IsKeyDown(InputConstants.Keys.CTRL) then
				self:AddCurvePoint()
			else
				if not self.activepoint then
					if self.hoverpoint then
						self.activepoint = self.hoverpoint
					end
				end
			end
		elseif button == InputConstants.MouseButtons.RIGHT then
			self:DeleteHoveredPoint()
		end
	else
		if button == InputConstants.MouseButtons.LEFT then
			if self.activepoint then
				self:ReleasePoint()
			end
		end
	end
end

function WorldPhysicsEditorPane:DrawLoop()
	local scale = ui:GetDisplayScale()
	local wx,wy = TheSim:GetScreenSize()
	local screen_scale = wx / 100
	local square_thickness = screen_scale / scale

	local edges = self.edges
	local curedge = self.hoverpoint
	local prevedge = curedge and self.edges[curedge].prevedge
	for i,edge in pairs(edges) do

		local p1 = edge.p1
		local p2 = edge.p2
		local v1 = Vector3(p1.x, 0, p1.y)
		local v2 = Vector3(p2.x, 0, p2.y)

		if i == curedge or i == prevedge then
			TheDebugRenderer:WorldLine({v1:Get()},{v2:Get()}, BGCOLORS.WHITE)
		else
			TheDebugRenderer:WorldLine({v1:Get()},{v2:Get()}, BGCOLORS.BLUE)
		end

		local pos1 = v1 + Vector3(0.25,0,0)
		local pos2 = v1 - Vector3(0.25,0,0)
		if i == curedge then
			TheDebugRenderer:WorldLine({pos1:Get()}, {pos2:Get()}, BGCOLORS.WHITE, square_thickness)
		else
			TheDebugRenderer:WorldLine({pos1:Get()}, {pos2:Get()}, BGCOLORS.BLUE, square_thickness)
		end

	end
end

function WorldPhysicsEditorPane:MovePoint()
	if self.activepoint then
		local pos = TheInput:GetWorldPosition()
		if pos then
			local edge = self.edges[self.activepoint]
			local prevedge = self.edges[edge.prevedge]
			edge.p1 = Vector2(pos.x, pos.z)
			prevedge.p2 = Vector2(pos.x, pos.z)
			self.pristine = false
		end
	end
end

function WorldPhysicsEditorPane:CheckHover()
	if not self.activepoint then
		local pos = TheInput:GetWorldPosition()
		if pos then
			local smallestdist = 100000
			local smallestidx
			local edges = self.edges
			for i,edge in pairs(edges) do
				local p = edge.p1
				local dx = pos.x - p.x
				local dz = pos.z - p.y
				local sqdist = dx*dx + dz * dz
				if sqdist < smallestdist then
					smallestdist = sqdist
					smallestidx = i
				end
			end
			if smallestdist < 0.5 * 0.5 then
				self.hoverpoint = smallestidx	-- p1 from that edge
			else
				self.hoverpoint = nil
			end
		end
	end
end

function WorldPhysicsEditorPane:OnRender(prefab, loopdata)
	if not TheWorld or TheWorld.prefab ~= prefab then
		ui:Text("** World Physics can only be edited when inside the level being edited **")
		return loopdata
	end

	if not self.editing then
		if ui:Button("Start Editing"..self.id) then
			self:StartEditing(loopdata)
		end
	else
		if ui:Button("Stop Editing"..self.id) then
			self:StopEditing()
		end
	end

	if loopdata ~= nil then
		ui:SameLine()
		ui:Dummy(8, 0)
		ui:SameLine()

		if ui:Button("Reset World Collision"..self.id) then
			ui:OpenPopup(" Reset World Collision?##worldcollisionreset"..self.id)
		end
		if ui:BeginPopupModal(" Reset World Collision?##worldcollisionreset"..self.id, false, ui.WindowFlags.AlwaysAutoResize) then
			ui:Spacing()
			ui:PushStyleColor(ui.Col.Button, { .75, 0, 0, 1 })
			ui:PushStyleColor(ui.Col.ButtonHovered, { 1, .2, .2, 1 })
			ui:PushStyleColor(ui.Col.ButtonActive, { .95, 0, 0, 1 })
			ui:Dummy(20, 0)
			ui:SameLine()
			if ui:Button("Reset##worldcollisionreset"..self.id) then
				self:StopEditing()
				GenerateCollisionEdge(TheWorld, self.constrain_to_blockers)
				loopdata = nil
				ui:CloseCurrentPopup()
			end
			ui:PopStyleColor(3)

			ui:SameLine();ui:Dummy(30,0);ui:SameLine()
			if ui:Button("Cancel##worldcollisionreset"..self.id) then
				ui:CloseCurrentPopup()
			end
			ui:SameLine()
			ui:Dummy(20, 0)
			ui:Spacing()
			ui:EndPopup()
		end
	end

	if self.editing then
		ui:Text("LMB - Move point")
		ui:Text("RMB - Delete point")
		ui:Text("CTRL+LMB - Add point")
		self:DrawLoop()
		self:CheckHover()
		self:MovePoint()
		-- defered commands
		self:DoReleasePoint()
		self:DoAddCurvePoint()
		self:DoDeleteHoveredPoint()

		if self.pristine then
			return nil
		else
			return self:GetPoints()
		end
	else
		if loopdata then
			self.draw_bounds = ui:_Checkbox("Draw Line Segments"..self.id, self.draw_bounds)
			if self.draw_bounds then
				self:DrawBounds(loopdata)
			end
		end
		return loopdata
	end
end

return WorldPhysicsEditorPane
