local Enum = require "util.enum"
local strict = require "util.strict"


local qconstants = {}

qconstants.QUIP_WEIGHT = {
    -- Magical numbers that weigh quips very high, so that they get spoken, if applicable.
    Quest = 100,
    Convo = 200, -- higher for even more specific scope
}
strict.strictify(qconstants.QUIP_WEIGHT, "qconstants.QUIP_WEIGHT")

qconstants.MODS = {
    ITEM_BUY_RATE = 1,
    GET_PAID_MONEY = 1,
    PAY_MONEY = 1,
}
qconstants.GENDER = Enum{ "MALE", "FEMALE", "NONBINARY", }
qconstants.ETAG = Enum{ "PLAYER", }
qconstants.OPINION = Enum{ "NEUTRAL", }


-------------------------------------------------------------------------------------------

qconstants.RELATIONSHIP = Enum{
    -- Single-minded hatred: they will go out of their way to pursue and undermine you.
    "HATED",
    -- You did something to piss them off. They won't interact with you.
    "DISLIKED",
    -- This person's identity is unknown but they also carry a suspicious/unfavorable disposition towards you.
    "SUSPICIOUS",
    -- The default for everyone you haven't explicitly met: you don't know their name, and they treat
    -- you at arm's lenght.
    "STRANGER",
    -- You gained their trust. You know their name. They'll deal with you.
    "ACQUAINTED",
    -- They call themselves a friend!
    "LIKED",
    -- They're more than a friend. They are loyal to you and will do everything they can to help you.
    "LOVED",
}
qconstants.RELATIONSHIP_OPINION = {
    HATED = -50,
    DISLIKED = -15,
    SUSPICIOUS = -5,
    STRANGER = 0,
    ACQUAINTED = 10,
    LIKED = 25,
    LOVED = 75,
}
strict.strictify(qconstants.RELATIONSHIP_OPINION, "qconstants.RELATIONSHIP_OPINION")

qconstants.RELATIONSHIP_PROPERTIES =
{
    HATED = { friendly = false, unfriendly = true, identity_known = true, reputation = -20 },
    DISLIKED = { friendly = false, unfriendly = true, identity_known = true, reputation = -10 },
    SUSPICIOUS = { friendly = false, unfriendly = true, identity_known = false, reputation = -5 },
    STRANGER = { friendly = false, unfriendly = false, identity_known = false, reputation = 0 },
    ACQUAINTED = { friendly = true, unfriendly = false, identity_known = true, reputation = 2 },
    LIKED = { friendly = true, unfriendly = false, identity_known = true, reputation = 10 },
    LOVED = { friendly = true, unfriendly = false, identity_known = true, reputation = 20 },
}
strict.strictify(qconstants.RELATIONSHIP_PROPERTIES, "qconstants.RELATIONSHIP_PROPERTIES")

for k, v in ipairs(qconstants.RELATIONSHIP:Ordered()) do
    assert( qconstants.RELATIONSHIP_PROPERTIES[v] ~= nil )
end


qconstants.TIMES = strict.readonly({
        JOB_TIME_DEFAULT = 1,
    })

return qconstants
