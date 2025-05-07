local UIAnim = require "widgets.uianim"
local Widget = require "widgets.widget"

-- ideally everything uses the same symbol references per "body part"
local SymbolReferences =
{
	head = { "head", "face", "eye", "skull", "head_follow", "scarf_back", "arm"},
	foot = { "foot", "feet", "leg", "leg_lower"}
}

-- for NPC to render "correctly" (see npc_autogen.lua, sg_npc.lua)
-- this list order matters due to parents (they must be initialized first)
local SubParts <const> =
{
	{ name = "head", symbol = "head_follow", parent = nil },
	{ name = "mouth", symbol = "mouth_swap", parent = "head" },
}

local function PopulateTargetSymbols(animState, outTable)
	for name,aliases in pairs(SymbolReferences) do
		for _,alias in ipairs(aliases) do
			if animState:BuildHasSymbol(alias) then
				outTable[name] = Vector2(animState:GetSymbolPosition(alias, 0, 0, 0))
				-- TheLog.ch.AnimPuppet:printf("Using symbol %s for alias %s", name, alias)
				break
			end
		end
	end
end

local AnimPuppet = Class(Widget, function(self)
	Widget._ctor(self, "StategraphEntityPuppet")

	self.puppet = self:AddChild(UIAnim())
	self.puppet_extra = {}
	self.targetsymbols = {}
end)

local function InitPuppet(puppet, target)
	local puppetAnimState = puppet:GetAnimState()
	puppetAnimState:SetBank(target.AnimState:GetCurrentBankName())
	puppetAnimState:SetBuild(target.AnimState:GetBuild())
	puppetAnimState:SetLayer(target.AnimState:GetLayer())
	-- SetTwoFaced ?
end

local function UpdatePuppet(puppet, target)
	local puppetAnimState = puppet:GetAnimState()
	local targetAnimName = target.AnimState:GetCurrentAnimationName()

	if puppetAnimState:GetCurrentAnimationName() ~= targetAnimName then
		puppetAnimState:PlayAnimation(targetAnimName)
	end

	puppetAnimState:SetFrame(target.AnimState:GetCurrentAnimationFrame())
	puppetAnimState:SetOrientation(target.AnimState:GetOrientation())

	local facing = target.AnimState:GetCurrentFacing()
	puppet:SetFacing(facing)
end

-- special case for NPC mouth, head (see npc_autogen.lua, sg_npc.lua)
function AnimPuppet:_InitTargetPart(partName, parent)
	assert(parent == nil or self.puppet_extra[parent] ~= nil)

	if not self.puppet_extra[partName] then
		self.puppet_extra[partName] = parent
			and self.puppet_extra[parent]:AddChild(UIAnim())
			or self:AddChild(UIAnim())

		-- TODO: victorc -- figure out if follower component can be used in UI space
		-- NPC heads are floaty with the present setup
		-- self.puppet_extra.mouth.inst.entity:AddFollower()
		-- self.puppet_extra.mouth.inst.entity:SetParent(self.puppet.inst.entity)
		-- self.puppet_extra.mouth.inst.Follower:FollowSymbol(self.puppet.inst.GUID, "mouth_swap")
	end
	InitPuppet(self.puppet_extra[partName], self.target[partName])
end

-- partName = mouth, head, etc.
-- symbolName = mouth_swap, head_follow, etc. on the parent
-- parentPartName = nil, "head", etc.
function AnimPuppet:_UpdateTargetPart(partName, symbolName, parentPartName)
	UpdatePuppet(self.puppet_extra[partName], self.target[partName])

	local animstate = parentPartName == nil
		and self.puppet:GetAnimState()
		or self.puppet_extra[parentPartName]:GetAnimState()
	local mx, my = animstate:GetSymbolPosition(symbolName, 0, 0, 0)

	local worldRef = parentPartName == nil
		and self.puppet
		or self.puppet_extra[parentPartName]
	local wx, wy = worldRef:TransformFromWorld(mx, my)

	if not isnan(wx) and not isnan(wy) then
		local flip = (self.target.AnimState:GetCurrentFacing() == FACING_LEFT) and -1 or 1
		self.puppet_extra[partName]:SetPosition(flip * wx,-wy)
		-- local x, y = self.puppet_extra[partName]:GetPosition()
		-- TheLog.ch.Puppet:printf("m=%1.3f,%1.3f w=%1.3f,%1.3f %s=%1.3f,%1.3f", mx, my, wx, wy, partName, x, y)
	end
