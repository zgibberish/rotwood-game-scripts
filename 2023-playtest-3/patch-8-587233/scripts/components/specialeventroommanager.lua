local Image = require("widgets/image")
local MinigamePlayerScore = require("widgets/ftf/minigameplayerscore")
local Panel = require("widgets/panel")
local Power = require "defs.powers"
local SpecialEventRoom = require("defs.specialeventrooms")
local Text = require("widgets/text")
local Widget = require("widgets/widget")
local audioid = require "defs.sound.audioid"
local fmodtable = require "defs.sound.fmodtable"
local kassert = require "util.kassert"
local krandom = require "util.krandom"
local lume = require "util.lume"


--[[ TODO @jambell here are the param values for the music states
intro - 0
countdown (silence) - 1
minigame music - 2
bronze - 3
silver - 4
gold - 5
lose - 6 ]]

local SpecialEventRoomManager = Class(function(self, inst)
	self.inst = inst

	self.spawners = {}

	self.event_triggers = {}
	self.update_events = {}

	self.selectedevent = nil

	self.initialize_fn = nil
	self.start_fn = nil
	self.scorewrapup_fn = nil
	self.finish_fn = nil

	self.event_active = false
	self.timer_active = false

	self.active_players = {}
	self.mem = {}

	self.rewardtier_achieved = nil

	self.scoreHUDS = {}

	self.temporarylisteners = {}

	-- RNG is not initialized here because this manager is instatiated at world load time so hosts
	-- will create this when populating props, but clients will create this when receiving the
	-- entity list from hosts.
end)

function SpecialEventRoomManager:GetRNG()
	assert(self.rng)
	return self.rng
end

-- Trigger a specialevent def callback, if defined.
function SpecialEventRoomManager:Trigger(cb_name, ...)
	local fn = self.selectedevent[cb_name]
	if fn then
		fn(self.inst, ...)
	end
end

-------------------- HUD FUNCTIONS --------------------
-- Initialize Event: on load of an 'event' roomtype in the dungeon, what should we do? Spawn NPCs, set up NPC conversation, spawn props etc
function SpecialEventRoomManager:InitializeEvent()
	local seed = TheDungeon:GetDungeonMap():GetRNG():Integer(2^32 - 1)
	self.rng = krandom.CreateGenerator(seed)
	TheLog.ch.SpecialEventRoomManager:printf("Special Event Room Manager Random Seed: %d", seed)

	if self.initialize_fn then
		self.initialize_fn(self.inst)
	end
end

