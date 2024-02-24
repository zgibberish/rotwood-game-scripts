local DebugAnimHistory = require "dbui.debug_animhistory"
local DebugBrainHistory = require "dbui.debug_brainhistory"
local DebugCamera = require "dbui.debug_camera"
local DebugComponentHistory = require "dbui.debug_componenthistory"
local DebugInputHistory = require "dbui.debug_inputhistory"
local DebugSGHistory = require "dbui.debug_sghistory"
local Quickfind = require "dbui.debug_quickfind"
local SaveData = require "savedata.savedata"
local iterator = require "util.iterator"
local lume = require "util.lume"
local ui = require "dbui.imgui"


local MAX_HISTORY = 6*60 -- 6 seconds of history

local History = Class(function(self, inst)
	self.inst = inst

	self.db = {
		animhistory = DebugAnimHistory(MAX_HISTORY),
		inputhistory = DebugInputHistory(MAX_HISTORY),
		sghistory = DebugSGHistory(MAX_HISTORY),
		brainhistory = DebugBrainHistory(MAX_HISTORY),
		componenthistory = DebugComponentHistory(MAX_HISTORY),
	}
	-- Store keys so we don't need to sort every frame in RecordState.
	self.db_keys = lume(self.db)
		:keys()
		:sort()
		:result()

	self.savedata = SaveData("replay")
	self.enabled = not PLAYTEST_MODE and TheNet:IsGameTypeLocal()

	-- Reset history when we enter a new room since the history doesn't make
	-- much sense in the new environment. Also prevents history files from
	-- getting enormous since they're bounded by time in a single room.
	self._onroom_created = function(source) self:ResetHistory() end
	self.inst:ListenForEvent("room_created", self._onroom_created, TheGlobalInstance)
end)

-- Stop tracking new entities. We'll automatically start tracking again if we
-- capture another frame.
function History:_ShutdownTracker()
	for name,history in iterator.indexed_pairs(self.db, self.db_keys) do
		history:ShutdownTracker()
	end
end

function History:ResetHistory()
	for name,history in iterator.indexed_pairs(self.db, self.db_keys) do
		history:Reset()
	end
end

function History:GetAnimHistory()
	return self.db.animhistory
end

function History:GetInputHistory()
	return self.db.inputhistory
end

function History:GetSGHistory()
	return self.db.sghistory
end

function History:GetBrainHistory()
	return self.db.brainhistory
end

function History:GetComponentHistory()
	return self.db.componenthistory
end

function History:GetMinTick()
	return self.db.animhistory:GetMinTick()
end

function History:GetMaxTick()
	return self.db.animhistory:GetMaxTick()
end

function History:IsEnabled()
	return self.enabled
end

function History:ToggleHistoryRecording()
	self.enabled = not self.enabled
	if not self.enabled then
		self:_ShutdownTracker()
	end
end

function History:Save()
	--jcheng: this makes it so saving is MUCH faster
	local olddevmode = DEV_MODE
	DEV_MODE = false
	for name,history in iterator.indexed_pairs(self.db, self.db_keys) do
		history:Save(self.savedata)
	end
	self:SaveMetadata()
	self.savedata:Save()
	DEV_MODE = olddevmode
end

function History:SaveMetadata()
	self.savedata:SetValue("metadata",
		{
			world_prefab = TheWorld and TheWorld.prefab or nil,
			scenegen_prefab = TheSceneGen and TheSceneGen.prefab or nil,
			world_is_town = TheWorld and TheWorld:HasTag("town") or nil,
			room_id = TheDungeon and TheDungeon:GetDungeonMap():GetCurrentRoomId() or nil,
		}
	)
end

function History:Load()
	self.savedata:Load()
	for name,history in iterator.indexed_pairs(self.db, self.db_keys) do
		history:Load(self.savedata)
	end
end

function History:RecordState()
	TheSim:ProfilerPush("[History] RecordState")
	local current_tick = TheSim:GetTick()

	for name,history in iterator.indexed_pairs(self.db, self.db_keys) do
		TheSim:ProfilerPush(name)
		history:RecordState(current_tick)
		TheSim:ProfilerPop()
	end

	TheSim:ProfilerPop()
end

function History:ResumeState()
	for name,history in iterator.indexed_pairs(self.db, self.db_keys) do
		history:ResumeState()
	end
end

