local FollowLabel = require "widgets.ftf.followlabel"
local RoomLoader = require "roomloader"
local playerutil = require "util.playerutil"
local fmodtable = require "defs.sound.fmodtable"
local soundutil = require "util.soundutil"

local COUNTDOWN_LENGTH = 3 --SECONDS

local StartRunPortal = Class(function(self, inst)
	self.inst = inst
	self.traveling = false

	self.countingDown = false
	self.countDownStartTime = nil

	self.inst:StartUpdatingComponent(self)
end)


function StartRunPortal:ShowStatusLabel()
	if not self.waitingForAllPlayersLabel then
		if TheDungeon.HUD then
			self.waitingForAllPlayersLabel = TheDungeon.HUD:OverlayElement(FollowLabel())
				:SetText(STRINGS.UI.HUD.WAITING_FOR_ALL_PLAYERS)
				:SetTarget(self.inst)
				:Offset(0, 525)
		end
		self.inst:PushEvent("start_heli")
	end
end

function StartRunPortal:HideStatusLabel()
	if self.waitingForAllPlayersLabel then 
		self.waitingForAllPlayersLabel:Remove()
		self.waitingForAllPlayersLabel = nil
		self.inst:PushEvent("stop_heli")
	end
end

function StartRunPortal:UpdateWaitingForAllPlayers(current, total, locationID, ascensionLevel)
	if self.waitingForAllPlayersLabel then
		local str = string.format(STRINGS.UI.HUD.RUN_DATA, STRINGS.NAMES[locationID], ascensionLevel)
		str = str .."\n".. string.format(STRINGS.UI.HUD.WAITING_FOR_ALL_PLAYERS, current, total)
		self.waitingForAllPlayersLabel:SetText(str)
		self.inst:PushEvent("start_heli")
	end
end

function StartRunPortal:UpdateCountdown(time, locationID, ascensionLevel)
	if self.waitingForAllPlayersLabel then
		local str = string.format(STRINGS.UI.HUD.RUN_DATA, STRINGS.NAMES[locationID], ascensionLevel)
		str = str .."\n".. string.format(STRINGS.UI.HUD.START_RUN_COUNTDOWN, time)
		self.waitingForAllPlayersLabel:SetText(str)
		--TheFrontEnd:GetSound():PlaySound(fmodtable.Event.ui_mpCountdownTick)
	end
end

function StartRunPortal:SetRequestActive() 
	if not self.active then
		self.inst:PushEvent("run_requested")
		self.active = true
	end
end

function StartRunPortal:SetRequestInactive() 
	if self.active then
		self.inst:PushEvent("run_cancelled")

		-- No run request is active
		self:HideStatusLabel()

		self.active = nil
		self.countingDown = false
	end
end

function StartRunPortal:OnUpdate(dt)
	local playerID, mode, arenaWorldPrefab, regionID, locationID, seed, altMapGenID, ascensionLevel, seqNr, questParams = TheNet:GetRequestedRunData()

	if playerID then
		-- Run request is active!
		self:SetRequestActive()

		-- Determine how many players are inside the area that are ready to travel (not busy)
		local x, y, z = self.inst.Transform:GetWorldPosition()
		local players = playerutil.FindPlayersInRange(x, z, self.radius)

		if not TheNet:IsHost() and not self.traveling then
			if TheNet:IsStartRunImminent() then 
				self.traveling = true
				print("Host told us start run is imminent! Fading out")
				TheFrontEnd:Fade(FADE_OUT, 0.5)	-- Fade out and wait for the host's start run update
			end
		end


		-- If there is only one player, skip the countdown:
		if #AllPlayers == 1 then
			COUNTDOWN_LENGTH = 0 --SECONDS
		else
			COUNTDOWN_LENGTH = 3 --SECONDS
		end



		if not self.traveling then
			local nrReadyPlayers = 0

			for k, player in pairs(players) do
				if player:IsAlive() and not player.components.playerbusyindicator:IsBusy() then
					nrReadyPlayers = nrReadyPlayers + 1
				end
			end

			if nrReadyPlayers == #AllPlayers then
				if self.countingDown then
					-- Countdown has been initiated. Count down and at 0, start the run.
					-- Check if all players are still around. If not, change state.
					local passed = GetTime() - self.countDownStartTime
					local remaining = COUNTDOWN_LENGTH - passed

					if remaining <= 0 then
						--Start the run! (will be ignored internally if this isn't the host calling it)
						if TheNet:IsHost() then
							TheNet:HostSetStartRunImminent()
							self.traveling = true

							-- networking2022: hack, host param false takes precedence until client progression data is synced
							if TheDungeon and TheDungeon:GetDungeonMap() then
								local hostQuestParams = TheDungeon:GetDungeonMap():BuildQuestParams(locationID)
								if questParams.wants_quest_room and not hostQuestParams.wants_quest_room then
									TheLog.ch.Networking:printf("Warning: Requested run wants_quest_room (%s) doesn't match host (%s).  Using host value.",
										tostring(questParams.wants_quest_room),
										tostring(hostQuestParams.wants_quest_room))
									questParams.wants_quest_room = hostQuestParams.wants_quest_room
								end
							end

							TheFrontEnd:Fade(FADE_OUT, 0.5, function()
								self.inst:DoTaskInTime(0.5, function()	-- Delay for 0.5 more seconds
									RoomLoader.StartRun(regionID, locationID, seed, altMapGenID, ascensionLevel, questParams)
								end)
							end)
						end
						-- Clients check whether a room change is actually happening in the TheNet:IsStartRunImminent() check above this if statement block
					else
						self:UpdateCountdown(math.ceil(remaining), locationID, ascensionLevel)
					end
				else
					-- We haven't started counting down yet. Start now!
					self:ShowStatusLabel()
					self.countDownStartTime = GetTime()
					self.countingDown = true
				end
			else
				self.countingDown = false
				self.countDownStartTime = nil

				-- We are waiting for players
				self:ShowStatusLabel()
				self:UpdateWaitingForAllPlayers(nrReadyPlayers, #AllPlayers, locationID, ascensionLevel)
			end
		else
			self:HideStatusLabel()
		end
	else
		self:SetRequestInactive()
	end
end

return StartRunPortal