-- Start Countdown: if this is a minigame, do a 3! 2! 1! countdown
function SpecialEventRoomManager:StartCountdown(startingplayer)
	self:TeleportPlayersToPlaySpace()
	-- for i,player in ipairs(AllPlayers) do
	-- 	player:PushEvent("inputs_disabled")
	-- end

	self.inst:DoTaskInTime(0, function()
		local suffix = nil
		if self.selectedevent.score_type == SpecialEventRoom.ScoreType.TIMELEFT then
			suffix = " sec left"
		elseif self.selectedevent.score_type == SpecialEventRoom.ScoreType.SCORELEFT then
			suffix = " ♥ left"
		else
			suffix = ""
		end

		local threshold_bronze = self.selectedevent.score_thresholds[SpecialEventRoom.RewardLevel.BRONZE]..suffix
		local threshold_silver = self.selectedevent.score_thresholds[SpecialEventRoom.RewardLevel.SILVER]..suffix
		local threshold_gold = self.selectedevent.score_thresholds[SpecialEventRoom.RewardLevel.GOLD]..suffix

		TheDungeon.HUD:MakePopText({ target = self.inst, button = "Gold: "..threshold_gold.."\nSilver: "..threshold_silver.."\nBronze: "..threshold_bronze, color = UICOLORS.GREEN, size = 130, fade_time = 6 })
		TheAudio:SetPersistentSoundParameter(audioid.persistent.room_music, "Music_Minigame_Phase", 1) --countdown silence
	end)

	self.inst:DoTaskInTime(6, function()
		TheDungeon.HUD:MakePopText({ target = self.inst, button = "3!", color = UICOLORS.ACTION, size = 256, fade_time = 1 })
		self.inst.SoundEmitter:PlaySoundWithParams(fmodtable.Event.Minigame_Countdown, { count = 1 }, nil, 1)
		self.inst:DoTaskInTime(1, function()
			TheDungeon.HUD:MakePopText({ target = self.inst, button = "2!", color = UICOLORS.ACTION, size = 256, fade_time = 1 })
			self.inst.SoundEmitter:PlaySoundWithParams(fmodtable.Event.Minigame_Countdown, { count = 2 }, nil, 1)
		end)
		self.inst:DoTaskInTime(2, function()
			TheDungeon.HUD:MakePopText({ target = self.inst, button = "1!", color = UICOLORS.ACTION, size = 256+25, fade_time = 1 })
			self.inst.SoundEmitter:PlaySoundWithParams(fmodtable.Event.Minigame_Countdown, { count = 3 }, nil, 1)
		end)

		self.inst:DoTaskInTime(3, function()
			TheDungeon.HUD:MakePopText({ target = self.inst, button = "GO!", color = UICOLORS.GREEN, size = 256+50, fade_time = 1 })
			self.inst.SoundEmitter:PlaySoundWithParams(fmodtable.Event.Minigame_Countdown, { count = 4 }, nil, 1)
			-- for i,player in ipairs(AllPlayers) do
			-- 	player:PushEvent("inputs_enabled")
			-- end
			self:StartEvent(startingplayer)
			TheAudio:SetPersistentSoundParameter(audioid.persistent.room_music, "Music_Minigame_Phase", 2) --minigame music
		end)
	end)
end

-- Start Event: when the players have talked to the NPC and have opted in, this is the execution of the event itself.
function SpecialEventRoomManager:StartEvent(player)
	self.event_active = true
	TheWorld:PushEvent("specialeventroom_activate", self.selectedevent.name)
	if self.start_fn then
		self.start_fn(self.inst, player)
	end
	if self.update_events ~= nil and #self.update_events > 0 then
		self.inst:StartUpdatingComponent(self)
	end

	if self.selectedevent.category == SpecialEventRoom.Types.MINIGAME then
		local newcollision={
	        { 9.2956867218018, -7.0219993591309 },
	        { -9.137393951416, -7.0224418640137 },
	        { 9.303295135498, 8.6779899597168 },
	        { 9.2956867218018, -7.0219993591309 },
	        { -9.137393951416, -7.0224418640137 },
	        { -8.9752588272095, 8.8696441650391 },
	        { -8.9752588272095, 8.8696441650391 },
	        { 9.303295135498, 8.6779899597168 } 
		}
		TheWorld.Map:SetCollisionEdges(newcollision, false)
	end
	TheDungeon:GetDungeonMap():RecordActionInCurrentRoom("specialevent")
end

-- Score Wrapup: display the final scores and display who won.
function SpecialEventRoomManager:ScoreWrapUp()
	if self.selectedevent.score_type ~= nil then
		self:EvaluatePerformance()
	end

	if self.scorewrapup_fn then
		self.scorewrapup_fn(self.inst)
	end

	self:DoResultsSequence()

	self.inst:StopUpdatingComponent(self)
end

function SpecialEventRoomManager:EvaluatePerformance()
	--JAMBELL(todo): support multiplayer
	local type = self.selectedevent.score_type
	local thresholds = self.selectedevent.score_thresholds

	local score
	if type == SpecialEventRoom.ScoreType.SCORELEFT or type == SpecialEventRoom.ScoreType.HIGHSCORE then
		score = self:GetScore(ThePlayer) 
	elseif type == SpecialEventRoom.ScoreType.TIMELEFT then
		score = self.inst.completed_timeleft
	end

	local result
	for i,tier in ipairs(SpecialEventRoom.RewardLevelIdx) do
		if score >= thresholds[tier] then
			result = tier
		end
	end

	if result == nil then
		result = "LOSE"
	end
	self.rewardtier_achieved = result
