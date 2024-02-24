local lume = require "util.lume"


local not_match_word_regex = "[^a-zA-Z0-9_]"

local WordPredictor = Class(function(self, text_edit)
	self.prediction = nil

	self.text = ""

	self.dictionaries = {}
end)

function WordPredictor:AddDictionary(dictionary)
	dictionary.postfix = dictionary.postfix or ""
	assert(not dictionary.words ~= not dictionary.generate_candidates, "Use words *or* generate_candidates.")
	dictionary.GetDisplayString = dictionary.GetDisplayString or function(word) return dictionary.prefix .. word .. dictionary.postfix end
	table.insert(self.dictionaries, dictionary)
end

local function _find_prediction_start(dictionaries, text, cursor_pos)
	local prediction = nil

	local is_cursor_at_end = text:len() == cursor_pos
	local input = text:sub(1, cursor_pos)
	-- As a safety measure, prevent completion across spaces.
	input = input:gsub(".- ", "")

	for _, dic in ipairs(dictionaries) do
		local search_text = input
		if dic.postfix:len() > 0
			and search_text:sub(-1, 1) == dic.postfix
		then
			-- Nothing to complete.
			search_text = ""
		elseif dic.prefix:len() > 0 then
			local count
			search_text, count = search_text:gsub(".-".. dic.prefix, "")
			if count == 0 then
				-- No delimiter means we're not valid.
				search_text = ""
			end
		end

		local min_chars_for_prediction = dic.num_chars or 2
		if search_text:len() >= min_chars_for_prediction then
			local pos
			local matches = {}
			if dic.generate_candidates then
				-- generate_candidates always uses the full input.
				pos = 0
				for _, match in ipairs(dic.generate_candidates(text, 1, is_cursor_at_end)) do
					local index = match.word:find(search_text, 1, true)
					if index ~= nil then
						table.insert(matches, {i = index, word = match.word, candidate = match})
					end
				end
			else
				--pos = text:len() - search_text:len()
				--jcheng: this used to have a bug where it miscalculated where to start if you had stuff after the search text
				--this search fixes this problem by using a different way to calculate the start pos
				pos = text:find(search_text, cursor_pos - search_text:len(), true) - 1
				for _, word in ipairs(dic.words) do
					local index = word:find(search_text, 1, true)
					if index ~= nil then
						table.insert(matches, {i = index, word = word})
					end
				end
			end
			-- When we input a word from the dictionary, ignore all matches so
			-- we'll allow the input to be used instead of replacing it with a
			-- longer word or getting stuck on completing the same word. Only
			-- block if there is no post fix, since typing the post fix will
			-- dismiss the prediction.
			local has_exact_match = (dic.postfix:len() == 0
				and lume.any(matches, function(v)
					return v.word == search_text
			end))
			if not has_exact_match and #matches > 0 then
				prediction = {}
				prediction.start_pos = pos
				prediction.matches = matches
				prediction.dictionary = dic
				break
			end
	end
	end

	if prediction then
		local matches = prediction.matches
		table.sort(matches, function(a, b) return (a.i == b.i and a.word < b.word) or a.i < b.i end)

		-- Strip prediction.matches down to a list of words.
		prediction.matches = {}
		prediction.candidates = {}
		for _, v in ipairs(matches) do
			table.insert(prediction.matches, v.word)
			prediction.candidates[v.word] = v
		end

		--~ local str = ""
		--~ for _, v in ipairs(prediction.matches) do str = str .. ", " .. v end
		--~ print(str)
	end
	return prediction
end

function WordPredictor:RefreshPredictions(text, cursor_pos)
	self.cursor_pos = cursor_pos
	self.text = text

	self.prediction = _find_prediction_start(self.dictionaries, text, cursor_pos)
end

function WordPredictor:Apply(prediction_index)
	local new_text = nil
	local new_cursor_pos = nil
	if self.prediction ~= nil then
		local postfix = self.prediction.dictionary.postfix
		local new_word = self.prediction.matches[math.clamp(prediction_index or 1, 1, #self.prediction.matches)]

		new_text = self.text:sub(1, self.prediction.start_pos) .. new_word .. postfix
		new_cursor_pos = #new_text

		local remainder_text = self.text:sub(self.cursor_pos + 1, #self.text) or ""
		local remainder_strip_pos = remainder_text:find(not_match_word_regex) or (#remainder_text + 1)
		if postfix ~= "" then
			local end_pos = remainder_strip_pos + (#postfix-1)
			if remainder_text:sub(remainder_strip_pos, end_pos) == postfix then
				remainder_strip_pos = remainder_strip_pos + #postfix
			end
		end

		new_text = new_text .. remainder_text:sub(remainder_strip_pos)
	end

	self:Clear()
	return new_text, new_cursor_pos
end

function WordPredictor:Clear()
	self.prediction = nil
	self.cursor_pos = nil
	self.text = nil
end

function WordPredictor:GetDisplayInfo(prediction_index)
	local text = ""
	if self.prediction ~= nil and prediction_index >= 1 and prediction_index <= #self.prediction.matches then
		local word = self.prediction.matches[prediction_index]
		local fn = self.prediction.dictionary.GetDisplayString
		text = fn(word, self.prediction.candidates[word])
	end
	return text
end

return WordPredictor

--c_spawn("cabbagerolls2")