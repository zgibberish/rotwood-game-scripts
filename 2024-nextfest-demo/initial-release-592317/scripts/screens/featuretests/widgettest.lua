local ActionButton = require "widgets.actionbutton"
local Screen = require("widgets/screen")
local Text = require("widgets/text")
local Image = require("widgets/image")
local Widget = require("widgets/widget")
local Panel = require "widgets/panel"
local PlayerPuppet = require("widgets/playerpuppet")
local ScrollPanel = require("widgets/scrollpanel")
local TestPanel = require "widgets/featuretests/testpanel"
local CheckBox = require "widgets.checkbox"
local ImageButton = require "widgets.imagebutton"
local RadialProgress = require "widgets/radialprogress"

local easing = require "util.easing"

local centerscale = 0.5

local WidgetTest = Class(Screen, function(self, profile)
	Screen._ctor(self, "WidgetTest")
	self.profile = profile
	self:DoInit()
	self.default_focus = self.back_button
end)

function WidgetTest:DoInit()

	self.alignbackground = self:AddChild(Image("images/bg_loading/loading.tex"))
		:SetAnchors("fill","fill")
		:SetBlendMask("images/masks.xml", "zebrahigh.tex")

	local updater = Updater.Ease( function(v) self.alignbackground:SetBlendParams(0,1,1,v) end, -1, 1, 0.5, easing.inOutQuad)
	self.alignbackground:RunUpdater(updater)

	self.helperWidget = self.helperWidget or self:AddChild(Widget())
	-- This needs to be done with an updater or a coro, TaskInTime or PeriodicTask happen on the wrong tick

	local siblingUpdater =
		Updater.Loop({
			Updater.Do(function() self:TestSiblingAnchors() end),
			Updater.Do(function()
				local count = 0
				for i,v in pairs(Ents) do
					count = count + 1
				end
				print("Total Widgets = ",count)
			end),
			Updater.Wait(3),
		}, 10000 )

	local SiblingAnchors = function()
		if self.updater then
			self:StopUpdater(self.updater)
			self.updater:Reset() -- in case we want to start it again
		end
		self.helperWidget:RemoveAllChildren()
		if self.updater ~= siblingUpdater then
			self.updater = self:RunUpdater(siblingUpdater)
		else
			self.updater = nil
		end
	end

	local parentUpdater =
		Updater.Loop({
			Updater.Do(function() self:TestParentAnchors() end),
			Updater.Do(function()
					local count = 0
					for i,v in pairs(Ents) do
						count = count + 1
					end
					print("Total Widgets = ",count)
				end),
			Updater.Wait(3),
		}, 10000 )


	local ParentAnchors = function()
		if self.updater then
			self:StopUpdater(self.updater)
			self.updater:Reset() -- in case we want to start it again
		end
		self.helperWidget:RemoveAllChildren()
		if self.updater ~= parentUpdater then
			self.updater = self:RunUpdater(parentUpdater)
		else
			self.updater = nil
		end
	end

	self.back_button = self:AddChild(ActionButton())
		:SetText("Back")
		:LayoutBounds("left","bottom",self)
		:SetOnClick(function()
			TheFrontEnd:PopScreen()
		end)

	local button = self:AddChild(ActionButton())
		:SetText("Layout Siblings")
		:LayoutBounds("left","top",self)
		:SetOnClick(SiblingAnchors)

	local button_col_2 = self:AddChild(ActionButton())
		:SetText("Gradient Test")
		:LayoutBounds("after", "top", button)
		:Offset(40, 0)
		:SetOnClick(function()
			if self.updater then
				self:StopUpdater(self.updater)
				self.updater:Reset() -- in case we want to start it again
			end
			self.updater = nil
			self:GradientTest()
		end)

	local button = self:AddChild(ActionButton())
		:SetText("Layout Children")
		:LayoutBounds("center","below",button)
		:SetOnClick(ParentAnchors)

	local button = self:AddChild(ActionButton())
		:SetText("Animate")
		:LayoutBounds("center","below",button)
		:SetOnClick(function()
			if self.updater then
				self:StopUpdater(self.updater)
				self.updater:Reset() -- in case we want to start it again
			end
			self.updater = nil
			self:Animate()
		end)
	local button = self:AddChild(ActionButton())
		:SetText("Scissor Test")
		:LayoutBounds("center","below",button)
		:SetOnClick(function()
			if self.updater then
				self:StopUpdater(self.updater)
				self.updater:Reset() -- in case we want to start it again
			end
			self.updater = nil
			self:ScissorTest()
		end)
	local button = self:AddChild(ActionButton())
		:SetText("Tinting Test")
		:LayoutBounds("center","below",button)
		:SetOnClick(function()
			if self.updater then
				self:StopUpdater(self.updater)
				self.updater:Reset() -- in case we want to start it again
			end
			self.updater = nil
			self:TintingTest()
		end)

	local button = self:AddChild(ActionButton())
		:SetText("SetSize Test")
		:LayoutBounds("center","below",button)
		:SetOnClick(function()
			if self.updater then
				self:StopUpdater(self.updater)
				self.updater:Reset() -- in case we want to start it again
			end
			self.updater = nil
			self:SetSizeTest()
		end)

	local button = self:AddChild(ActionButton())
		:SetText("Anchor Test")
		:LayoutBounds("center","below",button)
		:SetOnClick(function()
			if self.updater then
				self:StopUpdater(self.updater)
				self.updater:Reset() -- in case we want to start it again
			end
			self.updater = nil
			self:AnchorTest()
		end)

	local button = self:AddChild(ActionButton())
		:SetText("9Slice/3Slice Test")
		:LayoutBounds("center","below",button)
		:SetOnClick(function()
			if self.updater then
				self:StopUpdater(self.updater)
				self.updater:Reset() -- in case we want to start it again
			end
			self.updater = nil
			self:SliceTest()
		end)

	local button = self:AddChild(ActionButton())
		:SetText("Mask Test")
		:LayoutBounds("center","below",button)
		:SetOnClick(function()
			if self.updater then
				self:StopUpdater(self.updater)
				self.updater:Reset() -- in case we want to start it again
			end
			self.updater = nil
			self:MaskTest()
		end)

	local button = self:AddChild(ActionButton())
		:SetText("TextTest")
		:LayoutBounds("center","below",button)
		:SetOnClick(function()
			if self.updater then
				self:StopUpdater(self.updater)
				self.updater:Reset() -- in case we want to start it again
			end
			self.updater = nil
			self:TextTest()
		end)

	local button = self:AddChild(ActionButton())
		:SetText("ScrollPanel")
		:LayoutBounds("center","below",button)
		:SetOnClick(function()
			if self.updater then
				self:StopUpdater(self.updater)
				self.updater:Reset() -- in case we want to start it again
			end
			self.updater = nil
			self:ScrollPanelTest()
		end)

end

