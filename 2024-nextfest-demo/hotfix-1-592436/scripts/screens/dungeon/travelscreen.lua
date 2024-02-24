local ActionButton = require "widgets.actionbutton"
local DungeonHistoryMap = require "widgets.ftf.dungeonhistorymap"
local Screen = require "widgets.screen"
local easing = require "util.easing"
local kassert = require "util.kassert"
local lume = require "util.lume"
local templates = require "widgets.ftf.templates"
local fmodtable = require "defs.sound.fmodtable"


local TravelScreen = Class(Screen, function(self, cardinal)
	Screen._ctor(self, "TravelScreen")
	kassert.typeof("string", cardinal)
	self:SetAudioCategory(Screen.AudioCategory.s.None)

	self.is_overlay = true
	self:SetNonInteractive()
	self.flush_inputs = false

	self.cardinal = cardinal
	self.time_before_travel = 2.5
	self.time_before_locked_in = self.time_before_travel * 0.5

	assert(not TheWorld:HasTag("town"))
	local worldmap = TheDungeon:GetDungeonMap()

	local dest_room = worldmap:GetDestinationForCardinalDirection(self.cardinal)
	self.travel_room_id = dest_room.index

	self.bg = self:AddChild(templates.BackgroundTint())

	self.map = self:AddChild(DungeonHistoryMap(worldmap.nav))
		:DrawFullMap()

	self.skip_button = self:AddChild(ActionButton())
		:SetDebug() -- Lots of changes to travel coming, so might not keep skip.
		:SetSize(BUTTON_W * 0.5, BUTTON_H)
		:SetText(STRINGS.UI.PAUSEMENU.SKIP_TRAVEL_BUTTON)
		:SetOnClick(function()
			if self.reached_point_of_no_return then
				self.skip_button:Hide()
				self.map:FastForwardAnimations()
			end
		end)
		:LayoutBounds("right", "bottom", self)
		:Offset(-30, 20)
		:Hide()

	self.default_focus = self.skip_button

	-- Nothing is interactive, so don't show the debug buttons.
	self.map.buttons:Hide()
end)

function TravelScreen.DebugConstructScreen(cls, player)
	local cardinal = lume.first(TheDungeon:GetDungeonMap():GetCurrentWorldEntrances())
	assert(cardinal, "Can only test TravelScreen from within a dungeon room.")
	local screen = TravelScreen(cardinal)
	screen.has_traveled = true -- don't actually travel
	screen.skip_button:SetText("Animate In")
		:SetOnClick(function()
			screen:AnimateIn()
		end)
	return screen
end

function TravelScreen:_HasPlayerSeenScreen()
	return self.inst:GetTimeAlive() > 0.5
end

function TravelScreen:TryCancelTravel(cb)
	if not self.reached_point_of_no_return then
		self.reached_point_of_no_return = true -- prevent re-entry
		self:StopUpdater(self.updater)
		self:AnimateOut(cb)
	end
end


function TravelScreen:OnBecomeActive()
	TravelScreen._base.OnBecomeActive(self)

	TheWorld.components.ambientaudio:SetTravelling(true)

	local worldmap = TheDungeon:GetDungeonMap()
	if worldmap:ShouldSkipMapTransitionFromCurrentRoom() then
		self:_TravelCardinalDirection()
		self:Hide()
	elseif not self.has_animated_in then
		self:AnimateIn()
		self.has_animated_in = true
	end
end

function TravelScreen:OnBecomeInactive()
	TravelScreen._base.OnBecomeInactive(self)
	TheWorld.components.ambientaudio:SetTravelling(false)
end

