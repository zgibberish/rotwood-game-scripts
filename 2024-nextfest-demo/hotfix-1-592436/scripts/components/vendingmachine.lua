local Consumable = require "defs.consumable"
local Currency = require "defs.currency"
local FollowPrompt = require "widgets.ftf.followprompt"
local Text = require "widgets.text"
local Templates = require "widgets.ftf.templates"
local Vec3 = require "math.modules.vec3"
local LootEvents = require "lootevents"
local soundutil = require "util.soundutil"
local fmodtable = require "defs.sound.fmodtable"
local Lume = require "util.lume"

-- Given an integer that is the expected maximum of some unsigned integer field, return the minimum number of bits
-- necessary to represent that number.
-- This function's main intent is to compute the bit count for fields over the net.
function RequiredBitCount(max)
	for i = 1, 64 do
		-- max is the maximum value we want to support.
		-- 2^i is the *number* of values we can represent, including 0.
		-- Thus the maximum representable value with i bits is 2^i - 1, so test with < rather than <=.
		if max < 2^i then
			return i
		end
	end
	return nil
end

local COST_MAXIMUM <const> = 10000
local SERIALIZED_DEPOSITED_BIT_COUNT <const> = RequiredBitCount(COST_MAXIMUM)

local DEPOSIT_RATE <const> = 1 -- Currency per tick.
local DEPOSIT_NETWORK_PERIOD_TICKS <const> = 5
local DEPOSIT_WIDGET_RATE =
{
	-- Max change per tick for the displayed number
	{ deltagreaterthan = 50, rate = 50 },
	{ deltagreaterthan = 20, rate = 5 },
	{ deltagreaterthan = 6, rate = 2 },
	{ deltagreaterthan = 0, rate = 1 },
}

local CURRENCY_FORMAT_STRINGS <const> = {
	[Currency.id.Run] = STRINGS.UI.VENDING_MACHINE.CURRENCY.RUN,
	[Currency.id.Meta] = STRINGS.UI.VENDING_MACHINE.CURRENCY.META,
	[Currency.id.Cosmetic] = STRINGS.UI.VENDING_MACHINE.CURRENCY.COSMETIC,
	[Currency.id.Health] = STRINGS.UI.VENDING_MACHINE.CURRENCY.HEALTH,
}

local INSUFFICIENT_FUNDS <const> = {
	[Currency.id.Run] = STRINGS.UI.VENDING_MACHINE.INSUFFICIENT_FUNDS.RUN,
	[Currency.id.Meta] = STRINGS.UI.VENDING_MACHINE.INSUFFICIENT_FUNDS.META,
	[Currency.id.Cosmetic] = STRINGS.UI.VENDING_MACHINE.INSUFFICIENT_FUNDS.COSMETIC,
	[Currency.id.Health] = STRINGS.UI.VENDING_MACHINE.INSUFFICIENT_FUNDS.HEALTH,
}

local function MakeTextWidget(text)
	return Text(FONTFACE.DEFAULT, FONTSIZE.DAMAGENUM_PLAYER, "", UICOLORS.INFO)
		:SetShadowColor(UICOLORS.BLACK)
		:SetShadowOffset(1, -1)
		:SetOutlineColor(UICOLORS.BLACK)
		:EnableShadow()
		:EnableOutline()
		:SetText(text)
end

