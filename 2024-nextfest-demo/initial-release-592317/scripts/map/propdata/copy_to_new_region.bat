pushd "C:\code\FromTheForge\data\scripts\map\propdata"

set region=
if not defined region (
	echo "Edit %0 and specify the new region."
	exit /b 1
)

:: TODO: We should do this with a button inside the game.
::
:: Not svn cp since we're not really branching, they're small, and I think lots
:: of branching confuses on svn.
copy "startingforest_kitchen_esw_propdata.lua"       "%region%_kitchen_esw_propdata.lua"
copy "startingforest_kitchen_ew_propdata.lua"        "%region%_kitchen_ew_propdata.lua"
copy "startingforest_kitchen_new_propdata.lua"       "%region%_kitchen_new_propdata.lua"
copy "startingforest_kitchen_nsw_propdata.lua"       "%region%_kitchen_nsw_propdata.lua"
copy "startingforest_kitchen_nw_propdata.lua"        "%region%_kitchen_nw_propdata.lua"
copy "startingforest_kitchen_sw_propdata.lua"        "%region%_kitchen_sw_propdata.lua"
copy "startingforest_minigame_esw_propdata.lua"      "%region%_minigame_esw_propdata.lua"
copy "startingforest_minigame_ew_propdata.lua"       "%region%_minigame_ew_propdata.lua"
copy "startingforest_minigame_new_propdata.lua"      "%region%_minigame_new_propdata.lua"
copy "startingforest_minigame_nsw_propdata.lua"      "%region%_minigame_nsw_propdata.lua"
copy "startingforest_minigame_nw_propdata.lua"       "%region%_minigame_nw_propdata.lua"
copy "startingforest_minigame_sw_propdata.lua"       "%region%_minigame_sw_propdata.lua"
copy "startingforest_potion_esw_propdata.lua"        "%region%_potion_esw_propdata.lua"
copy "startingforest_potion_ew_propdata.lua"         "%region%_potion_ew_propdata.lua"
copy "startingforest_potion_new_propdata.lua"        "%region%_potion_new_propdata.lua"
copy "startingforest_potion_nsw_propdata.lua"        "%region%_potion_nsw_propdata.lua"
copy "startingforest_potion_nw_propdata.lua"         "%region%_potion_nw_propdata.lua"
copy "startingforest_potion_sw_propdata.lua"         "%region%_potion_sw_propdata.lua"
copy "startingforest_powerupgrade_esw_propdata.lua"  "%region%_powerupgrade_esw_propdata.lua"
copy "startingforest_powerupgrade_ew_propdata.lua"   "%region%_powerupgrade_ew_propdata.lua"
copy "startingforest_powerupgrade_new_propdata.lua"  "%region%_powerupgrade_new_propdata.lua"
copy "startingforest_powerupgrade_nsw_propdata.lua"  "%region%_powerupgrade_nsw_propdata.lua"
copy "startingforest_powerupgrade_nw_propdata.lua"   "%region%_powerupgrade_nw_propdata.lua"
copy "startingforest_powerupgrade_sw_propdata.lua"   "%region%_powerupgrade_sw_propdata.lua"
copy "startingforest_small_esw_propdata.lua"         "%region%_small_esw_propdata.lua"
copy "startingforest_small_ew_propdata.lua"          "%region%_small_ew_propdata.lua"
copy "startingforest_small_new_propdata.lua"         "%region%_small_new_propdata.lua"
copy "startingforest_small_nsw_propdata.lua"         "%region%_small_nsw_propdata.lua"
copy "startingforest_small_nw_propdata.lua"          "%region%_small_nw_propdata.lua"
copy "startingforest_small_sw_propdata.lua"          "%region%_small_sw_propdata.lua"
copy "startingforest_kitchen_nesw_propdata.lua"      "%region%_kitchen_nesw_propdata.lua"
copy "startingforest_minigame_nesw_propdata.lua"     "%region%_minigame_nesw_propdata.lua"
copy "startingforest_potion_nesw_propdata.lua"       "%region%_potion_nesw_propdata.lua"
copy "startingforest_powerupgrade_nesw_propdata.lua" "%region%_powerupgrade_nesw_propdata.lua"
copy "startingforest_small_nesw_propdata.lua"        "%region%_small_nesw_propdata.lua"
copy "startingforest_specialevent_conversation_esw_propdata.lua"  "%region%_specialevent_conversation_esw_propdata.lua"
copy "startingforest_specialevent_conversation_ew_propdata.lua"   "%region%_specialevent_conversation_ew_propdata.lua"
copy "startingforest_specialevent_conversation_new_propdata.lua"  "%region%_specialevent_conversation_new_propdata.lua"
copy "startingforest_specialevent_conversation_nsw_propdata.lua"  "%region%_specialevent_conversation_nsw_propdata.lua"
copy "startingforest_specialevent_conversation_nw_propdata.lua"   "%region%_specialevent_conversation_nw_propdata.lua"
copy "startingforest_specialevent_conversation_sw_propdata.lua"   "%region%_specialevent_conversation_sw_propdata.lua"
copy "startingforest_specialevent_conversation_nesw_propdata.lua" "%region%_specialevent_conversation_nesw_propdata.lua"
