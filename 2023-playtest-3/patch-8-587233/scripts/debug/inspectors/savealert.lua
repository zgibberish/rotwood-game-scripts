local SaveAlert = Class(function(self, name)
end)

function SaveAlert:Activate(ui, node, id, onCloseFn)
	self.node = node
	self.name = node.name .. "##".. id
	self.onClose = onCloseFn
	self.active = true

	ui:OpenPopup(self.name)
end

function SaveAlert:IsActive()
	return self.active
end

function SaveAlert:Render(ui)

	local headerColor = RGB(204, 12, 12)
	ui:PushStyleColor(ui.Col.TitleBgActive, headerColor)
	ui:PushStyleColor(ui.Col.TitleBg, headerColor)

	local popupModel = ui:BeginPopupModal(self.name, true, ui.WindowFlags.AlwaysAutoResize)

	ui:PopStyleColor()
	ui:PopStyleColor()

	if popupModel then

		ui:Text("You have unsaved changes! Save changes?")
		ui:Dummy(0,10)

		-- make buttons centred
		ui:Dummy(50,0)
		ui:SameLine()

		if ui:Button("Save") then
			self.node:Save()
			self.active = false
			ui:CloseCurrentPopup()
			if self.onClose then
				self.onClose()
			end
		end

		ui:SameLineWithSpace()

		if ui:Button("Discard") then
			self.node:Revert()
			self.active = false
			ui:CloseCurrentPopup()
			if self.onClose then
				self.onClose()
			end
		end

		ui:SameLineWithSpace()

		if ui:Button("Cancel") then
			self.active = false
			ui:CloseCurrentPopup()
		end

		ui:EndPopup()
	end
end

return SaveAlert
