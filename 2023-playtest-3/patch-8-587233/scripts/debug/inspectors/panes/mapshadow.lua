local ui = require "dbui.imgui"

MapShadowEditorPane = Class(function(self)
	self.map_shadow = {}
end)

function MapShadowEditorPane:GetShadowLevel(x,y)
	return self.map_shadow[y+1][x+1]
end

function MapShadowEditorPane:SetShadowLevel(x,y, level)
	self.map_shadow[y+1][x+1] = level
end

function MapShadowEditorPane:SetShadowTile(x,y,level)
	local cur_tile = TheWorld.Map:GetTile(x,y,0)

	local numTiles = #TheWorld.shadow_tilegroup.Order
	local numLevels = numTiles - 2
	if level >= 0 and level <= numLevels then
		local actual_tile = TheWorld.Map:GetTile(x,y,1)
		local new_tile = level + 2
		TheWorld.Map:SetTile(x,y,new_tile,1)
		-- rebuild both old and new
		TheWorld.Map:RebuildLayer(actual_tile, x, y, 1)
		TheWorld.Map:RebuildLayer(new_tile, x, y, 1)
		return true
	end
end

function MapShadowEditorPane:Darken(x,y)
	local new_level = self.paint_level
	local cur_shadow = self:GetShadowLevel(x,y)
	if not new_level then
		new_level = cur_shadow + 1
	end
	if self:SetShadowTile(x,y,new_level) then
		self.paint_level = new_level
		self:SetShadowLevel(x,y,new_level)
	else
		self.paint_level = cur_shadow
	end
end

function MapShadowEditorPane:Lighten(x,y)
	local cur_shadow = self:GetShadowLevel(x,y)
	local new_level = self.paint_level
	if not new_level then
		new_level = cur_shadow - 1
	end
	if self:SetShadowTile(x,y,new_level) then
		self.paint_level = new_level
		self:SetShadowLevel(x,y,new_level)
	else
		self.paint_level = cur_shadow
	end
end

function MapShadowEditorPane:Clone(x,y)
	local cur_shadow = self:GetShadowLevel(x,y)
	local new_level = self.paint_level
	if not new_level then
		new_level = cur_shadow
	end
	if self:SetShadowTile(x,y,new_level) then
		self.paint_level = new_level
		self:SetShadowLevel(x,y,new_level)
	else
		self.paint_level = cur_shadow
	end
end

function MapShadowEditorPane:OnMouseButton(button, down, x, y)
	if button == 0 then
		if down then
			self.leftdrag = true
			return true
		else
			self.paint_level = nil
			self.leftdrag = false
			return true
		end
	elseif button == 1 then
		if down then
			self.centerdrag = true
			return true
		else
			self.paint_level = nil
			self.centerdrag = false
			return true
		end
	elseif button == 2 then
		if down then
			self.rightdrag = true
			return true
		else
			self.paint_level = nil
			self.rightdrag = false
			return true
		end
	end
end

function MapShadowEditorPane:StartEditing()
	self.handler = TheInput:AddMouseButtonHandler(function(button, down, x, y) self:OnMouseButton(button, down, x, y) end )

	local inst = CreateEntity()
		:TagAsDebugTool()
	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst.AnimState:SetBank("gridplacer")
	inst.AnimState:SetBuild("gridplacer")
	inst.AnimState:PlayAnimation("anim", true)
	inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
	inst.AnimState:ShowLayer("Layer 3")

	inst.Transform:SetScale(1, 1, 1)
	self.highlight = inst

	self.is_editing = true
end

function MapShadowEditorPane:StopEditing()
	self.is_editing = nil
	if self.highlight then
		self.highlight:Remove()
		self.highlight = nil
	end
	if self.handler then
		self.handler:Remove()
		self.handler = nil
	end
	self.lastdragtile = nil
end

function MapShadowEditorPane:OnRender(prefab)

	if not TheWorld or TheWorld.prefab ~= prefab then
		ui:Text("** Map Shadow can only be edited when inside the level being edited **")
		return
	end

	if not self.is_editing then
		if ui:Button("Start Editing") then
			self:StartEditing()
		end
	else
		if ui:Button("Stop Editing") then
			self:StopEditing()
		else
			ui:SameLine();ui:Dummy(30,0);ui:SameLine();ui:Text("LMB - Darken   MMB - Clone   RMB - Lighten")

			local x, z = TheInput:GetWorldXZ()
			local xx, zz = TheWorld.Map:GetTileCenterXZ(x, z)
			if xx ~= nil then
				self.highlight.Transform:SetPosition(xx, 0, zz)
			end

			if self.leftdrag then
				if xx then
					local xp, yp = TheWorld.Map:GetTileCoordsAtXZ(xx, zz)
					if not self.lastdragtile or xp ~= self.lastdragtile.x or yp ~= self.lastdragtile.y then
						self:Darken(xp,yp)
					end
					self.lastdragtile = {x=xp,y=yp}
				end
			elseif self.rightdrag then
				if xx then
					local xp, yp = TheWorld.Map:GetTileCoordsAtXZ(xx, zz)
					if not self.lastdragtile or xp ~= self.lastdragtile.x or yp ~= self.lastdragtile.y then
						self:Lighten(xp,yp)
					end
					self.lastdragtile = {x=xp,y=yp}
				end
			elseif self.centerdrag then
				if xx then
					local xp, yp = TheWorld.Map:GetTileCoordsAtXZ(xx, zz)
					if not self.lastdragtile or xp ~= self.lastdragtile.x or yp ~= self.lastdragtile.y then
						self:Clone(xp,yp)
					end
					self.lastdragtile = {x=xp,y=yp}
				end
			else
				self.lastdragtile = nil
			end
		end
	end
end

return MapShadowEditorPane
