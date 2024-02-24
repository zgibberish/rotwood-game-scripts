local current

local updater = {
	Default = {},
	Reset = {},
}

local __SimResetSettings
local __SimResetCalled

function updater.TriggerSimReset(simResetSettings)
	assert(not __SimResetCalled)
	__SimResetCalled = true
	__SimResetSettings = simResetSettings
	current = updater.Reset
end

updater.Default.Update = Update
updater.Default.WallUpdate = WallUpdate

current = updater.Default

updater.Reset.Update = function(dt)
end

updater.Reset.WallUpdate = function(dt)
	if TheFrontEnd then
		TheFrontEnd:PopEntireAudioParameterStack()
	end
	SimReset(__SimResetSettings)
end

function updater.Update(dt)
	return current.Update(dt)
end

function updater.WallUpdate(dt)
	return current.WallUpdate(dt)
end

return updater