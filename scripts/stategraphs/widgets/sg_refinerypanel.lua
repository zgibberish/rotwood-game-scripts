local Image = require("widgets/image")
local easing = require("util/easing")
local lume = require("util/lume")


local events =
{
	EventHandler("start_refine", function(inst)
		inst.sg:GoToState("enter_refine_state")
	end),

	EventHandler("end_refine", function(inst)
		inst.sg:GoToState("exit_refine_state")
	end)
}

local states =
{
	State({
		name = "idle",
	}),

	State({
		name = "enter_refine_state",

		onenter = function(inst)
			local pres = {}

			local move_time = 0.66

			table.insert(pres, Updater.Parallel({
				-- Updater.Ease(function(v) inst.widget.refinery_ui_root:SetPosition(v, 0) end, 0, -350, move_time, easing.inOutQuad),
				Updater.Ease(function(v) inst.widget.refine_button:SetMultColorAlpha(v) end, 1, 0, move_time, easing.outQuad),
			}))

			table.insert(pres, Updater.Do(function()
				inst.widget.refine_button:Hide()
			end))

			inst.sg.statemem.updater = inst.widget:RunUpdater(Updater.Series(pres))
		end,

		events =
		{
			EventHandler("uiupdater_done", function(inst, updater)
				if updater == inst.sg.statemem.updater then
					inst.sg:GoToState("items_to_center")
				end
			end)
		}
	}),

	State({
		name = "exit_refine_state",

		onenter = function(inst)
			local pres = {}
			inst.widget.refine_button:Show()

			table.insert(pres, Updater.Series({
				Updater.Ease(function(v) inst.widget.confirm_button:SetMultColorAlpha(v) end, 1, 0, 0.5, easing.outQuad),
				Updater.Do(function() inst.widget.confirm_button:Hide() end),
			}))

			local move_time = 0.66

			table.insert(pres, Updater.Parallel({
				-- Updater.Ease(function(v) inst.widget.refinery_ui_root:SetPosition(v, 0) end, -350, 0, move_time, easing.inOutQuad),
				Updater.Ease(function(v) inst.widget.refine_button:SetMultColorAlpha(v) end, 0, 1, move_time, easing.outQuad),
			}))

			inst.sg.statemem.updater = inst.widget:RunUpdater(Updater.Series(pres))
		end,

		events =
		{
			EventHandler("uiupdater_done", function(inst, updater)
				if updater == inst.sg.statemem.updater then
					inst.sg:GoToState("idle")
				end
			end)
		}
	}),

	State({
		name = "items_to_center",

		onenter = function(inst)
			local p_items = inst.widget.pending_items
			local refine_list = {}
			local total_num = inst.widget:GetTotalNumberOfPending()
			local cost_per_refine = 5
			local remaining = total_num%cost_per_refine
			local num_available = (total_num - remaining)
			local num_refines = math.floor(num_available / cost_per_refine)

			local num_per_slot = {}
			for slot, item in pairs(p_items) do
				num_per_slot[slot] = item.count
			end

			for _ = 1, num_refines do
				local refine = {}
				local to_fill = cost_per_refine
				for i = 1, #inst.widget.pending_slots do
					if num_per_slot[i] then
						local slot = i
						local num = num_per_slot[i]
						local to_add = math.min(to_fill, num)
						to_fill = to_fill - to_add
						if to_add > 0 then
							refine[slot] = to_add
							num_per_slot[slot] = num_per_slot[slot] - to_add
						end
						if to_fill == 0 then
							break
						end
					end
				end

				refine_list = lume.sum(refine_list, refine)
			end

			local pres = {}
			local parallel = {}
			local icon_widgets = {}
			local refine_results = {}
			local refine_items = {}
			local num_pres = 0

			for i = 1, #inst.widget.pending_slots do
				if refine_list[i] then
					local slot_num = i
					local num_to_use = refine_list[i]
					local slot = inst.widget.pending_slots[slot_num]
					local item = slot:GetItemInstance()
					if item then -- also check if the item can be refined
						num_pres = num_pres + 1

						local size = slot.button.image.size_x
						local icon_widget = inst.widget.refinery_ui_root:AddChild(Image())
							:SetTexture(item:GetDef().icon)
							:SetSize(size, size)
							:LayoutBounds("center", "center", slot.button.image)
							:Hide()

						local x, y = icon_widget:GetPosition()
						local tarX, tarY = inst.widget.button_root:GetPosition()

						table.insert(icon_widgets, icon_widget)

						table.insert(parallel, Updater.Series({
							Updater.Wait(0.15 * num_pres),
							Updater.Do(function()
								local split_stack = inst.widget:RemoveItemFromPending(item, slot_num, num_to_use)
								table.insert(refine_items, split_stack)
								icon_widget:Show()
							end),
							-- move to the middle
							Updater.Parallel({
								Updater.Ease(function(v) icon_widget:SetPosition(v, nil) end, x, tarX, 0.33, easing.inOutQuad),
								Updater.Ease(function(v) icon_widget:SetPosition(nil, v) end, y, tarY, 0.4, easing.inOutQuad),
								Updater.Ease(function(v) icon_widget:SetScale(v) end, 1, 1.5, 0.33, easing.outQuad),
							}),
							Updater.Ease(function(v) icon_widget:SetScale(v) end, 1.5, 0, 0.5, easing.inBack),
						}))
					end

				end
			end

			table.insert(pres, Updater.Parallel(parallel))
			table.insert(pres, Updater.Do(function()
				local result, result_idx = inst.widget:RefineItems(refine_items)
				table.insert(refine_results, result)
			end))
			table.insert(pres, Updater.Do(function()
				for i = #icon_widgets, 1, -1 do
					if i > #refine_results then
						icon_widgets[i]:Remove()
						icon_widgets[i] = nil
					else
						local item = refine_results[i]
						icon_widgets[i]:SetTexture(item:GetDef().icon)
						icon_widgets[i]:Reparent(inst.widget.resulting_root)
						icon_widgets[i]:SendToFront()
					end
				end
			end))

			-- table.insert(pres, Updater.While(function() return inst.widget.monster_research:IsAnyWidgetUpdating() end))

			inst.sg.statemem.refine_results = refine_results
			inst.sg.statemem.icon_widgets = icon_widgets

			inst.sg.statemem.updater = inst.widget:RunUpdater(Updater.Series(pres))
		end,

		events =
		{
			EventHandler("uiupdater_done", function(inst, updater)
				if updater == inst.sg.statemem.updater then
					inst.sg:GoToState("show_refine_results", { results = inst.sg.statemem.refine_results, widgets = inst.sg.statemem.icon_widgets })
				end
			end)
		}
	}),

	State({
		name = "show_refine_results",

		onenter = function(inst, data)
			local pres = {}

			local results = data.results
			local icons = data.widgets

			for idx, result in ipairs(results) do
				local icon = icons[idx]
				local target_slot_num = lume.find(inst.widget.resulting_items, result)

				local target_slot = inst.widget.resulting_slots[target_slot_num]
				local resultX, resultY = target_slot:GetPosition()

				local scale_time = 0.15

				table.insert(pres, Updater.Series({
					Updater.Wait(scale_time * idx),
					Updater.Ease(function(v) icon:SetScale(v) end, 0, 1.5, scale_time, easing.outQuad),
					Updater.Parallel({
						Updater.Do(function(v) icon:MoveTo(resultX, resultY, 0.33, easing.inOutQuad) end),
						Updater.Ease(function(v) icon:SetScale(v) end, 1.5, 1, 0.33, easing.outQuad),
					}),
					Updater.Do(function()
						icon:Remove()
						target_slot:SetItem(inst.widget.resulting_items[target_slot_num], inst.widget.player)
					end),

					-- Updater.Wait(0.33),

					-- Updater.Do(function()
					-- 	for item, result in pairs(inst.widget.research_results) do
					-- 		inst.widget.monster_research:ShowResearchProgress(result.def, result.log)
					-- 	end
					-- 	inst.widget.research_results = {}
					-- end),

					-- Updater.While(function() return inst.widget.monster_research:IsAnyWidgetUpdating() end),
				}))
			end

			inst.sg.statemem.updater = inst.widget:RunUpdater(Updater.Parallel(pres))
		end,

		events =
		{
			EventHandler("uiupdater_done", function(inst, updater)
				if updater == inst.sg.statemem.updater then
					inst.sg:GoToState("show_confirm_button")
				end
			end)
		}
	}),

	State({
		name = "show_confirm_button",

		onenter = function(inst)
			inst.widget.confirm_button:Show()
			inst.sg.statemem.updater = inst.widget:RunUpdater(Updater.Ease(function(v) inst.widget.confirm_button:SetMultColorAlpha(v) end, 0, 1, 0.5, easing.outQuad))
		end,

		events =
		{
			EventHandler("uiupdater_done", function(inst, updater)
				if updater == inst.sg.statemem.updater then
					inst.sg:GoToState("idle")
				end
			end)
		}
	})
}


return StateGraph("sg_refineryscreen", states, events, "idle")