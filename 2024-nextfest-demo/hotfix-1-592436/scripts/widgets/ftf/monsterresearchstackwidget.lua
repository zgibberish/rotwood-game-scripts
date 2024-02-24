local Widget = require("widgets/widget")
local Panel = require("widgets/panel")
local Text = require("widgets/text")
local MetaProgressWidget = require("widgets/ftf/metaprogresswidget")

local easing = require"util/easing"
local lume = require"util/lume"

local MonsterResearchStackWidget = Class(Widget, function(self, owner)
	Widget._ctor(self, "MonsterResearchStackWidget")

	self.owner = owner

	self.width = RES_X / 3
	self.height = RES_Y

	self.bg = self:AddChild(Panel("images/ui_ftf_forging/forge_sidebar.tex"))
		:SetNineSliceCoords(50, 450, 60, 620)
		:SetNineSliceBorderScale(0.5)
		:SetSize(self.width, self.height)
		:Offset(40, 0)
		:SetMultColor(0.5, 0.5, 0.5)

	self.title = self:AddChild(Text(FONTFACE.DEFAULT, 60, "Monster Research", UICOLORS.LIGHT_TEXT_TITLE))

	self.research_root = self:AddChild(Widget("Monster Research"))
	self.research_widgets = {}

	self:Refresh()
end)

function MonsterResearchStackWidget:SetOwner(owner)
	self.owner = owner
	self.inst:ListenForEvent("show_meta_reward", function(_, data) self:OnShowMetaProgress(data) end, self.owner)
	return self
end

function MonsterResearchStackWidget:OnShowMetaProgress(data)
	local widget = data.widget
	local showing = data.showing
	for i, w in ipairs(self.research_widgets) do
		local uiupdater = w.inst.components.uiupdater
		if uiupdater and w ~= widget then
			if showing then
				uiupdater:PauseAll()
			else
				uiupdater:ResumeAll()
			end
		end
	end
end

function MonsterResearchStackWidget:IsAnyWidgetUpdating()
	for i, w in ipairs(self.research_widgets) do
		if w.inst.components.uiupdater and w.inst.components.uiupdater:ShouldUpdate() then
			return true
		end
	end
	return false
end

function MonsterResearchStackWidget:Clear()
	self.research_root:RemoveAllChildren()
	self.research_widgets = {}
	self:Refresh()
end

function MonsterResearchStackWidget:Refresh()
	self.title:LayoutBounds("center", "top", self.bg)
		:Offset(0, -10)

	self.research_root:LayoutChildrenInGrid(1, 5)

	self.research_root:LayoutBounds("center", "below", self.title)
end

function MonsterResearchStackWidget:AddMonsterResearchWidget(research)
	if self:IsResearchShown(research.def.name) then
		return
	end

	local w = MetaProgressWidget(self.owner)
		:SetBarSize(self.width * 0.85, 40)

	w.rewards_per_row = 9

	local name = w:AddChild(Text(FONTFACE.DEFAULT, 30, research:GetLocalizedName(), UICOLORS.LIGHT_TEXT_TITLE))
	self.research_root:AddChild(w)
	table.insert(self.research_widgets, w)
	w:SetMetaProgressData(research)
	name:LayoutBounds("left", "above", w)
	self:Refresh()
	-- self:AnimateWidgetIn(w)
end

function MonsterResearchStackWidget:RemoveMonsterResearchWidget(widget)
	lume.remove(self.research_widgets, widget)
	widget:Remove()
	self:Refresh()
end

function MonsterResearchStackWidget:IsResearchShown(name)
	for _, widget in ipairs(self.research_widgets) do
		if widget:GetMetaProgress().def.name == name then
			return true
		end
	end
	return false
end

function MonsterResearchStackWidget:GetWidgetForResearch(def)
	for _, widget in ipairs(self.research_widgets) do
		if widget:GetMetaProgress().def == def then
			return widget
		end
	end
	return false
end

function MonsterResearchStackWidget:ShowResearchProgress(def, log)
	local w = self:GetWidgetForResearch(def)
	w.log = log
	w:ShowMetaProgression()
end

function MonsterResearchStackWidget:AnimateWidgetIn(w)
	local time = 0.25
	if #self.research_widgets > 1 then
		local tarx, tary = w:GetPos()
		local x, y = self.research_widgets[#self.research_widgets-1]:GetPos()
		-- w:SendToBack()

		self:RunUpdater(
			Updater.Parallel({
				Updater.Ease(function(v) w:SetPosition(x, v) end, y, tary, time, easing.inOutQuad),
				Updater.Ease(function(v) w:SetMultColorAlpha(v) end, 0, 1, time, easing.outQuad),
			}))
	else
		self:RunUpdater(
			Updater.Parallel({
				Updater.Ease(function(v) w:SetScale(v) end, 0, 1, time, easing.inOutQuad),
				Updater.Ease(function(v) w:SetMultColorAlpha(v) end, 0, 1, time, easing.outQuad),
			}))
	end
end

return MonsterResearchStackWidget