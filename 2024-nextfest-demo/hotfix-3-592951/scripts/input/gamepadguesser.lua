-- GamepadGuesser
--
-- Guess the platform of your lua Joysticks from their names.
--
-- https://github.com/idbrii/love-gamepadguesser
--
-- Copyright © 2022 idbrii.
-- Released under the MIT License.


local gamepadguesser = {}

local all_patterns = {
    -- KLEI: These patterns match the keys in DEVICE_MAP.
    -- No patterns for xbox because that's the default.
    ps4 = {
        "%f[%w]PS[1-4]%f[%D]",
        "%f[%d]8BitDo P%d", -- PS1-style
    },
    ps5 = {
        "%f[%w]PS[5-9]%f[%D]", "Sony%s", "Play[Ss]tation", "DualSense",
    },
    nxpro = {
        "Wii%f[%L]",
        "%f[%u]S?NES%f[%U]", "%f[%l]s?nes%f[%L]", "%f[%u]Famicom%f[%L]",
        "%f[%u]N64%f[%D]",
        "%f[%u]GameCube%f[%L]",
        "%f[%u]Switch%f[%L]",
        "%f[%d]8BitDo SN?%d", -- SNES-style
        "%f[%d]8BitDo N%d", -- NES-style
    },
    nxjoycon = {
        "Joy[- ]Cons?%f[%L]",
    },
    -- Our art doesn't have sega and I don't have a sega gamepad to test with,
    -- so don't include it.
    --~ sega = {
    --~     -- Be very cautious since sega gamepads are rare.
    --~     "%f[%a]Sega%f[%W]",
    --~ },
}

local function getNameFromMapping(mapping)
    return mapping:match("^%x*,(.-),")
end

function gamepadguesser.test_printAllGuesses(db_fpath)
    local f = io.open(db_fpath, "r")
    for line in f:lines() do
        if line:match('^%x') then
            local name = getNameFromMapping(line)
            assert(name, line)
            local console = gamepadguesser.joystickNameToConsole(name)
            if name then
                print(console, '<-', name)
            end
        end
    end
    f:close()
end



-- Map a joystick name (e.g., from gamecontrollerdb) to a console.
function gamepadguesser.joystickNameToConsole(name)
    for console,patterns in pairs(all_patterns) do
        for _,pat in ipairs(patterns) do
            if name:match(pat) then
                return console
            end
        end
    end
    -- Xbox button layout is ubiquitous
    return "xbox"
end


local function test_simple_cases()
    -- These are actual names provided by controllers I plugged into the game.
    assert("nxpro" == gamepadguesser.joystickNameToConsole("Nintendo Switch Pro Controller"))
    assert("ps4" == gamepadguesser.joystickNameToConsole("PS4 Controller"))
    assert("ps5" == gamepadguesser.joystickNameToConsole("DualSense Wireless Controller"))
    assert("xbox" == gamepadguesser.joystickNameToConsole("Controller (XBOX 360 For Windows)")) -- steam controller
    assert("xbox" == gamepadguesser.joystickNameToConsole("Xbox 360 Controller for Windows"))
    assert("xbox" == gamepadguesser.joystickNameToConsole("Xbox 360 Controller"))

    -- These were old special cases in DEVICE_MAP.
    assert("ps5" == gamepadguesser.joystickNameToConsole("DualSense Wireless Controller"))
    assert("ps4" == gamepadguesser.joystickNameToConsole("PS4 Controller"))
    assert("xbox" == gamepadguesser.joystickNameToConsole("XInput Controller"))
    assert("nxpro" == gamepadguesser.joystickNameToConsole("Nintendo Switch Pro Controller"))
end

-- Not useful as a testy test, so uncomment to run and inspect results.
--~ gamepadguesser.test_printAllGuesses("data/gamecontrollerdb.txt")

return gamepadguesser
