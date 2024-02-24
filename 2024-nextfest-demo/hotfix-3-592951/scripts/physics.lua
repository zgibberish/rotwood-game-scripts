--This is called back by the engine side
PhysicsCollisionCallbacks = {}
function OnPhysicsCollision(guid1, guid2)
	local i1 = Ents[guid1]
	local i2 = Ents[guid2]

	local callback = PhysicsCollisionCallbacks[guid1]
	if callback ~= nil then
		callback(i1, i2)
	end

	callback = PhysicsCollisionCallbacks[guid2]
	if callback ~= nil then
		callback(i2, i1)
	end
end

--------------------------------------------------------------------------

function MakeItemDropPhysics(inst, size, mass)
	local phys = inst.entity:AddPhysics()
	phys:SetMass(mass or 50)
	phys:SetCollisionGroup(COLLISION.ITEMS)
	phys:CollidesWith(COLLISION.WORLD)
	phys:CollidesWith(COLLISION.OBSTACLES)
	phys:CollidesWith(COLLISION.SMALLOBSTACLES)
	phys:SetCircle(size)
	return phys
end

function MakeProjectilePhysics(inst, size)
	local phys = inst.entity:AddPhysics()
	phys:SetMass(1)
	--#TODO: add projectile collision group flag
	phys:SetCollisionGroup(COLLISION.ITEMS)
	phys:CollidesWith(COLLISION.GROUND)
	phys:CollidesWith(COLLISION.OBSTACLES)
	phys:SetCircle(size)
	return phys
end

function MakeCharacterPhysics(inst, size, mass)
	local phys = inst.entity:AddPhysics()
	phys:SetMass(mass or 100)
	phys:SetCollisionGroup(COLLISION.CHARACTERS)
	phys:CollidesWith(COLLISION.WORLD)
	phys:CollidesWith(COLLISION.OBSTACLES)
	phys:CollidesWith(COLLISION.SMALLOBSTACLES)
	phys:CollidesWith(COLLISION.CHARACTERS)
	phys:CollidesWith(COLLISION.GIANTS)
	phys:SetRoundRect(size)
	return phys
end

function MakeNpcPhysics(inst, size, mass)
	return MakeCharacterPhysics(inst, size, mass or 10000)
end

function MakeSmallMonsterPhysics(inst, size, mass)
	return MakeCharacterPhysics(inst, size, mass or 10000)
end

function MakeGiantMonsterPhysics(inst, size, mass)
	local phys = inst.entity:AddPhysics()
	phys:SetMass(mass or 100000)
	phys:SetCollisionGroup(COLLISION.GIANTS)
	phys:CollidesWith(COLLISION.WORLD)
	phys:CollidesWith(COLLISION.OBSTACLES)
	phys:CollidesWith(COLLISION.CHARACTERS)
	phys:CollidesWith(COLLISION.GIANTS)
	phys:SetRoundRect(size)
	return phys
end

function MakeObstacleMonsterPhysics(inst, size)
	local phys = inst.entity:AddPhysics()
	phys:SetMass(0)
	phys:SetCollisionGroup(COLLISION.OBSTACLES)
	phys:CollidesWith(COLLISION.ITEMS)
	phys:CollidesWith(COLLISION.CHARACTERS)
	phys:CollidesWith(COLLISION.GIANTS)
	phys:SetRoundRect(size)
	return phys
end

function MakeObstaclePhysics(inst, size)
	local phys = inst.entity:AddPhysics()
	phys:SetMass(0)
	phys:SetCollisionGroup(COLLISION.OBSTACLES)
	phys:CollidesWith(COLLISION.ITEMS)
	phys:CollidesWith(COLLISION.CHARACTERS)
	phys:CollidesWith(COLLISION.GIANTS)
	phys:SetRoundLine(size)
	return phys
end

function MakeSmallObstaclePhysics(inst, size)
	local phys = inst.entity:AddPhysics()
	phys:SetMass(0)
	phys:SetCollisionGroup(COLLISION.SMALLOBSTACLES)
	phys:CollidesWith(COLLISION.ITEMS)
	phys:CollidesWith(COLLISION.CHARACTERS)
	phys:SetRoundLine(size)
	return phys