function WidgetTest:AnchorTest()
	self.helperWidget:RemoveAllChildren()
	local helper = self.helperWidget:AddChild(Widget())
	local centerImage1 = helper:AddChild(Image("images/bg_loading/loading.tex"))
		:SetScale(0.3)
		:SetMultColor(0.9,0.9,0.9,1)

	for i = 1,10 do
		local child = centerImage1:AddChild(Image("images/uitest/target.tex"))
			:IgnoreParentMultColor()
			:SetScale(0.2)
			:SetAnchors(math.random(),math.random())
	end

	centerImage1:AddChild(Text(FONTFACE.DEFAULT, 210))
		:SetMultColor(0,0,0,1)
		:SetText("Fractional anchors")
		:IgnoreParentMultColor()
		:LayoutBounds("center","top",centerImage1)


	local centerImage2 = helper:AddChild(Image("images/bg_loading/loading.tex"))
		:SetScale(0.3)
		:SetMultColor(0.9,0.9,0.9,1)
		:LayoutBounds("after","center",centerImage1)
		:Offset(100,0)

	local child = centerImage2:AddChild(Image("images/uitest/target.tex"))
		:IgnoreParentMultColor()
		:SetScale(0.3)
		:SetAnchors("left","bottom")
	local child = centerImage2:AddChild(Image("images/uitest/target.tex"))
		:IgnoreParentMultColor()
		:SetScale(0.3)
		:SetAnchors("right","top")
	local child = centerImage2:AddChild(Image("images/uitest/target.tex"))
		:IgnoreParentMultColor()
		:SetScale(0.3)
		:SetAnchors("center","top")

	centerImage2:AddChild(Text(FONTFACE.DEFAULT, 210))
		:SetText("Fixed Anchors")
		:IgnoreParentMultColor()
		:SetMultColor(0,0,0,1)
		:LayoutBounds("center","top",centerImage2)

	local centerImage3 = helper:AddChild(Image("images/bg_loading/loading.tex"))
		:SetScale(0.3)
		:SetMultColor(0.9,0.9,0.9,1)
		:LayoutBounds("center","below",centerImage1)
		:Offset(0,-100)

	local child = centerImage3:AddChild(Image("images/uitest/target.tex"))
		:IgnoreParentMultColor()
		:StretchX(0, 1 )

	centerImage3:AddChild(Text(FONTFACE.DEFAULT, 210))
		:SetMultColor(0,0,0,1)
		:SetText("Stretch X")
		:IgnoreParentMultColor()
		:LayoutBounds("center","top",centerImage3)

	local centerImage4 = helper:AddChild(Image("images/bg_loading/loading.tex"))
		:SetScale(0.3)
		:SetMultColor(0.9,0.9,0.9,1)
		:LayoutBounds("center","below",centerImage2)
		:Offset(0,-100)

	local child = centerImage4:AddChild(Image("images/uitest/target.tex"))
		:IgnoreParentMultColor()
		:StretchY(0, 1)

	centerImage4:AddChild(Text(FONTFACE.DEFAULT, 210))
		:SetMultColor(0,0,0,1)
		:SetText("Stretch Y")
		:IgnoreParentMultColor()
		:LayoutBounds("center","top",centerImage4)

	local centerImage5 = helper:AddChild(Image("images/bg_loading/loading.tex"))
		:SetScale(0.6, 0.3)
		:SetMultColor(0.9,0.9,0.9,1)
		:LayoutBounds("right","below",centerImage3)
		:Offset(0,-100)

--[[
	local child = centerImage5:AddChild(Image("images/uitest/target.tex"))
		:IgnoreParentMultColor()
		:SetMultColor(1,1,1,0.9)
--		:Stretch(Axis.X,50,50,0,0) 	-- works
--		:Stretch(Axis.X,0,100,0,0)	-- works
--		:Stretch(Axis.X,100,0,0,0)	-- works
--  		:StretchX(0,1,50,50)		-- works
--  		:StretchX(0,1,0,100)		-- works
  		:StretchX(0,0.5,100,100)		-- works
]]
--	local child = centerImage5:AddChild(Image("images/uitest/target.tex"))
--		:IgnoreParentMultColor()
--		:SetMultColor(1,1,1,0.9)
-- 		:StretchX(0.5,1,100,100)		-- works


	local child = centerImage5:AddChild(Image("images/uitest/target.tex"))
		:IgnoreParentMultColor()
		:SetMultColor(1,1,1,0.9)
--		:Stretch(Axis.Y) 		-- works
--		:Stretch(Axis.Y,0,0,50,50) 	-- works
--		:Stretch(Axis.Y,0,0,100,20)	-- works
--		:Stretch(Axis.Y,0,0,20,100)	-- works
--  		:StretchY(0,1,50,50)		-- works
--  		:StretchY(0,1,0,100)		-- works
		:Stretch(Axis.All, 20,40,20,40)		-- works

	centerImage5:AddChild(Text(FONTFACE.DEFAULT, 210))
		:SetMultColor(0,0,0,1)
		:SetText("Stretch Insets")
		:IgnoreParentMultColor()
		:LayoutBounds("center","top",centerImage5)

	local centerImage6 = helper:AddChild(Image("images/bg_loading/loading.tex"))
		:SetScale(0.5, 0.4)
		:SetMultColor(0.9,0.9,0.9,1)
		:LayoutBounds("left","below",centerImage4)
		:Offset(0,-100)

	local child = centerImage6:AddChild(Image("images/uitest/target.tex"))
		:IgnoreParentMultColor()
		:SetMultColor(1,1,1,0.9)
		:StretchX(0,0.5,20,40)		-- works
		:StretchY(0,0.5,40,20)		-- works
	local child = centerImage6:AddChild(Image("images/uitest/target.tex"))
		:IgnoreParentMultColor()
		:SetMultColor(1,1,1,0.9)
		:StretchX(0.5,1,20,40)		-- works
		:StretchY(0.5,1,40,20)		-- works

	centerImage6:AddChild(Text(FONTFACE.DEFAULT, 210))
		:SetMultColor(0,0,0,1)
		:SetText("Partial Stretch")
		:IgnoreParentMultColor()
		:LayoutBounds("center","top",centerImage6)
	helper:LayoutBounds("center","center",0,0)

	-- to check measurements stretch with insets
	local scaleView = self.helperWidget:AddChild(Image("images/uitest/target.tex"))
		:SetSize(20,20)
		:SetMultColor(1,1,1,0.8)
		:LayoutBounds("left","top", centerImage5)
	local scaleView = self.helperWidget:AddChild(Image("images/uitest/target.tex"))
		:SetSize(40,40)
		:SetMultColor(1,1,1,0.8)
		:LayoutBounds("right","bottom", centerImage5)

	-- to check measurements partial stretch with insets
	local scaleView = self.helperWidget:AddChild(Image("images/uitest/target.tex"))
		:SetSize(20,20)
		:SetMultColor(1,1,1,0.8)
		:LayoutBounds("left","bottom", centerImage6)
	local scaleView = self.helperWidget:AddChild(Image("images/uitest/target.tex"))
		:SetSize(40,40)
		:SetMultColor(1,1,1,0.8)
		:LayoutBounds("right","top", centerImage6)
end


function WidgetTest:Animate()
	local num_children = 10

	self.helperWidget:RemoveAllChildren()
	local helper = self.helperWidget:AddChild(Widget())

	local centerImage1 = helper:AddChild(Image("images/bg_loading/loading.tex"))
		:SetScale(0.3)
		:SetMultColor(1,0,0,1)
	local child = {}
	for i=1,num_children do
		child[i] = centerImage1:AddChild(Image("images/bg_loading/loading.tex"))
			:SetMultColor(0.5,0.5,0.5,1)
			:SetScale(0.3)
			:SetPosition(math.random(800)-400, math.random(800)-400)
		if i % 2 == 0 then
			child[i]:IgnoreParentMultColor()
		end
	end

	centerImage1.updater = centerImage1:RunUpdater(
		Updater.Loop({
				Updater.Parallel({
						Updater.Wait(2),
						Updater.Do(function()
							if math.random(0,2) == 0 then
								centerImage1:TintTo(nil, {math.random(),math.random(),math.random(),1}, 3)
							end
							if math.random(0,2) == 0 then
								centerImage1:ScaleTo(nil, math.random() * 2, 2)
							end
							if math.random(0,2) == 0 then
								centerImage1:RotateTo(math.random(360), 2)
							end
							if math.random(0,2) == 0 then
								centerImage1:MoveTo(math.random(400) - 200, math.random(400) - 200, 2)
							end
							for i=1,num_children do
								if math.random(0,2) == 0 then
									child[i]:TintTo(nil, {math.random(),math.random(),math.random(),math.random()}, 3)
								end
								if math.random(0,2) == 0 then
									child[i]:ScaleTo(nil, math.random() * 0.3, 2)
								end
								if math.random(0,2) == 0 then
									child[i]:RotateTo(math.random() * 360, 2)
								end
								if math.random(0,2) == 0 then
									child[i]:MoveTo(math.random(800) - 400, math.random(800) - 400, 2)
								end
							end
						end)
					})
			})
		)
end

