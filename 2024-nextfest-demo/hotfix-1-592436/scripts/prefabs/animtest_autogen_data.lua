-- Note - this assumes the directory autogen/<category> exists, so if you ever clone this file, make sure to modify category and add its directory
local category = "animtest"

local prefabutil = require "prefabs.prefabutil"
return prefabutil.LoadAutogenDefs(category)