end

function SpecialEventRoomManager:DoResultsSequence()
	--TODO(jambell): support multiplayer
	local type = self.selectedevent.score_type
	local result = self.rewardtier_achieved
	local secondsbetween = 3

	TheDungeon.HUD:MakePopText({ target = self.inst, button = "FIN!", color = UICOLORS.ACTION, size = 256, fade_time = secondsbetween })
	self.inst.SoundEmitter:PlaySound(fmodtable.Event.Minigame_Finish)

	local score
	if type == SpecialEventRoom.ScoreType.TIMELEFT then
		score = self.inst.completed_timeleft.."sec left"
	elseif type == SpecialEventRoom.ScoreType.SCORELEFT then
		score = self:GetScore(ThePlayer).."HP left"
	elseif type == SpecialEventRoom.ScoreType.HIGHSCORE then
		score = self:GetScore(ThePlayer)
	end

	self.inst:DoTaskInTime(1 * secondsbetween, function()
		TheDungeon.HUD:MakePopText({ target = self.inst, button = score, color = UICOLORS.GREEN, size = 128, fade_time = secondsbetween })
	end)

	self.inst:DoTaskInTime(2 * secondsbetween, function()
		TheDungeon.HUD:MakePopText({ target = self.inst, button = result, color = UICOLORS.GREEN, size = 256, fade_time = 8 })
		-- Win / lose music
		-- print(result)
		-- print(SpecialEventRoom.RewardLevelIdx.BRONZE)
		if result == "BRONZE" then
			TheAudio:SetPersistentSoundParameter(audioid.persistent.room_music, "Music_Minigame_Phase", 3) -- win bronze	
		elseif result == "SILVER" then
			TheAudio:SetPersistentSoundParameter(audioid.persistent.room_music, "Music_Minigame_Phase", 4) -- win silver
		elseif result == "GOLD" then
			TheAudio:SetPersistentSoundParameter(audioid.persistent.room_music, "Music_Minigame_Phase", 5) -- win gold
		else
			TheAudio:SetPersistentSoundParameter(audioid.persistent.room_music, "Music_Minigame_Phase", 6) -- lose
		end
	end)

	self.inst:DoTaskInTime(3 * secondsbetween, function()
		self:TeleportPlayersFromPlaySpace()
		self:FinishEvent()
	end)
end

-- Finish Event: either when the timer is done or the event conditions have been completed
function SpecialEventRoomManager:FinishEvent(player)
	if self.event_active then
		TheWorld:PushEvent("specialeventroom_complete")

		if self.selectedevent.category == SpecialEventRoom.Types.MINIGAME then
			TheWorld:_SetWorldCollision(2)
		end
		if self.finish_fn then
			self.finish_fn(self.inst, player)
		end
		self.update_events = nil
		self.event_active = false
		self:RemoveTemporaryEventListenersFromPlayers()
	end
end

-------------------- INITIALIZATION --------------------
function SpecialEventRoomManager:OnSpawn()
	TheLog.ch.Mystery:printf("Spawning mystery")
	local forced_mystery = TheSaveSystem.cheats:GetValue("forced_mystery")
	local eventname
	if forced_mystery then
		TheLog.ch.Mystery:printf("Spawning mystery for debug: '%s'", forced_mystery)
		eventname = forced_mystery
	elseif TheDungeon:GetDungeonMap():IsCurrentRoomType("ranger") then
		eventname = TheSaveSystem.dungeon:GetValue("selected_ranger")
	elseif TheDungeon:GetDungeonMap():IsCurrentRoomType("wanderer") then
		eventname = TheSaveSystem.dungeon:GetValue("selected_wanderer")
	end

	assert(eventname, "Trying to load a SpecialEventRoom without an event")

	local event = SpecialEventRoom.Events[eventname]

	kassert.assert_fmt(event, "Trying to load an invalid SpecialEventRoom: %s", eventname)

	if event ~= nil then
		self:LoadEvent(event)
		self:InitializeEvent()
	end
