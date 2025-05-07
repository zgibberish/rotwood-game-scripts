return {

    ----------------------------NOTES----------------------------
    --[[
        --The strings for these titles can be found in data/scripts/defs/cosmetics/strings_cosmetics.lua
        
        --Titles can be batch generated and/or individually edited in the Cosmetic Editor in-game (control-P and type "cosmetic editor")
        
        --Autogenning titles using the "Gen from batch" button will create game files that can be found at
        data/scripts/prefabs/autogen/cosmetic

        --The "Gen from batch" button *won't* delete game files if a title has been removed, so you'll have to
        go into data/scripts/prefabs/autogen/cosmetic and delete the file to remove a title from the game

        --If you group select all the files in data/scripts/prefabs/autogen/cosmetic and delete them to do a fresh gen batch, 
        make sure you don't delete the default_title.lua or the game will have no title to default to and will crash
    ]]

    ----------------------------TITLES----------------------------

    --UNASSIGNED!-- These titles have no associated mastery. Give them a home!
        {
            name = "buckaroo",
            mastery="none",
            rarity="COMMON",
            cosmetic_data={ title_key="BUCKAROO",},
        },
        {
            name = "ace",
            mastery="none",
            rarity="COMMON",
            cosmetic_data={ title_key="ACE",},
        },
        {
            name = "pawbeans",
            mastery="none",
            rarity="COMMON",
            cosmetic_data={ title_key="PAWBEANS",},
        },
        --queen/king/royalty should unlock together
        {
            name = "highqueen",
            mastery="none",
            rarity="LEGENDARY",
            cosmetic_data={ title_key="HIGHQUEEN",},
        },
        {
            name = "highking",
            mastery="none",
            rarity="LEGENDARY",
            cosmetic_data={ title_key="HIGHKING",},
        },
        {
            name = "highroyalty",
            mastery="none",
            rarity="LEGENDARY",
            cosmetic_data={ title_key="HIGHROYALTY",},
        },
        {
            name = "goofygoober",
            mastery="none",
            rarity="COMMON",
            cosmetic_data={ title_key="GOOFYGOOBER",},
        },
        {
            name = "shredder",
            mastery="none",
            rarity="COMMON",
            cosmetic_data={ title_key="SHREDDER",},
        },
        {
            name = "creepycryptid",
            mastery="none",
            rarity="EPIC",
            cosmetic_data={ title_key="CREEPYCRYPTID",},
        },
        {
            name = "teammascot",
            mastery="none",
            rarity="COMMON",
            cosmetic_data={ title_key="TEAMMASCOT",},
        },
        {
            name = "pocketmedic",
            mastery="none",
            rarity="COMMON",
            cosmetic_data={ title_key="POCKETMEDIC",},
        },
        {
            name = "glasscannon",
            mastery="none",
            rarity="COMMON",
            cosmetic_data={ title_key="GLASSCANNON",},
        },
        {
            name = "tank",
            mastery="none",
            rarity="COMMON",
            cosmetic_data={ title_key="TANK",},
        },
        --maybe from crafting a certain number of armour pieces?
        {
            name = "fashionista",
            mastery="none",
            rarity="COMMON",
            cosmetic_data={ title_key="FASHIONISTA",},
        },
        {
            name = "jokesclown",
            mastery="none",
            rarity="COMMON",
            cosmetic_data={ title_key="JOKESCLOWN",},
        },
        {
            name = "mysteriousstranger",
            mastery="none",
            rarity="COMMON",
            cosmetic_data={ title_key="MYSTERIOUSSTRANGER",},
        },
        {
            name = "chickenchaser",
            mastery="none",
            rarity="COMMON",
            cosmetic_data={ title_key="CHICKENCHASER",},
        },
        {
            name = "impostor",
            mastery="none",
            rarity="COMMON",
            cosmetic_data={ title_key="IMPOSTOR",},
        },

    --------------------------

    --HAMMER ("HAMMER_MASTERY")--
        --golf swing mastery
        {
            name = "albatross",
            mastery="HAMMER_MASTERY",
            rarity="COMMON",
            
            cosmetic_data={ title_key="ALBATROSS",},
        },
    --------------------------

    --POLEARM ("POLEARM_MASTERY")--
        --advanced drill mastery
        {
            name = "drillsergeant",
            mastery="POLEARM_MASTERY",
            rarity="EPIC",
            
            cosmetic_data={ title_key="DRILLSERGEANT",},
        },
    --------------------------
    
    --CANNON ("CANNON_MASTERY")--
        {
            name = "boomer",
            mastery="NONE",
            rarity="COMMON",
            
            cosmetic_data={ title_key="BOOMER",},
        },
    --------------------------

    --STRIKER ("STRIKER_MASTERY")--
        {
            name = "juggler",
            mastery="NONE",
            rarity="COMMON",
            
            cosmetic_data={ title_key="JUGGLER",},
        },
    --------------------------

    --ALL WEAPONS--
        --all weapon mastery
        {
            name = "battlemaster",
            mastery="NONE",
            rarity="LEGENDARY",
            
            cosmetic_data={ title_key="BATTLEMASTER",},
        },
    --------------------------

    --TREEMON FOREST TITLES--
        --cabbage roll mastery
        {
            name = "lilbuddy",
            mastery="CABBAGEROLL_MASTERY",
            rarity="COMMON",
            
            cosmetic_data={ title_key="LILBUDDY",},
        },

        --beets mastery
        {
            name = "beetmaster",
            mastery="NONE",
            rarity="COMMON",
            
            cosmetic_data={ title_key="BEETMASTER",},
        },

        --zucco, gourdo, yammo kill mastery
        {
            name = "piemaster",
            mastery="NONE",
            rarity="EPIC",
            
            cosmetic_data={ title_key="PIEMASTER",},
        },

        --treemon mastery
        {
            name = "treehugger",
            mastery="NONE",
            rarity="COMMON",
            
            cosmetic_data={ title_key="TREEHUGGER",},
        },

        --megatreemon mastery
        {
            name = "forestkeeper",
            mastery="NONE",
            rarity="LEGENDARY",
            
            cosmetic_data={ title_key="FORESTKEEPER",},
        },

        --gnarlic mastery
        {
            name = "stinky",
            mastery="NONE",
            rarity="COMMON",
            
            cosmetic_data={ title_key="STINKY",},
        },
    --------------------------

    --OWLITZER FOREST TITLES--
        --owlitzer mastery
        {
            name = "nightshroud",
            mastery="NONE",
            rarity="LEGENDARY",
            
            cosmetic_data={ title_key="NIGHTSHROUD",},
        },

        --floracrane mastery
        {
            name = "primaballerina",
            mastery="NONE",
            rarity="EPIC",
            
            cosmetic_data={ title_key="PRIMABALLERINA",},
        },

        --eyev mastery
        {
            name = "watcher",
            mastery="NONE",
            rarity="COMMON",
            
            cosmetic_data={ title_key="WATCHER",},
        },
    --------------------------

    --BANDICOOT SWAMP TITLES--
        --bandicoot mastery
        {
            name = "madtrickster",
            mastery="NONE",
            rarity="LEGENDARY",
            
            cosmetic_data={ title_key="MADTRICKSTER",},
        },

        --slowpoke mastery
        {
            name = "chubbster",
            mastery="NONE",
            rarity="COMMON",
            
            cosmetic_data={ title_key="CHUBBSTER",},
        },

        --woworm mastery
        {
            name = "woworm",
            mastery="NONE",
            rarity="COMMON",
            
            cosmetic_data={ title_key="WOWORM",},
        },
    --------------------------
}