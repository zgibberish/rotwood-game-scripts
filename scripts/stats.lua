-- THIS IS OLD
--
-- This is DST's metrics system. FtF's is in metrics.lua.
--



-- require "stats_schema"    -- for when we actually organize

--~ STATS_ENABLE = METRICS_ENABLED
--~ -- NOTE: There is also a call to 'anon/start' in dontstarve/main.cpp which has to be un/commented

--~ --- GAME Stats and details to be sent to server on game complete ---
local ProfileStats = {}


--~ ---------------------------------------------------------------------------------------
--~ --#V2C: moved these table functions here for now
--~ --      don't think we'll need these anymore once we clean out this file as well
--~ function table.setfield(Table,Name,Value)

--~     -- Table (table, optional); default is _G
--~     -- Name (string); name of the variable--e.g. A.B.C ensures the tables A
--~     --   and A.B and sets A.B.C to <Value>.
--~     --   Using single dots at the end inserts the value in the last position
--~     --   of the array--e.g. A. ensures table A and sets A[#A]
--~     --   to <Value>.  Multiple dots are interpreted as a string--e.g. A..B.
--~     --   ensures the table A..B.
--~     -- Value (any)
--~     -- Compatible with Lua 5.0 and 5.1

--~     if type(Table) ~= 'table' then
--~         Table,Name,Value = _G,Table,Name
--~     end

--~     local Concat,Key = false,''

--~     string.gsub(Name,'([^%.]+)(%.*)',
--~                     function(Word,Delimiter)
--~                         if Delimiter == '.' then
--~                             if Concat then
--~                                 Word = Key .. Word
--~                                 Concat,Key = false,''
--~                             end
--~                             if Table == _G then -- using strict.lua have to declare global before using it
--~                                 global(Word)
--~                             end
--~                             if type(Table[Word]) ~= 'table' then
--~                                 Table[Word] = {}
--~                             end
--~                             Table = Table[Word]
--~                         else
--~                             Key = Key .. Word .. Delimiter
--~                             Concat = true
--~                         end
--~                     end
--~                     )

--~     if Key == '' then
--~         Table[#Table+1] = Value
--~     else
--~         Table[Key] = Value
--~     end

--~ end


--~ function table.getfield(Table,Name)
--~     -- Access a value in a table using a string
--~     -- table.getfield(A,"A.b.c.foo.bar")

--~     if type(Table) ~= 'table' then
--~         Table,Name = _G,Table
--~     end

--~     for w in string.gfind(Name, "[%w_]+") do
--~         Table = Table[w]
--~         if Table == nil then
--~             return nil
--~         end
--~     end
--~     return Table
--~ end

--~ function table.findfield(Table,Name)
--~     local indx = ""

--~     for i,v in pairs(Table) do
--~         if i == Name then
--~             return i
--~         end
--~         if type(v) == "table" then
--~             indx = table.findfield(v,Name)
--~             if indx then
--~                 return i .. "." .. indx
--~             end
--~         end
--~     end
--~     return nil
--~ end

--~ function table.findpath(Table,Names,indx)
--~     local path = ""
--~     indx = indx or 1
--~     if type(Names) == "string" then
--~         Names = {Names}
--~     end

--~     for i,v in pairs(Table) do
--~         if i == Names[indx] then
--~             if indx == #Names then
--~                 return i
--~             elseif type(v) == "table" then
--~                 path = table.findpath(v,Names,indx+1)
--~                 if path then
--~                     return i .. "." .. path
--~                 else
--~                     return nil
--~                 end
--~             end
--~         end
--~         if type(v) == "table" then
--~             path = table.findpath(v,Names,indx)
--~             if path then
--~                 return i .. "." .. path
--~             end
--~         end
--~     end
--~     return nil
--~ end

--~ ---------------------------------------------------------------------------------------

--~ --- non-user-facing Tracking stats  ---
--~ TrackingEventsStats = {}
--~ TrackingTimingStats = {}
local GameStats = {}
--~ local OnLoadGameInfo = {}

--~ -- GLOBAL FOR C++
--~ function GetClientMetricsData()
--~     if Profile == nil then
--~         return nil
--~     end

--~     local data = {}
--~     data.play_instance = Profile:GetPlayInstance()
--~     data.install_id = Profile:GetInstallID()

--~     return data
--~ end

--~ local function IncTrackingStat(stat, subtable)

--~ 	if not STATS_ENABLE then
--~ 		return
--~ 	end

--~     local t = TrackingEventsStats
--~     if subtable then
--~         t = TrackingEventsStats[subtable]

--~         if not t then
--~             t = {}
--~             TrackingEventsStats[subtable] = t
--~         end
--~     end

--~     t[stat] = 1 + (t[stat] or 0)
--~ end

--~ local function SetTimingStat(subtable, stat, value)

--~ 	if not STATS_ENABLE then
--~ 		return
--~ 	end

--~     local t = TrackingTimingStats
--~     if subtable then
--~         t = TrackingTimingStats[subtable]

--~         if not t then
--~             t = {}
--~             TrackingTimingStats[subtable] = t
--~         end
--~     end

--~     t[stat] = math.floor(value/1000)
--~ end

--~ local function SendTrackingStats()

--~ 	if not STATS_ENABLE then
--~ 		return
--~ 	end

--~ 	if table.numkeys(TrackingEventsStats) then
--~     	local stats = json.encode({events=TrackingEventsStats, timings=TrackingTimingStats})
--~     	TheSim:LogBulkMetric(stats)
--~     end
--~ end

--~ local function PrefabListToMetrics(list)
--~     local metrics = {}
--~     for i,item in ipairs(list) do
--~         if metrics[item.prefab] == nil then
--~             metrics[item.prefab] = 0
--~         end
--~         if item.components.stackable ~= nil then
--~             metrics[item.prefab] = metrics[item.prefab] + item.components.stackable:StackSize()
--~         else
--~             metrics[item.prefab] = metrics[item.prefab] + 1
--~         end
--~     end
--~     -- format for storage
--~     local metrics_kvp = {}
--~     for name,count in pairs(metrics) do
--~         table.insert(metrics_kvp, {prefab=name, count=count})
--~     end
--~     return metrics_kvp
--~ end

--~ local function BuildContextTable(player)
--~     local sendstats = {}

--~     -- can be called with a player or a userid
--~     if type(player) == "table" then
--~         sendstats.user = player.userid
--~         sendstats.user_age = player.components.age ~= nil and player.components.age:GetAgeInDays() or nil
--~     else
--~         sendstats.user = player
--~     end
--~     -- GJANS TODO: Send the host wherever we can!
--~     --if type(host) == "table" then
--~         --sendstats.host = host.userid
--~     --else
--~         --sendstats.host = host
--~     --end

--~     local client_metrics = nil
--~     if sendstats.user ~= nil then
--~         if sendstats.user == TheNet:GetUserID() then
--~             client_metrics = GetClientMetricsData()
--~         elseif TheNet:IsHost() then
--~             client_metrics = TheNet:GetClientMetricsForUser(sendstats.user)
--~         end
--~     end

--~     sendstats.build = APP_VERSION
--~     if client_metrics ~= nil then
--~         sendstats.install_id = client_metrics.install_id
--~         sendstats.session_id = client_metrics.play_instance
--~     end
--~     if TheWorld ~= nil then
--~         sendstats.save_id = TheWorld.meta.session_identifier
--~         sendstats.master_save_id = nil

--~         if TheWorld.state ~= nil then
--~             sendstats.world_time = TheWorld.state.cycles + TheWorld.state.time
--~         end
--~     end

--~     sendstats.user =
--~         (sendstats.user ~= nil and (sendstats.user.."@chester")) or
--~         (DEV_MODE and "testing") or
--~         "unknown"

--~     return sendstats
--~ end


--~ local function BuildStartupContextTable() -- includes a bit more metadata about the user, should probably only be on startup
--~     local sendstats = BuildContextTable(TheNet:GetUserID())

--~     sendstats.platform = PLATFORM
--~     sendstats.branch = RELEASE_CHANNEL

--~     local modnames = KnownModIndex:GetModNames()
--~     for i, name in ipairs(modnames) do
--~         if KnownModIndex:IsModEnabled(name) then
--~             sendstats.branch = sendstats.branch .. "_modded"
--~             break
--~         end
--~     end

--~     return sendstats
--~ end

--~ local function ClearProfileStats()
--~     ProfileStats = {}
--~ end

--~ --[[local function GetProfileStats(wipe)
--~ 	if table.numkeys(ProfileStats) == 0 then
--~ 		return json.encode( {} )
--~ 	end

--~ 	wipe = wipe or false
--~ 	local jsonstats = ''
--~ 	local sendstats = BuildContextTable() -- Ack! This should be passing in a user or something...

--~ 	sendstats.stats = ProfileStats
--~ 	--print("_________________++++++ Sending Accumulated profile stats...\n")
--~ 	--ddump(sendstats)

--~ 	jsonstats = json.encode(sendstats)

--~ 	if wipe then
--~ 		ClearProfileStats()
--~     end
--~     return jsonstats
--~ end]]


--~ --[[local function SendAccumulatedProfileStats()
--~ 	if not STATS_ENABLE then
--~ 		return
--~ 	end

--~ 	--local sendstats = GetProfileStats(true)
--~     --sendstats.event = "accumulatedprofile"
--~ 	-- TODO:STATS TheSim:SendProfileStats(sendstats)
--~ end]]


--~ local function GetTestGroup()
--~ 	local id = TheSim:GetSteamIDNumber()

--~ 	local groupid = id%2 -- group 0 must always be default, because GetSteamIDNumber returns 0 for non-steam users
--~ 	return groupid
--~ end


--~ local function PushMetricsEvent(event_id, player, values, is_only_local_users_data)

--~     local sendstats = BuildContextTable(player)
--~     sendstats.event = event_id

--~     if values then
--~         for k,v in pairs(values) do
--~             sendstats[k] = v
--~         end
--~     end

--~     --print("PUSH METRICS EVENT")
--~     --dumptable(sendstats)
--~     --print("^^^^^^^^^^^^^^^^^^")
--~     local jsonstats = json.encode_compliant(sendstats)
--~     TheSim:SendProfileStats(jsonstats, is_only_local_users_data)
--~ end

--~ ------------------------------------------------------------------------------------------------
--~ -- GLOBAL functions
--~ ------------------------------------------------------------------------------------------------

-- value is optional, 1 if nil
local function ProfileStatsAdd(item, value)
    --print ("ProfileStatsAdd", item)
    if value == nil then
		value = 1
    end

    if ProfileStats[item] then
		ProfileStats[item] = ProfileStats[item] + value
    else
		ProfileStats[item] = value
    end
end

--~ function ProfileStatsAddItemChunk(item, chunk)
--~     if ProfileStats[item] == nil then
--~     	ProfileStats[item] = {}
--~     end

--~     if ProfileStats[item][chunk] then
--~     	ProfileStats[item][chunk] =ProfileStats[item][chunk] +1
--~     else
--~     	ProfileStats[item][chunk] = 1
--~     end
--~ end

local function ProfileStatsSet(item, value)
	ProfileStats[item] = value
end

--~ function ProfileStatsGet(item)
--~ 	return ProfileStats[item]
--~ end

--~ -- The following takes advantage of table.setfield (util.lua) which
--~ -- takes a string representation of a table field (e.g. "foo.bar.bleah.eeek")
--~ -- and creates all the intermediary tables if they do not exist

--~ function ProfileStatsAddToField(field, value)
--~     --print ("ProfileStatsAdd", item)
--~     if value == nil then
--~         value = 1
--~     end

--~     local oldvalue = table.getfield(ProfileStats,field)
--~     if oldvalue then
--~     	table.setfield(ProfileStats,field, oldvalue + value)
--~     else
--~     	table.setfield(ProfileStats,field, value)
--~     end
--~ end

--~ function ProfileStatsSetField(field, value)
--~     if type(field) ~= "string" then
--~         return nil
--~     end
--~     table.setfield(ProfileStats, field, value)
--~     return value
--~ end

--~ function ProfileStatsAppendToField(field, value)
--~     if type(field) ~= "string" then
--~         return nil
--~     end
--~     -- If the field name ends with ".", setfield adds the value to the end of the array
--~     table.setfield(ProfileStats, field .. ".", value)
--~ end

function SuUsed(item,value)
    GameStats.super = true
    ProfileStatsSet(item, value)
end

--~ function SetSuper(value)
--~     --print("Setting SUPER",value)
--~     OnLoadGameInfo.super = value
--~ end

function SuUsedAdd(item,value)
    GameStats.super = true
    ProfileStatsAdd(item, value)
end

function WasSuUsed()
    return GameStats.super
end


--~ ------------------------------------------------------------------------------------------------
--~ -- Export public methods
--~ ------------------------------------------------------------------------------------------------

--~ return {
--~     BuildContextTable = BuildContextTable,
--~     GetTestGroup = GetTestGroup,
--~     PushMetricsEvent = PushMetricsEvent,
--~     ClearProfileStats = ClearProfileStats,
--~     PrefabListToMetrics = PrefabListToMetrics,
--~ }