function WidgetTest:SetSizeTest()
	self.helperWidget:RemoveAllChildren()
	local root = self.helperWidget:AddChild(Widget())
	local button1 = self.helperWidget:AddChild(ActionButton())
		:SetText("Set Position")
		:LayoutBounds("center","top",self)
		:SetOnClick(function()
			root:RemoveAllChildren()
			local centerImage = root:AddChild(Image("images/uitest/target.tex"))
				:SetMultColor(1,1,1,0.9)
			local child = centerImage:AddChild(Image("images/uitest/target.tex"))
				:SetMultColor(1,1,1,0.9)
				:SetPosition(400,0)
				:SetScale(0.5, 0.5)
		end)
	local button2 = self.helperWidget:AddChild(ActionButton())
		:SetText("SetPosition Scaled")
		:LayoutBounds("after","center",button1)
		:SetOnClick(function()
			root:RemoveAllChildren()
			local centerImage = root:AddChild(Image("images/uitest/target.tex"))
				:SetMultColor(1,1,1,0.9)
				:SetScale(0.5, 0.5)
			local child = centerImage:AddChild(Image("images/uitest/target.tex"))
				:SetMultColor(1,1,1,0.9)
				:SetPosition(400,0)
				:SetScale(0.5, 0.5)
		end)
	local button3 = self.helperWidget:AddChild(ActionButton())
		:SetText("SetSize")
		:LayoutBounds("after","center",button2)
		:SetOnClick(function()
			root:RemoveAllChildren()
			local centerImage = root:AddChild(Image("images/uitest/target.tex"))
				:SetMultColor(1,1,1,0.9)
				:SetSize(400,400)
			local child = centerImage:AddChild(Image("images/uitest/target.tex"))
				:SetMultColor(1,1,1,0.9)
				:SetPosition(400,0)
				:SetScale(0.5, 0.5)
		end)
	local button4 = self.helperWidget:AddChild(ActionButton())
		:SetText("SetSize 2")
		:LayoutBounds("center","below",button1)
		:SetOnClick(function()
			root:RemoveAllChildren()
			local centerImage = root:AddChild(Image("images/uitest/target.tex"))
				:SetMultColor(1,1,1,0.9)
				:SetSize(1280,720)
			local child = centerImage:AddChild(Image("images/uitest/target.tex"))
				:SetMultColor(1,1,1,0.9)
				:SetPosition(400,0)
				:SetScale(0.5, 0.5)
		end)
	local button5 = self.helperWidget:AddChild(ActionButton())
		:SetText("SizeTo")
		:LayoutBounds("after","center",button4)
		:SetOnClick(function()
			root:RemoveAllChildren()
			local centerImage
			centerImage = root:AddChild(Image("images/uitest/target.tex"))
				:SetMultColor(1,1,1,0.9)
				:SizeTo(nil,1280,nil,720,4, nil, function()
					centerImage:SizeTo(nil,400,nil,400,4)
				end)
			local child = centerImage:AddChild(Image("images/uitest/target.tex"))
				:SetMultColor(1,1,1,0.9)
				:SetPosition(400,0)
				:SetScale(0.5, 0.5)
		end)

	local button6 = self.helperWidget:AddChild(ActionButton())
		:SetText("SizeTo Child")
		:LayoutBounds("after","center",button5)
		:SetOnClick(function()
			root:RemoveAllChildren()
			local centerImage
			centerImage = root:AddChild(Image("images/uitest/target.tex"))
				:SetMultColor(1,1,1,0.9)
				:RotateIndefinitely(-0.3)
			local child
			child = centerImage:AddChild(Image("images/uitest/target.tex"))
				:SetMultColor(1,1,1,0.9)
				:SetPosition(400,0)
				:SetScale(0.5, 0.5)
				:SizeTo(nil,400,nil,400,4, nil, function()
					-- since the parent rotates, this shouldn't
					child:SizeTo(nil,800,nil,800,4)
				end)
				:RotateIndefinitely(0.3)
		end)
end

function WidgetTest:TintingTest()
	self.helperWidget:RemoveAllChildren()
	local helper = self.helperWidget:AddChild(Widget())

	local centerImage1 = helper:AddChild(Image("images/bg_loading/loading.tex"))
		:SetScale(0.3)
		:SetMultColor(1,0,0,1)

	centerImage1:AddChild(Text(FONTFACE.DEFAULT, 210))
		:SetText("No parent tint")
		:IgnoreParentMultColor()
		:LayoutBounds("center","top",centerImage1)

	local child1 = centerImage1:AddChild(Image("images/bg_loading/loading.tex"))
		:SetMultColor(0.5,0.5,0.5,1)
		:SetScale(0.5)
		:IgnoreParentMultColor()

	local centerImage2 = helper:AddChild(Image("images/bg_loading/loading.tex"))
		:SetScale(0.3)
		:SetMultColor(1,0,0,1)
		:LayoutBounds("center","below",centerImage1)
		:Offset(0,-10)

	centerImage2:AddChild(Text(FONTFACE.DEFAULT, 210))
		:SetText("parent tint")
		:LayoutBounds("center","top",centerImage2)

	local child2 = centerImage2:AddChild(Image("images/bg_loading/loading.tex"))
		:SetMultColor(0.5,0.5,0.5,1)
		:SetScale(0.5)
		:IgnoreParentMultColor()

	local centerImage3 = helper:AddChild(Image("images/bg_loading/loading.tex"))
		:SetScale(0.3)
		:SetMultColor(1,0,0,1)
		:LayoutBounds("center","below",centerImage2)
		:Offset(0,-10)
	centerImage3:AddChild(Text(FONTFACE.DEFAULT, 210))
		:SetText("parent tint")
		:LayoutBounds("center","top",centerImage3)

	local child3 = centerImage3:AddChild(Image("images/bg_loading/loading.tex"))
		:SetScale(0.5)

	local centerImage4 = helper:AddChild(Image("images/bg_loading/loading.tex"))
		:SetScale(0.3)
		:SetMultColor(1,0,0,1)
		:LayoutBounds("after","center",centerImage1)
		:Offset(10,0)
		:PulseAlpha(0.4,1.0,0.003)
	centerImage4:AddChild(Text(FONTFACE.DEFAULT, 210))
		:SetText("parent tint")
		:LayoutBounds("center","top",centerImage4)

	local child4 = centerImage4:AddChild(Image("images/bg_loading/loading.tex"))
		:SetScale(0.5)

	local centerImage5 = helper:AddChild(Image("images/bg_loading/loading.tex"))
		:SetScale(0.3)
		:SetMultColor(1,0,0,1)
		:LayoutBounds("center","below",centerImage4)
		:Offset(0,-10)
		:PulseColor(WEBCOLORS.WHITE, WEBCOLORS.YELLOW, 0.9)
	centerImage5:AddChild(Text(FONTFACE.DEFAULT, 210))
		:SetText("parent tint")
		:LayoutBounds("center","top",centerImage5)
	local child5 = centerImage5:AddChild(Image("images/bg_loading/loading.tex"))
		:SetScale(0.5)

	local centerImage6 = helper:AddChild(Image("images/bg_loading/loading.tex"))
		:SetScale(0.3)
		:SetMultColor(1,0,0,1)
		:LayoutBounds("center","below",centerImage5)
		:Offset(0,-10)
		:Blink(1.5)
	centerImage6:AddChild(Text(FONTFACE.DEFAULT, 210))
		:SetText("parent tint")
		:LayoutBounds("center","top",centerImage6)
	local child6 = centerImage6:AddChild(Image("images/bg_loading/loading.tex"))
		:SetScale(0.5)

	local updater = Updater.Loop({
			Updater.Series({
					Updater.Parallel({
							Updater.Wait(4),
							Updater.Do(function()
								local r = math.random()
								local g = math.random()
								local b = math.random()
								local a = math.random()
								centerImage1:TintTo(nil, {r,g,b,1}, 3)
								centerImage2:TintTo(nil, {r,g,b,1}, 3)
								centerImage3:AlphaTo(a, 3)
							end),
						}),
				})
		})
	helper:RunUpdater(updater)

	helper:LayoutBounds("center","center", 0,0)
end

