
local ERRORS = {
    CONFIG_DIR_WRITE_PERMISSION = {
        message = "Unable to write to config directory. Please make sure you have permissions for your Klei save folder.",
        url = "https://support.klei.com/hc/en-us/articles/360029882171",
    },
    CONFIG_DIR_READ_PERMISSION = {
        message = "Unable to read from config directory. Please make sure you have read permissions for your Klei save folder.",
        url = "https://support.klei.com/hc/en-us/articles/360035294792",
    },
    CUSTOM_COMMANDS_ERROR = {
        message = "Error loading customcommands.lua.",
    },
    AGREEMENTS_WRITE_PERMISSION = {
        message = "Unable to write to the agreements file. Please make sure you have permissions for your Klei save folder.",
        url = "https://support.klei.com/hc/en-us/articles/360029881751",
    },
    CONFIG_DIR_DISK_SPACE = {
        message = "There is not enough available hard drive space to reliably save worlds. Please free up some hard drive space.",
    },

}

if DEV_MODE then
    -- These are developer-specific and should only be used inside DEV_MODE.
    ERRORS.DEV_FAILED_TO_SPAWN_WORLD = {
        message = "Failed to load world from save slot.\n\n Delete the save you loaded.\n If you used Host Game, delete your first saveslot.",
    }
    ERRORS.DEV_FAILED_TO_LOAD_PREFAB = {
        message = "Failed to load prefab from file '%s'.\n\n Run updateprefabs.bat to fix.",
    }
    ERRORS.DEV_FAILED_TO_SPAWN_PREFAB = {
        message = "Failed to spawn prefab '%s'.\n\n Ensure it's set as a dependency somewhere (prop, level) and run updateprefabs.bat.",
    }
end

local known_error = {}

-- context_txt should only be internal text (prefab names) so it doesn't need
-- to be translated.
function known_assert(condition, key, context_txt)
    if not condition then
        context_txt = context_txt or ""
        local msg = key
        if ERRORS[key] then
            known_error.key = key
            known_error.message = ERRORS[key].message
            known_error.url = ERRORS[key].url
            known_error.message = known_error.message:format(context_txt)
            msg = known_error.message
        end
        error(msg, 2)
    end
    return condition
end

function GetCurrentKnownError()
    if known_error.key then
        return known_error
    end
end

