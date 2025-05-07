local ContentNode = require "questral.contentnode"
local contentutil = require "questral.util.contentutil"


local SimContent = Class(function(self, ...) self:init(...) end)
SimContent:add_mixin( ContentNode )

SimContent._classname = "SimContent"
SimContent:UseClassAsKey()

function SimContent:init(id)
    assert(id)
    self:SetContentID(id)
    dbassert(self:GetContentID(), "Use SimContent.CreateContent to define base content classes that will be named after their class.")
end

-- Create generic content.
function SimContent.CreateContent()
    local q = Class(SimContent)
    q:SetContentID(contentutil.BuildClassNameFromCurrentFile())
    return q
end

function SimContent:__serialize()
    return { _content_key = self:GetContentKey(), _content_id = self:GetContentID() }
end

return SimContent
