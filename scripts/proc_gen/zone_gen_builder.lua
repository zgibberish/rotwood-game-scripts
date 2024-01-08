local Lume = require "util.lume"
local Vec2 = require "math.modules.vec2"
local ZoneGrid = require "map.zone_grid"
local DungeonProgress = require "proc_gen.dungeon_progress"
local SceneSpacer = require "proc_gen.scene_spacer"
local PropProcGen = require "proc_gen.prop_proc_gen"
local PropColorVariant = require "proc_gen.prop_color_variant"
local KMath = require "util.kmath"
local Bound2 = require "math.modules.bound2"
require "mathutil"

local function Enabled(t)
	return t.enabled
end

local function InitializeElementList(scene_props, spacers, particle_systems, dungeon_progress)
	local elements = {}

	-- Create a list of props to shuffle and cycle through. The same prop may appear multiple times, thereby effecting
	-- specific ratios of props.
	-- 1) Compute the likelihoods as modulated by dungeon progress. Remember the lowest non-zero likelihood.
	local likelihood_min
	local weighted_elements = Lume(table.appendarrays(scene_props, spacers, particle_systems))
		:map(function(element)
			local likelihood = element:GetDungeonProgressConstraints()
				and DungeonProgress.ComputeLikelihood(dungeon_progress, element:GetDungeonProgressConstraints())
				or 1
			if 0.0 < likelihood and (not likelihood_min or likelihood < likelihood_min) then
				likelihood_min = likelihood
			end
			return {
				likelihood = likelihood,
				element = element
			}
		end)
		:result()

	if likelihood_min then
		-- 2) Convert floating-point likelihoods into integer prop counts by dividing likelihoods by likelihood_min.
		-- Thus the least likely prop will appear once, and the rest will scale to match.
		-- Remember the highest count.
		local count_max
		local counted_elements = Lume(weighted_elements)
			:map(function(weighted_element)
				local factor = weighted_element.likelihood / likelihood_min
				local count = (weighted_element.element:GetCount() or 1) * factor
				count = math.ceil(count)
				if not count_max or count_max < count then
					count_max = count
				end
				return {
					count = count,
					element = weighted_element.element
				}
			end)
			:result()

		-- 3) The likelihood_min may have been very tiny resulting in very large counts. We now have the correct
		-- distribution in integers, but our numbers may be excessively large. Scale them down to something
		-- reasonable, based on the count_max.
		-- Note that this may push less likely props out of candidacy completely.
		local COUNT_MAX = 100
		local factor = COUNT_MAX < count_max
			and (COUNT_MAX / count_max)
			or 1
		for _, counted_element in ipairs(counted_elements) do
			local count = math.floor(counted_element.count * factor)
			for _ = 1, count do
				table.insert(elements, counted_element.element)
			end
		end
	end

	return elements
end

-- This is the class that actually places props within the zone, governed by a particular ZoneGen asset.
-- This class contains data that is mutated at runtime and so is kept separate from ZoneGen, which is immutable at
-- run-time.
local ZoneGenBuilder = Class(function(
	self, 
	scene_gen, 
	zone_gen, 
	rng, 
	zone_grid, 
	map_layout, 
	featured_locations, 
	previous_placement_circles, 
	report,
	dungeon_progress
)
	self.scene_gen = scene_gen
	self.zone_gen = zone_gen
	self.rng = rng
	self.zone_grid = zone_grid
	self.map_layout = map_layout
	self.featured_locations = featured_locations
	self.report = report
	self.report.log = {}

	-- Build a set of candidate tiles to spawn in.
	self.tiles = {}
	for _, zone in ipairs(zone_gen.zones) do
		zone_grid:ForEachCellInZone(zone, function(_, x, z)
			self.tiles[self.zone_grid:GridToIndex(x, z)] = {x = x, z = z, spawn_count = 0}
		end)
	end
	self.tile_indices = Lume(self.tiles):keys():sort():result() -- @chrisp #rng - determinism
	self.rng:Shuffle(self.tile_indices)
	self.tile_iter = 1

	local scene_props = Lume(zone_gen.scene_props):filter(Enabled):result()
	local spacers = Lume(zone_gen.spacers):filter(Enabled):result()
	local particle_systems = Lume(zone_gen.particle_systems):filter(Enabled):result()

	-- Extract required_props. They will appear in the weighted_props list too.
	self.required_props = Lume(table.appendarrays(scene_props, particle_systems))
		:filter(function(scene_element)
			return Lume(scene_element.flags):find(PropProcGen.Tag.s.required):result()
		end)
		:result()

	-- Push centered props to the front so they are placed first, as their constraints
	-- are more restrictive.
	local next_centered_index = 1
	for i = 1, #self.required_props do
		if i ~= next_centered_index then
			local is_centered = Lume(self.required_props[i].flags)
				:find(PropProcGen.Tag.s.centered)
				:result()
			if is_centered then
				-- Swap it with next_centered_index...
				local temp = self.required_props[i]
				self.required_props[i] = self.required_props[next_centered_index]
				self.required_props[next_centered_index] = temp

				-- ...then increment next_centered_index.
				next_centered_index = next_centered_index + 1
			end
		end
	end

	self.shuffled_elements = InitializeElementList(scene_props, spacers, particle_systems, dungeon_progress)

	self.circles = previous_placement_circles or {}
	self.placement_circles = {}
	self.placed_elements = {}

	-- Initialize placed_props with seed_circles too, so we don't spawn intersecting them.
	self.previously_placed_elements = previous_placement_circles 
		and Lume(previous_placement_circles)
			:map(function(circle) 
				return {
					location = circle.center, 
					element = SceneSpacer.FromRawTable({radius = circle.radius})
				}
			end)
			:result()
		or {}
end)