function WidgetTest:ScissorTest()
	self.helperWidget:RemoveAllChildren()
	local centerImage = self.helperWidget:AddChild(Image("images/bg_loading/loading.tex"))
		:SetScale(centerscale, centerscale)
		:IgnoreParentMultColor(true)
		:SetMultColor(1,0,0,1)
		:SetScale(0.5,0.5)

	local w,h = centerImage:GetSize()

	local updater =
	Updater.Loop({
		Updater.Series({
			Updater.Parallel({
				Updater.Wait(3),
				Updater.Do(function() centerImage:ScissorTo({0,0,0,0},{0,0,500,500},3) end),
			}),
			Updater.Parallel({
				Updater.Wait(3),
				Updater.Do(function() centerImage:ScissorTo({0,0,500,500},{-500,-500,1000,1000},3) end),
			}),
			Updater.Parallel({
				Updater.Wait(3),
				Updater.Do(function() centerImage:ScissorTo({-500,-500,1000,1000},{0,0,0,0},3) end),
			}),
		})
	})
	centerImage:RunUpdater(updater)
	local updater = Updater.Loop({
		Updater.Series({
			Updater.Parallel({
				Updater.Wait(4),
				Updater.Do(function() centerImage:MoveTo(math.random(-200,200), math.random(-200,200),3) end),
			}),
		})
	})
	centerImage:RunUpdater(updater)

	local updater = Updater.Loop({
		Updater.Series({
			Updater.Parallel({
				Updater.Wait(3.5),
				Updater.Do(
					function()
						centerImage:ScaleTo(nil,math.random(),3.5)
					end),
			}),
		})
	})
	centerImage:RunUpdater(updater)

	local image =centerImage:AddChild(Image("images/bg_loading/loading.tex"))
		:SetScale(0.15, 0.15)
		:IgnoreParentMultColor(true)
		:SetMultColor(0.9,0.9,0.9,1)
		:RotateIndefinitely(3)
	local image =centerImage:AddChild(Image("images/bg_loading/loading.tex"))
		:SetScale(0.25, 0.25)
		:IgnoreParentMultColor(true)
		:SetMultColor(0.9,0.9,0.9,1)
		:RotateIndefinitely(4)
		:SetPosition(300,300)

	-- Nested scissor inside
	local centerImage = self.helperWidget:AddChild(Image("images/bg_loading/loading.tex"))
		:SetScale(0.2, 0.2)
		:IgnoreParentMultColor(true)
		:SetMultColor(0,1,0,1)
		:SetPosition(-200,-200)
		:SetScissor(-800,-430,1600,860)
	local child = centerImage:AddChild(Image("images/bg_loading/loading.tex"))
		:SetScale(0.8, 0.8)
		:IgnoreParentMultColor(true)
		:SetMultColor(1,0,0,1)
		:SetPosition(0,0)
		:SetScissor(-800,-430,1600,860)
	centerImage:AddChild(Text(FONTFACE.DEFAULT, 210))
		:SetText("Nested Scissor")
		:IgnoreParentMultColor()
		:SetMultColor(1,1,1,1)
		:LayoutBounds("center","top",centerImage)

	-- Nested scissor outside
	local centerImage = self.helperWidget:AddChild(Image("images/bg_loading/loading.tex"))
		:SetScale(0.2, 0.2)
		:IgnoreParentMultColor(true)
		:SetMultColor(0,0,1,1)
		:SetPosition(200,-200)
		:SetScissor(-800,-430,1600,860)

	local child = centerImage:AddChild(Image("images/bg_loading/loading.tex"))
		:SetScale(0.8, 0.8)
		:IgnoreParentMultColor(true)
		:SetMultColor(1,0,0,1)
		:SetPosition(500,450)
		:SetScissor(-800,-430,1600,860)

	centerImage:AddChild(Text(FONTFACE.DEFAULT, 210))
		:SetText("Nested Scissor Outside")
		:IgnoreParentMultColor()
		:SetMultColor(1,1,1,1)
		:LayoutBounds("center","top",centerImage)

end


function WidgetTest:TestSiblingAnchors()
	self.layoutindex = self.layoutindex or 1
	local index = self.layoutindex
	local layouts = {}
	layouts [1]= {
				{"center","center"},
				{"before","center"},
				{"after","center"},
				{"before","below"},
				{"after","below"},
				{"before","above"},
				{"after","above"},
				{"center","above"},
				{"center","below"},
			}
	layouts[2] =
			{
				{"center_left","center_top"},
				{"center_left","center"},
				{"center_left","center_bottom"},
				{"center_right","center_top"},
				{"center_right","center"},
				{"center_right","center_bottom"},
				{"center","center_top"},
				{"center","center_bottom"},
			}
	layouts[3]=
			{
				{"left","top"},
				{"right","top"},
				{"left","bottom"},
				{"right","bottom"},
			}
	layouts[4] =
			{
				{"left_center","bottom_center"},
				{"right_center","bottom_center"},
				{"left_center","top_center"},
				{"right_center","top_center"},
			}
	self.helperWidget:RemoveAllChildren()
	local helper = self.helperWidget:AddChild(Widget())
	local centerImage = helper:AddChild(Image("images/bg_loading/loading.tex"))
		:SetScale(centerscale, centerscale)
		:IgnoreParentMultColor(true)
		:SetMultColor(1,0,0,1)

	for _,layout in pairs(layouts[index]) do
		local image = helper:AddChild(Image("images/bg_loading/loading.tex"))
			:SetScale(0.15, 0.15)
			:IgnoreParentMultColor(true)
			:SetMultColor(0.9,0.9,0.9,1)
		image:AddChild(Text(FONTFACE.DEFAULT, 210))
			:SetText(layout[1]..","..layout[2])
			:IgnoreParentMultColor()
			:SetMultColor(1,1,1,1)
		image:LayoutBounds(layout[1],layout[2],centerImage)
	end

	local scaleUp
	local scaleDown
	local wait

	scaleUp = function()
		centerImage:ScaleTo(0.5, 0.8, 1.0, nil, scaleDown)
	end
	scaleDown = function()
		centerImage:ScaleTo(0.8, 0.5, 1.0, nil, wait)
	end
	wait = function()
		centerImage:ScaleTo(0.5, 0.5, 1.0, nil, scaleUp)
	end
	wait()

	self.layoutindex = self.layoutindex + 1
	if self.layoutindex > #layouts then
		self.layoutindex = 1
	end
end

function WidgetTest:TestParentAnchors()
	self.layoutindex = self.layoutindex or 1
	local index = self.layoutindex
	local layouts = {}
	layouts [1]= {
				{"center","center"},
				{"before","center"},
				{"after","center"},
				{"before","below"},
				{"after","below"},
				{"before","above"},
				{"after","above"},
				{"center","above"},
				{"center","below"},
			}
	layouts[2] =
			{
				{"center_left","center_top"},
				{"center_left","center"},
				{"center_left","center_bottom"},
				{"center_right","center_top"},
				{"center_right","center"},
				{"center_right","center_bottom"},
				{"center","center_top"},
				{"center","center_bottom"},
			}
	layouts[3]=
			{
				{"left","top"},
				{"right","top"},
				{"left","bottom"},
				{"right","bottom"},
			}
	layouts[4] =
			{
				{"left_center","bottom_center"},
				{"right_center","bottom_center"},
				{"left_center","top_center"},
				{"right_center","top_center"},
			}
	self.helperWidget:RemoveAllChildren()
	local helper = self.helperWidget:AddChild(Widget())
	local centerImage = helper:AddChild(Image("images/bg_loading/loading.tex"))
		:SetScale(centerscale, centerscale)
		:IgnoreParentMultColor(true)
		:SetMultColor(1,0,0,1)

	for _,layout in pairs(layouts[index]) do
		local image = centerImage:AddChild(Image("images/bg_loading/loading.tex"))
			:SetScale(0.3, 0.3)
			:IgnoreParentMultColor(true)
			:SetMultColor(0.9,0.9,0.9,1)
		image:AddChild(Text(FONTFACE.DEFAULT, 210))
			:SetText(layout[1]..","..layout[2])
			:IgnoreParentMultColor()
			:SetMultColor(1,1,1,1)
		image:LayoutBounds(layout[1],layout[2],centerImage)
	end

	local scaleUp
	local scaleDown
	local wait
	scaleUp = function()
		centerImage:ScaleTo(0.5, 0.8, 1.0, nil, scaleDown)
	end
	scaleDown = function()
		centerImage:ScaleTo(0.8, 0.5, 1.0, nil, wait)
	end
	wait = function()
		centerImage:ScaleTo(0.5, 0.5, 1.0, nil, scaleUp)
	end
	wait()

	self.layoutindex = self.layoutindex + 1
	if self.layoutindex > #layouts then
		self.layoutindex = 1
	end