end

function SpecialEventRoomManager:LoadEvent(event)
	if event.on_init_fn then
		self.initialize_fn = event.on_init_fn
	end

	self:SetUpEventTriggers(event)
	self.selectedevent = event

	if event.on_start_fn then
		self.start_fn = event.on_start_fn
	end

	if event.on_update_fn then
		self:AddUpdateEvent(event)
	end

	if event.on_scorewrapup_fn then
		self.scorewrapup_fn = event.on_scorewrapup_fn
	end

	if event.on_finish_fn then
		self.finish_fn = event.on_finish_fn
	end
end

function SpecialEventRoomManager:SetUpEventTriggers(event)
	if next(event.event_triggers) then
		if self.event_triggers[event.name] ~= nil then
			assert(nil, "Tried to set up event triggers for a room that already has them!")
		end
		self.event_triggers[event.name] = {}
		local triggers = self.event_triggers[event.name]
		for event, fn in pairs(event.event_triggers) do
			local listener_fn = function(inst, ...) fn(inst, event, ...) end
			triggers[event] = listener_fn
			self.inst:ListenForEvent(event, listener_fn)
		end
	end
end

function SpecialEventRoomManager:RemoveEventTriggers(event)
	local event_def = event:GetDef()
	if next(event_def.event_triggers) then
		local triggers = self.event_triggers[event_def.name]
		if triggers then
			for event, fn in pairs(triggers) do
				self.inst:RemoveEventCallback(event, fn)
			end
		end
		self.event_triggers[event_def.name] = nil
	end
end

-------------------- TIMER --------------------

function SpecialEventRoomManager:StartTimer(seconds) -- get the name from selectedevent
	self.inst:AddComponent("timer")
	self.inst.components.timer:StartTimer(self.selectedevent.name, seconds, true)

	self.inst.maxtime = seconds

	self.timer_active = true

	-- UI Timer
	local timerhud = TheDungeon.HUD:AddChild(Widget())
	:SetAnchors("center", "bottom")
	timerhud.text = timerhud:AddChild(Text(FONTFACE.DEFAULT, 30, "", UICOLORS.LIGHT_TEXT))
	:SetText(lume.round(self.inst.components.timer:GetTimeRemaining(self.selectedevent.name)))
	:SetFontSize(128)
	:SetPosition(0, 240)
	self.inst.timerhud = timerhud

	self.inst:ListenForEvent("timerdone", function(inst, data)
		if data.name == self.selectedevent.name then
			self.inst.completed_timeleft = 0
			self:ScoreWrapUp()
			self.inst.timerhud:Remove()
			self.inst.timerhud = nil
		end
	end)

	self.inst:StartUpdatingComponent(self)
end

function SpecialEventRoomManager:GetTimerSecondsRemaining()
	return self.inst.components.timer:GetTimeRemaining(self.selectedevent.name)
end

function SpecialEventRoomManager:GetTimerSecondsPassed()
	return self.inst.maxtime - self.inst.components.timer:GetTimeRemaining(self.selectedevent.name)
end

function SpecialEventRoomManager:GetTimerTicksRemaining()
	return self.inst.components.timer:GetTicksRemaining(self.selectedevent.name)
end

function SpecialEventRoomManager:GetTimerTicksPassed()
	return (self.inst.maxtime * 60) - self.inst.components.timer:GetTicksRemaining(self.selectedevent.name)
end

function SpecialEventRoomManager:GetTimerAnimFramesRemaining()
	return self.inst.components.timer:GetAnimFrames(self.selectedevent.name)