-- Pop the next element in the shuffled, ratio'd list.
function ZoneGenBuilder:NextElement()
	if next(self.required_props) then
		return self.required_props[1]
	end
	-- Reshuffle when we get to the end.
	if not self.next_element then
		self.rng:Shuffle(self.shuffled_elements)
		self.next_element = next(self.shuffled_elements)
	end

	local index = self.next_element
	local element = self.shuffled_elements[index]
	self.next_element = next(self.shuffled_elements, index)
	return element, index
end

-- Go through the list of tiles only once. Don't re-shuffle.
function ZoneGenBuilder:NextTile()
	for i = self.tile_iter, #self.tile_indices do
		local tile = self.tiles[self.tile_indices[i]]
		if tile.spawn_count == 0 then
			self.tile_iter = i + 1
			return tile
		end
	end
	self.tile_iter = nil
end

-- Find and return the tile closest to the center of the stage. Swap its index in self.tile_indices
-- such that it is subsequently skipped by NextTile().
function ZoneGenBuilder:CenterTile()
	local closest_distance
	local center_tile_index
	for i, tile in pairs(self.tiles) do
		local world_position = self.zone_grid:GridToWorld(tile)
		local distance = math.abs(world_position.x) + math.abs(world_position.z)
		if not closest_distance or distance < closest_distance then
			closest_distance = distance
			center_tile_index = i
		end
	end

	-- Find the center tile in tile_indices.
	local center_tile_iter = Lume(self.tile_indices):find(center_tile_index):result()

	-- If it has not already been processed, adjust tile_indices to show that now it has.
	if self.tile_iter <= center_tile_iter then
		local temp = self.tile_indices[self.tile_iter]
		self.tile_indices[self.tile_iter] = center_tile_index
		self.tile_indices[center_tile_iter] = temp
		self.tile_iter = self.tile_iter + 1
	end

	return self.tiles[center_tile_index]
end

function ZoneGenBuilder:GetTileBounds(tile)
	local bounds = self.zone_gen.offstage
		-- Props in tiles along the perimeter of the stage need to be further restricted 
		-- because we render about half of an empty tile as occupied with overhang, and we don't want props to occupy
		-- that space
		and self.zone_grid:GetOffstageBounds(tile.x, tile.z)
		-- Conversely, sometimes we want to explicitly permit props on the overhang.
		or self.zone_grid:GetStageBounds(tile.x, tile.z)

	-- Either of the previous bounds functions might return nil so fall back to the
	-- unrestricted tile bounds.
	return bounds
		or self.zone_grid:GetTileBounds(tile.x, tile.z)
end

