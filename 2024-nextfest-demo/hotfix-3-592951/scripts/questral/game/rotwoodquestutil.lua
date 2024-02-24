local Biomes = require "defs.biomes"
local Consumable = require "defs.consumable"
local Npc = require "components.npc"
local Quest = require "questral.quest"
local fmodtable = require "defs.sound.fmodtable"
local kassert = require "util.kassert"
local lume = require "util.lume"

-- Game-specific utilities.
local rotwoodquestutil = {}


function rotwoodquestutil.Not(fn)
    return function(...)
        return not fn(...)
    end
end

function rotwoodquestutil.IsCastPresent(quest, cast_id)
    assert(quest.def.cast[cast_id], "Input cast doesn't exist. Should be the name passed to AddCast.")
    local ent = quest:GetCastMember(cast_id)
    -- Currently, checking for the inst is enough to know they are in the scene.
    return ent and ent.inst
end

local function fmt_color_desire(pretty_string)
    -- Orange is the colour of desire.
    return ("<#EA7722>%s</>"):format(pretty_string)
end

local function get_first_interesting_ingredient(ingredients)
    for ing_name,needs in pairs(ingredients) do
        if ing_name ~= "glitz" then
            return ing_name
        end
    end
    local ing_name = next(ingredients)
    return ing_name
end

function rotwoodquestutil.GetPrettyRecipeIngredient_NpcHome(npc_node)
    return rotwoodquestutil.GetPrettyRecipeIngredient(npc_node.inst.components.npc:DesiredHomeRecipe())
end

-- Gets the most interesting ingredient as a string to display to user.
function rotwoodquestutil.GetPrettyRecipeIngredient(recipe)
    assert(recipe)
    kassert.greater(lume.count(recipe.ingredients), 0, "Must have ingredients")
    local ing_name = get_first_interesting_ingredient(recipe.ingredients)
    local mat = Consumable.Items.MATERIALS[ing_name]
    return fmt_color_desire(mat.pretty.name)
end

-- Can't apply this param in Quest_Start because the NPC may not exist yet.
function rotwoodquestutil.UpdateDesiredHomeRecipeParam(quest)
    local node = quest:GetCastMember("giver")
    if node.inst then
        local recipe = node.inst.components.npc:DesiredHomeRecipe()
        quest.param.primary_ingredient_name = rotwoodquestutil.GetPrettyRecipeIngredient(recipe)
    end
end

