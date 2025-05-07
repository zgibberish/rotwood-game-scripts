local Enum = require "util.enum"

local CustomScript = Class(function(self)
end)

function CustomScript:PropEdit(prop_editor, ui, prop_params)
end

function CustomScript:LivePropEdit(prop_editor, ui, prop_params, script_defaults)
end

function CustomScript:Apply(prop_entity, script_args)
end

function CustomScript:CollectAssets(assets, script_args)
end

function CustomScript:CollectPrefabs(prefabs, script_args)
end

function CustomScript:CustomInit(inst, script_args)
end

CustomScript.default = CustomScript()

Market = Enum {
	"Meta",
	"Run",
	"Dye"
}

local WareDispenser = Class(CustomScript, function(self, inst)
	self.index = 1
	self.market = Market.s.Meta
	if inst then
		self:CustomInitImpl(inst)
	end
end)
local Super = WareDispenser._base

WareDispenser.INDEX_MAXIMUM = 5

function WareDispenser:CustomInitImpl(inst)
	inst.EditEditable = WareDispenser.EditEditable -- Assign this for handling editable UI for this
end

function WareDispenser:CustomInit(inst, script_args)
	Super.CustomInit(self, inst, script_args)
	self:CustomInitImpl(inst)
end

-- Invoked via EditableEditor/LevelPropLayoutEditor.
function WareDispenser.EditEditable(inst, ui)
	local id = "##WareDispenser.EditEditable"
	if not ui:CollapsingHeader("Ware Dispenser"..id) then
		return
	end

	ui:Indent()
	local self = inst.components.prop.script_args

	local changed, new = ui:ComboAsString("Market"..id, self.market, Market:Ordered())
	if changed then
		self.market = new
		inst.components.prop:OnPropChanged()
	end

	local changed, new = ui:SliderInt("Index"..id, self.index, 1, WareDispenser.INDEX_MAXIMUM)
	if changed then
		self.index = new
		inst.components.prop:OnPropChanged()
	end
	
	ui:Unindent()
end

WareDispenser.default = WareDispenser()

return WareDispenser