-- DebugMenu is a container for some debug features that aren't in a window.
--
-- See DebugNodes for inspector windows/panels.
local DebugMenu = Class(function(self, include_full_debug_menu)
	self.inst = CreateEntity("DebugMenu")
		:MakeSurviveRoomTravel()
	self.inst:AddTag("dbg_nohistory")

	if include_full_debug_menu then
		self.quickfind = Quickfind()
		self.debug_camera = DebugCamera()
	end
	-- Always include history so we can include it in feedback.
	self.history = History(self.inst)
end)

local time = 0


local DebugRenderer = Class(function(self)
	self.worldlinesbatch = {}
	self.persistworldlinehandle = 1
	self.persistworldlinesbatch = {}
end)

TheDebugRenderer = DebugRenderer()

function DebugRenderer:WorldLine(p1, p2, color, thickness, lifetime)
	dbassert(p1)
	dbassert(p2)
	color = color or {1,1,1,1}
	thickness = thickness or 1

	if not lifetime then
		table.insert(self.worldlinesbatch, {p1, p2, color, thickness})
	else
		self.persistworldlinesbatch[self.persistworldlinehandle] =
			{p1, p2, color, thickness, lifetime}
		self.persistworldlinehandle = self.persistworldlinehandle + 1
		-- TODO: victorc - return handle?
	end
end

function DebugRenderer:scalePoint(p, s)
	if type(s) == "table" then
		return {p[1] * s[1], p[2] * s[2], p[3] * s[3]}
	elseif type(s) == "number" then
		return {p[1] * s, p[2] * s, p[3] * s}
	else
		return p
	end
end

-- LHCS rotate about z-axis by rot radians
function DebugRenderer:rotatePoint(p, rot)
	local cosr = math.cos(rot)
	local sinr = math.sin(rot)
	return {p[1] * cosr + p[2] * sinr, p[2] * cosr - p[1] * sinr, p[3]}
end

function DebugRenderer:translatePoint(p, op)
	return {p[1] + op[1], p[2] + op[2], p[3] + op[3]}
end

function DebugRenderer:transformPoint(p, t, r, s)
	s = s or 1
	r = r or 0
	t = t or {0, 0, 0}
	return DebugRenderer:translatePoint(DebugRenderer:rotatePoint(DebugRenderer:scalePoint(p, s), r), t)
end

function DebugRenderer:ScreenEllipse(a, b, wpos, lpos, rot, color, thickness, segments)
	if not segments then
		local rr = math.sqrt(a*a + b*b)
		if rr <= 100 then
			segments = 20
		else
			segments = 20 + math.floor(2 * rr / 100)
		end
	end

	local screen_x, screen_y = TheSim:GetScreenSize()
	local tr = {wpos[1]+screen_x/2, -wpos[2]+screen_y/2, 0}
	local scale = {screen_x/RES_X, -screen_y/RES_Y, 1}
	rot = rot or 0
	local theta_inc = 2 * math.pi / segments
	local theta = 0

	local p0 = {lpos[1] + a, lpos[2], 0}
	local p0t = DebugRenderer:transformPoint(p0, tr, rot, scale)
	for i = 1, segments do
		local p1 = {lpos[1] + a * math.cos(theta), lpos[2] + b * math.sin(theta), 0}
		local p1t = DebugRenderer:transformPoint(p1, tr, rot, scale)
		ui:ScreenLine(p0t, p1t, color, thickness)
		p0 = p1
		p0t = p1t
		theta = theta + theta_inc
	end

	local pf = {lpos[1] + a, lpos[2], 0}
	local pft = DebugRenderer:transformPoint(pf, tr, rot, scale)
	ui:ScreenLine(p0t, pft, color, thickness)
end

function DebugRenderer:WorldEllipse(a, b, wpos, lpos, rot, color, thickness, segments)
	if not segments then
		local rr = math.sqrt(a*a + b*b)
		if rr <= 1 then
			segments = 20
		else
			segments = 20 + math.floor(2 * rr)
		end
	end

	rot = rot or 0
	local theta_inc = 2 * math.pi / segments
	local theta = 0

	local p0 = {lpos[1] + a, lpos[2], lpos[3]}
	local p0t = DebugRenderer:transformPoint(p0, wpos, rot)
	for i = 1, segments do
		local p1 = {lpos[1] + a * math.cos(theta), lpos[2] + b * math.sin(theta), lpos[3]}
		local p1t = DebugRenderer:transformPoint(p1, wpos, rot)
		TheDebugRenderer:WorldLine(p0t, p1t, color, thickness)
		p0 = p1
		p0t = p1t
		theta = theta + theta_inc
	end

	local pf = {lpos[1] + a, lpos[2], lpos[3]}
	local pft = DebugRenderer:transformPoint(pf, wpos, rot)
	TheDebugRenderer:WorldLine(p0t, pft, color, thickness)