function ZoneGenBuilder:RandomPointInTile(tile, element)
	local bounds = self:GetTileBounds(tile)
	local radius = element:GetPersistentRadius()
	local tile_world_location = self.zone_grid:GridToWorld(tile)
	local inset = {}

	-- See if this tile is subject to restricted bounds.
	local HALF_TILE = TILE_SIZE / 2
	local tile_edge = HALF_TILE - 0.01
	local offsets = {
		{x = tile_edge, z = 0, max = {x = -radius, z = 0}},
		{x = -tile_edge, z = 0, min = {x = radius, z = 0}},
		-- Note that the y-axis of the bounds is the inverse of the z-axis.
		{x = 0, z = tile_edge, min = {x = 0, z = radius}},
		{x = 0, z = -tile_edge, max = {x = 0, z = -radius}},
	}
	for i, offset in ipairs(offsets) do
		local world_location = {
			x = tile_world_location.x + offset.x, 
			z = tile_world_location.z + offset.z
		}
		if not bounds:contains(Vec2(world_location.x, world_location.z)) then
			if offset.min then
				bounds.min.x = bounds.min.x + offset.min.x
				bounds.min.y = bounds.min.y + offset.min.z
			end
			if offset.max then
				bounds.max.x = bounds.max.x + offset.max.x
				bounds.max.y = bounds.max.y + offset.max.z
			end
			inset[i] = true
		end
	end

	-- For the cardinal directions we have not touched, check the adjacent cells for membership in our
	-- ZoneGen and pull in the bounds in that direction if they are not a match.
	local offsets = {
		{x = 1, z = 0, max = {x = -radius, z = 0}},
		{x = -1, z = 0, min = {x = radius, z = 0}},
		-- Note that the y-axis of the bounds is the inverse of the z-axis.
		{x = 0, z = 1, min = {x = 0, z = radius}},
		{x = 0, z = -1, max = {x = 0, z = -radius}},
	}
	assert(self.tiles[self.zone_grid:GridToIndex(tile.x, tile.z)])
	for i, offset in ipairs(offsets) do
		if not inset[i] then
			local x = tile.x + offset.x
			local z = tile.z + offset.z
			if 0 <= x and 0 <= z then
				local index = self.zone_grid:GridToIndex(x, z)
				if not self.tiles[index] then
					if offset.min then
						bounds.min.x = bounds.min.x + offset.min.x
						bounds.min.y = bounds.min.y + offset.min.z
					end
					if offset.max then
						bounds.max.x = bounds.max.x + offset.max.x
						bounds.max.y = bounds.max.y + offset.max.z
					end
				end
			end
		end
	end

	if bounds:is_valid() then
		local world_location = Vec2(
			self.rng:Float(bounds.min.x, bounds.max.x),
			self.rng:Float(bounds.min.y, bounds.max.y)
		)
		local grid_location = self.zone_grid:WorldToGrid({x = world_location.x, z = world_location.y})
		assert(grid_location.x == tile.x)
		assert(grid_location.z == tile.z)
		return world_location
	end
end

function ZoneGenBuilder:ZoneGenContains(element, x, z)
	-- Compute the point on the circle in the 4 cardinal directions and see if those points
	-- are in tiles in our zone gen. If not, return false.
	local radius = element:GetPersistentRadius()
	local offsets = {
		{x = radius, z = 0},
		{x = -radius, z = 0},
		{x = 0, z = radius},
		{x = 0, z = -radius},
	}
	local tile = self.zone_grid:WorldToGrid({x = x, z = z})
	if not tile then
		-- Location is not on the tile layout.
		return false
	end
	local tile_index = self.zone_grid:GridToIndex(tile.x, tile.z)
	local bounds = self:GetTileBounds(tile)
	for _, offset in ipairs(offsets) do
		local world_location = {x = x + offset.x, z = z + offset.z}
		local grid_location = self.zone_grid:WorldToGrid(world_location)
		-- If world_location is nil, the circle point is outside the zone_grid entirely, which is ok.
		if grid_location then
			local index = self.zone_grid:GridToIndex(grid_location.x, grid_location.z)
			if not self.tiles[index] then
				return false
			end

			-- If the test point is in the same tile as the center, it must be within the possibly
			-- restricted bounds.
			if index == tile_index 
				and not bounds:contains(Vec2(world_location.x, world_location.z)) 
			then
				return false
			end
		end
	end
	return true
end

-- Return true if the circle with a radius equal to the element's persistent radius centered on the specified point
-- intersects any existent placement circle, or intersects the edge of the zone composition
-- of this zone_gen.
function ZoneGenBuilder:IsIntersecting(element, x, z)
	local element_center = Vec2(x,z)
	if not self:ZoneGenContains(element, x, z) then
		return "intersects "..self.zone_gen:GetLabel()
	end
	for _, placed_element in ipairs(self.placed_elements) do
		local threshold = element:GetPersistentRadius() + placed_element.element:GetPlacementRadius()
		if Vec2.dist2(element_center, placed_element.location) < threshold * threshold then
			return "intersects "..placed_element.element:GetLabel()
		end
	end
	for _, placed_element in ipairs(self.previously_placed_elements) do
		local threshold = element:GetPersistentRadius() + placed_element.element:GetPlacementRadius()
		if Vec2.dist2(element_center, placed_element.location) < threshold * threshold then
			return "intersects "..placed_element.element:GetLabel()
		end
	end
