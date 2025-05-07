local Enum = require "util.enum"
local colorutil = require "util.colorutil"
local ScriptLoader = require "questral.scriptloader"

local prefabutil = {}

function prefabutil.RegisterHitbox(inst, name, hitboxinst)
	-- if we're registered to a parent, get their hitflags. Requires ordered registering
	if hitboxinst then
		assert(inst.components.hitbox, "Can't register a hitbox before the main entity has been registered")
		hitboxinst.HitBox:SetHitGroup(HitGroup.MOB)
		hitboxinst.HitBox:SetHitFlags(HitGroup.CHARACTERS)
	end
	hitboxinst = hitboxinst or inst
	inst.hitboxes = inst.hitboxes or {}

	if not inst.hitboxes[name] then
		-- TheLog.ch.PrefabUtil:printf("Entity %s registered hitbox '%s'", inst, name)
		inst.hitboxes[name] = hitboxinst
	end
end

local function TryAddAsset(assets, assettype, path, force)
	if not force or softresolvefilepath(path) ~= nil then
		assets[#assets + 1] = Asset(assettype, path)
		return true
	end
end
prefabutil.TryAddAsset = TryAddAsset -- more likely, use other functions in here.

function prefabutil.TryAddAsset_Anim(assets, build, force)
	local path = "anim/".. build ..".zip"
	return TryAddAsset(assets, "ANIM", path, debug)
end

function prefabutil.CollectAssetsForAnim(assets, build, bank, bankfile, force)
	prefabutil.TryAddAsset_Anim(assets, build, force)

	if bankfile ~= nil and bankfile ~= build then
		prefabutil.TryAddAsset_Anim(assets, bankfile, force)
	end
end

function prefabutil.CollectAssetsAndPrefabsForScript(assets, prefabs, name, scriptfile, script_args, force)
	if not scriptfile then
		return
	end
	if TryAddAsset(assets, "PKGREF", "scripts/prefabs/customscript/"..scriptfile..".lua", force) then
		local script = require("prefabs.customscript."..scriptfile)
		if script ~= nil then
			script = script[name] or script.default
			if script ~= nil then
				local args = deepcopy(script_args or {})
				args.prefab = name
				if script.CollectAssets ~= nil then
					script.CollectAssets(assets, args)
				end
				if script.CollectPrefabs ~= nil then
					script.CollectPrefabs(prefabs, args)
				end
			end
		end
	end
end

function prefabutil.CollectAssetsForParticleSystem(assets, params, force)
	local dupe = {}
	for i,emitter in pairs(params.emitters or {}) do
		if emitter.texture ~= nil then
			local img = emitter.texture[1]
			if img ~= nil and string.len(img) > 5 and string.sub(img, -4) then
				img = string.sub(img, 1, -5)
				if not dupe[img] then
					dupe[img] = true
					assets[#assets + 1] = Asset("ATLAS", "images/"..img..".xml")
					assets[#assets + 1] = Asset("IMAGE", "images/"..img..".tex")
				end
			end
		end
	end
end

function prefabutil.ApplyScript(inst, prefab, scriptfile, script_args)
	if not scriptfile then
		return
	end
	local script = require("prefabs.customscript."..scriptfile)
	if script ~= nil then
		local args = deepcopy(script_args or {})
		args.prefab = prefab
		script = script[prefab] or script.default
		if script ~= nil and script.CustomInit ~= nil then
			script.CustomInit(inst, args)
		end
	end
end



-- Shared code between x_autogen and xeditor.

function prefabutil.ColorCubeNameToTex(colorcube)
	colorcube = colorcube or "identity_cc"
	return "images/color_cubes/".. colorcube ..".tex"
end

local ProgressSegments = Enum{
	"Any", -- not a real value. only for editor.
	"early",
	"midway",
	"nearboss",
}
prefabutil.ProgressSegments = ProgressSegments
function prefabutil.ProgressToSegment(dungeon_progress)
	if dungeon_progress >= 0.75 then
		return ProgressSegments.s.nearboss
	elseif dungeon_progress >= 0.5 then
		return ProgressSegments.s.midway
	else
		return ProgressSegments.s.early
	end
end
local function test_ProgressSegments()
	local current_segment = prefabutil.ProgressToSegment(1)
	assert(current_segment == prefabutil.ProgressSegments.s.nearboss)
end

function prefabutil.SetupDeathFxPrefabs(prefabslist, prefab_name)
	table.insert(prefabslist, "fx_deaths")
	table.insert(prefabslist, "death_" .. prefab_name .. "_frnt")
	table.insert(prefabslist, "death_" .. prefab_name .. "_grnd")
end

function prefabutil.LoadAutogenDefs(category)
	local defs = {}
	local base_path = "scripts/prefabs/autogen/"..category
	ScriptLoader:LoadAllScript(base_path,  function(filename, result)
												local key = result.__displayName
												defs[key] = result
											end)
	return defs
end

return prefabutil
