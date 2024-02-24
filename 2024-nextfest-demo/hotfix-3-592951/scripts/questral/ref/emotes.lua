local CommsCharacter = require "ui.widgets.commscharacter"
--NOT USED!! real emotes can be found in data \ scripts \ defs \ emotion.lua -Kris
return
{
    thought = {
        mood = CommsCharacter.MOOD.NEUTRAL,
        anim = "thought"
    },

    shrug = {
        mood = CommsCharacter.MOOD.NEUTRAL,
        anim = "shrug"
    },

    sigh = {
        mood = CommsCharacter.MOOD.NEUTRAL,
        anim = "sigh",
        no_blink = true,
    },

    threaten = {
        mood = CommsCharacter.MOOD.NEUTRAL,
        anim = "threaten"
    },

    whatever = {
        mood = CommsCharacter.MOOD.NEUTRAL,
        anim = "whatever",
        no_blink = true,
    },

    agree = {
        mood = CommsCharacter.MOOD.NEUTRAL,
        anim = "agree",
        no_blink = true,
    },

    disagree = {
        mood = CommsCharacter.MOOD.NEUTRAL,
        anim = "disagree",
        no_blink = true,
    },

    greeting = {
        mood = CommsCharacter.MOOD.NEUTRAL,
        anim = "greeting"
    },

    smirk = {
        mood = CommsCharacter.MOOD.NEUTRAL,
        anim = "smirk",
        no_blink = true,
    },

    whoa = {
        mood = CommsCharacter.MOOD.NEUTRAL,
        anim = "whoa",
        no_blink = true,
    },

    aloof = {
        mood = CommsCharacter.MOOD.NEUTRAL,
        anim = "aloof",
        no_blink = true,
    },

    shoot = {
        mood = CommsCharacter.MOOD.PILOT_SHOOT,
        anim = "shoot"
    },

    hit = {
        from_any_mood = true,
        mood = CommsCharacter.MOOD.PILOT_FLIGHT,
        anim = "hit",
        priority = 100,
    },

    ship_interact = {
        from_any_mood = true,
        mood = CommsCharacter.MOOD.PILOT_FLIGHT,
        anim = "ship_interact",
    },
    interact = {
        mood = CommsCharacter.MOOD.NEUTRAL,
        anim = "interact",
    },

    death = {
        from_any_mood = true,
        anim = "death",
        no_blink = true,
        terminal = true,
        priority = 10000,
    },

    cheer = {
        from_any_mood = true,
        mood = CommsCharacter.MOOD.PILOT_FLIGHT,
        anim = "cheer",
    },

    yes = {
        vocalization_override = CommsCharacter.VOCALIZATION.POSITIVE,
    },

    no = {
        vocalization_override = CommsCharacter.VOCALIZATION.NEGATIVE,
    },

    neutral = {
        mood = CommsCharacter.MOOD.NEUTRAL,
    },

    angry = {
        mood = CommsCharacter.MOOD.ANGRY,
    },

    happy = {
        mood = CommsCharacter.MOOD.HAPPY,
    },

    scared = {
        mood = CommsCharacter.MOOD.SCARED,
    },

    laugh = {
        mood = CommsCharacter.MOOD.NEUTRAL,
        anim = "laugh"
    },
}
