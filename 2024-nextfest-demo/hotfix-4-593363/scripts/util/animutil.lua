-- Some ease-of-use functions for working with animation hierarchies.

local animutil = {}

animutil.ForEachAnimState = function(inst, fn)
	fn(inst.AnimState)
	if inst.highlightchildren then
		for _, child in ipairs(inst.highlightchildren) do
			fn(child.AnimState)
		end
	end
end

animutil.OverrideSymbol = function(inst, symbol, build, override_symbol)
	TheLog.ch.AnimSpam:printf("OverrideSymbol: %s -> %s[%s]", symbol, build, override_symbol)
	animutil.ForEachAnimState(inst, function(anim_state) 
		anim_state:OverrideSymbol(symbol, build, override_symbol) 
	end)
end

animutil.OverrideSymbolMultColor = function(inst, symbol, r, g, b, a)
	animutil.ForEachAnimState(inst, function(anim_state) 
		anim_state:SetSymbolMultColor(symbol, r, g, b, a)
	end)
end

animutil.HideSymbol = function(inst, symbol)
	animutil.ForEachAnimState(inst, function(anim_state) 
		anim_state:HideSymbol(symbol)
	end)
end

return animutil
