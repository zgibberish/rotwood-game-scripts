local Power = require "defs.powers"
local Widget = require("widgets/widget")
local Image = require("widgets/image")
local lume = require("util/lume")

local UPGRADES_TO_TEXTURE =
{
	-- power starts at common
	[Power.Rarity.COMMON] =
	{
		"images/ui_ftf_powers/pips_0-0.tex",
		"images/ui_ftf_powers/pips_0-1.tex",
		"images/ui_ftf_powers/pips_0-2.tex",
	},
	-- power starts at epic
	[Power.Rarity.EPIC] = 
	{
		"images/ui_ftf_powers/pips_1-1.tex",
		"images/ui_ftf_powers/pips_1-2.tex",
	},
	-- power starts at legendary
	[Power.Rarity.LEGENDARY] =
	{
		"images/ui_ftf_powers/pips_2-2.tex",
	},
}

local PowerPipsWidget = Class(Widget, function(self)
	Widget._ctor(self, "PowerPipsWidget")

	self.image_root = self:AddChild(Widget("Root"))
	self.pip_fill = self.image_root:AddChild(Image("images/ui_ftf_powers/pips_0-2.tex"))
	self.pip_border = self.image_root:AddChild(Image("images/ui_ftf_powers/pips_border.tex"))
	self.pip_border:LayoutBounds("center", "center", self.pip_fill)
end)

-- Accepts power ItemInstance instead of pow since may present unselected powers.
function PowerPipsWidget:SetPower(power)
	self.power = power
	self.def = power:GetDef()
	self:UpdatePips()
end

function PowerPipsWidget:UpdatePips()
	-- local num_pips = 3 -- lume.count(self.def.tuning)
	local base_rarity = Power.GetBaseRarity(self.def)
	local base_rarity_idx = lume.find(Power.RarityIdx, Power.GetBaseRarity(self.def))
	local current_rarity_idx = lume.find(Power.RarityIdx, self.power:GetRarity())
	local pip_idx = (current_rarity_idx - base_rarity_idx) + 1
	local tex = UPGRADES_TO_TEXTURE[base_rarity][pip_idx]
	dbassert(tex, self.def.name)
	self.pip_fill:SetTexture(tex)
end

return PowerPipsWidget
