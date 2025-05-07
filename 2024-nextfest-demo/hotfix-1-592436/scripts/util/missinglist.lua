-- Visualized with DebugMissingAssets.
local missinglist = {}

local items = {}

function missinglist.AddMissingItem(category, item, msg)
	local cat = items[category] or {}
	items[category] = cat
	table.insert(cat, {
			name = item,
			msg = msg,
		})
end

function missinglist.GetAllMissing()
	return items
end

return missinglist
