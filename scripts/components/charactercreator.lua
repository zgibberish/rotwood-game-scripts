local Cosmetic = require("defs.cosmetics.cosmetics")
local krandom = require("util.krandom")
local lume = require("util.lume")

local CharacterCreator = Class(function(self, inst)
	self.inst = inst
	self.isnew = true
	self.bodyparts = {}
	self.colorgroups = {}
	self.filtertags = {}
	self.symboltags = {}

	for colorgroup in pairs(Cosmetic.ColorGroups) do
		local colors = self:GetColorList(colorgroup)
		self:SetColorGroup(colorgroup, colors[1].name)
	end

	self:SetSpecies("ogre")
end)

local species_heads = 
{
	[CHARACTER_SPECIES.CANINE] = "canine_head_1",
	[CHARACTER_SPECIES.MER] = "mer_head_1",
	[CHARACTER_SPECIES.OGRE] = "ogre_head_1",
}

function CharacterCreator:GetSpecies()
	return self.species
end

function CharacterCreator:SetSpecies(species)
	if self:GetSpecies() == species then
		return
	end

	self.species = species

	local replaced_parts = {}
	for bodypart in pairs(Cosmetic.BodyPartGroups) do
		local name = self.bodyparts[bodypart]
		if name ~= nil then
			local def = Cosmetic.BodyParts[bodypart][name]
			if def.filtertags and not def.filtertags[species] then
				table.insert(replaced_parts, bodypart)
			end
		else
			table.insert(replaced_parts, bodypart)
		end
	end

	for _, bodypart in ipairs(replaced_parts) do
		local candidate_parts = Cosmetic.GetSpeciesBodyParts(bodypart, species)
		if #candidate_parts == 0 then
			self:SetBodyPart(bodypart, nil)
		else
			self:SetBodyPart(bodypart, candidate_parts[1].name)
			local colorgroup = candidate_parts[1].colorgroup
			if colorgroup ~= nil then
				local candidate_colors = Cosmetic.GetSpeciesColors(colorgroup, species)
				candidate_colors = krandom.Shuffle(candidate_colors)
				assert(#candidate_colors > 0, "BAD COSMETIC SETUP, MISSING COLORS FOR GROUP:" .. colorgroup)
				self:SetColorGroup(colorgroup, candidate_colors[1].name)
			end
		end
	end
end

function CharacterCreator:IsNew()
	return self.isnew
end

-- The owner parameter is a Bit of a hack since we need to check if the player has unlocked something, but we might be randomizing a puppet
function CharacterCreator:IsBodyPartUnlocked(def, owner)
	owner = owner or self.inst
	if owner.components.unlocktracker then
		return owner.components.unlocktracker:IsCosmeticUnlocked(def.name, "PLAYER_BODYPART")
	else -- A nil unlocktracker means this is a new character so we check the filtertags instead
		return def.filtertags.default_unlocked ~= nil
	end
end

function CharacterCreator:IsBodyPartPurchased(def, owner)
	owner = owner or self.inst
	if owner.components.unlocktracker then
		return owner.components.unlocktracker:IsCosmeticPurchased(def.name, "PLAYER_BODYPART")
	else -- A nil unlocktracker means this is a new character so we check the filtertags instead
		return def.filtertags.default_purchased ~= nil
	end
end

function CharacterCreator:IsColorUnlocked(def, owner)
	owner = owner or self.inst
	if owner.components.unlocktracker then
		return owner.components.unlocktracker:IsCosmeticUnlocked(def.name, "PLAYER_COLOR")
	else -- A nil unlocktracker means this is a new character so we check the filtertags instead
		return def.filtertags.default_unlocked ~= nil
	end
end

function CharacterCreator:IsColorPurchased(def, owner)
	owner = owner or self.inst
	if owner.components.unlocktracker then
		return owner.components.unlocktracker:IsCosmeticPurchased(def.name, "PLAYER_COLOR")
	else -- A nil unlocktracker means this is a new character so we check the filtertags instead
		return def.filtertags.default_purchased ~= nil
	end
end

function CharacterCreator:GetBodyPartList(bodypart, filtered)
	return Cosmetic.GetBodyPartList(bodypart, filtered and self.filtertags or nil)
end

function CharacterCreator:GetBodyPart(bodypart)
	return self.bodyparts[bodypart]
end

function CharacterCreator:ClearAllExcept(exception)
	local bodyparts = Cosmetic.BodyPartGroups
	for bodypart in pairs(bodyparts) do
		if bodypart ~= exception then
			self:ClearBodyPartSymbols(bodypart)
		end
	end
end

function CharacterCreator:SetBodyPart(bodypart, name)
	if self.bodyparts[bodypart] == name then
		return false, false
	end

	local items = Cosmetic.BodyParts[bodypart]
	if items == nil then
		print("[CharacterCreator] Invalid body part: "..bodypart)
		return
	end

	local def = items[name]
	if def == nil and name ~= nil then
		print("[CharacterCreator] Invalid "..bodypart.." item: "..name)
		return
	end

	local oldpart = self.bodyparts[bodypart]
	if def ~= nil then
		self.bodyparts[bodypart] = name
		self:OverrideBodyPartSymbols(bodypart, def.build, def.colorgroup)
	else
		self.bodyparts[bodypart] = nil
		self:ClearBodyPartSymbols(bodypart)
	end

	--Reset filter tags
	local oldfiltertags = self.filtertags
	self.filtertags = {}

	for tag in pairs(def ~= nil and def.filtertags or oldfiltertags) do
		if tag ~= "default_unlocked" and tag ~= "default_purchased" then
			self.filtertags[tag] = true
		end
	end

	--Reset symbol tags
	local oldsymboltags = {}
	oldsymboltags[bodypart] = deepcopy(self.symboltags[bodypart])
	self.symboltags[bodypart] = {}

	if def ~= nil and def.symboltags ~= nil then
		for tag in pairs(def.symboltags) do
			self.symboltags[bodypart][tag] = true
		end
	end

	-- filter color groups
	local isColorMatched = function(color, tags, matchAll)
		matchAll = matchAll or false
		if not color.filtertags then
			return true
		end
		if not matchAll then
			if not tags then
				return true
			else
				for tag, _v in pairs(tags) do
					if color.filtertags[tag] then
						return true
					end
				end
			end
			return false
		else
			if not tags then
				return false
			else
				for tag, _v in pairs(tags) do
					if not color.filtertags[tag] then
						return false
					end
				end
			end
			return true
		end
	end

	for groupId, colorname in pairs(self.colorgroups) do
		local currentBodyPartColor = Cosmetic.Colors[groupId][colorname]
		if currentBodyPartColor and not isColorMatched(currentBodyPartColor, self.filtertags, false) then
			--TheLog.ch.CharacterCreator:printf("Color group=%s id=%d is invalid for filter tags", groupId, colorname)
			local bodyPartColors = Cosmetic.Colors[groupId]
			local newFilterTags = deepcopy(self.filtertags)
			newFilterTags["default"] = true
			for newname, newColor in pairs(bodyPartColors) do
				if isColorMatched(newColor, newFilterTags, true) then
					self:SetColorGroup(groupId, newname)
				end
			end
		end
	end

	--Show/Hide symbols if symbol tags changed
	local tagschanged = false
	for tag in pairs(self.symboltags[bodypart]) do
		if oldsymboltags[bodypart][tag] then
			oldsymboltags[bodypart][tag] = nil
		else
			tagschanged = true
			break
		end
	end
	tagschanged = tagschanged or (oldsymboltags[bodypart] ~= nil and next(oldsymboltags[bodypart]) ~= nil)

	if tagschanged then
		for symbol, tag in pairs(Cosmetic.BodySymbolFilters) do
			if self.symboltags[bodypart][tag] then
				self.inst.AnimState:ShowSymbol(symbol)
			else
				self.inst.AnimState:HideSymbol(symbol)
			end
		end
	end

	--Check if filter tags changed
	tagschanged = false
	for tag in pairs(self.filtertags) do
		if oldfiltertags[tag] then
			oldfiltertags[tag] = nil
		else
			tagschanged = true
			break
		end
	end
	tagschanged = tagschanged or next(oldfiltertags) ~= nil

	self.inst:PushEvent("onbodypartchanged", { bodypart = bodypart, oldpart = oldpart, newpart = self.bodyparts[bodypart] })
	return tagschanged, true
end

function CharacterCreator:OverrideBodyPartSymbols(bodypart, build, colorgroup)
	if build == nil then
		self:ClearBodyPartSymbols(bodypart)
		return
	end

	local symbols = Cosmetic.BodySymbols[bodypart]
	if symbols ~= nil then
		for i = 1, #symbols do
			local symbol = symbols[i]
			self.inst.AnimState:OverrideSymbol(symbol, build, Cosmetic.BodySymbolRemaps[symbol] or symbol)

			local colorgroup1 = Cosmetic.SymbolColorOverrides[symbol] or colorgroup
			local colorname = self.colorgroups[colorgroup1]
			local color = colorname ~= nil and Cosmetic.Colors[colorgroup1][colorname] or nil
			if color ~= nil then
				self.inst.AnimState:SetSymbolColorShift(symbol, table.unpack(color.hsb))
			else
				self.inst.AnimState:ClearSymbolColorShift(symbol)
			end
		end
	end
end

function CharacterCreator:ClearBodyPartSymbols(bodypart)
	local symbols = Cosmetic.BodySymbols[bodypart]
	if symbols ~= nil then
		for i = 1, #symbols do
			local symbol = symbols[i]
			self.inst.AnimState:ClearOverrideSymbol(symbol)
			self.inst.AnimState:ClearSymbolColorShift(symbol)
		end
	end
end

function CharacterCreator:ClearAllBodyPartSymbols()
	local bodyparts = Cosmetic.BodyPartGroups
	for bodypart in pairs(bodyparts) do
		self:ClearBodyPartSymbols(bodypart)
	end
end

function CharacterCreator:GetColorList(colorgroup, filtered)
	return Cosmetic.GetColorList(colorgroup, filtered and self.filtertags or nil)
end

function CharacterCreator:GetColor(colorgroup)
	return self.colorgroups[colorgroup]
end

function CharacterCreator:SetColorGroup(colorgroup, colorname)
	if self.colorgroups[colorgroup] == colorname then
		return false
	end

	local colors = Cosmetic.Colors[colorgroup]
	if colors == nil then
		print("[CharacterCreator] Invalid color group: "..colorgroup)
		return false
	end

	local color = colors[colorname]
	if color == nil then
		print("[CharacterCreator] Invalid "..colorgroup.." color id: ", colorname)
		return false
	end

	if colorgroup == "SKIN_TONE" then
		self.inst:PushEvent("update_skin_color", color.rgb)
		if PER_PLAYER_SILHOUETTE_COLOR then
			local r,g,b,a = table.unpack(color.rgb)
			self.inst.AnimState:SetSilhouetteColor(r,g,b,PLAYER_SILHOUETTE_ALPHA)
		end
	end

	local oldcolor = self.colorgroups[colorgroup]
	self.colorgroups[colorgroup] = colorname
	self:SetSymbolColorShift(colorgroup, table.unpack(color.hsb))

	self.inst:PushEvent("oncolorchanged", { colorgroup = colorgroup, oldcolor = oldcolor, newcolor = self.colorgroups[colorgroup] })

	return true
end

function CharacterCreator:SetSymbolColorShift(colorgroup, hue, saturation, brightness)
	for bodypart, name in pairs(self.bodyparts) do
		if Cosmetic.BodyParts[bodypart][name].colorgroup == colorgroup then
			local symbols = Cosmetic.BodySymbols[bodypart]
			for i = 1, #symbols do
				local symbol = symbols[i]
				if Cosmetic.SymbolColorOverrides[symbol] == nil then
					self.inst.AnimState:SetSymbolColorShift(symbol, hue, saturation, brightness)
				end
			end
		end
	end
	for symbol, colorgroup1 in pairs(Cosmetic.SymbolColorOverrides) do
		if colorgroup == colorgroup1 then
			self.inst.AnimState:SetSymbolColorShift(symbol, hue, saturation, brightness)
		end
	end
end

function CharacterCreator:ClearSymbolColorShift(colorgroup)
	for bodypart, name in pairs(self.bodyparts) do
		if Cosmetic.BodyParts[bodypart][name].colorgroup == colorgroup then
			local symbols = Cosmetic.BodySymbols[bodypart]
			for i = 1, #symbols do
				local symbol = symbols[i]
				if Cosmetic.SymbolColorOverrides[symbol] == nil then
					self.inst.AnimState:ClearSymbolColorShift(symbols[i])
				end
			end
		end
	end
	for symbol, colorgroup1 in pairs(Cosmetic.SymbolColorOverrides) do
		if colorgroup == colorgroup1 then
			self.inst.AnimState:ClearSymbolColorShift(symbol)
		end
	end
end

function CharacterCreator:Randomize(species, owner, unlock_all)
	species = species or krandom.PickValue(CHARACTER_SPECIES)

	self:SetSpecies(species)

	for bodypart in pairs(Cosmetic.BodyPartGroups) do
		local bodyparts = Cosmetic.GetSpeciesBodyParts(bodypart, species)
		if not unlock_all then
			bodyparts = lume.removeall(bodyparts, function(bp)
				local unlocked = self:IsBodyPartUnlocked(bp, owner)
				local purchased = self:IsBodyPartPurchased(bp, owner)
				return not unlocked or not purchased
			end)
		end

		bodyparts = krandom.Shuffle(bodyparts)

		if #bodyparts > 0 then
			self:SetBodyPart(bodypart, bodyparts[1].name)
			local colorgroup = bodyparts[1].colorgroup
			if colorgroup ~= nil then
				local colors = Cosmetic.GetSpeciesColors(colorgroup, species)
				if not unlock_all then
					colors = lume.removeall(colors, function(clr)
						local unlocked = self:IsColorUnlocked(clr, owner)
						local purchased = self:IsColorPurchased(clr, owner)
						return not unlocked or not purchased
					end)
				end

				colors = krandom.Shuffle(colors)
				assert(#colors > 0, "BAD COSMETIC SETUP, MISSING COLORS FOR GROUP:" .. colorgroup)
				self:SetColorGroup(colorgroup, colors[1].name)
			end
		end
	end
end

function CharacterCreator:OnSave()
	local data = {}
	if next(self.bodyparts) ~= nil then
		data.bodyparts = {}
		for bodypart, name in pairs(self.bodyparts) do
			data.bodyparts[bodypart] = name
		end
	end
	if next(self.colorgroups) ~= nil then
		data.colorgroups = {}
		for colorgroup, id in pairs(self.colorgroups) do
			data.colorgroups[colorgroup] = id
		end
	end

	data.species = self.species

	return next(data) ~= nil and data or nil
end

function CharacterCreator:OnLoad(data)
	self.isnew = nil
	local did_change = false

	self.species = data.species

	if data.bodyparts ~= nil then
		for bodypart, name in pairs(data.bodyparts) do
			local tags_changed, parts_changed = self:SetBodyPart(bodypart, name)
			did_change = did_change or parts_changed
		end
	end

	if data.colorgroups ~= nil then
		for colorgroup, name in pairs(data.colorgroups) do
			local colour_changed = self:SetColorGroup(colorgroup, name)
			did_change = did_change or colour_changed
		end
	end

	if did_change then
		self.inst:PushEvent("charactercreator_load")
	end
end


function CharacterCreator:OnNetSerialize()
	local e = self.inst.entity

	local nrbodyparts = table.numkeys(self.bodyparts)
	e:SerializeUInt(nrbodyparts, 5)

	local nrcolorgroups = table.numkeys(self.colorgroups)
	e:SerializeUInt(nrcolorgroups, 4)

	for bodypart, name in pairs(self.bodyparts) do
		e:SerializeString(bodypart)
		e:SerializeString(name)
	end

	for colorgroup, name in pairs(self.colorgroups) do
		e:SerializeString(colorgroup)
		e:SerializeString(name)
	end

	e:SerializeString(self.species)
end

function CharacterCreator:OnNetDeserialize()
	self.isnew = nil
	
	local e = self.inst.entity
	local nrbodyparts = e:DeserializeUInt(5);
	local nrcolorgroups = e:DeserializeUInt(4);

	local did_change = false

	for i = 1, nrbodyparts do 
		local bodypart = e:DeserializeString();
		local name = e:DeserializeString();

		local tags_changed, parts_changed = self:SetBodyPart(bodypart, name)
		did_change = did_change or parts_changed
	end

	for i = 1, nrcolorgroups do 
		local colorgroup = e:DeserializeString();
		local colorname = e:DeserializeString();

		local colour_changed = self:SetColorGroup(colorgroup, colorname)
		did_change = did_change or colour_changed
	end

	local species = e:DeserializeString()
	if species ~= self.species then
		self:SetSpecies(species)
	end

	if did_change then
		self.inst:PushEvent("charactercreator_load")
	end
end


function CharacterCreator:GetDebugString()
	local str = ""
	-- local delim = "\nFilter Tags - "
	-- for tag in pairs(self.filtertags) do
	-- 	str = str..string.format("%s%s", delim, tag)
	-- 	delim = ", "
	-- end
	-- delim = "\nSymbol Tags - "
	-- for tag in pairs(self.symboltags) do
	-- 	str = str..string.format("%s%s", delim, tag)
	-- 	delim = ", "
	-- end
	-- for bodypart in pairs(Cosmetic.BodyPartGroups) do
	-- 	str = str.."\n\t["..bodypart.."]"
	-- 	local name = self.bodyparts[bodypart]
	-- 	if name ~= nil then
	-- 		str = str.." - "..name
	-- 		local def = Cosmetic.BodyParts[bodypart][name]
	-- 		if def.colorgroup ~= nil then
	-- 			str = str.." - #"..HexToStr(self.colorgroups[def.colorgroup])
	-- 		end
	-- 	end
	-- end
	return str
end

return CharacterCreator
