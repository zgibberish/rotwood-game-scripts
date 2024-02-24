local DebugNodes = require "dbui.debug_nodes"
local ease = require "util.ease"
local easing = require "util.easing"
local lume = require "util.lume"


local DebugEasing = Class(DebugNodes.DebugNode, function(self)
	DebugNodes.DebugNode._ctor(self, "Debug Easing")
	self.ease = {
		label = "",
	}
	self.easing = {
		label = "",
		key = "",
	}
end)

DebugEasing.PANEL_WIDTH = 600
DebugEasing.PANEL_HEIGHT = 780

local function Plot(ui, label, values)
	values = values or table.empty

	-- Show entire range of values because it's often outside of [0,1].
	local min = math.min(0, table.unpack(values))
	local max = math.max(1, table.unpack(values))

	return ui:PlotLines( label, "", values, 0, min, max, 200 )
end

function DebugEasing:RenderPanel( ui, panel )
	ui:TextColored(WEBCOLORS.PALETURQUOISE, "Simple [0,1] tween functions with ease.lua")
	ui:Text("Use with lume.lerp() to apply to any domain.")
	ui:Text("Use with Vector3:lerp() and color:lerp() or other object lerps.")
	Plot(ui, self.ease.label, self.ease.values)

	local idx = ui:_Combo( "ease.lua", self.ease.idx or 1, self.ease.keys or table.empty )
	if idx ~= self.ease.idx then
		self.ease.idx = idx

		self.ease.keys = lume.keys( ease )
		table.sort( self.ease.keys )

		self.ease.key = self.ease.keys[ self.ease.idx ]
		local easefn = ease[ self.ease.key ]
		self.ease.values = {}
		for i = 1, 100 do
			table.insert( self.ease.values, easefn(i / 100))
		end
		self.ease.label = ("ease.%s(t)"):format(self.ease.key)
	end


	ui:Spacing()
	ui:Separator()

	ui:TextColored(WEBCOLORS.PALETURQUOISE, "Numeric tween functions from easing.lua")
	-- GLN changed the order and meaning of these arguments to be less confusing!
	ui:Text([[Pass in your domain range as the arguments:
t - current time
b - beginning (initial) value
c - change (delta) value (same units as b)
d - duration (same units as t)]])

	if self.easing.key:find("Back") then
		ui:Text("s - (optional) ??")
	elseif self.easing.key:find("Elastic") then
		ui:Text("a - (optional) wave amplitude\np - (optional) wave period")
	end
	Plot(ui, self.easing.label, self.easing.values)

	idx = ui:_Combo( "easing.lua", self.easing.idx or 1, self.easing.keys or table.empty )
	if idx ~= self.easing.idx then
		self.easing.idx = idx

		self.easing.keys = lume.keys( easing )
		table.sort( self.easing.keys )

		self.easing.key = self.easing.keys[ self.easing.idx ]
		local easefn = easing[ self.easing.key ]
		self.easing.values = {}
		for i = 1, 100 do
			table.insert( self.easing.values, easefn( i, 0, 1.0, 100 ))
		end
		self.easing.label = ("easing.%s(t, 0, 1.0, 100)"):format(self.easing.key)
	end
end

DebugNodes.DebugEasing = DebugEasing

return DebugEasing
