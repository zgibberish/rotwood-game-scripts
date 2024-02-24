local Hsb = require "util.hsb"

local PropColorVariant = Class(function(self, variant)
	self.color = Hsb()
	self.likelihood = 1
end)

PropColorVariant.CLIPBOARD_CONTEXT = "++prop_color_variant"

function PropColorVariant.FromDeprecatedVariant(deprecated_variant)
	local variant = PropColorVariant()
	variant.color = Hsb.FromRawTable({
		hue = deprecated_variant.hue,
		saturation = deprecated_variant.saturation,
		brightness = deprecated_variant.brightness
	})
	variant.likelihood = deprecated_variant.likelihood
	return variant
end

function PropColorVariant.FromRawTable(raw_table)
	local variant = PropColorVariant()
	for k, v in pairs(raw_table) do
		variant[k] = v
	end
	variant.color = Hsb.FromRawTable(raw_table.color)
	return variant
end

function PropColorVariant:GetLabel()
	return self.name or self.color:GetLabel()
end

function PropColorVariant:Ui(ui, id)
	self.name = ui:_InputTextWithHint("Name"..id, self:GetLabel(), self.name)
	if self.name == "" then
		self.name = nil
	end
	local new_color = self.color:Ui(ui, id.."Color")
	if new_color then
		self.color = new_color
	end
	self.likelihood = ui:_DragFloat("Likelihood"..id, self.likelihood, 0.01, 0.01, 100)
end

local function SelectableUi(context, ui, id, index, color_variant, selected_variant)
	local deferred_fn
	local changed, is_selected = ui:Selectable(
		"[" .. index .. "] " .. color_variant:GetLabel() .. id,
		selected_variant == index
	)
	if changed then
		selected_variant = is_selected and index or nil
	end
	if selected_variant == index then
		ui:Indent()
		local new_selected_variant, color_variant_fn = ui:ListElementManipulators(
			PropColorVariant.CLIPBOARD_CONTEXT,
			id,
			context.color_variants,
			selected_variant,
			PropColorVariant,
			PropColorVariant.FromRawTable
		)
		if new_selected_variant then
			selected_variant = new_selected_variant
			deferred_fn = color_variant_fn
		end

		color_variant:Ui(ui, id)

		ui:Unindent()
	end
	return deferred_fn, selected_variant
end

function PropColorVariant.ColorVariantsUi(context, ui, id, selected_variant)
	if not ui:CollapsingHeader("Color Variants"..id) then
		return
	end
	ui:Indent()
	if not context.color_variants then
		context.color_variants = {}
	end
	local deferred_fn
	for i, color_variant in ipairs(context.color_variants) do
		local color_variant_fn
		color_variant_fn, selected_variant = SelectableUi(context, ui, id .. i, i, color_variant, selected_variant)
		if color_variant_fn then
			deferred_fn = color_variant_fn
		end
	end
	if deferred_fn then
		deferred_fn()
	end
	if ui:Button(ui.icon.add .. id) then
		table.insert(context.color_variants, PropColorVariant() )
	end
	ui:SetTooltipIfHovered("Add Color Variant")
	ui:SameLineWithSpace()
	local pasted = ui:PasteButton(PropColorVariant.CLIPBOARD_CONTEXT, id.."PasteColorVariant", "Paste Color Variant")
	if pasted then
		table.insert(context.color_variants, PropColorVariant.FromRawTable(pasted))
	end
	ui:Unindent()
	return selected_variant
end

function PropColorVariant.ChooseColorVariant(rng, context)
	if not context.color_variants then
		return
	end
	local choice = WeightedChoice(
		rng,
		context.color_variants, 
		function(variant) return variant.likelihood end
	)
	if not choice then
		return
	end
	-- Strip the metatable so the color can be persisted in the save data.
	local color = deepcopy( choice.color)
	setmetatable(color, nil)
	return color
end

return PropColorVariant
