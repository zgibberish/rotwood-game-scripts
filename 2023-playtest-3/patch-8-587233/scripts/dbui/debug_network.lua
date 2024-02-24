local DebugNodes = require "dbui.debug_nodes"
local DebugSettings = require "debug.inspectors.debugsettings"
require "consolecommands"
require "constants"

local DebugNetwork = Class(DebugNodes.DebugNode, function(self)
	DebugNodes.DebugNode._ctor(self, "Debug Network")
	self.options = DebugSettings("DebugNetwork.options")
		:Option("filter_entity_prefabname", "")
end)

DebugNetwork.PANEL_WIDTH = 800
DebugNetwork.PANEL_HEIGHT = 800

local selectedLocalBlob 
local selectedRemoteClient 
local selectedRemoteBlob

local clientGraphs = {}
local totalsendkbps = { 0.0, 0.0 }
local totalrecvkbps = { 0.0, 0.0 }


local function IsHostClientID(clientID)
	-- this will need to change if host migration is supported
	return clientID == 0
end



function DebugNetwork:RenderBadConnectionSimulator(ui)
	if ui:CollapsingHeader("Bad Connection Simulator") then

		local dirty = false
		local sett = TheNet:GetBadNetworkSimulatorState();
		if ui:Checkbox("Enabled", sett.enabled) then
			sett.enabled = not sett.enabled
			dirty = true
		end

		ui:SameLineWithSpace()
		if ui:Button("Reset to defaults") then

			sett.sendLimitKbps = 256
			sett.sendLagMinimumMs = 50
			sett.sendLagMaximumMs = 65		
			sett.sendPacketLossPercentage = 2.5

			sett.receiveLimitKbps = 256
			sett.receiveLagMinimumMs = 50
			sett.receiveLagMaximumMs = 65
			sett.receivePacketLossPercentage = 2.5

			dirty = true		
		end

		-- Simplyfied controls:
		local changed, value
		local throughput = sett.sendLimitKbps
		changed, value = ui:SliderInt("Max Throughput", throughput, 10, 512, "%dkbps")
		if changed then
			throughput = value
			dirty = true
		end

		local lag = sett.sendLagMaximumMs + sett.receiveLagMaximumMs
		changed, value = ui:SliderInt("Lag", lag, 0, 500, "%dms")
		if changed then
			lag = value
			dirty = true
		end

		local loss = sett.sendPacketLossPercentage + sett.receivePacketLossPercentage
		changed, value = ui:SliderFloat("Packet Loss", loss, 0, 10, "%0.1f%%")
		if changed then
			loss = value
			dirty = true
		end

		if dirty == true then

			sett.sendLimitKbps = throughput

			sett.sendLagMaximumMs = lag	* 0.5	
			sett.sendLagMinimumMs = sett.sendLagMaximumMs - 30;	-- Add some variation
			if sett.sendLagMinimumMs < 0 then
				sett.sendLagMinimumMs = 0
			end
			sett.sendPacketLossPercentage = loss * 0.5

			sett.receiveLimitKbps = sett.sendLimitKbps
			sett.receiveLagMaximumMs = sett.sendLagMaximumMs
			sett.receiveLagMinimumMs = sett.sendLagMinimumMs
			sett.receivePacketLossPercentage = sett.sendPacketLossPercentage;

			TheNet:SetBadNetworkSimulatorState(sett);
		end
	end
end



