function CountEntities()
	local invalid = 0
	local prefablist = {}
    local count = 0
    local noprefab = 0
    local awake = 0
	for i,v in pairs(Ents) do
		count = count + 1
		if not v:IsValid() then
			invalid = invalid + 1
		end
		if not v:IsAsleep() then
			awake = awake + 1
		end
		local prefab = v.prefab
		if not prefab then
			noprefab = noprefab + 1
		else
			prefablist[prefab] = prefablist[prefab] and prefablist[prefab]+1 or 1
		end
	end
	print(string.format("Total entities: %d (awake %d)",count,awake))
	print(string.format("No prefab: %d",noprefab))
	print(string.format("Invalid entities: %d",invalid))
	local tosort = {}
	for i,v in pairs(prefablist) do
		tosort[#tosort+1] = {i,v}
	end
	table.sort(tosort, function(a,b) return a[2]>b[2] end)
    for i,v in pairs(tosort) do
		print(string.format("   %20s - %5d",v[1],v[2]))
	end
end

function GetProfilerSave(results)
    TheLog.ch.Profiler:printf("GetProfilerSave not implemented")
    do
        return
    end
end

function GetProfilerPlayers(results)
	local clients = TheNet:GetClientList()
	if clients then
		results.numplayers = #clients
		local data = {
			isconnected = {},
			islocal = {},
			rtt = {},
			packetloss = {},
		}
		for j,k in ipairs(clients) do
			table.insert(data.isconnected, tostring(k.isconnected or false))
			table.insert(data.islocal, tostring(k.islocal or false))
			table.insert(data.rtt, k.rtt or -1)
			table.insert(data.packetloss, k.packetloss or -1)
		end
		for key,val in pairs(data) do
			results[key] = table.concat(val, " ")
		end
	end
	return results
end


function GetProfilerServerStats(results)
	if TheNet:IsHost() then
		results.ClientMode = "Host"
	else
		results.ClientMode = "Client"
	end
end

function GetProfilerModInfo(results)
	if TheWorld then
		local modnames = ModManager:GetServerModsNames()
		local mods = ""
		local count = 0
		for _,modname in pairs(ModManager:GetServerModsNames()) do
			mods = mods.."["..modname.."]"
			count = count+1
		end
		results.mods = tostring(count)..":"..mods
	end
end

function GetProfilerMetaData()
	local results = {}
	GetProfilerServerStats(results)
	GetProfilerSave(results)
	GetProfilerPlayers(results)
	GetProfilerModInfo(results)	
	return results
end

function ExpandWorldFromProfile()
	local profile
	TheSim:GetPersistentString( "../profile.json",	
		function(load_success, str)
    		if load_success == true then
				profile = str
			end
		end)
	local pos1 = profile:find('{"cat":"dont_starve","name":"metadata"',1,true)
	local pos2 = profile:find('}},',1,true)
	if pos1 and pos2 then
		local sub = profile:sub(pos1, pos2+1)
		local jsonprofile = json.decode( sub )
		local args = jsonprofile.args
		local levelstring = args.levelstring
		if levelstring then
			local insz, outsz = TheSim:SetPersistentString( "profile_world", levelstring, false, nil)
		end
	end
end
