--------------------------------------------------------------------------
--This prefab file is for loading autogenerated Cine prefabs
--------------------------------------------------------------------------

local cineutil = require "prefabs.cineutil"
local cine_autogen_data = require "prefabs.cine_autogen_data"


local ret = {}
local groups = {}

for name, params in pairs(cine_autogen_data) do
	if params.group ~= nil and string.len(params.group) > 0 then
		local cinelist = groups[params.group]
		if cinelist ~= nil then
			cinelist[#cinelist + 1] = name
		else
			groups[params.group] = { name }
		end
	end
	ret[#ret + 1] = cineutil.MakeAutogenCine(name, params)
end

--Don't need group prefabs for cines
--[[for groupname, cinelist in pairs(groups) do
	--Dummy prefab (no fn) for loading dependencies
	ret[#ret + 1] = Prefab(GroupPrefab(groupname), nil, nil, cinelist)
end]]

return table.unpack(ret)