end

function SpecialEventRoomManager:GetTimerAnimFramesPassed()
	return (self.inst.maxtime * 30) - self.inst.components.timer:GetAnimFramesRemaining(self.selectedevent.name)
end


function SpecialEventRoomManager:TogglePauseTimer(toggle)
	if toggle then
		self.inst.components.timer:PauseTimer(self.selectedevent.name)
		self.timer_active = false
	else
		self.inst.components.timer:ResumeTimer(self.selectedevent.name)
		self.timer_active = true
	end
end

function SpecialEventRoomManager:TimerIsRunning()
	return self.inst.components.timer:HasTimer(self.selectedevent.name)
end

function SpecialEventRoomManager:StopTimer()
	self.inst.components.timer:StopTimer(self.selectedevent.name)
	if self.inst.timerhud ~= nil then
		self.inst.timerhud:Remove()
		self.inst.timerhud = nil
	end
end

function SpecialEventRoomManager:AddUpdateEvent(event)
	self.update_events[event] = event.on_update_fn
end

-------------------- HELPER FUNCTIONS --------------------
function SpecialEventRoomManager:AddPlayerInvulnerability()
	-- TODO: replace AllPlayers with a list of involved players
	-- TODO: set up an eventlistener to automatically remove player invulnerability at FinishEvent()
	for i, v in ipairs(AllPlayers) do
		v.components.combat:SetDamageReceivedMult(self.selectedevent.name, 0)
	end
end

function SpecialEventRoomManager:RemovePlayerInvulnerability()
	-- TODO: replace AllPlayers with a list of involved players
	for i, v in ipairs(AllPlayers) do
		v.components.combat:RemoveAllDamageMult(self.selectedevent.name)
	end
end

function SpecialEventRoomManager:AddTemporaryEventListenerToPlayers(event, fn)
	for i, v in ipairs(AllPlayers) do
		v:ListenForEvent(event, fn)
	end

	table.insert(self.temporarylisteners, { event = event, fn = fn })
end

function SpecialEventRoomManager:RemoveTemporaryEventListenersFromPlayers()
	for i,data in ipairs(self.temporarylisteners) do
		for _, player in ipairs(AllPlayers) do
			player:RemoveEventCallback(data.event, data.fn)
		end
	end
end