end

local FEATURE_WIDTH = ZoneGrid.WORLD_TILE_SIZE
local HALF_FEATURE_WIDTH = FEATURE_WIDTH / 2
ZoneGenBuilder.FEATURE_HEIGHT = ZoneGrid.WORLD_TILE_SIZE
local TALL_FEATURE_HEIGHT = ZoneGrid.WORLD_TILE_SIZE * 2

function ZoneGenBuilder.MakeFeaturedLocationRect(world_location, feature_height)
	local x = world_location.x or 0
	local y = world_location.y or 0
	return Bound2.new(
		Vec2(x - HALF_FEATURE_WIDTH, y - feature_height),
		Vec2(x + HALF_FEATURE_WIDTH, y + (feature_height * 0.5))
	)
end

local function TopLeft(bounds)
	return Vec2(bounds.min.x, bounds.max.y)
end

local function TopRight(bounds)
	return Vec2(bounds.max.x, bounds.max.y)
end

local function BottomLeft(bounds)
	return Vec2(bounds.min.x, bounds.min.y)
end

local function BottomRight(bounds)
	return Vec2(bounds.max.x, bounds.min.y)
end

-- Sweep a featured location rect from the min point to the max point and create a polygon that encompasses that sweep.
function ZoneGenBuilder.MakeFeaturedLocationRectSweep(a, b, feature_height)
	-- Start at the top-most point and wind clockwise.
	if a.y < b.y then
		local temp = a
		a = b
		b = temp
	end

	-- Convert locations into Bound2s.
	a = ZoneGenBuilder.MakeFeaturedLocationRect(a, feature_height)
	b = ZoneGenBuilder.MakeFeaturedLocationRect(b, feature_height)

	local convex_polygon = {
		TopLeft(a),
		TopRight(a)
	}
	local ax_lt_bx = a.min.x < b.min.x
	if ax_lt_bx then
		table.insert(convex_polygon, TopRight(b))
	else
		table.insert(convex_polygon, BottomRight(a))
	end
	convex_polygon = table.appendarrays(convex_polygon, {
		BottomRight(b),
		BottomLeft(b)
	})
	if ax_lt_bx then
		table.insert(convex_polygon, BottomLeft(a))
	else
		table.insert(convex_polygon, 	TopLeft(b))
	end
	return convex_polygon
end

function ZoneGenBuilder:IsObscuringFeaturedLocation(element, placement)
	local is_tall = element.flags 
		and Lume(element.flags):any(function(flag) return flag == PropProcGen.Tag.s.tall end):result()
	local feature_height
	if is_tall then
		feature_height = TALL_FEATURE_HEIGHT
	else
		feature_height = ZoneGenBuilder.FEATURE_HEIGHT
	end

	local placement_location = Vec2.new(placement.x, placement.z)

	for _, world_location in ipairs(self.featured_locations) do
		-- If the featured location is structured as a point
		if world_location.x or world_location.z then
			local bounds = ZoneGenBuilder.MakeFeaturedLocationRect(
				Vec2(world_location.x, world_location.z), 
				feature_height
			)
			if bounds:contains(placement_location) then
				return true
			end
		-- If the featured location is structured as a set of line segments.
		elseif world_location.player and world_location.exits then
			for _, exit in ipairs(world_location.exits) do
				local convex_polygon = ZoneGenBuilder.MakeFeaturedLocationRectSweep(
					Vec2(world_location.player.x, world_location.player.z), 
					Vec2(exit.x, exit.z),
					feature_height
				)
				if IsPointInsideConvexPolygon(placement_location, convex_polygon) then
					return true
				end
			end
		end
	end
	return false
end

