local ui = require "dbui.imgui"

local BackgroundGradientEditorPane = Class(function(self, max_points, useAlpha)
	self.curve = {{0,0,0,0}, {0,0,0,1}}
	self.max_points = max_points or 14
	-- We add a hidden point at the beginning and the end to define our
	-- extent values.
	self.max_points = self.max_points + 2
	self.use_alpha = useAlpha or false
end)


function BackgroundGradientEditorPane:SortKeyTable(tbl)
	if self.use_alpha then
		table.sort(tbl, function(a,b)
				        return
						a[1]<b[1] or
						(a[1]==b[1] and a[2]<b[2]) or
						(a[1]==b[1] and a[2]==b[2] and a[3]<b[3]) or
						(a[1]==b[1] and a[2]==b[2] and a[3] == b[3]) and a[4] < b[4] or
						(a[1]==b[1] and a[2]==b[2] and a[3] == b[3] and a[4] == b[4]) and a[5] < b[5]
					end)
	else
		table.sort(tbl, function(a,b)
				        return
						a[1]<b[1] or
						(a[1]==b[1] and a[2]<b[2]) or
						(a[1]==b[1] and a[2]==b[2] and a[3]<b[3]) or
						(a[1]==b[1] and a[2]==b[2] and a[3] == b[3]) and a[4] < b[4]
					end)
	end
end

function BackgroundGradientEditorPane:ResetEditor()
	self.curve = {{0,0,0,0}, {1,0,0,0}}
	self:SetActivePoint(nil)
end

function BackgroundGradientEditorPane:LoadData(data)
	local new = deepcopy(data) or {{0,0,0,0}, {0,0,0,1}}
	if not deepcompare(self.loaded_curve,new) then
		self:ResetEditor()
		self.curve = self:PrepareData(new)
		self.loaded_curve = deepcopy(new)
		self:SetActivePoint(1)
	end

end

function BackgroundGradientEditorPane:PrepareData(curve)
	if #curve[1] == 2 then
		-- RGBA uints
		self.use_ints = true
		local res = {}
		for i,v in pairs(curve) do
			local t = v[1]
			local col = HexToRGBA(v[2])
			if self.use_alpha then
				table.insert(res, {t,col[1],col[2],col[3],col[4]})
			else
				table.insert(res, {t,col[1],col[2],col[3]})
			end
		end
		return res
	else
		-- floats
		self.use_ints = nil
		return deepcopy(curve)
	end
end

function BackgroundGradientEditorPane:SaveData()
	-- save a sorted copy so that we don't get dirty when points change order
	local work = self:GetWorkingCopy()
	self:SortKeyTable(work)
	if not self.use_ints then
		-- replicate back to saved data so that we don't think we got new data next time around
		self.loaded_curve = deepcopy(work)
		return deepcopy(work)
	else
		-- replicate back to saved data so that we don't think we got new data next time around
		local res = {}
		for i,v in pairs(work) do
			local hex = RGBToHex({v[2],v[3],v[4],v[5] or 0})
			table.insert(res, {v[1], hex})
		end
		self.loaded_curve = deepcopy(res)
		return deepcopy(res)
	end
end

function BackgroundGradientEditorPane:GetWorkingCopy()
	local work = {}
	for i,v in pairs(self.curve) do
		table.insert(work, v)
	end
	return work
end