-- Accepts a certain amount of currency and then emits a ware.
local VendingMachine = Class(function(self, inst, ware_data)
	self.inst = inst
	
	-- Array-like table of deposit amounts, keyed by player.Network:GetPlayerID()
	-- Takes local data in directly to prevent excessive refunds due to network latency.
	self.deposited = {} 
	self.display_total_deposited = 0
	
	-- A table of data from the host that contains the actual deposited numbers.
	-- Syncs with clients self.deposited if no local player is interacting with the machine.
	self.netsync_deposited = {}
	
	-- A table of refund data, taken from the host.
	self.refunds = {}

	-- Host-only table k:playerID, v:timeout task, is pulsed on when receiving player deposits
	-- and times out eventually or responds to explicit stop messages.
	self.is_interacting = {}

	-- Details about the specific product for sale by the machine.
	-- Info such as def id or equipment slot
	-- synced over the network
	self.product_details = {}


	-- deferred Deposits are used to reduce the number of networked deposit events 
	-- They are saved up for a number of frames, before being added as an actual network event
	self.deferredDeposits = {}

	if ware_data then
		self:SetWareData(ware_data)
	end

	self.crowdsourced_item_emitted = false

	self._onplayerdeactivated = function(_, player) self:OnPlayerDeactivated(player) end

	self.inst:ListenForEvent("playerdeactivated", self._onplayerdeactivated, TheWorld)
	inst:ListenForEvent("on_hud_created", function() self:InitializeUi() end, TheDungeon)
	
	self.on_perform_interact_fn = function(vending_machine) 
		Lume(vending_machine.components.interactable.focused_players):each(function(player) 
			self:UpdatePlayerStatus(player)
		end)
	end

	self.inst:StartUpdatingComponent(self)
end)

VendingMachine.DEFAULT_UI_Y_OFFSET = 3

function VendingMachine:InitializeUi()
	-- This function may be called multiple times. If self.root is valid, we are already initialized.
	if self.root then
		return
	end

	-- We add our root widget to the dungeon hud, so it needs to exist.
	if not TheDungeon.HUD then
		return
	end

	self.root = FollowPrompt()
		:SetName("VendingMachine")
	TheDungeon.HUD:AddWorldWidget(self.root)
	self.root
		:SetTarget(self.inst)
		:SetOffsetFromTarget(Vec3(0, VendingMachine.DEFAULT_UI_Y_OFFSET, 0))
end

function VendingMachine:Initialize(ware_name, power, power_type, ui_y_offset)
	if not self.root then
		self:InitializeUi()
	end
	
	-- should be a table of strings
	self.product_details = {power, power_type}

	if not self.ware_id and ware_name then
		local wares = require "defs/vendingmachine_wares"
		self.ware_id = ware_name
		self:SetWareData(wares[ware_name])
	end

	self.root:SetOffsetFromTarget(Vec3(0, ui_y_offset or VendingMachine.DEFAULT_UI_Y_OFFSET, 0))

	self.inst:PushEvent("initialized_ware", {
		ware_name = ware_name,
		power = power,
		power_type = power_type
	})
end

function VendingMachine:GetProductDetails()
	return self.product_details
end

function VendingMachine:SetWareData(ware_data)

	-- ware_data =
	--      name: the name to be printed on the price tag
	--      price: how much currency is needed to buy
	--      currency: what type of currency is needed to buy

	--      init_fn: a function to run when the vendingmachine is created, to set up data used later by the vendingmachine
	--      summary_fn: what widget should float above the vending machine to show what is inside
	--      details_fn: what widget should float above the vending machine to show more details about what is inside
	--      can_purchase_fn: optional function to ask if a player is permitted to purchase the ware
	--      purchased_fn: the function to run when the price is met

	local name = type(ware_data.name) == "function" 
		and ware_data.name(self.inst)
		or ware_data.name

	local cost = type(ware_data.cost) == "function"
		and ware_data.cost(self.inst)
		or ware_data.cost

	self.currency = ware_data.currency
	self.crowd_fundable = ware_data.crowd_fundable
	self.initialized_interactable = false
	self.cost = cost
	self.can_purchase_fn = ware_data.can_purchase_fn or function() return true end
	self.purchased_fn = ware_data.purchased_fn

	if self.inst.components.interactable then
		self:InitInteractable()
	end

	-- VendingMachine widget design
	-- details: hidden unless you are in interact range, includes name
	-- summary: widget that is always visible
	-- price_tag: currency and amount, always visible
	-- purchase_button: hidden unless you are in interact range AND you can interact i.e. can contribute funds

	self.price_tag_visibility_by_proximity = ware_data.price_tag_visibility_by_proximity
	local initial_price_tag_visible = not self.price_tag_visibility_by_proximity
	self.price_tag = self:AddWidget(MakeTextWidget(self:MakePriceText(self.cost)), initial_price_tag_visible)

	local details = ware_data.details_fn
		and ware_data.details_fn(self.inst)
		or MakeTextWidget(name)
	self.details = self:AddWidget(details, false)
	self.summary = self:AddWidget(ware_data.summary_fn and ware_data.summary_fn(self.inst), true)
	self:Layout()