function ZoneGenBuilder:PlaceElement(element, x, z)
	local world_position = {x = x, z = z}
	local grid_position = self.zone_grid:WorldToGrid(world_position)
	if not grid_position then
		return false
	end

	local tile_index = self.zone_grid:GridToIndex(grid_position.x, grid_position.z)
	local tile = self.tiles[tile_index] 

	-- If the generated position is not within any of our zone tiles, reject it.
	if not tile then
		return false
	end

	-- Props in tiles along the perimeter of the stage need to be further restricted 
	-- because we render about half of an empty tile as occupied with cliff-edge, and we don't want props to occupy
	-- that space.
	local tile_bounds = self:GetTileBounds(grid_position)
	if not tile_bounds:contains(Vec2(x, z)) then
		return false
	end

	-- Filter by tile type.
	local external_tile_id = self.zone_grid.tile_layer.data[tile_index]
	local tile_name = self.map_layout.tilegroup.ExternalOrder[external_tile_id]
	if not element:CanPlaceOnTile(tile_name) then
		return false
	end

	-- Space is often reserved in front of important grid props that we do not want to obscure.
	if not self.zone_gen.can_obscure_features and self:IsObscuringFeaturedLocation(element, world_position) then
		return false
	end

	-- Walkability must match for on-stage props.
	if not self.zone_gen.offstage 
		and self.zone_gen.non_walkable == TheWorld.Map:IsWalkableAtXZ(x, z) 
	then
		return false
	end

	local function MatchElement(other_element)
		-- It is important to check nil-ness of element.prop as that tells us that element is a SceneProp.
		return (element.prop and other_element.prop and element.prop == other_element.prop)
			or (element.particle_system and other_element.particle_system and element.particle_system == other_element.particle_system)
	end

	-- Ok, good to go. Firstly, update required and unique flags.
	if next(self.required_props) then
		assert( MatchElement(self.required_props[1]))
		table.remove(self.required_props, 1)
	end
	if element.flags and Lume(element.flags):find(PropProcGen.Tag.s.unique):result() then
		self.shuffled_elements = Lume(self.shuffled_elements):removeall(function(shuffled_element)
			return MatchElement(shuffled_element)
		end):result()
	end

	-- Then register the placement.
	tile.spawn_count = tile.spawn_count + 1
	table.insert(self.circles, {
		center = Vec2(x,z), 
		radius = element:GetPersistentRadius(),
		type = element:GetDecorType()
	})
	if element:GetBufferRadius() ~= 0.0 then
		table.insert(self.placement_circles, {center = Vec2(x,z), radius = element:GetPlacementRadius()})
	end
	table.insert(self.placed_elements, {location = Vec2(x,z), element = element})
end

function ZoneGenBuilder:Warn(warning)
	table.insert(self.report.log, warning)
	-- print (warning)
end

function ZoneGenBuilder:PlaceElements()	
	-- Loop forever, placing elements as we go, until we can't any more.
	local spawn_attempts = 0
	local center_tile = false
	while true do
		spawn_attempts = spawn_attempts + 1

		-- In order to achieve the correct distribution of elements, we should only cycle elements in the outer loop.
		local element, start = self:NextElement()
		if not element then
			break
		end
		local centered_element = element.flags 
			and Lume(element.flags):find(PropProcGen.Tag.s.centered):result()

		-- Choose a circle to spawn next to.
		local circle = #self.circles ~= 0 and self.circles[1] or nil

		-- If there are no neighbors with potential adjacent space, grab the next empty tile.
		if not circle then
			while true do
				local tile = centered_element and self:CenterTile() or self:NextTile()
				if not tile then
					return spawn_attempts
				end
				center_tile = centered_element
				local center = self:RandomPointInTile(tile, element)
				if center then
					local intersecting = self:IsIntersecting(element, center.x, center.y)
					if not intersecting then
						self:PlaceElement(element, center.x, center.y)
						break
					end
					self:Warn("WARNING! Rejecting tile ("..tile.x..", "..tile.z..") because "..element:GetLabel().." "..intersecting)
				else	
					self:Warn("WARNING! Rejecting tile ("..tile.x..", "..tile.z..") because "..element:GetLabel().." cannot fit in "..self.zone_gen:GetLabel().."! It is too large!")				
				end

				-- If we failed to place a centered element, give up and don't loop because we won't be advancing through
				-- tiles in a way that ensures termination.
				if centered_element then
					self:Warn("WARNING! Failed to place 'center' element "..element:GetLabel().." in tile ("..tile.x..", "..tile.z..")")
					center_tile = false
					break
				end
			end
		-- Otherwise, spawn next to a circle.
		-- TODO @chrisp #scenegen - We should skip centered elements if we are not in the center tile. Usually this won't be a problem
		-- because centered elements will also be tagged as required, and hence placed first.
		-- i.e.
		-- elseif centered_element == center_tile then
		else
			local element_radius = element:GetPlacementRadius()
			local distance_between_proposed_adjacent_placements = (element_radius + element:GetPersistentRadius()) / 2
			local half_prop_arc = math.sin(distance_between_proposed_adjacent_placements / (circle.radius + element_radius)) + 0.01
			local prop_arc = half_prop_arc * 2

			-- Choose a tangent point on which to try to spawn the prop.
			if not circle.initial_angle then
				circle.initial_angle = self.rng:Float(math.pi * 2)
				circle.angle_iter =  -half_prop_arc
			end

			local direction = KMath.polar_to_cartesian(
				circle.radius + element:GetPlacementRadius() + 0.1, 
				circle.initial_angle + circle.angle_iter + half_prop_arc
			)
			direction = Vec2(direction.x, direction.z)
			local center = circle.center + direction
			
			-- circle.angle_iter will always point at the edge of the previously placed circle.
			circle.angle_iter = circle.angle_iter + prop_arc

			-- If we've gone all the way around this circle, it is done.
			if (math.pi * 2) <= circle.angle_iter then
				table.remove(self.circles, 1)
			end
			
			local intersecting = self:IsIntersecting(element, center.x, center.y)
			if not intersecting then
				self:PlaceElement(element, center.x, center.y)
			else
				-- self:Warn("  WARNING! circle ("..math.round(center.x, 2)..", "..math.round(center.y, 2)..", "..math.round(circle.angle_iter, 2)..") "..element:GetLabel().." "..intersecting)
			end
		end
	end

	return spawn_attempts
