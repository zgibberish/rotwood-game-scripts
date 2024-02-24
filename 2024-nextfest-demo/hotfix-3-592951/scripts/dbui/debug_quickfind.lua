local DebugPanel = require "dbui.debug_panel"
local lume = require "util.lume"
require "class"


-- Mostly based on gln's DebugManager.lua
local Quickfind = Class(function(self)
end)

function Quickfind:IsOpen()
    return self.open_command_palette ~= nil
end

local function GetBindingString(name, binding)
	-- Instance method, but it doesn't use self.
	return DebugPanel.GetBindingString(nil, name, binding)
end

local AddMenuToCommands
AddMenuToCommands = function(command_strings, commands, binding_def)
	if binding_def.skip_palette
		or (binding_def.isEnabled and not binding_def.isEnabled())
	then
		return
	end

	if binding_def.menuItems then
		for _,subm in ipairs(binding_def.menuItems) do
			local m = shallowcopy(subm)
			m.name = ("%s/%s"):format(binding_def.name, m.name)
			AddMenuToCommands(command_strings, commands, m)
		end
	elseif binding_def.fn then
		table.insert(commands, binding_def.fn)
		table.insert(command_strings, GetBindingString(binding_def.name, binding_def.binding))
	end
end


local function BindingsToCommandPalette( bindings, dbg, params )
    local command_strings, commands = {}, {}

	for _,binding_def in ipairs(bindings) do
		AddMenuToCommands(command_strings, commands, binding_def)
	end
    return command_strings, commands
end

-- Based on a list of bindings (see debugkeys.lua)
function Quickfind:OpenCommandPalette( bindings )
    assert( bindings )
    self.open_command_palette = true
    if bindings ~= self.command_palette_bindings then
        self.command_palette_bindings = bindings
        self.command_palette, self.commands = BindingsToCommandPalette( bindings, self )
    end
    return self.command_palette, self.commands
end

-- Build any sort of palette list of names and functions:
--	TheFrontEnd.debugMenu.quickfind:OpenListOfCommands({hello=print, haha=print})
function Quickfind:OpenListOfCommands(commands_to_fn)
    assert(commands_to_fn)
    self.open_command_palette = true
    if commands_to_fn ~= self.command_palette_bindings then
        self.command_palette_bindings = commands_to_fn
        self.command_palette = lume.keys(commands_to_fn)
		table.sort(self.command_palette)
		self.commands = lume.enumerate(self.command_palette, function(k,v)
			return commands_to_fn[v]
		end)
    end
    return self.command_palette, self.commands
end

function Quickfind:Render(ui)
	ui:SetDisplayScale(TheFrontEnd.imgui_font_size)

    if self.open_command_palette == nil or self.commands == nil then
		-- Even just calling Combo when it's not open will trigger the
		-- default Debug panel to show up. Hence, we must jump through this
		-- hoop to avoid calling it at all if unnecessary.
        return
    end
	local popupname = "##Command Palette"
	local y = 20 -- below steam fps counter
	ui:SetNextWindowPos(0, y, ui.Cond.Always)
	ui:SetNextWindowSize(RES_X/3, 10, ui.Cond.Always)
	local flags = ui.WindowFlags.NoBackground | ui.WindowFlags.NoNav | ui.WindowFlags.NoDecoration

	if ui:Begin(popupname, false, flags) then

		local confirmed, idx, closed = ui:Combo(popupname, 1, self.command_palette, nil, self.open_command_palette == true)
		if self.open_command_palette == true then
			self.open_command_palette = false
		elseif closed then
			self.open_command_palette = nil
			-- This is unsatisfactory, but because the command palette eats events, input.control_state is not going to
			-- correctly reflect the underlying key state.
			-- After ResetControlState(), it will STILL not reflect the underlying key state (eg. if a key was pressed
			-- during the command palette, and held down after closing), but at least IsControlDown will return false
			-- NOTE: Above comment is from GLN. Not sure if this is necessary for FtF.
			TheInput:ResetControlState()
		end
		if confirmed and idx > 0 then
			self.open_command_palette = nil
			local fn = self.commands[idx]
			local command_name = self.command_palette[idx]
			-- Pass command name so we don't need a closure for every single action.
			-- Same table keys in DebugPanel, Quickfind, and BindKeys.
			fn({
					name = command_name,
					from_quickfind = true,
				})
		end
	end
	ui:End()
end

return Quickfind