function SpecialEventRoomManager:TeleportPlayersToPlaySpace()
	local playerstopositions =
	{
		-- One Player
		{
			{ 0, 0 },
		},
		-- Two Players
		{
			{-4, 0},
			{ 4, 0},
		},
		-- Three Players
		{
			{-4, 0},
			{ 0, 0},
			{ 4, 0},
		},
		-- Four Players
		{
			{-6,  0},
			{ -3, 0},
			{ 3,  0},
			{ 6,  0},
		}
	}

	self.inst.originalplayerxz = {}
	local positions = playerstopositions[#AllPlayers]
	for i,player in ipairs(AllPlayers) do
		local x,z = player.Transform:GetWorldXZ()
		self.inst.originalplayerxz[player] = {}
		self.inst.originalplayerxz[player].x = x
		self.inst.originalplayerxz[player].z = z
		player.Transform:SetPosition(positions[i][1], 0, positions[i][2])
		-- TheDungeon.HUD:MakePopText({ target = player, button = "! TEMPORARY TELEPORT !", color = UICOLORS.KONJUR, size = 45, fade_time = 1.5 })
	end
end

function SpecialEventRoomManager:TeleportPlayersFromPlaySpace()
	assert(self.inst.originalplayerxz ~= nil, "[SpecialEventRoomManager] Cannot TeleportPlayersFromPlaySpace if we didn't first TeleportPlayersToPlaySpace")
	for i,player in ipairs(AllPlayers) do
		local pos = self.inst.originalplayerxz[player]
		player.Transform:SetPosition(pos.x, 0, pos.z)
		-- TheDungeon.HUD:MakePopText({ target = player, button = "! TEMPORARY TELEPORT !", color = UICOLORS.KONJUR, size = 45, fade_time = 1.5 })
	end
end

function SpecialEventRoomManager:ScaleEnemyHealth(health)
	-- First, scale by Number of Players
	health = (health * #AllPlayers)

	-- Then, add extra health for any of the powers any of the players have.
	local extrahealthperrarity = 
	{
		[Power.Rarity.COMMON] = 150,
		[Power.Rarity.EPIC] = 300,
		[Power.Rarity.LEGENDARY] = 500,
	}

	local extrahealth = 0
	for _, player in ipairs(AllPlayers) do
		local powermanager = player.components.powermanager
		local damagepowers = powermanager:GetPowersOfCategory(Power.Categories.DAMAGE)
		for _,pow in pairs(damagepowers) do
			extrahealth = extrahealth + extrahealthperrarity[pow.persistdata.rarity]
		end
	end
	health = health + extrahealth

	return health
end

-------------------- HUD FUNCTIONS --------------------
function SpecialEventRoomManager:DisplayBottomHUD()
	local bottomhud = TheDungeon.HUD:AddChild(Widget())
	:SetAnchors("center", "bottom")
	bottomhud.text = bottomhud:AddChild(Text(FONTFACE.DEFAULT, 30, "", UICOLORS.LIGHT_TEXT))
	:SetText("ConfigureMe")
	:SetFontSize(128)
	:SetPosition(0, 240*4)
	self.inst.bottomhud = bottomhud
end

function SpecialEventRoomManager:RemoveBottomHUD()
	self.inst.bottomhud:Remove()
end

function SpecialEventRoomManager:UpdateBottomHUD(text)
	assert(self.inst.bottomhud ~= nil, "[SpecialEventRoomManager] Cannot UpdateBottomHUD before it exists")
	self.inst.bottomhud.text:SetText(text)
end
-------------------- COMMON MINIGAME FEATURES --------------------
function SpecialEventRoomManager:IncrementScoreOnTakeDamage()
	local onTakeDamage = function(target)
		self:ChangeScore(target, 1)
	end
	self:AddTemporaryEventListenerToPlayers("take_damage", onTakeDamage)
end
function SpecialEventRoomManager:DecrementScoreOnTakeDamage(value)
	local onTakeDamage = function(target)
		print(target)
		self:ChangeScore(target, value and -value or -1)
	end
	self:AddTemporaryEventListenerToPlayers("take_damage", onTakeDamage)
end

function SpecialEventRoomManager:IncrementScoreOnKill()
	local onKill = function(target)
		self:ChangeScore(target, 1)
	end
	self:AddTemporaryEventListenerToPlayers("kill", onKill)
end

-------------------- SCORES --------------------
function SpecialEventRoomManager:InitializeScores(startingscore)
	self.inst.score = {}
	for i, v in ipairs(AllPlayers) do
		self.inst.score[v] = startingscore or 0
	end

	-- Create container for all minigame UI
	self.minigameHud = TheDungeon.HUD:AddChild(Widget())
		:SetName("Minigame HUD")
		:SetAnchors("center", "center")

	-- Add scoreboard widgets
	self.scoreWidget = self.minigameHud:AddChild(Widget())
	self.scoreBackground = self.scoreWidget:AddChild(Panel("images/ui_ftf_minigames/ui_minigame_bg.tex"))
		:SetName("Score background")
		:SetNineSliceCoords(170, 390, 200, 395) -- minx, miny, maxx, maxy 
		:SetNineSliceBorderScale(0.5)
		:SetSize(180, 200) -- change X size only
	self.scorePlayerContainer = self.scoreWidget:AddChild(Widget())


end

function SpecialEventRoomManager:DisplayScores()
	--TODO: arrange these scores better, visually
	for i,v in ipairs(AllPlayers) do
		-- local hud = TheDungeon.HUD:AddChild(Widget())
		-- :SetAnchors("center", "left")

		-- hud.text = hud:AddChild(Text(FONTFACE.DEFAULT, 30, "", UICOLORS.LIGHT_TEXT))
		-- :SetText("P"..i..":"..self.inst.score[v])
		-- :SetFontSize(128)
		-- :SetPosition(-600 + (240*(i)), 360)
		-- self.inst.hud = hud
		-- table.insert(self.scoreHUDS, hud)
	end


	-- Defining the vertical position, before adding any children elements
	self.scorePlayerContainer:LayoutBounds(nil, "top", self.scoreBackground)
		:SetName("AllPlayersWrapper")
		:Offset(0,-45)

	-- temporary variable
	local previousPlayer = nil

	-- Add a player score display per player
	for itemPos, player in ipairs(AllPlayers) do -- Creates the "itemPos" and "player" variables based on the AllPlayers table, and loops.


		local total_items_in_array = #AllPlayers
		local is_single_player = total_items_in_array == 1
		
		-- Add a widget for each player
		local playerWidget = self.scorePlayerContainer:AddChild(MinigamePlayerScore(itemPos,is_single_player,self.selectedevent.score_type))	

		if previousPlayer == nil then 
			playerWidget
				:LayoutBounds("center_left", "top")
				:Offset(0, -25) -- margin topui_minigame_divider
		else			
			playerWidget
				:LayoutBounds("after", "top", previousPlayer)
				:Offset(10, 0) -- spacing between Player Scores
		end

		previousPlayer = playerWidget; -- Saves the previous player score in a variable

		-- Adds a divider image between players on MP 
		if is_single_player ~= true and total_items_in_array ~= itemPos then 
			self.scorePlayerContainer:AddChild(Image("images/ui_ftf_minigames/ui_minigame_divider.tex"))
			:SetSize(3,130)
			:LayoutBounds("after", "top", playerWidget)
			:Offset(4,25) -- (h,v)
		end

		table.insert(self.scoreHUDS, playerWidget)
	end

	-- Position player container within background (adjusting hor)
	self.scorePlayerContainer:LayoutBounds("center", nil, self.scoreBackground);
		
	-- Position score at the top of the screen
	self.scoreWidget:LayoutBounds("center", "top", 0, RES_Y/2)
		:SetName("MainScoreContainer")

end

function SpecialEventRoomManager:ChangeScore(player, score)
	self.inst.score[player] = math.max(0, self.inst.score[player] + score)
	self:UpdateScoreHUD()
	self:Trigger("on_scorechanged_fn", self.inst.score[player])
end

function SpecialEventRoomManager:SetScore(player, score)
	self.inst.score[player] = score
	self:UpdateScoreHUD()
	self:Trigger("on_scorechanged_fn", self.inst.score[player])
end

function SpecialEventRoomManager:UpdateScoreHUD()
	for i, player in ipairs(AllPlayers) do
		-- self.scoreHUDS[i].text:SetText(("P%d: %s"):format(i, self:GetScore(player)))
		self.scoreHUDS[i]:UpdateScore(self:GetScore(player))
	end
end

function SpecialEventRoomManager:GetScore(player)
	return self.inst.score[player]
end

function SpecialEventRoomManager:OnUpdate(dt)
	local stop_updating = true
	if self.update_events ~= nil then
		for event, fn in pairs(self.update_events) do
			fn(self.inst, event, dt)
		end
		stop_updating = false
	end

	if self.timer_active then
		local remaining = self.inst.components.timer:GetTimeRemaining(self.selectedevent.name)
		if remaining and remaining >= 0 then
			self.inst.timerhud.text:SetText(lume.round(self.inst.components.timer:GetTimeRemaining(self.selectedevent.name)))
			stop_updating = false
		end
	end

	if stop_updating then
		self.inst:StopUpdatingComponent(self)
	end
end
return SpecialEventRoomManager