end

function ZoneGenBuilder:Build()
	-- Fill placed_props.
	local spawn_attempts = self:PlaceElements()
	local spawn_health = spawn_attempts ~= 0 
		and #self.placed_elements / spawn_attempts 
		or 1

	if self.report then
		self.report.circles = {}
	end

	-- Translate placed_elements into placements and return them.
	local element_placements = {}
	for _, placed_element in ipairs(self.placed_elements) do
		-- Only place elements that wrap prefabs (i.e. place props and particle systems, but not spacers)
		if placed_element.element.prop then
			local prefab = placed_element.element.prop
			element_placements[prefab] = element_placements[prefab] or {}
			table.insert(
				element_placements[prefab], 
				{
					x = placed_element.location.x, 
					y = placed_element.element:GetHeight(), 
					z = placed_element.location.y, 
					color_variant = PropColorVariant.ChooseColorVariant(self.rng, placed_element.element),
					canopy = placed_element.element.canopy,
					light_spot = placed_element.element.light_spot,
					tags = {DecorTags[DecorLayer.id[self.zone_gen.decor_layer]], self.zone_gen.tag}
				}
			)
		elseif placed_element.element.particle_system then
			local prefab = placed_element.element.particle_system
			element_placements[prefab] = element_placements[prefab] or {}
			table.insert(
				element_placements[prefab], 
				{
					x = placed_element.location.x, 
					y = placed_element.element:GetHeight(), 
					z = placed_element.location.y,
					particle_system = {
						layer_override = placed_element.element.layer
					},
					tags = {DecorTags[DecorLayer.id[self.zone_gen.decor_layer]], self.zone_gen.tag}
				}
			)
		end
		if self.report then
			table.insert(self.report.circles, {
				position = placed_element.location,
				radius = placed_element.element:GetPersistentRadius(),
				type = placed_element.element:GetDecorType()
			})
		end
	end

	local seeded_circles = Lume(self.placed_elements)
		:filter(function(placed_element)
			-- Don't seed spacers.
			return placed_element.element:GetDecorType() ~= DecorType.s.Spacer
		end)
		:map(function(placed_element)
			return {
				center = placed_element.location, 
				radius = placed_element.element:GetPersistentRadius()
			}
		end)
		:result()

	return element_placements, spawn_health, seeded_circles, self.placement_circles
end

function BuildZone(scene_gen, zone_gen, rng, zone_grid, map_layout, featured_locations, previous_placement_circles, report, dungeon_progress)
	return ZoneGenBuilder(
		scene_gen, 
		zone_gen, 
		rng, 
		zone_grid, 
		map_layout, 
		featured_locations, 
		previous_placement_circles,
		report,
		dungeon_progress
	):Build()
end

return ZoneGenBuilder
