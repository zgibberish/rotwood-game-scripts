local PopupDialogController = Class(function(self)
end)

local dialogGroupInfo = {}
local currentDialogIndex = 1
local currentScreen = nil

function PopupDialogController:QueueDialog(dialogType, dialogProperties, dialogPosition, blocksScreen)
	local dialogInfo =
	{
		type = dialogType,
		properties = dialogProperties,
		position = dialogPosition ~= nil and dialogPosition or Vector3(0,0),
		blocksScreen = blocksScreen == nil and true or blocksScreen, -- If this dialog should be a screen that needs to be dismissed, or just a floating dialog
	}
	table.insert(dialogGroupInfo, dialogInfo)
end

function PopupDialogController:Start()

	-- Contoller already active; don't start again
	if currentScreen ~= nil then
		return
	end

	self:OpenDialog()
end

function PopupDialogController:OpenDialog()

	local dialogInfo = dialogGroupInfo[currentDialogIndex]

	currentScreen = dialogInfo.type(self, dialogInfo.position, dialogInfo.blocksScreen, table.unpack(dialogInfo.properties))
	if dialogInfo.blocksScreen then
		TheFrontEnd:PushScreen(currentScreen)
	else
		TheFrontEnd:GetActiveScreen():AddChild(currentScreen)
	end
end

function PopupDialogController:NextDialog(onNextFunction)

	if onNextFunction ~= nil then
		onNextFunction()
	end

	local dialogInfo = dialogGroupInfo[currentDialogIndex]
	if dialogInfo.blocksScreen then
		TheFrontEnd:PopScreen(currentScreen)
	else
		currentScreen:Remove()
	end
	currentDialogIndex = currentDialogIndex + 1

	-- Go to next dialog
	if currentDialogIndex <= #dialogGroupInfo then
		self:OpenDialog()
	else
		-- End of dialog queue. Reset everything
		dialogGroupInfo = {}
		currentDialogIndex = 1
		currentScreen = nil
	end
end

function PopupDialogController:IsLastDialog()
	return currentDialogIndex == #dialogGroupInfo
end

return PopupDialogController