end

WidgetTest_TexIndex = 1

function WidgetTest:SliceTest()
	self.helperWidget:RemoveAllChildren()

	local function UpdateSlice9()
		self.slice9:SetNineSliceBorderScale(self.slicescale)
		self.slice9:SetSize(self.slicew,self.sliceh)
		self.slice9:SetScale(self.widgetscale, self.widgetscale)
		self.slice9:LayoutBounds(self.slicehalign,"center",self)
	end

	local centerImage = self.helperWidget:AddChild(Image("images/bg_loading/loading.tex"))
		:SetScale(0.5, 0.5)
		:IgnoreParentMultColor(true)
		:SetMultColor(1,0,0,1)
	local image = self.helperWidget:AddChild(Image("images/bg_loading/loading.tex"))
		:SetScale(0.5, 0.5)
		:IgnoreParentMultColor(true)
		:SetMultColor(0,0,1,1)
		:LayoutBounds("after","center",centerImage)
	local image = self.helperWidget:AddChild(Image("images/bg_loading/loading.tex"))
		:SetScale(0.5, 0.5)
		:IgnoreParentMultColor(true)
		:SetMultColor(0,0,1,1)
		:LayoutBounds("before","center",centerImage)
	local image = self.helperWidget:AddChild(Image("images/bg_loading/loading.tex"))
		:SetScale(0.5, 0.5)
		:IgnoreParentMultColor(true)
		:SetMultColor(0,0,1,1)
		:LayoutBounds("center","above",centerImage)
	local image = self.helperWidget:AddChild(Image("images/bg_loading/loading.tex"))
		:SetScale(0.5, 0.5)
		:IgnoreParentMultColor(true)
		:SetMultColor(0,0,1,1)
		:LayoutBounds("center","below",centerImage)

	local firstbutton = self.helperWidget:AddChild(ActionButton())
		:SetText("Size 300")
		:LayoutBounds("center","top",self)
		:Offset(-100,0)
		:SetOnClick(function()
			self.slicew = 300
			self.sliceh = 300
			UpdateSlice9()
		end)
	local button1 = self.helperWidget:AddChild(ActionButton())
		:SetText("Size 500")
		:LayoutBounds("after","center",firstbutton)
		:SetOnClick(function()
			self.slicew = 500
			self.sliceh = 500
			UpdateSlice9()
		end)
	local button1 = self.helperWidget:AddChild(ActionButton())
		:SetText("Size 700")
		:LayoutBounds("after","center",button1)
		:SetOnClick(function()
			self.slicew = 700
			self.sliceh = 700
			UpdateSlice9()
		end)
	local button1 = self.helperWidget:AddChild(ActionButton())
		:SetText("Left align")
		:LayoutBounds("after","center",button1)
		:SetOnClick(function()
			self.slicehalign = "left"
			UpdateSlice9()
		end)

	local button1 = self.helperWidget:AddChild(ActionButton())
		:SetText("Right align")
		:LayoutBounds("after","center",button1)
		:SetOnClick(function()
			self.slicehalign = "right"
			UpdateSlice9()
		end)

	local secondrow = self.helperWidget:AddChild(ActionButton())
		:SetText("Scale 1.0")
		:LayoutBounds("center","below",firstbutton)
		:SetOnClick(function()
			self.widgetscale = 1.0
			UpdateSlice9()
		end)

	local button1 = self.helperWidget:AddChild(ActionButton())
		:SetText("Scale 0.7")
		:LayoutBounds("after","center",secondrow)
		:SetOnClick(function()
			self.widgetscale = 0.7
			UpdateSlice9()
		end)
	local button1 = self.helperWidget:AddChild(ActionButton())
		:SetText("Scale 0.3")
		:LayoutBounds("after","center",button1)
		:SetOnClick(function()
			self.widgetscale = 0.3
			UpdateSlice9()
		end)
	local thirdrow = self.helperWidget:AddChild(ActionButton())
		:SetText("Border Scale 4.0")
		:LayoutBounds("center","below",secondrow)
		:SetOnClick(function()
			self.slicescale = 4.0
			UpdateSlice9()
		end)

	local button1 = self.helperWidget:AddChild(ActionButton())
		:SetText("Border Scale 3.0")
		:LayoutBounds("after","center",thirdrow)
		:SetOnClick(function()
			self.slicescale = 3.0
			UpdateSlice9()
		end)
	local button1 = self.helperWidget:AddChild(ActionButton())
		:SetText("Border Scale 2.0")
		:LayoutBounds("after","center",button1)
		:SetOnClick(function()
			self.slicescale = 2.0
			UpdateSlice9()
		end)

	local button1 = self.helperWidget:AddChild(ActionButton())
		:SetText("Border Scale 1.0")
		:LayoutBounds("after","center",button1)
		:SetOnClick(function()
			self.slicescale = 1.0
			UpdateSlice9()
		end)

	local button1 = self.helperWidget:AddChild(ActionButton())
		:SetText("Border Scale 0.5")
		:LayoutBounds("after","center",button1)
		:SetOnClick(function()
			self.slicescale = 0.5
			UpdateSlice9()
		end)

	self.slicew = 910
	self.sliceh = 512

	self.slicehalign = "center"
	self.slicescale = 1
	self.widgetscale = 1
	local names = {
		"images/9slice/actionscounter_bg.tex",
		"images/9slice/argument_bg_bait.tex",
		"images/9slice/brawl_container.tex",
		"images/9slice/grafts_slot_unique.tex",
		"images/9slice/mod_bg_active.tex",
		"images/9slice/roundbox.tex",
		"images/9slice/slice.tex",
		"images/9slice/toast_bg.tex",
	}
	local tex = names[(WidgetTest_TexIndex % #names)+1]
	WidgetTest_TexIndex = WidgetTest_TexIndex + 1

	self.slice9 = TestPanel(tex)
	--:SetMultColor(1,1,1,0.5)
		:SetToolTip("This is a tooltip\nline 2\nline 3\nline 4\nLine 5")
	self.helperWidget:AddChild(self.slice9)
	self.slice9:AddChild(Text(FONTFACE.DEFAULT, 210))
		:SetText("Hello")
	local sizeX = 910
	local sizeY = 512

	sizeX = math.clamp(sizeX or 200, 190, 1000)
	sizeY = math.clamp(sizeY or 200, 90, 500)
	UpdateSlice9()
end

function WidgetTest:MaskTest()
	self.helperWidget:RemoveAllChildren()


	local container = self.helperWidget:AddChild(Widget())

	-------------- Row 1 - Regular masking with image
	-- Info widgets
	local portraitBg1 = container:AddChild(Image("images/ui_ftf_ingame/boss_portrait_bg.tex"))
		:LayoutBounds("after", "center")
		:Offset(20, 0)
	local plus = container:AddChild(Text(FONTFACE.DEFAULT, 200, "+", UICOLORS.WHITE))
		:LayoutBounds("after", "center")
		:Offset(20, 0)
	local portraitMask1 = container:AddChild(Image("images/ui_ftf_ingame/boss_portrait_mask.tex"))
		:LayoutBounds("after", "center")
		:Offset(20, 0)
	local plus = container:AddChild(Text(FONTFACE.DEFAULT, 200, "+", UICOLORS.WHITE))
		:LayoutBounds("after", "center")
		:Offset(20, 0)
	local portraitIcon1 = container:AddChild(Image("images/mapicons_ftf/worldmap_icon_m_rotwood.tex"))
		:LayoutBounds("after", "center")
		:Offset(20, 0)
	local plus = container:AddChild(Text(FONTFACE.DEFAULT, 200, "+", UICOLORS.WHITE))
		:LayoutBounds("after", "center")
		:Offset(20, 0)
	local portraitGlow1 = container:AddChild(Image("images/ui_ftf_ingame/boss_portrait_glow.tex"))
		:SetScale(1.2, 1.2)
		:SetMultColor(UICOLORS.BACKGROUND_DARK)
		:LayoutBounds("after", "center")
		:Offset(20, 0)
		:RotateIndefinitely(0.3)
		:SetHiddenBoundingBox(true)
	local equals = container:AddChild(Text(FONTFACE.DEFAULT, 200, "=", UICOLORS.WHITE))
		:LayoutBounds("after", "center")
		:Offset(20, 0)

	-- Actual masked one
	local portraitContainer = container:AddChild(Widget())
	local portraitBg2 = portraitContainer:AddChild(Image("images/ui_ftf_ingame/boss_portrait_bg.tex"))
	local portraitMask2 = portraitContainer:AddChild(Image("images/ui_ftf_ingame/boss_portrait_mask.tex"))
		:SetMask()

	local portraitGlow2 = portraitContainer:AddChild(Image("images/ui_ftf_ingame/boss_portrait_glow.tex"))
		:SetScale(1.2, 1.2)
		:SetMultColor(UICOLORS.BACKGROUND_DARK)
		:RotateIndefinitely(0.3)
		:SetHiddenBoundingBox(true)
		:SetMasked()
	local portraitIcon2 = portraitContainer:AddChild(Image("images/mapicons_ftf/worldmap_icon_m_rotwood.tex"))
		:SetMasked()
	portraitContainer:LayoutBounds("after", "center")
		:Offset(20, 0)

	-------------- Row 2 - Blended mask
	-- Info widgets
	self.maskindex = self.maskindex or 1
	local blendmasks = {"zebrahigh.tex", "gradient.tex", "perlin.tex", "zebra.tex", "zigzag.tex"}
	self.maskindex = self.maskindex + 1
	if self.maskindex > #blendmasks then
		self.maskindex = 1
	end
	local blendmask = blendmasks[self.maskindex]
	local portraitBg1 = container:AddChild(Image("images/ui_ftf_ingame/boss_portrait_bg.tex"))
		:LayoutBounds("left", "below", portraitBg1)
		:Offset(20, 0)
	local plus = container:AddChild(Text(FONTFACE.DEFAULT, 200, "+", UICOLORS.WHITE))
		:LayoutBounds("after", "center")
		:Offset(20, 0)
	local portraitMask1 = container:AddChild(Image("images/masks/"..blendmask))
		:SetScale(0.4,0.4)
		:LayoutBounds("after", "center")
		--:Offset(20, 0)

	local equals = container:AddChild(Text(FONTFACE.DEFAULT, 200, "=", UICOLORS.WHITE))
		:LayoutBounds("after", "center")
		:Offset(20, 0)

	-- Actual masked one
	local portraitContainer = container:AddChild(Widget())
	local portraitBg2 = portraitContainer:AddChild(Image("images/ui_ftf_ingame/boss_portrait_bg.tex"))
		:SetBlendMask("images/masks.xml",blendmask)

	portraitContainer:LayoutBounds("after", "center")
		:Offset(20, 0)

	local updater = Updater.Loop({
			Updater.Series({
					Updater.Ease( function(v) portraitBg2:SetBlendParams(0,1,1,v) end, 1, -1, 1.5, easing.inOutQuad),
					Updater.Wait(0.4),
					Updater.Ease( function(v) portraitBg2:SetBlendParams(0,1,1,v) end, -1, 1, 1.5, easing.inOutQuad),
					Updater.Wait(0.4),
				})
		})
	portraitBg2:RunUpdater(updater)


	-------------- Row 3 - regular mask with anim
	if InGamePlay() then
		local animBg1 = container:AddChild(Image("images/ui_ftf_ingame/boss_portrait_bg.tex"))
			:LayoutBounds("left", "below", portraitBg1)
			:Offset(0, -20)
		local plus = container:AddChild(Text(FONTFACE.DEFAULT, 200, "+", UICOLORS.WHITE))
			:LayoutBounds("after", "center")
			:Offset(20, 0)
		local animMask1 = container:AddChild(Image("images/ui_ftf_ingame/boss_portrait_mask.tex"))
			:LayoutBounds("after", "center")
			:Offset(20, 0)
		local plus = container:AddChild(Text(FONTFACE.DEFAULT, 200, "+", UICOLORS.WHITE))
			:LayoutBounds("after", "center")
			:Offset(20, 0)
		local placeholder1 = container:AddChild(Image("images/global/square.tex"))
			:SetSize(140, 140)
			:LayoutBounds("after", "center")
			:Offset(20, 0)
			:Hide()
		local puppet1 = container:AddChild(PlayerPuppet())
			:SetHiddenBoundingBox(true)
			:SetScale(.6, .6)
			:SetFacing(FACING_RIGHT)
			:SetPosition(placeholder1:GetPosition())
			:Offset(0, -190)
		local plus = container:AddChild(Text(FONTFACE.DEFAULT, 200, "+", UICOLORS.WHITE))
			:LayoutBounds("after", "center", placeholder1)
			:Offset(20, 0)
		local animGlow1 = container:AddChild(Image("images/ui_ftf_ingame/boss_portrait_glow.tex"))
			:SetScale(1.2, 1.2)
			:SetMultColor(UICOLORS.BACKGROUND_DARK)
			:LayoutBounds("after", "center")
			:Offset(20, 0)
			:RotateIndefinitely(0.3)
			:SetHiddenBoundingBox(true)
		local equals = container:AddChild(Text(FONTFACE.DEFAULT, 200, "=", UICOLORS.WHITE))
			:LayoutBounds("after", "center")
			:Offset(20, 0)

		-- Actual masked one
		local animContainer = container:AddChild(Widget())
		local animBg2 = animContainer:AddChild(Image("images/ui_ftf_ingame/boss_portrait_bg.tex"))
		local animMask2 = animContainer:AddChild(Image("images/ui_ftf_ingame/boss_portrait_mask.tex"))
			:SetMask()
		local puppet2 = animContainer:AddChild(PlayerPuppet())
			:SetHiddenBoundingBox(true)
			:SetScale(.6, .6)
			:SetFacing(FACING_RIGHT)
			:SetPosition(0, -190)
			:SetMasked()
		local animGlow2 = animContainer:AddChild(Image("images/ui_ftf_ingame/boss_portrait_glow.tex"))
			:SetScale(1.2, 1.2)
			:SetMultColor(UICOLORS.BACKGROUND_DARK)
			:RotateIndefinitely(0.3)
			:SetHiddenBoundingBox(true)
			:SetMasked()
		animContainer:LayoutBounds("after", "center")
			:Offset(20, 0)


		-- Row 4 - Using anim as mask
		local placeholder2 = container:AddChild(Image("images/global/square.tex"))
			:SetSize(140, 140)
			:LayoutBounds("left", "below", animBg1)
			:Offset(20, -80)
			:Hide()
		local puppet2 = container:AddChild(PlayerPuppet())
			:LayoutBounds("left", "below", animBg1)
			:SetHiddenBoundingBox(true)
			:SetScale(.6, .6)
			:SetFacing(FACING_RIGHT)
			:SetPosition(placeholder2:GetPosition())
			:Offset(0, -190)
		local plus = container:AddChild(Text(FONTFACE.DEFAULT, 200, "+", UICOLORS.WHITE))
			:LayoutBounds("after", "center",placeholder2)
			:Offset(20, -40)
		local animBg3 = container:AddChild(Image("images/ui_ftf_ingame/boss_portrait_bg.tex"))
			:LayoutBounds("after", "center")
			:Offset(0, 0)
		local plus = container:AddChild(Text(FONTFACE.DEFAULT, 200, "+", UICOLORS.WHITE))
			:LayoutBounds("after", "center")
			:Offset(20, 0)
		local animGlow3 = container:AddChild(Image("images/ui_ftf_ingame/boss_portrait_glow.tex"))
			:SetScale(1.2, 1.2)
			:SetMultColor(UICOLORS.BACKGROUND_DARK)
			:LayoutBounds("after", "center")
			:Offset(20, 0)
			:RotateIndefinitely(0.3)
			:SetHiddenBoundingBox(true)
		local equals = container:AddChild(Text(FONTFACE.DEFAULT, 200, "=", UICOLORS.WHITE))
			:LayoutBounds("after", "center")
			:Offset(20, 0)

		-- Actual masked one
		local animContainer = container:AddChild(Widget())
		local puppet3 = animContainer:AddChild(PlayerPuppet())
			:SetHiddenBoundingBox(true)
			:SetScale(.6, .6)
			:SetFacing(FACING_RIGHT)
			:SetPosition(0, -190)
			:SetRotation(30)
		puppet3.puppet:SetMaskOnly()

		local animGlow3 = animContainer:AddChild(Image("images/ui_ftf_ingame/boss_portrait_glow.tex"))
			:SetScale(1.2, 1.2)
			:SetMultColor(UICOLORS.BACKGROUND_DARK)
			:RotateIndefinitely(0.3)
			:SetHiddenBoundingBox(true)
			:SetMasked()

		local animBg3 = animContainer:AddChild(Image("images/ui_ftf_ingame/boss_portrait_bg.tex"))
			:SetMasked()
		animContainer:LayoutBounds("after", "center")
			:Offset(20, 0)


		-- Row 5 - Using anim as mask, with an image clear mask
		local placeholder2 = container:AddChild(Image("images/global/square.tex"))
			:SetSize(140, 140)
			:LayoutBounds("left", "below", placeholder2)
			:Offset(20, -140)
			:Hide()
		local puppet2 = container:AddChild(PlayerPuppet())
			:LayoutBounds("left", "below", animBg1)
			:SetHiddenBoundingBox(true)
			:SetScale(.6, .6)
			:SetFacing(FACING_RIGHT)
			:SetPosition(placeholder2:GetPosition())
			:Offset(0, -190)
		local plus = container:AddChild(Text(FONTFACE.DEFAULT, 200, "+", UICOLORS.WHITE))
			:LayoutBounds("after", "center",placeholder2)
			:Offset(20, 0)
		local animBg3 = container:AddChild(Image("images/ui_ftf_ingame/boss_portrait_bg.tex"))
			:LayoutBounds("after", "center")
			:Offset(0, -20)
		local minus = container:AddChild(Text(FONTFACE.DEFAULT, 200, "-", UICOLORS.WHITE))
			:LayoutBounds("after", "center")
			:Offset(20, 30)
		local animGlow3 = container:AddChild(Image("images/ui_ftf_ingame/boss_portrait_glow.tex"))
			:SetScale(1.2, 1.2)
			:SetMultColor(UICOLORS.BACKGROUND_DARK)
			:LayoutBounds("after", "center")
			:Offset(20, 0)
			:RotateIndefinitely(0.3)
			:SetHiddenBoundingBox(true)
		local equals = container:AddChild(Text(FONTFACE.DEFAULT, 200, "=", UICOLORS.WHITE))
			:LayoutBounds("after", "center")
			:Offset(20, 0)

		-- actual masked one
		local animContainer = container:AddChild(Widget())
		local puppet3 = animContainer:AddChild(PlayerPuppet())
			:SetHiddenBoundingBox(true)
			:SetScale(.6, .6)
			:SetFacing(FACING_RIGHT)
			:SetPosition(0, -190)
			:SetRotation(30)
		puppet3.puppet:SetMaskOnly()

		local animGlow3 = animContainer:AddChild(Image("images/ui_ftf_ingame/boss_portrait_glow.tex"))
			:SetScale(1.2, 1.2)
			:SetMultColor(UICOLORS.BACKGROUND_DARK)
			:RotateIndefinitely(0.3)
			:SetHiddenBoundingBox(true)
			:SetMaskClear()

		local animBg3 = animContainer:AddChild(Image("images/ui_ftf_ingame/boss_portrait_bg.tex"))
			:SetMasked()
		animContainer:LayoutBounds("after", "center")
			:Offset(20, 0)

		-- ROW 6 - Two different widget masking context
		-- First portrait
		local portraitContainer = container:AddChild(Widget())
			:LayoutBounds("left", "below", placeholder2)
			:Offset(80, -260)
		local animBg3 = portraitContainer:AddChild(Image("images/ui_ftf_ingame/boss_portrait_bg.tex"))
		local animMask2 = portraitContainer:AddChild(Image("images/ui_ftf_ingame/boss_portrait_mask.tex"))
			:SetMask()
		local puppet2 = portraitContainer:AddChild(PlayerPuppet())
			:SetHiddenBoundingBox(true)
			:SetScale(.6, .6)
			:SetFacing(FACING_RIGHT)
			:SetPosition(0, -190)
			:SetMasked()

		-- Masked health bar
		local healthBar = container:AddChild(Widget())
		local healthBarBg = healthBar:AddChild(Image("images/ui_ftf_ingame/player_hp_back.tex"))
		local healthBarMask = healthBar:AddChild(Image("images/ui_ftf_ingame/player_hp_progress.tex"))
			:SetMask()
		local healthBarFill = healthBar:AddChild(Image("images/global.xml", "square.tex"))
			:SetSize(110, 216)
			:SetMultColor(UICOLORS.BONUS)
			:SetMasked()
		healthBar:LayoutBounds("after", "center", portraitContainer)
			:Offset(30, 0)
			:SetRotation(353)
		local min = 0
		local max = 216
		local updater = Updater.Loop({
				Updater.Series({
						Updater.Ease(function(v) healthBarFill:SetSize(110,v):SetPos(0, v * 0.5 - max * 0.5) end, min, max, 1.5, easing.inOutQuad),
						Updater.Wait(0.4),
						Updater.Ease(function(v) healthBarFill:SetSize(110,v):SetPos(0, v * 0.5 - max * 0.5) end, max, min, 1.5, easing.inOutQuad),
						Updater.Wait(0.4),
					})
			})
		healthBarFill:RunUpdater(updater)

		local equals = container:AddChild(Text(FONTFACE.DEFAULT, 200, "=", UICOLORS.WHITE))
			:LayoutBounds("after", "center")
			:Offset(20, 10)

		-- Combined
		local portraitContainer2 = container:AddChild(Widget())
			:LayoutBounds("after", "center", equals)
			:Offset(180, 0)
		local animBg3 = portraitContainer2:AddChild(Image("images/ui_ftf_ingame/boss_portrait_bg.tex"))
		local animMask2 = portraitContainer2:AddChild(Image("images/ui_ftf_ingame/boss_portrait_mask.tex"))
			:SetMask()
		local puppet2 = portraitContainer2:AddChild(PlayerPuppet())
			:SetHiddenBoundingBox(true)
			:SetScale(.6, .6)
			:SetFacing(FACING_RIGHT)
			:SetPosition(0, -190)
			:SetMasked()
		-- Masked health bar
		local healthBar2 = container:AddChild(Widget())
		local healthBarBg = healthBar2:AddChild(Image("images/ui_ftf_ingame/player_hp_back.tex"))
		local healthBarMask = healthBar2:AddChild(Image("images/ui_ftf_ingame/player_hp_progress.tex"))
			:SetMask()
		local healthBarFill = healthBar2:AddChild(Image("images/global.xml", "square.tex"))
			:SetSize(130, 216)
			:SetMultColor(UICOLORS.BONUS)
			:SetMasked()
		healthBar2:LayoutBounds("center", "center", portraitContainer2)
			:Offset(-90, -9)
			:SetRotation(353)
		local min = 0
		local max = 216
		local updater = Updater.Loop({
				Updater.Series({
						Updater.Ease(function(v) healthBarFill:SetSize(110,v):SetPos(0, v * 0.5 - max * 0.5) end, min, max, 1.5, easing.inOutQuad),
						Updater.Wait(0.4),
						Updater.Ease(function(v) healthBarFill:SetSize(110,v):SetPos(0, v * 0.5 - max * 0.5) end, max, min, 1.5, easing.inOutQuad),
						Updater.Wait(0.4),
					})
			})
		healthBarFill:RunUpdater(updater)


	else
		-- If we can't load the anims
		local containerW, containerH = container:GetSize()
		local infoLabel = container:AddChild(Text(FONTFACE.DEFAULT, 38, "To see the character anim masking test too, click the <#F6B742>Widget Test</> button when in town, on the <#F6B742>Debug Menu</> option", UICOLORS.WHITE))
			:SetRegionSize(containerW, 60)
			:LayoutBounds("center", "below")
			:Offset(0, -20)
	end

	-- Layout container
	container:LayoutBounds("center", "center", 0, 0)

end

function WidgetTest:TextTest()
	self.helperWidget:RemoveAllChildren()

	local w = 800
	local container = self.helperWidget:AddChild(Panel("images/9slice/roundbox.tex"))
		:SetSize(w, 600)
	container.text = container:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SPEECH_TEXT))
		:LayoutBounds("after", "center")
		:Offset(20, 0)
		:SetAutoSize(w - 20)
		:SetPersonalityText("SetPersonalityText with default personality\n Seems I'm runnin' dry on supplies. Gonna have to rustle up some 'fore we can get cookin' again.")