end

VendingMachine.MakeTextWidget = MakeTextWidget

local function LayoutWidget(widget, prev)
	return (widget and widget:IsShown())
		and widget:LayoutBounds("center", "above", prev)
		or prev
end

-- Arrange the widgets appopriate to the current state of the VendingMachine.
function VendingMachine:Layout()
	local prev = self.price_tag
	prev = LayoutWidget(self.details, prev)
	prev = LayoutWidget(self.summary, prev)
end

function VendingMachine:MakePriceText(price)
	-- TODO @chrisp #heal - probably want a progress bar for health
	return string.format(CURRENCY_FORMAT_STRINGS[self.currency], price, self.cost)
end

-- Add a widget to our local root widget, hide it if necessary, and apply a world offset.
function VendingMachine:AddWidget(widget, visible)
	if not widget then
		return
	end
	self.root:AddChild(widget)
	if not visible then
		widget:Hide()
	end
	return widget
end

function VendingMachine:Shutdown()
	if self.root then
		self.root:Remove()
	end
end

function VendingMachine:OnRemoveFromEntity()
	self:Shutdown()
end

function VendingMachine:OnRemoveEntity()
	self:Shutdown()
end

function VendingMachine:OnNetSerialize()
	-- data on which players have added teffra
	self.inst.entity:SerializeUInt(Lume(self.deposited):values():count():result(), 3)

	for k, v in pairs(self.deposited) do
		self.inst.entity:SerializePlayerID(k)
		self.inst.entity:SerializeUInt(v or 0, SERIALIZED_DEPOSITED_BIT_COUNT)
	end

	self.inst.entity:SerializeUInt(Lume(self.refunds):values():count():result(), 3)
	for k, v in pairs(self.refunds) do
		self.inst.entity:SerializePlayerID(k)
		self.inst.entity:SerializeUInt(v or 0, SERIALIZED_DEPOSITED_BIT_COUNT)
	end

	-- details about the item such as specific item defs or equipment slots used
	self.inst.entity:SerializeUInt(#self.product_details, 2)
	for _, detail in ipairs(self.product_details) do
		self.inst.entity:SerializeString(detail)
	end

	-- which specific ware id is on offer (from vendingmachine_wares.lua)
	self.inst.entity:SerializeString(self.ware_id or "")

	self.inst.entity:SerializeBoolean(self.crowdsourced_item_emitted)
end

function VendingMachine:OnNetDeserialize()
	-- data on which players have added teffra
	local nrplayers = self.inst.entity:DeserializeUInt(3)
	if nrplayers then
		for i = 1, nrplayers do
			local playerid = self.inst.entity:DeserializePlayerID()
			local deposited = self.inst.entity:DeserializeUInt(SERIALIZED_DEPOSITED_BIT_COUNT)
			if not TheNet:IsLocalPlayer(playerid) then
				self.deposited[playerid] = deposited
			else
				self.netsync_deposited[playerid] = deposited
			end
		end
	end

	-- data on which players need refunds
	local nrrefunds = self.inst.entity:DeserializeUInt(3)
	if nrrefunds then
		for i = 1, nrrefunds do
			local playerid = self.inst.entity:DeserializePlayerID()
			local refund = self.inst.entity:DeserializeUInt(SERIALIZED_DEPOSITED_BIT_COUNT)

			if TheNet:IsLocalPlayer(playerid) then
				local delta = refund - (self.refunds[playerid] or 0)
				if delta > 0 then
					self:RefundPlayer_Silent(playerid, delta)
				end
			end

			self.refunds[playerid] = refund
		end
	end

	-- details about the item such as specific item defs or equipment slots used
	local num_details = self.inst.entity:DeserializeUInt(2)
	local product_details = {}
	for i = 1, num_details do
		local detail = self.inst.entity:DeserializeString()
		product_details[i] = detail
	end

	-- which specific ware id is on offer (from vendingmachine_wares.lua)
	local ware_id = self.inst.entity:DeserializeString()
	ware_id = ware_id ~= ""	and ware_id or nil
	if self.ware_id ~= ware_id
		or self.product_details[1] ~= product_details[1]
		or self.product_details[2] ~= product_details[2]
	then
		self:Initialize(ware_id, product_details[1], product_details[2])
	end

	local item_emitted = self.inst.entity:DeserializeBoolean()
	if item_emitted and not self.crowdsourced_item_emitted and self:IsCrowdFunded() then 
		self.crowdsourced_item_emitted = item_emitted
		self:ShutdownInteractable()
	end

	self:UpdatePriceTag()
end

function VendingMachine:OnPostSpawn()
	if not self.initialized_interactable then
		self:InitInteractable()
	end
end

function VendingMachine:InitInteractable()
	local interactable = self.inst.components.interactable
	dbassert(interactable)
	interactable
		:SetInteractStateName("deposit_currency")
		:SetInteractConditionFn(function(_inst, player, _is_focused) return self:CanInteract(player) end)
		:SetOnGainInteractFocusFn(function(_inst, player) self:OnGainInteractFocus(player) end)
		:SetOnInteractFn(function(_inst, player) self:OnInteract(player) end)
		:SetOnLoseInteractFocusFn(function(_inst, player) self:OnLoseInteractFocus(player) end)
	self.initialized_interactable = true
end

function VendingMachine:UpdatePlayerStatus(player)
	local can, purchase_text = self:CanDeposit(player)
	if can then
		if self.currency == Currency.id.Health then
			purchase_text = STRINGS.UI.VENDING_MACHINE.SAMPLE_HEALING_FOUNTAIN
		elseif self:IsCrowdFunded() then
			purchase_text = STRINGS.UI.VENDING_MACHINE.DEPOSIT
		else
			purchase_text = STRINGS.UI.VENDING_MACHINE.PURCHASE
		end
	end
	player.components.interactor:SetStatusText("VendingMachine", purchase_text)
end

function VendingMachine:OnGainInteractFocus(player)
	if self.summary then
		self.summary:Hide()
	end
	if self.details then
		if self.inst.components.interactable:GetFocusedPlayerCount() ~= 0 then
			self.details:Show()
		end
		if self.details.OnGainInteractFocus then
			self.details:OnGainInteractFocus(player)
		end
	end
	if self.price_tag and self.price_tag_visibility_by_proximity then
		self.price_tag:Show()
	end
	self:Layout()

	self:UpdatePlayerStatus(player)
	self.inst:ListenForEvent("perform_interact", self.on_perform_interact_fn)	
end

function VendingMachine:OnLoseInteractFocus(player)
	if self.summary then
		self.summary:Show()
	end
	if self.details then
		if self.details.OnLoseInteractFocus then
			self.details:OnLoseInteractFocus(player)
		end
		if self.inst.components.interactable:GetFocusedPlayerCount() == 0 then
			self.details:Hide()
		end
	end	
	if self.price_tag and self.price_tag_visibility_by_proximity then
		self.price_tag:Hide()
	end
	self:Layout()

	player.components.interactor:SetStatusText("VendingMachine", nil)
	self.inst:RemoveEventCallback("perform_interact", self.on_perform_interact_fn)
end

function VendingMachine:ShutdownInteractable()
	self.inst.components.interactable:SetInteractCondition_Never()
	self.root:Hide()
end

local CurrencyMaterial = {
	[Currency.id.Run] = Consumable.Items.MATERIALS.konjur,
	[Currency.id.Meta] = Consumable.Items.MATERIALS.konjur_soul_lesser,
	[Currency.id.Cosmetic] = Consumable.Items.MATERIALS.glitz,
	[Currency.id.Health] = nil,
}

function VendingMachine:GetAvailableFunds(player)
	if self.currency == Currency.id.Health then
		return player.components.health:GetMissing()
	else
		return player.components.inventoryhoard:GetStackableCount(CurrencyMaterial[self.currency])
	end
end

function VendingMachine:IsCrowdFunded()
	-- crowd_fundable items are networked and the final purchase is spawned by the host as a prefab in the world
	-- non-crowd_fundable items are executed on the local machine and the final purchase must be placed directly into the player's inventory
	return self.crowd_fundable
end

function VendingMachine:GetTotalDeposited()
	local total = 0
	for id, amount in pairs(self.deposited) do
		total = total + amount
	end
	return total
end

function VendingMachine:ReduceFunds(deposit, player, silent)
	if self.currency == Currency.id.Health then
		player.components.health:DoDelta(deposit)
	else
		player.components.inventoryhoard:RemoveStackable(CurrencyMaterial[self.currency], deposit)
	end

	if not silent then
		--sound
		local params = {}
		params.fmodevent = fmodtable.Event.vendingMachine_deposit_oneShot
		--@luca TODO this should probably be a loop instead
		soundutil.PlayLocalSoundData(player, params) -- TODO: audio, may not rate-limit as desired
	end
end

function VendingMachine:GetRemainingCost()
	-- Don't deposit more than there is left to pay.
	return math.max(0, self.cost - self:GetTotalDeposited())
end

--- Compute the deposit to be spent on a single invocation of OnInteract().
function VendingMachine:ComputeDeposit(player)
	local deposit
	if self:IsCrowdFunded() then
		-- Don't deposit more than our DEPOSIT_RATE (per tick).
		dbassert(math.fmod(DEPOSIT_RATE, 1) == 0, "DEPOSIT_RATE must be a whole number to avoid fractional deposits")
		deposit = math.min(DEPOSIT_RATE, self:GetRemainingCost())
	else
		deposit = self.cost
	end

	-- Can't spend more than we have.
	deposit = math.min(deposit, self:GetAvailableFunds(player))

	return deposit
end

--- Return true if the player can deposit funds.
-- this is NOT included in CanInteract on purpose so all players can see the details of the items on offer.
function VendingMachine:CanDeposit(player)
	if not self.ware_id then 
		return 
	end

	local available_funds = self:GetAvailableFunds(player)
	local can_spend = self:IsCrowdFunded()
		and available_funds > 0 -- Any non-zero amount is permissible for crowd-funded wares.
		or available_funds >= self.cost -- Need the full cost to buy it if it is not crowd-funded.
	if not can_spend then
		return false, INSUFFICIENT_FUNDS[self.currency]
	end
	
	-- TODO @chrisp #heal - concatenate with extant reasons, but probably we just want a list of reasons, shown one at a
	-- time, so defer this until that feature comes online
	return self.can_purchase_fn(self.inst, player)
end

--- A VendingMachine remains interactable until ShutdownInteractable() is invoked. This lets players bring up the
--- details widget even after they have purchased an item, though the purchase button will be hidden.
function VendingMachine:CanInteract(player)
	return true
end

function VendingMachine:OnInteract(player)
	if self:CanDeposit(player) then
		self:DepositFunds(player)
	end
end

function VendingMachine:DepositFunds(player)
	local id = player.Network:GetPlayerID()
	local deposit = self:ComputeDeposit(player)

	if deposit > 0 then
		self:ReduceFunds(deposit, player)
		self:DeltaDepositForPlayerID(id, deposit)
		-- If the vending machine isn't crowd funded we don't need to pool money with other players
		if not self:IsCrowdFunded() then
			self:LocalDepositCurrency(id, deposit)
		else
			self:NetDepositCurrency(id, deposit)
		end
	end
end

function VendingMachine:LocalDepositCurrency(id, delta)
	if self:IsCrowdFunded() then
		if TheNet:IsHost() then -- only handle crowdsourced items on the host
			if self:IsPurchaseComplete(id) then
				local player = GetPlayerEntityFromPlayerID(id)

				if not self.crowdsourced_item_emitted then  -- Only emit once
					self:OnPurchaseComplete(player)
					self.crowdsourced_item_emitted = true
					self:ShutdownInteractable()
				end
			end
		end
	else
		if self:IsPurchaseComplete(id) then
			local player = GetPlayerEntityFromPlayerID(id)
			self:OnPurchaseComplete(player)
		end
	end
end

function VendingMachine:NetDepositCurrency(id, delta)
	-- Send the host a message telling them you've deposited money:
	-- save up deposits and send if off:
	self.deferredDeposits[id] = (self.deferredDeposits[id] or 0) + delta

	if not self._netdeposit_task then
		self._netdeposit_task = self.inst:DoTaskInTicks(DEPOSIT_NETWORK_PERIOD_TICKS, function() self:_NetSendDeferredDeposits() end)
	end

	if not TheNet:IsHost() then
		if self._netsync_task then
			self._netsync_task:Cancel()
			self._netsync_task = nil
		end
		self._netsync_task = self.inst:DoTaskInTicks(90, function() self:_NetSyncDeposits() end)	-- Wait to update all network events before accepting the network data as ground truth
	end
end

function VendingMachine:_NetSendDeferredDeposits()
	-- Send the deferred amounts over the network:
	for playerID, amount in pairs(self.deferredDeposits) do
		if amount > 0 then
			TheNetEvent:Deposit(self.inst.Network:GetEntityID(), playerID, amount)
		end
	end
	self.deferredDeposits = {}
	self._netdeposit_task = nil	-- Remove the timed send function
end


function VendingMachine:OnUpdate(dt)
	local total = Lume.round(self:GetTotalDeposited())

	-- make display_total_deposited approach the total, with a max step of DEPOSIT_WIDGET_RATE
	local delta = Lume.round(total - self.display_total_deposited)

	local absdelta = math.abs(delta)
	local rate = 1
	
	for _, rate_data in pairs(DEPOSIT_WIDGET_RATE) do
		if absdelta >= rate_data.deltagreaterthan then
			rate = rate_data.rate
			break
		end
	end
	
	delta = Lume.clamp(delta, -rate, rate)
	if delta ~= 0 then
		self.display_total_deposited = Lume.round(self.display_total_deposited + delta)
		self:UpdatePriceTag()
	end
end



function VendingMachine:_NetSyncDeposits()
	self._netsync_task = nil

	local local_players = TheNet:GetLocalPlayerList()

	for _, id in ipairs(local_players) do
		local net_deposit = self.netsync_deposited[id] or 0

		local delta = (self.deposited[id] or 0) - net_deposit
		if delta ~= 0 then 
			self.deposited[id] = net_deposit

			-- refund the player any difference in currencies
			if delta > 0 then
				self:RefundPlayer_Silent(id, delta)
			else
				-- should only ever be a positive amount, but just in case...
				local player = GetPlayerEntityFromPlayerID(id)
				self:ReduceFunds(delta, player, true)
			end
		end
	end

	-- wipe this table as it is now synced up.
	self.netsync_deposited = {}

	self:UpdatePriceTag()
end

function VendingMachine:OnNetDepositCurrency(id, delta)
	-- This is called by the host when a player tells the host they have deposited money
	if not TheNet:IsLocalPlayer(id) then
		-- Normally this is handled during :DepositFunds()
		-- If this message is coming from a remote player then we need to do it again on the host's machine.
		self:DeltaDepositForPlayerID(id, delta)
	end

	self:LocalDepositCurrency(id, delta)

	if self.cost and self:GetTotalDeposited() > self.cost then
		local refund = self:GetTotalDeposited() - self.cost
		self.refunds[id] = (self.refunds[id] or 0) + refund
		self:DeltaDepositForPlayerID(id, -refund)
	end
end

-- TODO @chrisp #deadcode - in-world refunds are never used
function VendingMachine:RefundPlayer_World(id, amount)
	-- spawns konjur blobs in the world that are they vacuumed up by the player.
	-- called by the host.
	local player = GetPlayerEntityFromPlayerID(id)
	TheDungeon.HUD:MakePopText({ target = self.inst, button = STRINGS.UI.VENDING_MACHINE.REFUND, color = UICOLORS.KONJUR, size = 100, fade_time = 3, y_offset = 70 })
	LootEvents.MakeEventSpawnCurrency(amount, self.inst:GetPosition(), player, false, true)
end

function VendingMachine:RefundPlayer_Silent(id, amount)
	-- deposits konjur directly into the player's inventory
	-- called by the local client for that player id
	local player = GetPlayerEntityFromPlayerID(id)
	if self.currency == Currency.id.Health then
		player.components.health:DoDelta(-amount)
	else
		player.components.inventoryhoard:AddStackable(CurrencyMaterial[self.currency], amount, true)
	end
end

-- TODO: networking2022, identify that this is host-only API?
function VendingMachine:ResetAnyPlayerInteractingStatus()
	if TheNet:IsHost() then
		table.clear(self.is_interacting)
	end
end

-- TODO: networking2022, identify that this is host-only API?
function VendingMachine:IsAnyPlayerInteracting()
	if TheNet:IsHost() then
		return next(self.is_interacting)
	end
	return false
end

function VendingMachine:_UpdateAnyPlayerInteractingStatus(id)
	if not TheNet:IsHost() then
		return
	end

	if self.inst.sg then
		self.inst.sg:PushEvent("is_interacting_changed")
	end
	if self.is_interacting[id] then
		self.is_interacting[id]:Cancel()
		self.is_interacting[id] = nil
	end

	-- tune this timeout value for responsiveness vs auto-shutoff based on latency
	self.is_interacting[id] = self.inst:DoTaskInTicks(10, function()
		self.is_interacting[id] = nil
		if self.inst.sg and not self:IsAnyPlayerInteracting() then
			self.inst.sg:PushEvent("is_interacting_changed")
		end
	end)
end

function VendingMachine:DeltaDepositForPlayerID(id, delta)
	self.deposited[id] = (self.deposited[id] or 0) + delta
	self:UpdatePriceTag()

	if TheNet:IsHost() and delta > 0 then
		self:_UpdateAnyPlayerInteractingStatus(id)
	end
end

function VendingMachine:UpdatePriceTag()
	if self:IsCrowdFunded() then
		self.price_tag:SetText(self:MakePriceText(math.max(Lume.round(self.cost - self.display_total_deposited), 0)))
	end
end

function VendingMachine:OnPlayerDeactivated(player)
	-- remove all funds contributed by this player
	local id = player.Network:GetPlayerID()
	if self.deposited[id] then
		self:DeltaDepositForPlayerID(id, -self.deposited[id])
	end
end

function VendingMachine:IsPurchaseComplete(id)
	return self:IsCrowdFunded()
		and self:GetTotalDeposited() >= self.cost
		or self.deposited[id] >= self.cost
end

function VendingMachine:OnPurchaseComplete(player)
	-- Run the function to generate the ware we just built, and then position it.
	local ware = self.purchased_fn and self.purchased_fn(self.inst, player)
	if ware then
		local x, y, z = self.inst.Transform:GetWorldPosition()
		z = z - TILE_SIZE / 2
		ware.Transform:SetPosition(x, y, z)
	end
	if self.details.OnPurchaseComplete then
		self.details:OnPurchaseComplete()
	end
	self:UpdatePlayerStatus(player)
end

function VendingMachine:DebugDrawEntity(ui, panel, colors)
	if TheNet:IsHost() then
		if ui:CollapsingHeader("Interacting Players", ui.TreeNodeFlags.DefaultOpen) then
			for player_id, _ in pairs(self.is_interacting) do
				ui:Text(string.format("Player %s", player_id))
			end
		end
	end
end

return VendingMachine
