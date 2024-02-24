
HashToNameMap = {}


function FindNetComponents()
	local filepath = require("util/filepath")
	local files = {}
	filepath.list_files("scripts/components", "*.lua", true, files)
	for i = 1, #files do
		local componentname = files[i]:match( "^.+/(.+)$"):match("(.+)%..+$")
		--print("Loading component " .. componentname)
		local cmp = require("components."..componentname)
		
		if type(cmp) == "table" and cmp.OnNetSerialize and cmp.OnNetDeserialize then
			-- register the component with the networked components register
			local hash = smallhash(componentname)
			HashToNameMap[hash] = componentname
			--print("Found network component " .. componentname .." hash: " .. hash)
		end
	end

	-- TODO: create an overall hash and check with other clients that the hash is the same.
	-- TODO: sort the list, create bits for each networked component
end


function GetComponentNameForHash(hash)
	return HashToNameMap[hash]
end