end

function WidgetTest:ScrollPanelTest()
	self.helperWidget:RemoveAllChildren()
	local helper = self.helperWidget:AddChild(Widget())

	local SIDEBAR_W = 1200

	self.slicew = 1200
	self.sliceh = 1200

	self.slicehalign = "center"
	self.slicescale = 1
	self.widgetscale = 1
	local names = {
		"images/9slice/actionscounter_bg.tex",
		"images/9slice/argument_bg_bait.tex",
		"images/9slice/brawl_container.tex",
		"images/9slice/grafts_slot_unique.tex",
		"images/9slice/mod_bg_active.tex",
		"images/9slice/roundbox.tex",
		"images/9slice/slice.tex",
		"images/9slice/toast_bg.tex",
	}
	local tex = names[(WidgetTest_TexIndex % #names)+1]
	WidgetTest_TexIndex = WidgetTest_TexIndex + 1

	self.slice9 = Panel(tex)
	self.slice9:SetSize(self.slicew, self.sliceh)
	helper:AddChild(self.slice9)


	local pad = 60 -- inner size of panel border
	self.content_scroll = helper:AddChild( ScrollPanel() )
		:SetAnchors( "center", "center" )
		:SetVirtualMargin( SPACING.M1 )
		:SetScrollBarOuterMargin( 0 )
		:SetSize(self.slicew - pad, self.sliceh - pad)
	self.content = self.content_scroll:AddScrollChild( Widget() )
	local circle = self.content:AddChild(Image( "images/global/circle.tex") )
		:SetSize(600, 1600)


	self.title = self.content:AddChild( Text( "title", FONTSIZE.SCREEN_TITLE, "CENTERBELOW" ) )
		:SetGlyphColor( UICOLORS.BLUE )
		:SetAutoSize( SIDEBAR_W )
		:SetWordWrap( true )
		:SetHAlign(ANCHOR_LEFT)
		:LayoutBounds("center","below",circle)

	local top = self.content:AddChild( Text( "title", FONTSIZE.SCREEN_TITLE, "CENTERABOVE" ) )
		:SetGlyphColor( UICOLORS.BLUE )
		:SetAutoSize( SIDEBAR_W )
		:SetWordWrap( true )
		:SetHAlign(ANCHOR_LEFT)
		:LayoutBounds("center","above",circle)
	local topleft = self.content:AddChild( Text( "title", FONTSIZE.SCREEN_TITLE, "TOPLEFT" ) )
		:SetGlyphColor( UICOLORS.BLUE )
		:SetAutoSize( SIDEBAR_W )
		:SetWordWrap( true )
		:SetHAlign(ANCHOR_LEFT)
		:LayoutBounds("left","top",circle)
	local bottomright = self.content:AddChild( Text( "title", FONTSIZE.SCREEN_TITLE, "BOTTOMRIGHT" ) )
		:SetGlyphColor( UICOLORS.BLUE )
		:SetAutoSize( SIDEBAR_W )
		:SetWordWrap( true )
		:LayoutBounds("right","bottom",circle)

	self.content_scroll:RefreshView()

end


function WidgetTest:GradientTest()
	self.helperWidget:RemoveAllChildren()

	local container = self.helperWidget:AddChild(Widget())

	local palette = {
		primary_active = UICOLORS.LIGHT_TEXT_TITLE,
		primary_inactive = UICOLORS.LIGHT_TEXT_TITLE,
	}
	local toggleButton = container:AddChild(CheckBox(palette))
		:SetText("Enabled")
		:SetValue(true, true)
		:LayoutBounds("center", "center")

	local portraitIcon1 = container:AddChild(Image("images/icons_boss/megatreemon.tex"))
		:LayoutBounds("center", "below", toggleButton)
		:Offset(0, -40)

	local text1 = container:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TITLE))
		:SetText("Gradient Characters <s>text with a dropshadow</> and <u>some</> <u#RED>underlined</u> <u#00ff00>text</>")
		:LayoutBounds("center", "below", portraitIcon1)
		:Offset(0, -40)

	local text2 = container:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TITLE))
		:SetText("Embedded <p img='images/bg_title/title.tex' color=00ff0080> images and <p bind='Controls.Digital.MENU_ACCEPT' color=RED> controller <p bind='Controls.Digital.MENU_TAB_NEXT'> icons <p bind='Controls.Digital.PAUSE'>")
		:LayoutBounds("center", "below", text1)
		:Offset(0, -40)

	local radialProgress1 = container:AddChild(RadialProgress("images/ui_ftf_research/item_radial_fill_1.tex"))
		:SetSize(80, 80)
		:SetProgress(0.3)
		:LayoutBounds("center", "below", text2)

	local radialProgress2 = container:AddChild(RadialProgress("images/ui_ftf_research/item_radial_fill_1.tex"))
		:SetSize(80, 80)
		:SetProgress(0.6)
		:Offset(80, 0)
		:LayoutBounds("after", "center", radialProgress1)

	local radialProgress3 = container:AddChild(RadialProgress("images/ui_ftf_research/item_radial_fill_1.tex"))
		:SetSize(80, 80)
		:SetProgress(0.9)
		:Offset(80, 0)
		:LayoutBounds("after", "center", radialProgress2)

	local buttonContainer = container:AddChild(Widget())
		:LayoutBounds("center", "below", text2)
		:Offset(0, -200)
	local button1 = buttonContainer:AddChild(ActionButton())
		:SetText("ActionButton")
		:LayoutBounds("left", "center", buttonContainer)
	local button2 = buttonContainer:AddChild(ImageButton())
		:LayoutBounds("after", "center", button1)
		:SetSize(400, 100)
		:Offset(100, 0)

	local inGamePlayGroup = {}
	local gradientWidgetTable = {
		["images/masks/ui_ramp_03.tex"] = {portraitIcon1, button1, radialProgress1, text2},
		["images/masks/ui_ramp_02.tex"] = {text1, button2, radialProgress2, radialProgress3},
		["images/masks/ui_ramp_01.tex"] = inGamePlayGroup
	}

	local enabled = true
	toggleButton:SetOnChangedFn(function(state)
			enabled = state
			if not enabled then
				for _, widgets in pairs(gradientWidgetTable) do
					for _, v in ipairs(widgets) do
						v:SetBrightnessMap(nil)
					end
				end
			end
		end)

	local updateBrightnessMap = function(intensity)
		if enabled then
			for colorRamp, widgets in pairs(gradientWidgetTable) do
				for _, v in ipairs(widgets) do
					v:SetBrightnessMap(colorRamp, intensity)
				end
			end
		end
	end

	if InGamePlay() then
		local animContainer = container:AddChild(Widget())
		local puppet1 = animContainer:AddChild(PlayerPuppet())
			:SetFacing(FACING_RIGHT)
		local puppet2 = animContainer:AddChild(PlayerPuppet())
			:SetFacing(FACING_RIGHT)
			:Offset(400, 0)

		animContainer:LayoutBounds("center", "below", text2)
			:Offset(0, -700)

		table.insert(inGamePlayGroup, puppet1.puppet)
	else
		-- If we can't load the anims
		local infoLabel = container:AddChild(Text(FONTFACE.DEFAULT, 48, "To see the character anim gradient test too, enter <#F6B742>d_widgettest()</> in the <#F6B742>Debug Console(~)</> when in town", UICOLORS.WHITE))
			:LayoutBounds("center", "below")
			:Offset(0, -20)

		table.insert(inGamePlayGroup, infoLabel)
	end

	-- Layout container
	container:LayoutBounds("center", "center", 0, 0)

	local updater = Updater.Loop({
			Updater.Series({
					Updater.Ease(updateBrightnessMap, 0, 1, 1.5, easing.inOutQuad),
					Updater.Wait(0.4),
					Updater.Ease(updateBrightnessMap, 1, 0, 1.5, easing.inOutQuad),
					Updater.Wait(0.4),
				})
		})
	container:RunUpdater(updater)

end

return WidgetTest