function TravelScreen:AnimateIn()

	-- Hide elements
	self.bg:SetMultColorAlpha(0)
	--~ self.map:SetMultColorAlpha(0) -- switching from alpha fade to unroll


	-- Get default positions
	local bgX, bgY = self.bg:GetPosition()
	local mapX, mapY = self.map:GetPosition()

	local map_offset = -300
	self.map:SetPosition(mapX + map_offset, mapY + map_offset)

	local unroller = self.map:CreateAnimateInUpdater()

	-- Start animating
	local animateSequence = Updater.Parallel({
			-- Animate map background
			Updater.Series({
					-- Updater.Wait(0.15),
					Updater.Parallel({
							Updater.Ease(function(v) self.bg:SetScale(v) end, 1.1, 1, 0.3, easing.outQuad),
							Updater.Ease(function(v) self.bg:SetPosition(bgX, v) end, bgY + 10, bgY, 0.3, easing.outQuad),
						}),
				}),

			-- And the map
			Updater.Series({
					-- Place the map.
					Updater.Ease(function(v) self.map:SetPosition(mapX + v, mapY + v) end, map_offset, 0, 0.4, easing.outQuint),
					-- Unroll the map.
					unroller,
					--~ Updater.Wait(0.1),
					--~ Updater.Parallel({
					--~ 		Updater.Ease(function(v) self.map:SetMultColorAlpha(v) end, 0, 1, 0.1, easing.outQuad),
					--~ 		Updater.Ease(function(v) self.map:SetPosition(mapX, v) end, mapY + 10, mapY, 0.4, easing.outQuad),
					--~ 	}),
				}),

			Updater.Ease(function(v) self.bg:SetMultColorAlpha(v) end, 0, 1, self.time_before_locked_in, easing.outQuad),

			Updater.Series({
					Updater.Wait(self.time_before_locked_in),
					Updater.Do(function(v)
						self.reached_point_of_no_return = true
						-- Start consuming input to prevent sounds from players.
						self.sinks_input = true
						if DEV_MODE then
							self.skip_button:Show()
						end
						self.time_remaining = self.time_before_travel - self.time_before_locked_in
					end),
					Updater.While(function()
						self.time_remaining = self.time_remaining - GetTickTime() * self.map:GetAnimMultiplier()
						return self.time_remaining > 0
					end)
				}),

			Updater.Series({
					-- We assume that travel updater will roughly follow our
					-- time_before_travel timing.
					self.map:CreateTravelUpdater(self.cardinal, self.travel_room_id, self.time_before_travel, self.time_before_locked_in),
					Updater.Do(function(v)
						--
						--
						-- Here we trigger the level transition!
						--
						--
						self:_TravelCardinalDirection()
					end),
				}),
		})

	self.updater = self:RunUpdater(animateSequence)
end

function TravelScreen:AnimateOut(cb)
	local out_time = 0.2
	local animateSequence = Updater.Parallel({
			Updater.Series({
					Updater.Ease(function(v) self.bg:SetMultColorAlpha(v) end, self.bg.mult_a, 0, out_time, easing.inQuad),
					Updater.Do(function(v)
						cb()
						TheFrontEnd:PopScreen(self)
					end),
				}),

			self.map:CreateTravelUpdater_Reverse(out_time),
		})

	self.updater = self:RunUpdater(animateSequence)
end

function TravelScreen:_TravelCardinalDirection()
	if self.has_traveled then
		return
	end
	self.has_traveled = true

	self.skip_button:Hide()

	-- mystery monster stinger
	--local room = TheDungeon:GetDungeonMap():GetDestinationForCardinalDirection(self.cardinal)
	--assert(room, "How did we pick an invalid direction?")
	--if room.is_mystery and room.roomtype == "monster" then
		--TheAudio:SetGlobalParameter(fmodtable.GlobalParameter.isMysteryMonster, 1)
	--end

	-- For testing, hide self instead of actually travelling.
	--~ self:Hide()

	-- clients will travel via OnNetworkClientLoadRoom
	if TheNet:IsHost() then
		TheLog.ch.TravelScreen:printf("Host traveling %s ...", self.cardinal)
		TheDungeon:GetDungeonMap():TravelCardinalDirection(self.cardinal)
	else
		TheLog.ch.TravelScreen:printf("Client waiting for host to travel %s ...", self.cardinal)
	end
end

return TravelScreen