end

-- Unlike most, this makes a collider that's deep in the z dimension.
function MakeVerticalObstaclePhysics(inst, size)
	local phys = inst.entity:AddPhysics()
	phys:SetMass(0)
	phys:SetCollisionGroup(COLLISION.OBSTACLES)
	phys:CollidesWith(COLLISION.ITEMS)
	phys:CollidesWith(COLLISION.CHARACTERS)
	phys:CollidesWith(COLLISION.GIANTS)
	phys:SetRoundColumn(size)
	return phys
end

function MakeDecorPhysics(inst, size)
	local phys = inst.entity:AddPhysics()
	phys:SetMass(0)
	phys:SetCollisionGroup(COLLISION.OBSTACLES)
	phys:CollidesWith(COLLISION.ITEMS)
	phys:CollidesWith(COLLISION.CHARACTERS)
	phys:CollidesWith(COLLISION.GIANTS)
	phys:SetRoundSquare(size - .05)
	return phys
end

function MakeSmallDecorPhysics(inst, size)
	local phys = inst.entity:AddPhysics()
	phys:SetMass(0)
	phys:SetCollisionGroup(COLLISION.SMALLOBSTACLES)
	phys:CollidesWith(COLLISION.ITEMS)
	phys:CollidesWith(COLLISION.CHARACTERS)
	phys:SetCircle(size - .05)
	return phys
end

function MakeHolePhysics(inst, size)
	local phys = inst.entity:AddPhysics()
	phys:SetMass(10000000000000000000000000) -- surely there must be a better way to make it so mobs can't just move this thing around
	phys:SetCollisionGroup(COLLISION.HOLE_LIMITS)
	phys:CollidesWith(COLLISION.CHARACTERS)
	phys:SetRoundSquare(size - .05)
	inst:Hide() -- temp: the prop itself should manage this
	return phys
end

function MakeTrapPhysics(inst, size, mass, collisiongroup, collideswith)
	local phys = inst.entity:AddPhysics()
	phys:SetMass(mass)
	phys:SetCollisionGroup(collisiongroup)

	for i = 1, #collideswith do
		phys:CollidesWith(collideswith[i])
	end

	phys:SetRoundLine(size)
	return phys
end

--------------------------------------------------------------------------
--Useful for obstacles that need to resize or that can be spawned
--colliding with characters, so that collisions are triggered immediately.

function MakeDynamicObstaclePhysics(inst, size)
	local phys = inst.entity:AddPhysics()
	phys:SetMass(100000000)
	phys:SetCollisionGroup(COLLISION.OBSTACLES)
	phys:CollidesWith(COLLISION.GROUND)
	phys:CollidesWith(COLLISION.ITEMS)
	phys:CollidesWith(COLLISION.CHARACTERS)
	phys:CollidesWith(COLLISION.GIANTS)
	if size ~= nil then
		phys:SetRoundLine(size)
	end
	return phys
end

function MakeDynamicSmallObstaclePhysics(inst, size)
	local phys = inst.entity:AddPhysics()
	phys:SetMass(100000000)
	phys:SetCollisionGroup(COLLISION.SMALLOBSTACLES)
	phys:CollidesWith(COLLISION.GROUND)
	phys:CollidesWith(COLLISION.ITEMS)
	phys:CollidesWith(COLLISION.CHARACTERS)
	if size ~= nil then
		phys:SetRoundLine(size)
	end
	return phys
end

function ConvertToStaticObstaclePhysics(inst, size)
	inst.Physics:SetMass(0)
	inst.Physics:ClearCollidesWith(COLLISION.GROUND)
	if size ~= nil then
		inst.Physics:SetSize(size)
	end
end

function ConvertToDynamicObstaclePhysics(inst, size)
	inst.Physics:CollidesWith(COLLISION.GROUND)
	inst.Physics:SetMass(100000000)
	if size ~= nil then
		inst.Physics:SetSize(size)
	end
end

--------------------------------------------------------------------------
