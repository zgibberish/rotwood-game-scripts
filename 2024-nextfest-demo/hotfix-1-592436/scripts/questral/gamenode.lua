local kassert = require "util.kassert"
local krandom = require "util.krandom"


--------------------------------------------------------------
-- Generic gameplay node in a tree of nodes, providing functionality
-- tree operations.

local GameNode = Class()

-- *Do not define constructor*.  No overhead, no obligation to call. Lazy-instantiate all fields.
-- function GameNode:init()
-- end

function GameNode:IsActivated()
    return self.activationId ~= nil
end

-- Entities will have one unique parent if it is attached to another GameNode.
function GameNode:GetParent()
    return self.parent
end

function GameNode:IsAncestor( e )
    assert( e )
    if self.parent == e then
        return true
    elseif self.parent then
        return self.parent:IsAncestor( e )
    end
    return false
end

function GameNode:GetAncestor( fn )
    local parent = self.parent
    if parent then
        if fn( parent ) then
            return parent
        else
            return parent:GetAncestor( fn )
        end
    end
end

function GameNode:GetAncestorByClass( class )
    assert(Class.IsClass(class))
    local parent = self.parent
    if class.is_instance(parent) then
        return parent
    elseif parent then
        return parent:GetAncestorByClass( class )
    end
end

function GameNode:FindCommonAncestor( node )
    local parent = self
    while parent do
        if node == parent or node:IsAncestor( parent ) then
            return parent
        else
            parent = parent.parent
        end
    end
    return parent
end

function GameNode:HasChild( child )
    return self.children and table.contains( self.children, child )
end

function GameNode:FindChild( fn )
    if self.children then
        for _, child in ipairs(self.children) do
            if fn( child ) then
                return child
            end
        end
    end
end

function GameNode:FindChildByClass( class )
    assert(Class.IsClass(class))
    if self.children then
        for _, child in ipairs(self.children) do
            if class.is_instance(child) then
                return child
            end
        end
    end
end

function GameNode:FindChildren( fn )
    local ret = {}
    if self.children then
        for _, child in ipairs(self.children) do
            if fn( child ) then
                table.insert(ret, child)
            end
        end
    end
    return ret
end

function GameNode:FindChildrenByClass( class )
    assert(Class.IsClass(class))
    local ret = {}
    if self.children then
        for _, child in ipairs(self.children) do
            if class.is_instance(child) then
                table.insert(ret, child)
            end
        end
    end
    return ret
end

-- Accesses the root GameNode, recursively, through this GameNode's parent.
function GameNode:GetRoot()
    local parent = self.parent or self
    while parent and parent.parent do
        parent = parent.parent
    end
    return parent
end

function GameNode:IsEmpty()
    return self.children == nil or #self.children == 0
end

function GameNode:GetChildren()
    return self.children or table.empty
end

function GameNode:GetBucketByClass( class )
    assert(Class.IsClass(class))
    return self:GetBucketByID( class._classname )
end

function GameNode:GetBucketByID( id )
    if self.buckets then
        return self.buckets[ id ] or table.empty
    end
    return table.empty
end

-- add this child to any bucket lists it ought to be in.
function GameNode:AddToBuckets( child )
    if self.bucket_filters then
        for id, fn in pairs( self.bucket_filters ) do
            if fn( child ) then
                if self.buckets == nil then
                    self.buckets = {}
                end

                local bucket = self.buckets[ id ]
                if bucket == nil then
                    bucket = {}
                    self.buckets[ id ] = bucket
                end

                table.insert( bucket, child )
            end
        end
    end
end

-- remove this child from any buckets it may be in
function GameNode:RemoveFromBuckets( child )
    if self.buckets then
        for _, bucket in pairs( self.buckets ) do
            table.removearrayvalue( bucket, child )
        end
    end
end

-- This is called on the Class itself, to register bucket assignment functions.
function GameNode:CreateNodeBucket( bucket_id, fn )
    assert(Class.IsClass(self))

    if rawget( self, "bucket_filters" ) == nil then
        self.bucket_filters = shallowcopy( self.bucket_filters ) or {}
    end

    assert( self.bucket_filters[ bucket_id ] == nil, "Duplicate bucket filter assigned: "..bucket_id)
    self.bucket_filters[ bucket_id ] = fn
end