function BackgroundGradientEditorPane:AddCurvePoint(ratio)
	if #self.curve >= self.max_points then
		return
	end

	-- figure out where we fall in the array
	ratio = math.clamp(ratio,0,1)
	local work = self:GetWorkingCopy()
	self:SortKeyTable(work)
	-- find where we go into the table
	local insertbefore
	for i=1,#work do
		if work[i][1] >= ratio then
			insertbefore = i
			break
		end
	end
	if insertbefore and insertbefore == 1 then
		local r = work[1][2]
		local g = work[1][3]
		local b = work[1][4]
		local a = work[1][5] -- nil if alpha not used, so all good
		local curvepoint = {ratio,r,g,b,a}
		table.insert(self.curve, curvepoint)
	elseif insertbefore then
		local p1 = insertbefore - 1
		local p2 = insertbefore
		local r1,r2 = work[p1][2], work[p2][2]
		local g1,g2 = work[p1][3], work[p2][3]
		local b1,b2 = work[p1][4], work[p2][4]
		local a1,a2 = work[p1][5], work[p2][5]

		local ratio1,ratio2 = work[p1][1], work[p2][1]
		local rangeratio = (ratio - ratio1) / (ratio2 - ratio1)
		local r = Lerp(r1,r2,rangeratio)
		local g = Lerp(g1,g2,rangeratio)
		local b = Lerp(b1,b2,rangeratio)
		local a = self.use_alpha and Lerp(a1,a2,rangeratio) or nil
		local curvepoint = {ratio, r,g,b,a}
		table.insert(self.curve, curvepoint)
	else
		local r = work[#work][2]
		local g = work[#work][3]
		local b = work[#work][4]
		local a = work[#work][5]  -- nil if alpha not used, so all good
		local curvepoint = {ratio,r,g,b,a}
		table.insert(self.curve, curvepoint)
	end

	self:SetActivePoint(#self.curve)
	self.dirty = true;
end

function BackgroundGradientEditorPane:SetActivePoint(index)
	-- make this point the last point so it's drawn last
	if index then
		local temp = self.curve[index]
		self.curve[index] = self.curve[#self.curve]
		self.curve[#self.curve] = temp
	end
	self.activepoint = #self.curve
end

function BackgroundGradientEditorPane:DeletePoint(index)
	-- set the focus to the last button with a smaller ratio
	if #self.curve <= 2 then
		return
	end
	local myratio = self.curve[index][1]
	table.remove(self.curve, index)
	-- the last point to the lef of this one becomes the active one, but make sure it's not one of the terminal ones
	local work = self:GetWorkingCopy()
	self:SortKeyTable(work)
	local candidate
	for i=1, #work do
		if work[i][1] < myratio then
			candidate = work[i]
		end
	end
	if not candidate then
		candidate = work[1]
	end
	self:SetActivePoint(nil)
	for i,v in ipairs(self.curve) do
		if v == candidate then
			self:SetActivePoint(i)
			break
		end
	end
	self.dirty = true
	assert(self.activepoint)
end

function BackgroundGradientEditorPane:StartDrag(index)
	self.dragpoint = index
	self.dragratio = self.curve[index][1]
end

function BackgroundGradientEditorPane:StopDrag(inRange)
	if self.dragpoint then
		if not inRange then
			-- reset to position before drag
			self.curve[self.dragpoint][1] = self.dragratio
			self.dirty = true
		end
		self.dragpoint = nil
		self.dragratio = nil
	end
end

function BackgroundGradientEditorPane:UpdateDrag(w, sx, sy, ex, ey)
	if self.dragpoint then
		if not ui:IsMouseDown(0) then
			local mx,my = ui:GetMousePos()
			if my >= sy and my <= ey then
				self:StopDrag(true)
			else
				self:StopDrag(false)
			end
		else
			local mx,my = ui:GetMousePos()
			local dx = mx - sx
			local ratio = dx/w
			-- this is a hack, I want the outer ones to stay at 0 and 1
			ratio = math.clamp(ratio,0,1)
			local oldratio = self.curve[self.dragpoint][1]
			self.curve[self.dragpoint][1] = ratio
			if ratio ~= oldratio then
				self.dirty = true
			end
		end
	end
end

-- draw an invisible button to track range clicking
local function DrawGradientButton(ui, pointSize, w, h)
	local sx, sy = ui:GetCursorScreenPos()
	--ui:Button("##gradient",w,h + pointSize * 2 - 2)
	ui:SetNextItemAllowOverlap()
	ui:InvisibleButton("##gradient",w,h + pointSize * 2 - 2)

	local ex, ey = ui:GetCursorScreenPos()
	local clickedRange = false
	if ui:IsItemClicked() then
		clickedRange = true
	end
	return clickedRange, sx, sy, ex, ey
end

local function DrawGradient(ui, work, totw, gradientH)
	local sxp, syp = ui:GetCursorScreenPos()
	-- drawing this in WindowGlobal, because in WindowLocal I have to account for menu height (to deal with CursorStartPosition and I can't really know this
	ui:DrawRectFilled(ui.Layer.WindowGlobal, sxp - 2, syp - 2, sxp+totw + 2, syp + gradientH + 2, RGB(128,128,128,255))

	local cols = work
	local numcols = #cols
	for i=0,numcols do
		local curvepoint = i == 0 and cols[1] or cols[i]
		local color1 = {curvepoint[2], curvepoint[3], curvepoint[4]}
		local ratio1 = i == 0 and 0 or curvepoint[1]

		local curvepoint = i==#cols and cols[numcols] or cols[i+1]
		local color2 = {curvepoint[2], curvepoint[3], curvepoint[4]}
		local ratio2 = i==#cols and 1 or curvepoint[1]

		local x1 = sxp + ratio1 * totw
		local x2 = sxp + ratio2 * totw
		local y = syp
		local h = gradientH

		ui:DrawRectFilledMultiColor(ui.Layer.WindowGlobal, x1, y, x2, y+h, color1, color2, color2, color1)
	end

	ui:SetCursorPos(sxp, syp + gradientH + 2)
end

function BackgroundGradientEditorPane:DoGradientDraggers(ui, work, pointSize, w, gradientH)

	local sx, sy = ui:GetCursorPos()
	local clickedRange, dragx1,dragy1,dragx2, dragy2 = DrawGradientButton(ui, pointSize, w, gradientH)
	ui:SetCursorPos(sx,sy)

	local sx, sy = ui:GetCursorPos()
	ui:SetCursorPos(sx, sy + pointSize/2 + 2 + gradientH)

	local sx,sy = ui:GetCursorScreenPos()

	local sxp, syp = ui:GetCursorScreenPos()
	local layer = ui.Layer.WindowGlobal
	local cx, cy = ui:GetCursorScreenPos()
	local clickedButton = false
	local hoveredButton = nil
	local deleteButton = nil

	local numcols = #work
	for i=1,numcols do
		local curvepoint = self.curve[i]
		local color = {curvepoint[2], curvepoint[3], curvepoint[4]}
		local ratio = curvepoint[1]

		if i == self.activepoint then
			ui:DrawTriangleFilled(layer, cx + ratio * w - pointSize/2, cy, cx + ratio * w + pointSize/2, cy, cx + ratio * w,cy -pointSize/2, RGB(64,64,64,255))
		else
			ui:DrawTriangleFilled(layer, cx + ratio * w - pointSize/2, cy, cx + ratio * w + pointSize/2, cy, cx + ratio * w,cy -pointSize/2, RGB(255,255,255,255))
		end
		ui:DrawRectFilled(layer, cx + ratio * w - pointSize/2, cy, cx + ratio * w + pointSize/2, cy + pointSize, color)
		ui:SetCursorScreenPos(cx + ratio * w - pointSize / 2, cy)
		ui:SetNextItemAllowOverlap()
		ui:InvisibleButton("##rect",pointSize,pointSize)

		 -- last one always has priority as we put the active point at the end of the list
		if ui:IsItemHovered() then
			hoveredButton = i
		end
		if ui:IsItemClicked() then
			clickedButton = i
			self:SetActivePoint(clickedButton)
		end
	end
	if hoveredButton then
		local curvepoint = self.curve[hoveredButton]
		local ratio = curvepoint[1]
		ui:DrawRect(layer, cx + ratio * w - pointSize/2, cy, cx + ratio * w + pointSize/2, cy + pointSize, RGB(255,255,255,255))
		if ui:IsMouseClicked(1) then
			deleteButton = hoveredButton
		end
	end

	if clickedButton then
		self:StartDrag(clickedButton)
	elseif clickedRange then
		local mx,my = ui:GetMousePos()
		local dx = mx - sx
		local ratio = dx/w
		self:AddCurvePoint(ratio)
		self:StartDrag(#self.curve)
	end

	if deleteButton then
		self:DeletePoint(deleteButton)
	end

	self:UpdateDrag(w, dragx1, dragy1, dragx2, dragy2)
end

function BackgroundGradientEditorPane:GetAlphas(data)
	local work = {}
	for i,v in pairs(data) do
		table.insert(work, {time = v[1], alpha = v[5], origindex = i})
	end
	table.sort(work, function(a,b)
				return (a.time < b.time) or
				       (a.time == b.time) and a.origindex < b.origindex
			end)
	local alphas = {}
	local origIndices = {}
	for i,v in pairs(work) do
		table.insert(alphas,v.time)
		table.insert(alphas,v.alpha)
		table.insert(origIndices,v.origindex)
	end
	return alphas, origIndices
end

function BackgroundGradientEditorPane:UpdateAlphas(data, alphas, indices)
	for i,origIndex in pairs(indices) do
		data[origIndex][5] = alphas[i * 2]
	end
	self.dirty = true
end

function BackgroundGradientEditorPane:OnRender(_ui, curve)
	self:LoadData(curve)

	self:SetActivePoint(self.activepoint or 2)
	self.dirty = false
	local num_colors = #self.curve
	local work = self:GetWorkingCopy()

	self:SortKeyTable(work)
	local misc_flags = ui.ColorEditFlags.NoSmallPreview
			   | ui.ColorEditFlags.NoSidePreview
			   | ui.ColorEditFlags.NoLabel
			   | ui.ColorEditFlags.DisplayHex

	local w = ui:GetColumnWidth()
	ui:Columns(3, "", false)
	ui:SetColumnOffset(1,w*0.25)
	ui:SetColumnOffset(2,w*1)
	ui:NextColumn()
	self.col = self.col or {1,0,0}
	local col = self.curve[self.activepoint]
	local changed, r,g,b = ui:ColorPicker3("EditColor", col[2], col[3], col[4], misc_flags)
	if changed then
		col[2] = r
		col[3] = g
		col[4] = b
		self.dirty = true
	end
	ui:Columns(1)

	local xp, yp = ui:GetCursorPos()

	-- draw the gradient
	local w = ui:GetColumnWidth()
	local gradientH = 20

	local sx, sy = ui:GetCursorPos()
	DrawGradient(ui, work, w, gradientH)
	ui:SetCursorPos(sx,sy)

	local pointSize = 20
	self:DoGradientDraggers(ui, work, pointSize, w, gradientH)
	local sx, sy = ui:GetCursorPos()
	if self.use_alpha then
		ui:Dummy(0, 7) -- avoid putting top of curve next to colours
		-- the alphas can change order, but need to come back into the original curve color
		local alphas, origIndices = self:GetAlphas(self.curve)
		local wx,wy = ui:GetWindowSize()
		local is_alpha_dirty = ui:CurveEditor("Alpha##COLORCURVE", alphas, wx-50, nil, false, true)
		if is_alpha_dirty then
			self:UpdateAlphas(self.curve, alphas, origIndices)
			self.curve = deepcopy(work)
		end
	end
	if self.dirty then
		return true, self:SaveData()
	end
end

return BackgroundGradientEditorPane
