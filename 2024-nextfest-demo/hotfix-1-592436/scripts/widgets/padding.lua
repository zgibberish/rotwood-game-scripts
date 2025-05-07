local Widget = require "widgets.widget"
require "class"

-- A widget that has no model, but a bounding box for layout purposes.

local Padding = Class(Widget, function(self, w, h)
    assert( w and h )
    Widget._ctor(self, "Padding")
    self.w, self.h = w, h
end)

function Padding:GetBoundingBox()
    local w, h = self.w, self.h
    return -w/2, -h/2, w/2, h/2
end