end

-- special case for props with highlightchildren used in parallax anims
function AnimPuppet:_InitTargetHighlightChildren()
	if self.puppet_extra.highlightchildren then
		for _,puppet in ipairs(self.puppet_extra.highlightchildren) do
			puppet:Remove()
		end
		table.clear(self.puppet_extra.highlightchildren)
	else
		self.puppet_extra.highlightchildren = {}
	end

	-- initialize child UIAnims, then sort widgets by target's local world z
	local parallaxOrder = { { z=0.0, puppet=self.puppet } }

	for i,child in ipairs(self.target.highlightchildren) do
		if not self.puppet_extra.highlightchildren[i] then
			self.puppet_extra.highlightchildren[i] = self:AddChild(UIAnim())
		end
		InitPuppet(self.puppet_extra.highlightchildren[i], child)

		local _x,_y,z = child.Transform:GetLocalPosition()
		for j,data in ipairs(parallaxOrder) do
			if data.z > z then
				table.insert(parallaxOrder, j, { z=z, puppet=self.puppet_extra.highlightchildren[i] })
				break
			elseif j == #parallaxOrder then
				table.insert(parallaxOrder, { z=z, puppet=self.puppet_extra.highlightchildren[i] })
				break
			end
		end
	end

	-- finalize order and mimic parallax in UI space; scales by arbitrary value
	for _i,data in ipairs(parallaxOrder) do
		data.puppet:SendToBack()
		data.puppet:SetPosition(0, data.z * 30)
	end
end

function AnimPuppet:_UpdateTargetHighlightChildren()
	for i,child in ipairs(self.target.highlightchildren) do
		UpdatePuppet(self.puppet_extra.highlightchildren[i], child)
	end
end

function AnimPuppet:SetTarget(target)
	if target then
		self.target = target
		InitPuppet(self.puppet, target)
		PopulateTargetSymbols(self.puppet:GetAnimState(), self.targetsymbols)

		for _i,part in ipairs(SubParts) do
			if target[part.name] then
				self:_InitTargetPart(part.name, part.parent)
			end
		end

		if target.highlightchildren then
			self:_InitTargetHighlightChildren()
		end

		self:StartUpdating()
	else
		self.target = nil
		table.clear(self.targetsymbols)
		self:StopUpdating()
	end
end

function AnimPuppet:ClearTarget()
	self:SetTarget(nil)
end

function AnimPuppet:GetAnimState()
	return self.puppet:GetAnimState()
end

function AnimPuppet:GetSymbolPosition(symbol)
	return self.targetsymbols[symbol] and self.targetsymbols[symbol] or nil
end

function AnimPuppet:SetFacing(facing)
	self.puppet:SetFacing(facing)
	return self
end

function AnimPuppet:OnUpdate(_dt)
	if self.target and self.target:IsValid() and not self.target:IsInLimbo() and not self.target:IsDead() then
		UpdatePuppet(self.puppet, self.target)
		-- TODO: victorc - does this need to be updated every frame?
		PopulateTargetSymbols(self.puppet:GetAnimState(), self.targetsymbols)

		for _i,part in ipairs(SubParts) do
			if self.puppet_extra[part.name] then
				self:_UpdateTargetPart(part.name, part.symbol, part.parent)
			end
		end

		if self.puppet_extra.highlightchildren then
			self:_UpdateTargetHighlightChildren()
		end
	end
end

function AnimPuppet:HasExtraPart(name)
	return self.puppet_extra[name] ~= nil
end

return AnimPuppet