function GameNode:CreateClassBucket( class )
    assert(Class.IsClass(class))
    self:CreateNodeBucket( class._classname, function( child ) return class.is_instance(child) end )
end

function GameNode:CountDescendants( fn )
    local count = 0
    self:TraverseDescendants( function( ent )
        if fn == nil or fn( ent ) then
            count = count + 1
        end
    end )
    return count
end

function GameNode:CountChildrenOfClass( class )
    local count = 0
    if self.children then
        for i, child in ipairs( self.children ) do
            if class.is_instance(child) then
                count = count + 1
            end
        end
    end
    return count
end

function GameNode:TraverseAncestors( fn )
    if fn( self ) == false then
        return
    end

    if self.parent then
        self.parent:TraverseAncestors( fn )
    end
end

local function AssertCanTraverse(node)
    -- Assert came from gln@e58016c21a51c0747fbaf8f304dc0d3ba32f9a9a, but no
    -- idea why it's necessary.
    if not node.TraverseDescendants then
        assert(node.TraverseDescendants, "Input node doesn't appear to be a GameNode.")
    end
end

-- traverse all children, recursively.
-- Recursion bottoms out if fn( entity ) returns false.
function GameNode:TraverseDescendants( fn, ... )
    if self.children then
        for _, child in ipairs(self.children) do
            if fn( child, ... ) ~= false then
                AssertCanTraverse(child)
                child:TraverseDescendants( fn, ... )
            end
        end
    end
end

function GameNode:TraverseDescendantsReverse( fn, ... )
    if self.children then
        for i = #self.children, 1, -1 do
            local child = self.children[i]
            if fn( child, ... ) ~= false then
                AssertCanTraverse(child)
                child:TraverseDescendants( fn, ... )
            end
        end
    end
end

function GameNode:TraverseDescendantsInclusive( fn, ... )
    if fn( self, ...) ~= false then
        self:TraverseDescendants( fn, ...)
    end
end

local function FloodEntitiesInternal( entity, from_entity, fn, closed )
    if not closed[ entity ] and fn( entity, from_entity ) ~= false then
        -- Mark this entity as seen.
        closed[ entity ] = true

        if entity.children then
            for _, child in ipairs( entity.children ) do
                FloodEntitiesInternal( child, entity, fn, closed )
            end
        end

        if entity.parent then
            FloodEntitiesInternal( entity.parent, entity, fn, closed )
        end
    end
end

-- This 'flood-fills' the entity graph starting with this entity, all children, then this entity's parent.
-- fn( entity, from_entity ) returns false, then flooding from 'entity' does not continue.
function GameNode:FloodEntities( fn )
    local closed = {}
    FloodEntitiesInternal( self, nil, fn, closed )
end

function GameNode:FindDescendant( fn )
    if self.children then
        for _, child in ipairs(self.children) do
            if fn( child ) then
                return child
            end
        end
        for _, child in ipairs(self.children) do
            local found = child:FindDescendant( fn )
            if found then
                return found
            end
        end
    end
end

function GameNode:FindDescendantByClass( class, fn )
    assert(Class.IsClass(class))
    return self:FindDescendant( function( child ) return class.is_instance(child) and (fn == nil or fn(child)) end )
end

function GameNode:FindDescendants( fn, ret )
    if ret == nil then
        ret = {}
    end

    if self.children then
        for _, child in ipairs(self.children) do
            if fn( child ) then
                table.insert(ret, child)
            end

            child:FindDescendants( fn, ret )
        end
    end

    return ret
end

function GameNode:FindDescendantsByClass(class, filter)
    assert(Class.IsClass(class))
    return self:FindDescendants(
        function(child)
            return class.is_instance(child) and (filter == nil or filter(child))
        end)
end

function GameNode:PickDescendant( fn, t )
    local function collectEntities( ent )
        if fn( ent, t ) then
            t = t or {}
            table.insert( t, ent )
        end
    end
    self:TraverseDescendants( collectEntities )

    return krandom.PickFromArray( t )
end

