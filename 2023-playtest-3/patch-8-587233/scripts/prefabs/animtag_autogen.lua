local AnimTageAutogenData = require "prefabs.animtag_autogen_data"

local prop_data = require("prefabs.prop_autogen_data")

local function GetBaseAnim(prefab)
	if prop_data[prefab] then
		-- should be able to get the root from there, it's the item at depth 0
		local parallax = prop_data[prefab].parallax
		for j,v in pairs(parallax) do
			if not v.dist or v.dist == 0 then
				local baseanim = v.anim
				return baseanim
			end
		end
	end
end

function UpdateBaseAnims()
	local dirty = false
	for i,def in pairs(AnimTageAutogenData) do
		for i,v in pairs(def.prefab or {}) do
			local baseanim = GetBaseAnim(v.prefab)
			if baseanim and v.baseanim ~= baseanim then
				v.baseanim = baseanim
				dirty = true
			end
		end
	end
	return dirty
end

function ApplyAnimEvents()
	UpdateBaseAnims()
	TheSim:ClearRegisteredAnimEvents()
	for i,def in pairs(AnimTageAutogenData) do
		local postfixes = {}
		for i,v in pairs(def.prefab or {}) do
			local postfix = v.baseanim and ("_"..v.baseanim) or ""
			postfixes[postfix] = true
		end
		for bankfile, animlist in pairs(def.anim_events or {}) do
			for anim,animdata in pairs(animlist) do
				for i,event in pairs(animdata.events or {})  do
					for postfix,_ in pairs(postfixes) do
						TheSim:RegisterAnimationEvent("anim/"..bankfile..".zip", anim .. postfix, event.frame, event.name)
					end
				end
			end
		end
	end
	TheSim:ApplyRegisteredAnimEvents()
end

function AnimTagInit()
	ApplyAnimEvents()
end

return AnimTagInit
