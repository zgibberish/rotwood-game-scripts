-- Score UI for the mini-games. Only keeps the player score widget, the background is at specialeventtoommanager.


local Widget = require("widgets/widget")
local Image = require("widgets/image")
local Text = require("widgets/text")
local SpecialEventRoom = require("defs.specialeventrooms")


---- WHEN THE WIDGET IS ADDED TO THE SCREEN ---- 
local MinigamePlayerScore = Class(Widget, function(self, player_number, is_single_player, score_type)  
	Widget._ctor(self, "MinigamePlayerScore")

	self.player_number = player_number
	self.is_single_player = is_single_player
	self.score_type = score_type --knows the minigame type

	self.scoreWrapper = self:AddChild(Widget()) -- adding a wrapper for alignment purposes
		:SetName("ScoreWrapper")
		:LayoutBounds("center","center")
	
	-- Decides what minigame UI to show
	if self.score_type == SpecialEventRoom.ScoreType.SCORELEFT then					
		self.scoreImage = self.scoreWrapper:AddChild(Image("images/ui_ftf_minigames/ui_minigame_heartGold.tex"))
			:SetSize(50 * HACK_FOR_4K, 50 * HACK_FOR_4K)

		-- Positions scoreText below the scoreImage and sets the initial value to 10
		self.scoreText = self.scoreWrapper:AddChild(Text())
		self.scoreText:SetText("10"):LayoutBounds("center","below",self.scoreImage)
		:SetGlyphColor(UICOLORS.LIGHT_TEXT)

	elseif self.score_type == SpecialEventRoom.ScoreType.TIMELEFT or self.score_type == SpecialEventRoom.ScoreType.HIGHSCORE then
		self.timeleftText = self.scoreWrapper:AddChild(Text())
		self.timeleftText:SetText("0")
		:SetGlyphColor(UICOLORS.LIGHT_TEXT)
		:SetFontSize(60)
		:Offset(0,10)
	end
 


	-- Doesn't show the label if single player
	if is_single_player ~= true then 

	    self.scorePlayerLabel = self:AddChild(Image()) 
			:SetSize(33 * HACK_FOR_4K, 23 * HACK_FOR_4K) 

		 -- Matches the scorePlayerLabel image with the player number
	 	if player_number == 1 then
	 		self.scorePlayerLabel:SetTexture("images/ui_ftf_minigames/ui_minigame_P1.tex")
	 	elseif player_number == 2 then
	  		self.scorePlayerLabel:SetTexture("images/ui_ftf_minigames/ui_minigame_P2.tex")
	 	elseif player_number == 3 then
	 		self.scorePlayerLabel:SetTexture("images/ui_ftf_minigames/ui_minigame_P3.tex")
	 	elseif player_number == 4 then
	 		self.scorePlayerLabel:SetTexture("images/ui_ftf_minigames/ui_minigame_P4.tex")
	 	end

		-- Positions scorePlayerLabel below the scoreText
		self.scorePlayerLabel:LayoutBounds("center","below",self.scoreText) -- (horizontal, vertical, variable it's aligning to)

		-- Decides the label placement based on minigame type
		if self.score_type == SpecialEventRoom.ScoreType.SCORELEFT then	 
			self.scorePlayerLabel:Offset(0,-19)
		elseif self.score_type == SpecialEventRoom.ScoreType.TIMELEFT or self.score_type == SpecialEventRoom.ScoreType.HIGHSCORE then
			self.scorePlayerLabel:Offset(0,-40)
		end

		-- Adds the player number text as child of scorePlayerLabel
	 	self.scorePlayerLabelNumber = self.scorePlayerLabel:AddChild(Text()) 
		self.scorePlayerLabelNumber:SetText("P" .. player_number) 
			:SetGlyphColor(UICOLORS.BLACK)
			:SetFontSize(20)
	end



end)

---- AFTER THE MINI-GAME STARTS----
function MinigamePlayerScore:UpdateScore(score_value) 

	--Selects the mini game type
	if self.score_type == SpecialEventRoom.ScoreType.SCORELEFT then
		-- Updates the scoreImage based on the current score value
		if score_value >= 9 then
			self.scoreImage:SetTexture("images/ui_ftf_minigames/ui_minigame_heartGold.tex")
		elseif score_value >= 6 then
			self.scoreImage:SetTexture("images/ui_ftf_minigames/ui_minigame_heartSilver.tex")
		elseif score_value >= 3 then
			self.scoreImage:SetTexture("images/ui_ftf_minigames/ui_minigame_heartBronze.tex")
		elseif score_value >= 0 then
			self.scoreImage:SetTexture("images/ui_ftf_minigames/ui_minigame_gameover.tex")
		end

		self.scoreText:SetText(score_value)	

	elseif self.score_type == SpecialEventRoom.ScoreType.TIMELEFT or self.score_type == SpecialEventRoom.ScoreType.HIGHSCORE then
	-- Updates the scoreText number
	
		self.timeleftText:SetText(score_value) 
	end





end

return MinigamePlayerScore