function GameNode:AttachChild( child )
    kassert.assert_fmt(not child:IsActivated(), "cannot attach %s to %s: already activated via parent %s?", tostring(child), tostring(self), tostring(child.parent))

    if self.children == nil then
        self.children = {}
    end

    kassert.assert_fmt( not table.contains( self.children, child ), "attached duplicate child. %s already has %s", self, child)
    table.insert( self.children, child )

    self:AddToBuckets( child )

    assert( child.parent == nil, "child already has parent" )
    child.parent = self

    -- Activation status propagates to any attached child.
    if self:IsActivated() then
        child:_ActivateNode( child )
    end

    if self.OnAttachChild then
        self:OnAttachChild(child)
    end

    return child
end

-- Reparents a child GameNode to newParent, without changing activation status.
function GameNode:ReattachChild( child, newParent )
    if newParent == self then
        return -- Permit this no-op.
    end

    assert( table.contains( self.children, child ))
    assert( child.parent == self )
    assert( newParent:GetRoot() == self:GetRoot() ) -- Must be part of the same entity tree.

    -- Detach from us, first.
    self:RemoveFromBuckets( child )
    table.removearrayvalue( self.children, child )

    -- Re-attach to newParent.
    if newParent.children == nil then
        newParent.children = {}
    end
    assert( not table.contains( newParent.children, child ), "Reattached duplicate child")
    table.insert( newParent.children, child )

    newParent:AddToBuckets( child )

    if self.OnDetachChild then
        self:OnDetachChild( child )
    end

    child.parent = newParent

    -- After fully attached.
    if newParent.OnAttachChild then
        newParent:OnAttachChild(child)
    end
end

-- Reattaches this GameNode to newParent
function GameNode:Reattach( newParent )
    self.parent:ReattachChild( self, newParent )
end

function GameNode:Detach()
    assert( self.parent or error(tostring(self)))
    self.parent:DetachChild( self )
end

function GameNode:DetachChild( child )
    assert( table.contains( self.children, child ), "Detaching invalid child." )
    assert( child.parent == self, "Detaching from wrong parent." )

    if child:IsActivated() then
        child:_DeactivateNode( child )

        if child.parent == nil then
            -- In case _DeactivateNode recursively detaches us.
            return
        end
    end

    self:RemoveFromBuckets( child )
    table.removearrayvalue( self.children, child )
    assert( child.parent == self )
    child.parent = nil

    -- After parentage is lost.
    if self.OnDetachChild then
        self:OnDetachChild( child )
    end
end

function GameNode:DetachChildren( fn )
    for i = #self.children, 1, -1 do
        if fn == nil or fn(self.children[i]) then
            self:DetachChild( self.children[i] )
        end
    end
end

local function GenerateId(self)
    self._nextId = (self._nextId or 0) + 1
    return self._nextId
end

function GameNode:GetActivationID()
    return self.activationId
end

-- Only call on the root node of the hierarchy!
--
-- root: the source node initially receiving Activate (either self, or some ancestor).
function GameNode:_ActivateNode( root )
    assert( not self:IsActivated(), tostring(self) )
    assert( self.parent == nil or self.parent:IsActivated())
    root = root or self

    local true_root = root:GetRoot()
    self.activationId = GenerateId(true_root)

    if self.children then
        for _, child in ipairs( self.children ) do
            -- This check exists to support the case when a child node attaches a new sibling while being Activated.
            if not child:IsActivated() then
                child:_ActivateNode( root )
            end
        end
    end

    -- Derived class handler must only be called after this and all children return true for IsActivated.
    if self.OnActivate then
        self:OnActivate( root )
    end
end


-- Only call on the root node of the hierarchy!
--
-- root: the source node initially receiving Deactivate (either self, or some ancestor).
function GameNode:_DeactivateNode( root )
    assert( self:IsActivated(), "not activated" )
    assert( root ~= nil ) -- Only root nodes should ever be manually deactivated.

    if self.children then
        for i = #self.children, 1, -1 do
            self.children[i]:_DeactivateNode( root )
        end
    end

    if self.OnDeactivate then
        self:OnDeactivate( root )
    end

    self.activationId = nil
end


-- Call when you want to permanently remove node from the scene, but don't want
-- to trigger Detach/Deactivate behaviour (e.g., quest detach implies completion).
function GameNode:TeardownNode(root)
    assert( self:IsActivated(), "not activated" )
    if self.children then
        for i = #self.children, 1, -1 do
            self.children[i]:TeardownNode(root)
        end
        self.children = nil
    end

    if self.OnTeardown then
        self:OnTeardown(root)
    end

    self.activationId = nil
end

return GameNode