-- Common NPC quest filters {{{1
-- Pass these as the third argument to OnAttract.

-- TODO(dbriscoe): Do we need any of these filters?
function rotwoodquestutil.Filter_IsWaitingForExile(quest, node, sim, objective_id)
    local inst = node.inst
    return inst.components.npc.exiled
end
function rotwoodquestutil.Filter_IsVisitor(quest, node, sim, objective_id)
    local inst = node.inst
    local player = node:GetInteractingPlayerEntity()
    return not inst.components.conversation.persist.memory.VISITOR
        and not inst.components.npc:CanCraftDesiredHome(player)
end
function rotwoodquestutil.Filter_IsSkipToItem(quest, node, sim, objective_id)
    local inst = node.inst
    local player = node:GetInteractingPlayerEntity()
    return not inst.components.npc:CanCraftDesiredHome(player)
        and inst.components.conversation.persist.memory.WANT_ITEM
end
function rotwoodquestutil.Filter_IsMoveIn(quest, node, sim, objective_id)
    local inst = node.inst
    local player = node:GetInteractingPlayerEntity()
    return inst.components.npc:CanCraftDesiredHome(player)
end
function rotwoodquestutil.Filter_IsFirstHired(quest, node, sim, objective_id)
    local inst = node.inst
    return inst.components.npc:HasDesiredHome()
        and not inst.components.conversation.persist.memory.FIRST_HIRED
end
function rotwoodquestutil.IsResident(node)
    local inst = node.inst
    -- Not sure it's good that we ignore them if they don't exist.
    return inst and inst.components.npc:HasDesiredHome()
end
function rotwoodquestutil.Filter_CanBuildHome(quest, node, sim, objective_id)
    local inst = node.inst
    local player = node:GetInteractingPlayerEntity()
    dbassert(player)
    return not inst.components.npc:HasDesiredHome()
        and inst.components.npc:CanCraftDesiredHome(player)
end

--Meeting any NPC for the first time in one run
function rotwoodquestutil.Filter_FirstMeetingNPC(filter_fn, quest, node, sim, objective_id)
    local can_spawn = not TheDungeon.progression.components.runmanager:HasMetTownNPCInDungeon()
    -- check that runmanager isn't flagged as having met an NPC already this run

    -- check extra filter_fn if one was passed in
    if filter_fn then
        can_spawn = can_spawn and filter_fn(quest, node, sim, objective_id)
    end

    return can_spawn
end

--Meeting a specific NPC for the first time in the game
function rotwoodquestutil.Filter_FirstMeetingSpecificNPC(quest, node, sim, npc, objective_id, filter_fn)
    local can_spawn = not quest:GetPlayer().components.unlocktracker:IsFlagUnlocked(npc)

    if can_spawn == false then
        print ("CAN'T MEET NPC FOR THE FIRST TIME WHO HAS ALREADY BEEN MET")
    end

    -- check extra filter_fn if one was passed in
    if filter_fn then
        can_spawn = can_spawn and filter_fn(quest, node, sim, objective_id)
    end

    return can_spawn
end

------------- FETCH QUEST

function rotwoodquestutil.GetPrettyMaterialName(mat_name)
    local mat = rotwoodquestutil.GetMaterial(mat_name)
    return fmt_color_desire(mat.pretty.name)
end

function rotwoodquestutil.GetMaterial(mat_name)
    assert(mat_name)
    local mat = Consumable.Items.MATERIALS[mat_name]
    assert(mat, mat_name)
    return mat
end

function rotwoodquestutil.HasFetchMaterial(quest, node, sim, objective_id)
    local player = quest:GetPlayer()
    local mat_name = quest:GetVar("request_material")
    local mat = rotwoodquestutil.GetMaterial(mat_name)

    return player.components.inventoryhoard:GetStackableCount(mat) >= 1
end

--check if an item exists in a player inventory using cx
function rotwoodquestutil.HasFetchMaterialCx(cx, objective_id)
    local player = cx.quest:GetPlayer()
    local mat_name = cx.quest:GetVar("request_material")
    local mat = rotwoodquestutil.GetMaterial(mat_name)

    return player.components.inventoryhoard:GetStackableCount(mat) >= 1
end

function rotwoodquestutil.DeliverFetchMaterial(cx)
    local player = cx.quest:GetPlayer()
    local mat_name = cx.quest:GetVar("request_material")
    local mat = rotwoodquestutil.GetMaterial(mat_name)

    return player.components.inventoryhoard:RemoveStackable(mat, 1)
end

-- Common NPC actions {{{1
function rotwoodquestutil.FocusCameraOnNPCIfLocal(quest, npc, playerID)
    local local_players = TheNet:GetLocalPlayerList()

    if table.contains(local_players, playerID) then
        local cast_inst = quest:GetCastMember(npc).inst
        cast_inst:DoTaskInTime(0, function() TheFocalPoint.components.focalpoint:AddExplicitTarget(cast_inst) end)
        cast_inst:DoTaskInTime(2, function() TheFocalPoint.components.focalpoint:ClearExplicitTargets() end)
    end
end

local function GetGiverNpcAndPlayerEntities(cx)
    local node = rotwoodquestutil.GetGiver(cx)
    local inst = node.inst
    local player = node:GetInteractingPlayerEntity()
    return inst, player
end

rotwoodquestutil.GetGiverNpcAndPlayerEntities = GetGiverNpcAndPlayerEntities

function rotwoodquestutil.UpgradeGiverHome(cx)
    local inst, player = GetGiverNpcAndPlayerEntities(cx)
    kassert.typeof("table", player)

    local home = inst.components.npc.home

    if home.components.buildingskinner ~= nil then
        local BuildingSkinScreen = require "screens.town.buildingskinscreen"
        cx:PresentCallbackScreen(BuildingSkinScreen, home, player)

    elseif home.components.buildingupgrader ~= nil then
        inst.components.npc:StartUpgradingHome(player)
    end
end

function rotwoodquestutil.MoveGiverHome(cx)
    cx:PresentCallbackAction(function(cb)

        local inst, player = GetGiverNpcAndPlayerEntities(cx)
        kassert.typeof("table", player)

        -- Must close prompt before we can start another interaction.
        TheDungeon.HUD:HidePrompt(inst)

        local home = inst.components.npc.home
        inst.components.npc:StartMovingHome(home, player, cb)
    end)
end

function rotwoodquestutil.ExileGiver(cx)
    local node = rotwoodquestutil.GetGiver(cx)
    node.inst.components.npc:ExileFromTown()
end

-- Prevents the giver from restarting a convo for input seconds. Useful to
-- allow their animation to play out before restarting conversation.
function rotwoodquestutil.ConvoCooldownGiver(cx, delay_seconds)
    local node = rotwoodquestutil.GetGiver(cx)
    node.inst.components.timer:StartTimer("talk_cd", delay_seconds)
end

function rotwoodquestutil.OpenShop(cx, screen_ctor)
    local inst, player = GetGiverNpcAndPlayerEntities(cx)
    kassert.typeof("table", player)
    TheFrontEnd:PushScreen(screen_ctor(player, inst))
end

-- /end NPC actions

-- Prefer to use quest:GetQuestManager() if possible.
function rotwoodquestutil.Debug_GetQuestManager()
    local player = ConsoleCommandPlayer()
    return player and player.components.questcentral:GetQuestManager()
end

-- Prefer to use quest:GetRoot() if possible.
function rotwoodquestutil.Debug_GetCastManager()
    return TheDungeon.progression.components.castmanager
end

function rotwoodquestutil.CompleteObjectiveIfCastMatches(quest, objective, role, prefab)
    if quest:IsActive(objective) and prefab == quest:GetCastMemberPrefab(role) then
        quest:Complete(objective)
        return true
    end
end

function rotwoodquestutil.OpenMap(cx)
    local player_actor = cx:GetPlayer()
    local DungeonSelectionScreen = require "screens.town.dungeonselectionscreen"

    local function make_screen()
        local screen = DungeonSelectionScreen(player_actor.inst)
        return screen
    end

    cx:PresentCallbackScreen(make_screen)
end

function rotwoodquestutil.IsInDungeon(id)
    return TheDungeon:GetDungeonMap().data.location_id == id
end

function rotwoodquestutil.IsInBiome(id)
    return TheDungeon:GetDungeonMap().data.region_id == id
end

function rotwoodquestutil.PushShopChat(cx, skip_talk)
    local agent = cx.quest:GetCastMember("giver")
    agent.skip_talk = skip_talk -- HACK
    cx:TryPushHook(Quest.CONVO_HOOK.s.CHAT_TOWN_SHOP, agent)
end

-- TODO: change cx to quest instead
-- TODO: do this via player.components.unlocktracker instead
function rotwoodquestutil.GetAllDiscoveredMobs()
    -- local unlocked_locations = {}
    -- for id, def in pairs(Biomes.locations) do
    --     if def.type == Biomes.location_type.DUNGEON then
    --         if TheWorld:IsUnlocked(def.id) then -- ENEMY
    --             table.insert(unlocked_locations, def)
    --         end
    --     end
    -- end

    -- local unlocked_mobs = {}
    -- for _, def in ipairs(unlocked_locations) do
    --     for _, mob in ipairs(def.monsters.mobs) do
    --         if string.match(mob, "trap") == nil and TheWorld:IsUnlocked(mob) then
    --             table.insert(unlocked_mobs, mob)
    --         end
    --     end
    -- end

    -- return unlocked_mobs
    return {}
end

-- TODO: change cx to quest instead
-- TODO: do this via player.components.unlocktracker instead
function rotwoodquestutil.GetDiscoveredMobDrops(rarity)

    -- local drops = {}
    -- for id, def in pairs (Consumable.Items.MATERIALS) do
    --     local src_mob = string.gsub(def.source, "drops_", "")
    --     if TheWorld:IsUnlocked(src_mob) then
    --         table.insert(drops, id)
    --     end
    -- end

    -- if rarity == nil then
    --     return drops
    -- end

    -- local filtered_drops = {}
    -- for _, id in ipairs(drops) do
    --     if table.contains(rarity, Consumable.Items.MATERIALS[id].rarity) then
    --         table.insert(filtered_drops, id)
    --     end
    -- end

    --return filtered_drops
    return {}
end

function rotwoodquestutil.SelectDiscoveredMobDrop(rarity)
    local drops = rotwoodquestutil.GetDiscoveredMobDrops(rarity)

    if #drops == 0 then
        print ("No drops found, picking default")
        return "cabbageroll_skin" -- Failsafe
    end

    return drops[math.random(1, #drops)]
end

function rotwoodquestutil.PickFetchMaterial(cx)
    if cx.quest.param.request_material ~= "PLACEHOLDER" then
        return
    end

    local drop = rotwoodquestutil.SelectDiscoveredMobDrop({ITEM_RARITY.s.COMMON, ITEM_RARITY.s.UNCOMMON})
    cx.quest.param.request_material = drop
end


-- TODO: use playerunlocks instead
function rotwoodquestutil.PickReward(cx)

    -- if cx.quest.param.reward ~= "PLACEHOLDER" then
    --     return
    -- end

    -- local rewards =
    -- {
    --     "stone_lamp", "well", "kitchen_barrel", "kitchen_sign", "outdoor_seating",
    --     "outdoor_seating_stool", "chair1", "chair2", "street_lamp","bench_megatreemon",
    --     "hammock", "plushies_lrg", "plushies_mid", "plushies_sm", "plushies_stack",
    --     "wooden_cart", "weapon_rack", "tanning_rack", "dye1", "dye2", "dye3", "leather_rack"
    -- }

    -- local reward_index = math.random(1, #rewards)
    -- while TheWorld:IsUnlocked(rewards[reward_index]) do
    --     table.remove(rewards, reward_index)
    --     if #rewards == 0 then
    --         break
    --     end
    --     reward_index = math.random(1, #rewards)
    -- end

    -- cx.quest.param.reward = rewards[reward_index]
end

function rotwoodquestutil.SetPlayerSpecies(cx)
    local player = cx.quest:GetPlayer()
    local species_id = "species_" .. player.components.charactercreator:GetSpecies()
    cx.quest:SetVar("species", STRINGS.NAMES[species_id])
end

function rotwoodquestutil.GiveReward(cx)
    local player = cx:GetPlayer().inst
    player.components.playercrafter:UnlockItem(cx.quest.param.reward, true)
end

function rotwoodquestutil.PushWeaponUnlockScreen(cx, give_weapon_fn, weapon_id)
    cx:PresentCallbackAction(function(cb)
        local player = cx:GetPlayer()
        if not player and player.inst then
            if cb then
                cb()
            end
            return
        end

        player.inst:DoTaskInAnimFrames(20, function()
            give_weapon_fn(player.inst)
            player.inst.sg:GoToState("unsheathe_fast")
        end)

        player.inst:DoTaskInAnimFrames(50, function()

            TheWorld.components.ambientaudio:PlayMusicStinger(fmodtable.Event.Mus_weaponUnlock_Stinger)

            local itemforge = require "defs.itemforge"
            local Equipment = require "defs.equipment"
            local item_def = Equipment.Items["WEAPON"][weapon_id]
            local item = itemforge.CreateEquipment(item_def.slot, item_def)
            local weapon_type = item_def.weapon_type
            local title = STRINGS.WEAPONS.UNLOCK.TITLE
            local unlock_string = STRINGS.WEAPONS.UNLOCK[weapon_type] or string.format("%s UNLOCK STRING MISSING", weapon_type)
            local how_to_play = STRINGS.WEAPONS.HOW_TO_PLAY[weapon_type] or string.format("%s HOW TO PLAY STRING MISSING", weapon_type)
            local focus_hit = STRINGS.WEAPONS.FOCUS_HIT[weapon_type] or string.format("%s FOCUS HIT STRING MISSING", weapon_type)
            local description = string.format("%s\n\n%s\n\n%s", unlock_string, how_to_play, focus_hit)

            local ItemUnlockPopup = require "screens.itemunlockpopup"
            local screen = ItemUnlockPopup(nil, nil, true)
                :SetItemUnlock(item, title, description)

            screen:SetOnDoneFn(
                function()
                    TheFrontEnd:PopScreen(screen)
                    if cb then
                        cb()
                    end
                end)

            TheFrontEnd:PushScreen(screen)
            screen:AnimateIn()

        end)
    end)
end


-- LockRoom: cause an entity to lock the room. You have to pass an entity to this function because we have to track *who* is keeping the room locked.
function rotwoodquestutil.LockRoom(quest)
    -- When this function is typically first called, giver's inst doesn't yet exist. Wait a few ticks.
    TheWorld:DoTaskInTicks(10, function()
        local giver = quest:GetCastMember("giver")
        if giver and giver.inst then
            giver.inst:AddComponent("roomlock")
        end
    end)
end

function rotwoodquestutil.UnlockRoom(quest)
    local giver = quest:GetCastMember("giver")
    if giver and giver.inst then
        giver.inst:RemoveComponent("roomlock")
    end
end

function rotwoodquestutil.GetGiver(cx_or_quest)
    local giver

    if cx_or_quest.GetCastMember then
        -- This is a quest, so just get the giver
        giver = cx_or_quest:GetCastMember("giver")
    elseif cx_or_quest.quest then
        -- This is a cx, so get the quest and then get the giver
        giver = cx_or_quest.quest:GetCastMember("giver")
    end

    assert(giver, "Couldn't find giver from what was provided. Please ask jambell for help!")

    return giver
end

--return how much dungeon currency is in the player's inventory 
function rotwoodquestutil.GetPlayerKonjur(player)
    return player.components.inventoryhoard:GetStackableCount(Consumable.Items.MATERIALS.konjur)
end

function rotwoodquestutil.HasDoneQuest(player, id)
    -- TODO: Once players each have their own quest state, this should be evaluated per-player
    local qman = player.components.questcentral:GetQuestManager()
    local quest = qman:FindCompletedQuestByID(id)
    return quest ~= nil
end

function rotwoodquestutil.IsQuestActiveOrComplete(player, id)
    local qman = player.components.questcentral:GetQuestManager()
    local quest = qman:FindQuestByID(id) or qman:FindCompletedQuestByID(id)
    return quest ~= nil
end

function rotwoodquestutil.IsQuestActive(player, id)
    local qman = player.components.questcentral:GetQuestManager()
    local quest = qman:FindQuestByID(id)
    return quest ~= nil
end

function rotwoodquestutil.PlayerNeedsPotion(player)
    return player.components.potiondrinker:CanGetMorePotionUses()
end

function rotwoodquestutil.PlayerHasRefilledPotion(player)
    return player.components.potiondrinker:HasRefilledPotionThisRoom()
end

function rotwoodquestutil.GiveItemToPlayer(player, slot, id, num, should_equip)
    player.components.inventoryhoard:Debug_GiveItem(slot, id, num, should_equip)
end

function rotwoodquestutil.CompleteQuestOnRoomExit(quest)
    quest:ActivateObjective("wait_for_exit_room")
end

function rotwoodquestutil.AddCompleteQuestOnRoomExitObjective(Q)
    Q:AddObjective("wait_for_exit_room")
        :OnEvent("exit_room", function(quest)
            quest:Complete("wait_for_exit_room")
        end)
        :OnEvent("end_current_run", function(quest)
            quest:Complete("wait_for_exit_room")
        end)
        :OnComplete(function(quest)
            quest:Complete()
        end)
end

-- data can contain:
-- objective_id
-- cast_id
-- on_activate_fn
-- on_complete_fn
function rotwoodquestutil.AddCompleteObjectiveOnCast(Q, data)
    local function complete_if_cast_exists(quest)
        -- if this cast exists, complete the objective
        local cast = quest:GetCastMember(data.cast_id)
        if cast and not cast.is_reservation then
            quest:Complete(data.objective_id)
        end
    end

    local obj = Q:AddObjective(data.objective_id)
                :OnActivate(function(quest)
                    if data.on_activate_fn then
                        data.on_activate_fn(quest)
                    end
                    complete_if_cast_exists(quest)
                end)
                :OnEvent("cast_member_filled", complete_if_cast_exists)
                :OnEvent("playerentered", complete_if_cast_exists)
                :OnComplete(function(quest)
                    if data.on_complete_fn then
                        data.on_complete_fn(quest)
                    end
                end)
    return obj
end

function rotwoodquestutil.AlreadyHasCharacter(npc_role)
    dbassert(Npc.Role:Contains(npc_role), "Unknown role. See npc.lua for the list.")
    return TheWorld:IsFlagUnlocked("wf_town_has_" .. npc_role)
        or TheWorld:IsFlagUnlocked("wf_seen_npc_" .. npc_role)
end

return rotwoodquestutil