function DebugNetwork:GatherClientsData()
	local clients = TheNet:GetClientList()

	if clients then
		local send_total = 0
		local recv_total = 0

		for k, client in pairs(clients) do

			if not client.islocal then
				if client.isconnected then
					if not clientGraphs[client.id] then
						clientGraphs[client.id] = {}
						clientGraphs[client.id].rtt = {}
						clientGraphs[client.id].packetloss = {}
						clientGraphs[client.id].packetsendperiod = {}
						clientGraphs[client.id].sendkbps = {}
						clientGraphs[client.id].recvkbps = {}
					end

					table.insert(clientGraphs[client.id].rtt, client.rtt)
					table.insert(clientGraphs[client.id].packetloss, client.packetloss)
					table.insert(clientGraphs[client.id].packetsendperiod, client.packetsendperiod * 1000.0)
					table.insert(clientGraphs[client.id].sendkbps, client.sendkbps)
					table.insert(clientGraphs[client.id].recvkbps, client.recvkbps)

					send_total = send_total + client.sendkbps
					recv_total = recv_total + client.recvkbps

					if (#clientGraphs[client.id].rtt > 500) then	-- limit the length of the history
						table.remove(clientGraphs[client.id].rtt, 1)
						table.remove(clientGraphs[client.id].packetloss, 1)
						table.remove(clientGraphs[client.id].packetsendperiod, 1)
						table.remove(clientGraphs[client.id].sendkbps, 1)
						table.remove(clientGraphs[client.id].recvkbps, 1)
					end
				end
			end
		end	

		table.insert(totalsendkbps, send_total)
		table.insert(totalrecvkbps, recv_total)

		if (#totalsendkbps > 500) then	-- limit the length of the history
			table.remove(totalsendkbps, 1)
			table.remove(totalrecvkbps, 1)
		end

	end

	return clients
end



function DebugNetwork:RenderClients(ui, clients)
	local colors = self.colorscheme
	if ui:CollapsingHeader("Clients") then

		local colw = ui:GetColumnWidth()
	
		ui:Columns(9, "Clients")

		ui:SetColumnWidth(0, colw * 0.05)
		ui:SetColumnWidth(1, colw * 0.15)

		ui:TextColored(colors.header, "ID")
		ui:NextColumn()
		ui:TextColored(colors.header, "Name")
		ui:NextColumn()
		ui:TextColored(colors.header, "Local")
		ui:NextColumn()
		ui:TextColored(colors.header, "Connected")
		ui:NextColumn()
		ui:TextColored(colors.header, "RTT")
		ui:NextColumn()
		ui:TextColored(colors.header, "Loss %")
		ui:NextColumn()
		ui:TextColored(colors.header, "SendKbps")
		ui:NextColumn()
		ui:TextColored(colors.header, "RecvKbps")
		ui:NextColumn()
		ui:TextColored(colors.header, "SendRate")
		ui:NextColumn()

		if clients then
			local send_total = 0
			local recv_total = 0

			for k, client in pairs(clients) do

				ui:Text(tostring(client.id))
				ui:NextColumn()
				ui:Text(client.name .. (IsHostClientID(client.id) and " (host)" or ""))
				ui:NextColumn()
				ui:Text(tostring(client.islocal))
				ui:NextColumn()
				if client.islocal then
					ui:Text("-")	-- isconnected
					ui:NextColumn()
					ui:Text("-")	-- rtt
					ui:NextColumn()
					ui:Text("-")	-- packet loss
					ui:NextColumn()
					ui:Text("-")	-- sendkbps
					ui:NextColumn()
					ui:Text("-")	-- recvkbps
					ui:NextColumn()
					ui:Text("-")	-- packetsendperiod
					ui:NextColumn()
				else
					ui:Text(tostring(client.isconnected))
					ui:NextColumn()

					if client.isconnected then
						--ui:Text(tostring(client.rtt))
						ui:SetNextItemWidth()	-- will set it to -FLT_MIN
						ui:PlotLines("", tostring(math.floor(client.rtt)), clientGraphs[client.id].rtt, 0, 0.0, 800.0, 50.0)
						ui:NextColumn()
						--ui:Text(tostring(client.packetloss) .. "%")
						ui:SetNextItemWidth()	-- will set it to -FLT_MIN
						ui:PlotLines("", string.format("%.1f%%", client.packetloss), clientGraphs[client.id].packetloss, 0, 0.0, 10.0, 50.0)
						ui:NextColumn()
						--ui:Text(tostring(client.sendkbps))
						ui:SetNextItemWidth()	-- will set it to -FLT_MIN
						ui:PlotLines("", tostring(math.floor(client.sendkbps)), clientGraphs[client.id].sendkbps, 0, 0.0, 256.0, 50.0)
						ui:NextColumn()
						--ui:Text(tostring(client.recvkbps))
						ui:SetNextItemWidth()	-- will set it to -FLT_MIN
						ui:PlotLines("", tostring(math.floor(client.recvkbps)), clientGraphs[client.id].recvkbps, 0, 0.0, 256.0, 50.0)
						ui:NextColumn()	
						--ui:Text(tostring(client.packetsendperiod) .. "%")
						ui:SetNextItemWidth()	-- will set it to -FLT_MIN
						ui:PlotLines("", string.format("%.1fms", client.packetsendperiod * 1000.0), clientGraphs[client.id].packetsendperiod, 0, 0.0, 0.1, 50.0)
						ui:NextColumn()

					else 
						clientGraphs[client.id] = nil
						ui:Text("-")	-- rtt
						ui:NextColumn()
						ui:Text("-")	-- packet loss
						ui:NextColumn()
						ui:Text("-")	-- sendkbps
						ui:NextColumn()
						ui:Text("-")	-- recvkbps
						ui:NextColumn()
						ui:Text("-")	-- sendrate
						ui:NextColumn()
					end
				end
			end	
		end

		ui:Columns()
	end
end




function DebugNetwork:GatherPlayersData()
	local clients = TheNet:GetClientList()

	if clients then
		local send_total = 0
		local recv_total = 0

		for k, client in pairs(clients) do

			if not client.islocal then
				if client.isconnected then
					if not clientGraphs[client.id] then
						clientGraphs[client.id] = {}
						clientGraphs[client.id].rtt = {}
						clientGraphs[client.id].packetloss = {}
						clientGraphs[client.id].packetsendperiod = {}
						clientGraphs[client.id].sendkbps = {}
						clientGraphs[client.id].recvkbps = {}
					end

					table.insert(clientGraphs[client.id].rtt, client.rtt)
					table.insert(clientGraphs[client.id].packetloss, client.packetloss)
					table.insert(clientGraphs[client.id].packetsendperiod, client.packetsendperiod * 1000.0)
					table.insert(clientGraphs[client.id].sendkbps, client.sendkbps)
					table.insert(clientGraphs[client.id].recvkbps, client.recvkbps)

					send_total = send_total + client.sendkbps
					recv_total = recv_total + client.recvkbps

					if (#clientGraphs[client.id].rtt > 500) then	-- limit the length of the history
						table.remove(clientGraphs[client.id].rtt, 1)
						table.remove(clientGraphs[client.id].packetloss, 1)
						table.remove(clientGraphs[client.id].packetsendperiod, 1)
						table.remove(clientGraphs[client.id].sendkbps, 1)
						table.remove(clientGraphs[client.id].recvkbps, 1)
					end
				end
			end
		end	

		table.insert(totalsendkbps, send_total)
		table.insert(totalrecvkbps, recv_total)

		if (#totalsendkbps > 500) then	-- limit the length of the history
			table.remove(totalsendkbps, 1)
			table.remove(totalrecvkbps, 1)
		end

	end

	return clients
end

function DebugNetwork:RenderPlayers(ui)
	local colors = self.colorscheme
	if ui:CollapsingHeader("Players") then

		local colw = ui:GetColumnWidth()
	
		ui:Columns(7, "Players")

		ui:TextColored(colors.header, "PlayerID")
		ui:NextColumn()
		ui:TextColored(colors.header, "Name")
		ui:NextColumn()
		ui:TextColored(colors.header, "Local")
		ui:NextColumn()
		ui:TextColored(colors.header, "InputID")
		ui:NextColumn()
		ui:TextColored(colors.header, "ClientID")
		ui:NextColumn()
		ui:TextColored(colors.header, "EntityID")
		ui:NextColumn()
		ui:TextColored(colors.header, "GUID")
		ui:NextColumn()


		local players = TheNet:GetPlayerList()

		if players then
			for k, playerID in pairs(players) do

				local col = RGB(59, 222, 99)	-- green
				local islocal = TheNet:IsLocalPlayer(playerID)
				if not islocal then
					col = RGB(207, 61, 61) -- red
				end

				ui:TextColored(col, tostring(playerID))
				ui:NextColumn()
				ui:TextColored(col, TheNet:GetPlayerName(playerID) or "")
				ui:NextColumn()
				ui:TextColored(col, tostring(islocal))
				ui:NextColumn()
				ui:TextColored(col, tostring(TheNet:FindInputIDForPlayerID(playerID) or ""))
				ui:NextColumn()
				ui:TextColored(col, tostring(TheNet:FindClientIDForPlayerID(playerID) or ""))
				ui:NextColumn()
				ui:TextColored(col, tostring(TheNet:FindEntityIDForPlayerID(playerID) or ""))
				ui:NextColumn()
				ui:TextColored(col, tostring(TheNet:FindGUIDForPlayerID(playerID) or ""))
				ui:NextColumn()
			end	
		end

		ui:Columns()
	end
end

function DebugNetwork:RenderNetworkState(ui, panel)
	if ui:CollapsingHeader("Host State") then
		if TheNet:IsInGame() then
			local gm, gmseqnr = TheNet:GetCurrentGameMode();
			ui:Text("Game Mode: " .. gm .. " SeqNr: " .. tostring(gmseqnr))
			if ui:TreeNode("Room Data", ui.TreeNodeFlags.DefaultOpen) then
				ui:TextColored(BGCOLORS.CYAN, "Simulation Sequence Number: " .. TheNet:GetSimSequenceNumber())

				local roomdata = TheNet:GetRoomData()

				local isRoomLocked = TheNet:GetRoomLockState()
				local isReadyToStartRoom = TheNet:IsReadyToStartRoom()
				local roomCompleteSeqNr, roomIsComplete, enemyHighWater, lastEnemyID = TheNet:GetRoomCompleteState()
				local threatlevel = TheNet:GetThreatLevel()
				if roomdata then
					ui:Text("Action ID: " .. roomdata.actionID)
					ui:Text("World Prefab: " .. roomdata.worldPrefab)
					ui:Text("SceneGen Prefab: " .. roomdata.sceneGenPrefab)
					ui:Text("Room ID: " .. roomdata.roomID)
				end
				ui:Text("Room Locked: " .. tostring(isRoomLocked))
				ui:Text("Is Ready To Start Room: " .. tostring(isReadyToStartRoom))
				ui:Text(string.format("Room Complete: SeqNr=%d IsComplete=%s EnemyHighWater=%d LastEnemyNetID=%d", roomCompleteSeqNr, roomIsComplete, enemyHighWater, lastEnemyID))
				ui:Text("Threat Level: " .. threatlevel)

				if roomdata then
					ui:Text(string.format("Number of Players on Room Change: " .. roomdata.playersOnRoomChange))
				end
				if ui:TreeNode("Players on Last Room Change", ui.TreeNodeFlags.DefaultOpen) then
					local colors = self.colorscheme
					ui:Columns(5, "Players on Last Room Change")
					ui:SetColumnWidth(0, 30)
					ui:SetColumnWidth(1, 60)
					ui:SetColumnWidth(2, 60)
					ui:SetColumnWidth(3, 120)
					ui:SetColumnWidth(4, 90)
					ui:TextColored(colors.header, "ID")
					ui:NextColumn()
					ui:TextColored(colors.header, "GUID")
					ui:NextColumn()
					ui:TextColored(colors.header, "NetID")
					ui:NextColumn()
					ui:TextColored(colors.header, "Name")
					ui:NextColumn()
					ui:TextColored(colors.header, "Debug")
					ui:NextColumn()
					local players = TheNet:GetPlayersOnRoomChange()
					for i,player in ipairs(players) do
						ui:Text(player.Network:GetPlayerID())
						ui:NextColumn()
						ui:Text(string.format("%d", player.GUID))
						ui:NextColumn()
						ui:Text(player.Network:GetEntityID())
						ui:NextColumn()
						ui:Text(player:GetCustomUserName())
						ui:NextColumn()
						if ui:Button("Debug##"..i) then
							panel:PushNode(DebugNodes.DebugEntity(Ents[player.GUID]) )
						end
						ui:NextColumn()
					end
					ui:Columns()
					ui:TreePop()
				end

				ui:TreePop()
			end
			if ui:TreeNode("Run Data", ui.TreeNodeFlags.DefaultOpen) then
				-- TODO: compare these values to those stored in local systems like worldmap, ascensionmanager, etc.
				local mode, arenaWorldPrefab, regionID, locationID, seed, altMapGenID, ascensionLevel, seqNr = TheNet:GetRunData()
				ui:Text("Mode: " .. mode)
				if mode == STARTRUNMODE_ARENA then
					ui:Text("Arena World Prefab: " .. arenaWorldPrefab)
				end
				ui:Text("Region ID: " .. regionID)
				ui:Text("Location ID: " .. locationID)
				ui:Text("Seed: " .. seed)
				if mode == STARTRUNMODE_DEFAULT then
					ui:Text("Alt MapGen ID: " .. altMapGenID)
				end
				ui:Text("Ascension Level: " .. ascensionLevel)
				ui:Text("Sequence Number: " .. seqNr)
				ui:TreePop()
			end
			if TheNet:IsHost() and ui:TreeNode("Run Player Status (Host-Only)") then
				local colors = self.colorscheme
				ui:Columns(2, "Run Player Status")
				ui:SetColumnWidth(0, 30)
				ui:SetColumnWidth(1, 120)
				ui:TextColored(colors.header, "ID")
				ui:NextColumn()
				ui:TextColored(colors.header, "Status")
				ui:NextColumn()
				local statusTable = TheNet:GetRunPlayerStatus()
				for playerID,status in pairs(statusTable) do
					ui:Text(playerID)
					ui:NextColumn()
					ui:Text(status .. " (" .. GetRunPlayerStatusDescription(status) .. ")")
					ui:NextColumn()
				end
				ui:Columns()
				ui:TreePop()
			end
		else
			ui:Text("Not in network game")
		end
	end
end



function DebugNetwork:RenderNetworkEvents(ui, panel)
	if ui:CollapsingHeader("Events") then
		local counters = TheNet:GetEventsCounters()
		if counters then

			local nrColumns = 2
			ui:Columns(nrColumns, "Events Counters")

			local colors = self.colorscheme
			ui:TextColored(colors.header, "Type")
			ui:NextColumn()
			ui:TextColored(colors.header, "Count")
			ui:NextColumn()

			if counters then
				for k, count in pairs(counters) do

					ui:Text(k)
					ui:NextColumn()
					ui:Text(tostring(count))
					ui:NextColumn()
				end
			end
			ui:Columns()
		end
	end
end

function DebugNetwork:RenderEntities(ui, panel)
	if ui:CollapsingHeader("Entities") then

		self.options:SaveIfChanged("filter_entity_prefabname", ui:FilterBar(self.options.filter_entity_prefabname, "Filter entity prefab", "Prefab pattern..."))

		local entities = TheNet:GetEntityList()

		ui:Text("Sim Seq Nr: " .. TheNet:GetSimSequenceNumber())


		local colw = ui:GetColumnWidth()
	
		local nrColumns = 10
		ui:Columns(nrColumns, "Entities")

		local onecolumn = colw / nrColumns;
		ui:SetColumnWidth(0, onecolumn * 0.6)	-- guid
		ui:SetColumnWidth(1, onecolumn * 0.6)	-- id
		ui:SetColumnWidth(2, onecolumn * 1.5)	-- prefab
		ui:SetColumnWidth(3, onecolumn * 1.5)	-- owner
		local colors = self.colorscheme
		ui:TextColored(colors.header, "Guid")
		ui:NextColumn()
		ui:TextColored(colors.header, "ID")
		ui:NextColumn()
		ui:TextColored(colors.header, "Prefab")
		ui:NextColumn()
		ui:TextColored(colors.header, "Owner")
		ui:NextColumn()
		ui:TextColored(colors.header, "SeqNr")
		ui:NextColumn()
		ui:TextColored(colors.header, "CtrlBlob")
		ui:NextColumn()
		ui:TextColored(colors.header, "DataBlob")
		ui:NextColumn()
		ui:TextColored(colors.header, "BlobSize")
		ui:NextColumn()
		ui:TextColored(colors.header, "Debug")
		ui:NextColumn();
		ui:TextColored(colors.header, "Kill")
		ui:NextColumn();

		for k, entity in pairs(entities or table.empty) do
			local ok_prefabname = ui:MatchesFilterBar(self.options.filter_entity_prefabname, entity.prefab or "")
			if ok_prefabname then
				local col = RGB(59, 222, 99)	-- green
				if not entity.islocal then
					col = RGB(207, 61, 61) -- red
				else
					if entity.transferring then
						col = RGB(198, 172, 0)	-- yellow
					end
				end

				ui:TextColored(col, tostring(math.floor(entity.guid)))
				ui:NextColumn()
				ui:TextColored(col, tostring(entity.id))
				ui:NextColumn()
				ui:TextColored(col, entity.prefab)
				ui:NextColumn()
				ui:TextColored(col, tostring(entity.owner))
				ui:NextColumn()
				ui:TextColored(col, tostring(entity.seqnr))
				ui:NextColumn()
				ui:TextColored(col, tostring(entity.ctrlblobid))
				ui:NextColumn()
				ui:TextColored(col, tostring(entity.datablobid))
				ui:NextColumn()
				ui:TextColored(col, tostring(entity.blobsize))
				ui:NextColumn()
				if ui:Button("Debug##"..k) then
					panel:PushNode(DebugNodes.DebugEntity(Ents[entity.guid]) )
				end
				ui:NextColumn()	
				if entity.islocal then
					if ui:Button("Kill##"..k) then
						local tokillent = Ents[entity.guid]

						if tokillent.components.health ~= nil then
							tokillent.components.health:Kill()
						else
							tokillent:Remove()
						end
					end
				end
				ui:NextColumn()
			end
		end

		ui:Columns()
	end
end



function DebugNetwork:RenderLocalBlobs(ui, panel)
	if ui:CollapsingHeader("Blobs (Local)") then
		if not TheNet:ShowBlobDebugger() then
			local localblobs = TheNet:GetLocalBlobs()
			if localblobs then
				local index = 1

				-- Find the previously selected blobID:
				for i, v in ipairs(localblobs) do
					if v == selectedLocalBlob then
						index = i
					end
				end
				selectedLocalBlob = localblobs[index]

				local changed, idx = ui:Combo("Blobs##1", index, localblobs)
				if changed then
					selectedLocalBlob = localblobs[idx]
				end

				if selectedLocalBlob ~= nil then
					ui:BeginChild("HexViewer##1", 0, 200, true, ui.WindowFlags.HorizontalScrollbar)
						TheNet:ViewLocalBlob(selectedLocalBlob)
					ui:EndChild()
				end
			end
		end
	end
end

function DebugNetwork:RenderRemoteBlobs(ui, panel)
	if ui:CollapsingHeader("Blobs (Remote)") then
			
		local clients = TheNet:GetRemoteClientsList()

		if clients then
			local index = 1

			-- Find the previously selected blobID:
			for i, v in ipairs(clients) do
				if v == selectedRemoteClient then
					index = i
				end
			end
			selectedRemoteClient = clients[index]

			local changed, idx = ui:Combo("Remote Client##1", index, clients)
			if changed then
				selectedRemoteClient = clients[idx]
			end

			if selectedRemoteClient ~= nil then
			local remoteblobs = TheNet:GetRemoteBlobs(selectedRemoteClient)
			if remoteblobs then
				local index2 = 1

				-- Find the previously selected blobID:
				for i, v in ipairs(remoteblobs) do
					if v == selectedRemoteBlob then
						index2 = i
					end
				end
				selectedRemoteBlob = remoteblobs[index2]

				local changed, idx = ui:Combo("Blobs##2", index2, remoteblobs)
				if changed then
					selectedRemoteBlob = remoteblobs[idx]
				end

					if selectedRemoteBlob ~= nil and selectedRemoteClient ~= nil then
				ui:BeginChild("HexViewer##2", 0, 200, true, ui.WindowFlags.HorizontalScrollbar)
					TheNet:ViewRemoteBlob(selectedRemoteBlob, selectedRemoteClient)
				ui:EndChild()
			end
		end
	end
		end
	end
end

function DebugNetwork:RenderPanel( ui, panel )

	local clients = self:GatherClientsData()

	-- Render the total kbps being send and received from this machine:
	ui:Columns(2, "Graphs")
	local colw = ui:GetColumnWidth()

--	ui:SetColumnWidth(0, colw * 0.5)
--	ui:SetColumnWidth(1, colw * 0.5)

	local sendval = totalsendkbps and #totalsendkbps > 0 and  math.floor(totalsendkbps[#totalsendkbps]) or 0.0
	ui:SetNextItemWidth()	-- will set it to -FLT_MIN
	ui:PlotLines("", "send "..tostring(sendval).."kbps", totalsendkbps, 0, 0.0, 256.0, 80.0)
	ui:NextColumn()

	local recvval = totalrecvkbps and #totalrecvkbps > 0 and math.floor(totalrecvkbps[#totalrecvkbps]) or 0.0
	ui:SetNextItemWidth()	-- will set it to -FLT_MIN
	ui:PlotLines("", "recv "..tostring(recvval).."kbps", totalrecvkbps, 0, 0.0, 256.0, 80.0)
	ui:Columns()

	panel.open_next_in_new_panel = true


	-- Render the checkbox to show network ownership:
	local showing = TheSim:GetDebugRenderEnabled() and TheSim:GetDebugNetworkRenderEnabled()
	if ui:Checkbox("Show Network Ownership dots (Shift-Alt-N)", showing) then
		TheSim:SetDebugRenderEnabled(true)
		TheSim:SetDebugNetworkRenderEnabled(not TheSim:GetDebugNetworkRenderEnabled())
	end



	-- Render the list of clients:
	self:RenderClients(ui, clients)
	self:RenderBadConnectionSimulator(ui)

	self:RenderNetworkState(ui, panel)
	self:RenderPlayers(ui)
	self:RenderNetworkEvents(ui, panel)
	
	-- Render the list of entities:
	self:RenderEntities(ui, panel)


	-- Blobs:
	self:RenderLocalBlobs(ui, panel)
	self:RenderRemoteBlobs(ui, panel)

end

DebugNodes.DebugNetwork = DebugNetwork

return DebugNetwork
