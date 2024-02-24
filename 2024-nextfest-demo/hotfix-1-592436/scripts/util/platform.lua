local Platform = {}


-- Distribution platforms

function Platform.IsPS4()
	return PLATFORM == "PS4"
end

function Platform.IsXB1()
	return PLATFORM == "XBONE"
end

function Platform.IsSteam()
	return PLATFORM == "WIN32_STEAM" or PLATFORM == "LINUX_STEAM" or Platform.IsMac()
end

function Platform.IsRail()
	return PLATFORM == "WIN32_RAIL"
end


-- Operating systems

function Platform.IsWindows()
	return PLATFORM == "WIN32_STEAM" or PLATFORM == "WIN32_RAIL"
end

function Platform.IsLinux()
	return PLATFORM == "LINUX_STEAM"
end

function Platform.IsAndroid()
	return PLATFORM == "ANDROID"
end

function Platform.IsMac()
	return PLATFORM == "OSX_STEAM"
end

function Platform.IsConsole()
	return Platform.IsPS4() or Platform.IsXB1()
end

function Platform.IsNotConsole()
	return not Platform.IsConsole()
end

function Platform.IsSteamDeck()
	return IS_STEAM_DECK
end

function Platform.IsBigPictureMode()
	return IS_BIG_PICTURE_MODE
end

return Platform