end

-- Call if you draw debug while sim paused so your old debug lines will get
-- cleared. Even if sim is paused, we'll process lines as if it weren't.
function DebugRenderer:ForceTickCurrentFrame()
	self.force_tick_this_frame = true
end

function DebugRenderer:Render(dt)
	local x,y,w,h = TheSim:GetWindowInset()
	local scale = ui:GetDisplayScale()
	x = x / scale
	y = y / scale
	w = w / scale
	h = h / scale
	ui:PushDrawClipRect(imgui.Layer.Background, x,y,x+w,y+h)
	for k,v in pairs(self.worldlinesbatch) do
		ui:WorldLine(v[1], v[2], v[3], v[4])
	end
	ui:PopDrawClipRect(imgui.Layer.Background)

	if self.force_tick_this_frame or TheSim:IsPlaying() then
		-- Only clear if playing so lines stay visible while stepping frames.
		self.worldlinesbatch = {}
		self.force_tick_this_frame = false
	else
		-- Exclude sim paused time from lifetime.
		dt = 0
	end

	local expiredPersistLines = {}
	for k,v in pairs(self.persistworldlinesbatch) do
		ui:WorldLine(v[1], v[2], v[3], v[4] )
		v[5] = v[5] - dt
		if v[5] <= 0.0 then
			expiredPersistLines[k] = true
		end
	end

	for k,v in pairs(expiredPersistLines) do
		self.persistworldlinesbatch[k] = nil
	end
end

function DebugMenu:RenderBackground(dt)
	TheDebugRenderer:Render(dt)

	ui:SetNextWindowSize( 0, 0, ui.Cond.Always )
	ui:SetNextWindowBgAlpha(0)
	local flags = ui.WindowFlags.NoTitleBar | ui.WindowFlags.NoResize | ui.WindowFlags.NoMove
	ui:Begin("debugdrawlayer", false, flags)

	if TheDebugSettings.showActiveAABB then
		local debugent = GetDebugEntity()
		if debugent then
			local minx,miny,minz,maxx,maxy,maxz = debugent.entity:GetWorldAABB()
			-- bottom
			local t = (time * 3) % (2 * math.pi)
			local c = (math.sin(t) + 1)/2
			local color = {c,c,1}
			ui:WorldLine({minx,miny,minz}, {minx,miny,maxz}, color)
			ui:WorldLine({minx,miny,maxz}, {maxx,miny,maxz}, color)
			ui:WorldLine({maxx,miny,maxz}, {maxx,miny,minz}, color)
			ui:WorldLine({maxx,miny,minz}, {minx,miny,minz}, color)

			-- top
			ui:WorldLine({minx,maxy,minz}, {minx,maxy,maxz}, color)
			ui:WorldLine({minx,maxy,maxz}, {maxx,maxy,maxz}, color)
			ui:WorldLine({maxx,maxy,maxz}, {maxx,maxy,minz}, color)
			ui:WorldLine({maxx,maxy,minz}, {minx,maxy,minz}, color)

			-- sides
			ui:WorldLine({minx,miny,minz}, {minx,maxy,minz}, color)
			ui:WorldLine({minx,miny,maxz}, {minx,maxy,maxz}, color)
			ui:WorldLine({maxx,miny,maxz}, {maxx,maxy,maxz}, color)
			ui:WorldLine({maxx,miny,minz}, {maxx,maxy,minz}, color)
		end
	end
	ui:End()
end

function DebugMenu:Render(dt)
	time = time + dt

	self.frames = (self.frames or 0) + 1
	-- somehow the first...x(?) franes we can't do this. I'm lazy.
	if self.frames < 5 then
		return
	end

	self:RenderBackground(dt)

	self.quickfind:Render(ui)

	local DebugNodes = require "dbui.debug_nodes"
	local panel = TheFrontEnd:FindOpenDebugPanel(DebugNodes.Embellisher)

	if self.history:IsEnabled() and not TheSim:IsDebugPaused() and not panel then
		self.history:RecordState()
	end

	self.debug_camera:Update()
end

return DebugMenu
