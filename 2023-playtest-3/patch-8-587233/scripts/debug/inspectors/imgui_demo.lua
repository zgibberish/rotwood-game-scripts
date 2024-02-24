local DebugNodes = require "dbui.debug_nodes"
local Enum = require "util.enum"
local color = require "math.modules.color"
local iterator = require "util.iterator"
local lume = require "util.lume"
local ui = require "dbui.imgui"
require "mathutil"

local ImGuiDemo = Class(DebugNodes.DebugNode, function(self, inst)
	DebugNodes.DebugNode._ctor(self, "ImGui Demo")

	self.inst = inst
    self.autoselect = inst == nil
    self.component_filter = ""
end)

--ImGuiDemo.singleInstance = true

-- Demonstration of how to use imgui
--
-- To run the test, add inside an OnUpdate loop:
--      local imgui_demo = require "debug.inspectors.imgui_demo"
--      imgui_demo.CreateImguiTestWindow()

-- We generally pass imgui around as a variable called ui.



-- Make the UI compact because there are so many fields
local function PushStyleCompact()
	local default_style = {
		ItemSpacing = Vector2(8,4),
		FramePadding = Vector2(4,3),
	}
    ui:PushStyleVar(ui.StyleVar.FramePadding, default_style.FramePadding.x, default_style.FramePadding.y * 0.60)
    ui:PushStyleVar(ui.StyleVar.ItemSpacing,  default_style.ItemSpacing.x,  default_style.ItemSpacing.y * 0.60)
end
local function PopStyleCompact()
    ui:PopStyleVar(2)
end


-- Helper to display a little (?) mark which shows a tooltip when hovered.
-- In your own code you may want to display an actual icon if you are using a merged icon fonts (see docs/FONTS.md)
local function HelpMarker(desc)
    ui:TextColored(WEBCOLORS.LIGHTGRAY, "(?)")
    if ui:IsItemHovered() then
        ui:BeginTooltip()
        ui:PushTextWrapPos(ui:GetFontSize() * 35.0)
        ui:Text(desc)
        ui:PopTextWrapPos()
        ui:EndTooltip()
	end
end



-- Call the functions that we remapped for simulated overloading to exercise
-- the different branches. Code pulled from imgui_demo.
local radio_selection1 = 0
local radio_selection2 = 0
local dont_ask_me_next_time = false
local dont_ask_me_again = false
local trigger_error = true
local lastClicked = ""
local function AddImguiTestSection_Remap()
    local _ = nil

    if ui:TreeNode("RadioButton") then
        ui:Text("RadioButton that returns item selected")
        _, radio_selection1 = ui:RadioButton("radio a", radio_selection1, 0) ; ui:SameLine()
        _, radio_selection1 = ui:RadioButton("radio b", radio_selection1, 1) ; ui:SameLine()
        _, radio_selection1 = ui:RadioButton("radio c", radio_selection1, 2)

        ui:Text("RadioButton that returns is button selected")
        local is_selected = false

        for i=0,2 do
            is_selected = ui:RadioButton("radio ".. i, radio_selection2 == i)
            if is_selected then
                radio_selection2 = i
            end
            ui:SameLine()
        end
        ui:Text("")

        _, dont_ask_me_next_time = ui:Checkbox("Normal button", dont_ask_me_next_time)
        ui:PushStyleVar(ui.StyleVar.FramePadding, 0,0)
        _, dont_ask_me_again = ui:Checkbox("ImGuiStyleVar_FramePadding button", dont_ask_me_again)
        ui:PopStyleVar()

        ui:TreePop()
    end

    if ui:TreeNode("Text styling") then

        ui:Value("Value", false)
        ui:Value("Value", 3.4) -- without format string, value is truncated!
        ui:Value("Value", 3.4, "%0.3f")
        ui:Value("Value", 3)
        ui:Text("Normal text")
        ui:Indent() do
            ui:Text("Normal indented text")
        end
        ui:Unindent()
        ui:Text("Before ImGuiStyleVar_IndentSpacing")
        ui:PushStyleVar(ui.StyleVar.IndentSpacing, ui.GetFontSize()*3) do
            ui:Text("Increase spacing to differentiate leaves from expanded contents.")
            ui:Indent() do
                ui:Text("Increase spacing to differentiate leaves from expanded contents.")
            end
            ui:Unindent()
        end
        ui:PopStyleVar()
        ui:Text("After ImGuiStyleVar_IndentSpacing")

        ui:TreePop()
    end

    -- There's no longer a way to display ui:GetColorU32(). We should expose
    -- GetStyleColorVec4 if we need that. Maybe like this:
    -- ui:ValueColor("ValueColor (Text)", { ui:GetStyleColorFloats(ui.Col.Text) })
    ui:ValueColor("ValueColor (Yellow)", BGCOLORS.YELLOW)

    ui:PushItemWidth(80)
    for i=0,7 do
        if i > 0 then ui:SameLine() end
        ui:PushID(i)
        ui:PushStyleColor(ui.Col.Button, {i/7.0, 0.6, 0.6, 1})
        ui:PushStyleColor(ui.Col.ButtonHovered, {i/7.0, 0.7, 0.7, 1})
        ui:PushStyleColor(ui.Col.ButtonActive, {i/7.0, 0.8, 0.8, 1})
        if ui:Button("Click") then
            lastClicked = "clicked "..tostring(i)
        end
        ui:PopStyleColor(3)
        ui:PopID()
    end
    ui:SameLine()
    ui:Text("  "..lastClicked)
    ui:PopItemWidth()
end

local function _ShowExampleMenuFile()
    ui:MenuItem("(dummy menu)", "", false, false)
    if (ui:MenuItem("New")) then end
    if (ui:MenuItem("Open", "Ctrl+O")) then end
    if (ui:BeginMenu("Open Recent")) then
        ui:MenuItem("fish_hat.c")
        ui:MenuItem("fish_hat.inl")
        ui:MenuItem("fish_hat.h")
        if (ui:BeginMenu("More..")) then
            ui:MenuItem("Hello")
            ui:MenuItem("Sailor")
            if (ui:BeginMenu("Recurse..")) then
                _ShowExampleMenuFile()
                ui:EndMenu()
            end
            ui:EndMenu()
        end
        ui:EndMenu()
    end
    if (ui:MenuItem("Save", "Ctrl+S")) then end
    if (ui:MenuItem("Save As..")) then end
    ui:Separator()
    if (ui:BeginMenu("Disabled", false)) then -- Disabled
        assert(false)
    end
    if (ui:MenuItem("Checked", "", true)) then end
    if (ui:MenuItem("Quit", "Alt+F4")) then end
end

local function AddImguiTestSection_Enum()
    ui:Value("ui.SelectableFlags.AllowDoubleClick", ui.SelectableFlags.AllowDoubleClick)
    ui:Value("ui.StyleVar.FramePadding ", ui.StyleVar.FramePadding)
    ui:Value("ui.StyleVar.IndentSpacing", ui.StyleVar.IndentSpacing)
    ui:Value("ui.Col.Text              ", ui.Col.Text)
    ui:Value("ui.Col.Button            ", ui.Col.Button)
    ui:Value("ui.Col.ButtonHovered     ", ui.Col.ButtonHovered)
    ui:Value("ui.Col.ButtonActive      ", ui.Col.ButtonActive)


    ui:BeginChild("#colors", 0, 300, true, ui.WindowFlags.AlwaysVerticalScrollbar)
    ui:PushItemWidth(-160)
    for i=0,ui.Col.COUNT-1 do
        local name = ui:GetStyleColorName(i)
        ui:Text(name)
    end
    ui:PopItemWidth()
    ui:EndChild()
end

local function AddImguiTestSection_Font()
	ui:Columns(2)
	for key,val in iterator.sorted_pairs(ui.icon) do
		local var_name = ("ui.icon.%s"):format(key)
		ui:Text(var_name)
		ui:NextColumn()
		if ui:Button(val, ui.icon.width) then
			ui:SetClipboardText(var_name)
		end
		if ui:IsItemHovered() then
			ui:SetTooltip(var_name)
		end
		ui:NextColumn()
	end
	ui:Columns()
end

-- Expose a few Borders related flags interactively
local ContentsType = Enum{"Text", "FillButton"}
local flags = {
	plain = ui.TableFlags.Borders | ui.TableFlags.RowBg,
	stretch = ui.TableFlags.SizingStretchSame | ui.TableFlags.Resizable | ui.TableFlags.BordersOuter | ui.TableFlags.BordersV | ui.TableFlags.ContextMenuInBody,
	headers = ui.TableFlags.Resizable | ui.TableFlags.Reorderable | ui.TableFlags.Hideable | ui.TableFlags.BordersOuter | ui.TableFlags.BordersV,
	bgcolor = ui.TableFlags.RowBg,
}
local display_headers = false
local contents_type = ContentsType.id.Text
local bgcolor = color(0.1, 0.3, 0.3, 0.65)
local row_bg_type = 1
local row_bg_target = 1
local cell_bg_type = 1
local function AddImguiTestSection_Tables(ui, panel)
	ui:TextWrapped("Converted from imgui_demo.cpp. This is only a small section of the tables demo. See the ImGui C Demo for many more possibilities.")

    if ui:TreeNode("Basic") then
        -- Here we will showcase three different ways to output a table.
        -- They are very simple variations of a same thing!

        -- [Method 1] Using TableNextRow() to create a new row, and TableSetColumnIndex() to select the column.
        -- In many situations, this is the most flexible and easy to use pattern.
        HelpMarker("Using TableNextRow() + calling TableSetColumnIndex() _before_ each cell, in a loop.")
        if ui:BeginTable("table1", 3) then
            for row=0,3 do
                ui:TableNextRow()
                for column=0,2 do
                    ui:TableSetColumnIndex(column)
                    ui:Text(string.format("Row %d Column %d", row, column))
                end
            end
            ui:EndTable()
        end

        -- [Method 2] Using TableNextColumn() called multiple times, instead of using a for loop + TableSetColumnIndex().
        -- This is generally more convenient when you have code manually submitting the contents of each columns.
        HelpMarker("Using TableNextRow() + calling TableNextColumn() _before_ each cell, manually.")
        if ui:BeginTable("table2", 3) then
            for row=0,3 do
                ui:TableNextRow()
                ui:TableNextColumn()
                ui:Text(string.format("Row %d", row))
                ui:TableNextColumn()
                ui:Text("Some contents")
                ui:TableNextColumn()
                ui:Text("123.456")
            end
            ui:EndTable()
        end

        -- [Method 3] We call TableNextColumn() _before_ each cell. We never call TableNextRow(),
        -- as TableNextColumn() will automatically wrap around and create new roes as needed.
        -- This is generally more convenient when your cells all contains the same type of data.
        HelpMarker(
            "Only using TableNextColumn(), which tends to be convenient for tables where every cells contains the same type of contents.\n"
            .."This is also more similar to the old NextColumn() function of the Columns API, and provided to facilitate the Columns->Tables API transition.")
        if ui:BeginTable("table3", 3) then
            for item=0,13 do
                ui:TableNextColumn()
                ui:Text(string.format("Item %d", item))
            end
            ui:EndTable()
        end

        ui:TreePop()
    end

    if ui:TreeNode("Borders, background") then

		bgcolor = ui:_ColorObjEdit("Background color", bgcolor)

        PushStyleCompact()
        flags.plain = ui:_CheckboxFlags("ui.TableFlags.RowBg", flags.plain, ui.TableFlags.RowBg)
        ui:SameLine(); HelpMarker("ui.TableFlags.RowBg automatically sets RowBg0 to alternative colors pulled from the Style.")
        flags.plain = ui:_CheckboxFlags("ui.TableFlags.Borders", flags.plain, ui.TableFlags.Borders)
        ui:SameLine(); HelpMarker("ui.TableFlags.Borders\n = ui.TableFlags.BordersInnerV\n | ui.TableFlags.BordersOuterV\n | ui.TableFlags.BordersInnerV\n | ui.TableFlags.BordersOuterH")
        ui:Indent()

        flags.plain = ui:_CheckboxFlags("ui.TableFlags.BordersH", flags.plain, ui.TableFlags.BordersH)
        ui:Indent()
        flags.plain = ui:_CheckboxFlags("ui.TableFlags.BordersOuterH", flags.plain, ui.TableFlags.BordersOuterH)
        flags.plain = ui:_CheckboxFlags("ui.TableFlags.BordersInnerH", flags.plain, ui.TableFlags.BordersInnerH)
        ui:Unindent()

        flags.plain = ui:_CheckboxFlags("ui.TableFlags.BordersV", flags.plain, ui.TableFlags.BordersV)
        ui:Indent()
        flags.plain = ui:_CheckboxFlags("ui.TableFlags.BordersOuterV", flags.plain, ui.TableFlags.BordersOuterV)
        flags.plain = ui:_CheckboxFlags("ui.TableFlags.BordersInnerV", flags.plain, ui.TableFlags.BordersInnerV)
        ui:Unindent()

        flags.plain = ui:_CheckboxFlags("ui.TableFlags.BordersOuter", flags.plain, ui.TableFlags.BordersOuter)
        flags.plain = ui:_CheckboxFlags("ui.TableFlags.BordersInner", flags.plain, ui.TableFlags.BordersInner)
        ui:Unindent()

        ui:AlignTextToFramePadding(); ui:Text("Cell contents:")
        ui:SameLine(); contents_type = ui:_RadioButton("Text", contents_type, ContentsType.id.Text)
        ui:SameLine(); contents_type = ui:_RadioButton("FillButton", contents_type, ContentsType.id.FillButton)

        display_headers = ui:_Checkbox("Display headers", display_headers)
        flags.plain = ui:_CheckboxFlags("ui.TableFlags.NoBordersInBody", flags.plain, ui.TableFlags.NoBordersInBody); ui:SameLine(); HelpMarker"Disable vertical borders in columns Body (borders will always appears in Headers"
        PopStyleCompact()

        if ui:BeginTable("table1", 3, flags.plain) then
            -- Display headers so we can inspect their interaction with borders.
            -- (Headers are not the main purpose of this section of the demo, so we are not elaborating on them too much. See other sections for details)
            if display_headers then
                ui:TableSetupColumn("One")
                ui:TableSetupColumn("Two")
                ui:TableSetupColumn("Three")
                ui:TableHeadersRow()
            end

            for row=0,4 do
                ui:TableNextRow()

				-- RowBg1 to make it alternate.
				ui:TableSetBgColor(ui.TableBgTarget.RowBg1, bgcolor)

                for column=0,2 do
                    ui:TableSetColumnIndex(column)
                    local buf = string.format("Hello %d,%d", column, row)
                    if contents_type == ContentsType.id.Text then
                        ui:Text(buf)
                    elseif contents_type == ContentsType.id.FillButton then
						-- imgui demo used -FLT_MIN instead of -1. I assume
						-- that's to specify "fill but otherwise don't specify
						-- size" But 1 is pretty tiny, so that's fine.
                        ui:Button(buf, -1, 0.0)
                    end
                end
            end
            ui:EndTable()
        end
        ui:TreePop()
    end


    if ui:TreeNode("Resizable, stretch") then
        -- By default, if we don't enable ScrollX the sizing policy for each columns is "Stretch"
        -- Each columns maintain a sizing weight, and they will occupy all available width.
        PushStyleCompact()
        flags.stretch = ui:_CheckboxFlags("ui.TableFlags.Resizable", flags.stretch, ui.TableFlags.Resizable)
        flags.stretch = ui:_CheckboxFlags("ui.TableFlags.BordersV", flags.stretch, ui.TableFlags.BordersV)
        ui:SameLine(); HelpMarker("Using the _Resizable flag automatically enables the _BordersInnerV flag as well, this is why the resize borders are still showing when unchecking this.")
        PopStyleCompact()

        if ui:BeginTable("table1", 3, flags.stretch) then
			for row=0,4 do
                ui:TableNextRow()
				for column=0,2 do
                    ui:TableSetColumnIndex(column)
                    ui:Text(string.format("Hello %d,%d", column, row))
                end
            end
            ui:EndTable()
        end
        ui:TreePop()
    end

    if ui:TreeNode("Reorderable, hideable, with headers") then
        HelpMarker(
            "Click and drag column headers to reorder columns.\n\n"
            .."Right-click on a header to open a context menu.")
        PushStyleCompact()
        flags.headers = ui:_CheckboxFlags("ui.TableFlags.Resizable", flags.headers, ui.TableFlags.Resizable)
        flags.headers = ui:_CheckboxFlags("ui.TableFlags.Reorderable", flags.headers, ui.TableFlags.Reorderable)
        flags.headers = ui:_CheckboxFlags("ui.TableFlags.Hideable", flags.headers, ui.TableFlags.Hideable)
        flags.headers = ui:_CheckboxFlags("ui.TableFlags.NoBordersInBody", flags.headers, ui.TableFlags.NoBordersInBody)
        flags.headers = ui:_CheckboxFlags("ui.TableFlags.NoBordersInBodyUntilResize", flags.headers, ui.TableFlags.NoBordersInBodyUntilResize); ui:SameLine(); HelpMarker("Disable vertical borders in columns Body until hovered for resize (borders will always appears in Headers)")
        PopStyleCompact()

        if ui:BeginTable("table1", 3, flags.headers) then
            -- Submit columns name with TableSetupColumn() and call TableHeadersRow() to create a row with a header in each column.
            -- (Later we will show how TableSetupColumn() has other uses, optional flags.headers, sizing weight etc.)
            ui:TableSetupColumn("One")
            ui:TableSetupColumn("Two")
            ui:TableSetupColumn("Three")
            ui:TableHeadersRow()
			for row=0,5 do
                ui:TableNextRow()
				for column=0,2 do
                    ui:TableSetColumnIndex(column)
                    ui:Text(string.format("Hello %d,%d", column, row))
                end
            end
            ui:EndTable()
        end

        -- Use outer_size.x == 0.0 instead of default to make the table as tight as possible (only valid when no scrolling and no stretch column)
        if ui:BeginTable("table2", 3, flags.headers | ui.TableFlags.SizingFixedFit, 0.0, 0.0) then
            ui:TableSetupColumn("One")
            ui:TableSetupColumn("Two")
            ui:TableSetupColumn("Three")
            ui:TableHeadersRow()
			for row=0,5 do
                ui:TableNextRow()
				for column=0,2 do
                    ui:TableSetColumnIndex(column)
                    ui:Text(string.format("Fixed %d,%d", column, row))
                end
            end
            ui:EndTable()
        end
        ui:TreePop()
    end

    if ui:TreeNode("Background color") then
        PushStyleCompact()
        flags.bgcolor = ui:_CheckboxFlags("ui.TableFlags.Borders", flags.bgcolor, ui.TableFlags.Borders)
        flags.bgcolor = ui:_CheckboxFlags("ui.TableFlags.RowBg", flags.bgcolor, ui.TableFlags.RowBg)
        ui:SameLine(); HelpMarker("ui.TableFlags.RowBg automatically sets RowBg0 to alternative colors pulled from the Style.")

		local RowBgType = Enum{ "None", "Red", "Gradient" }
		local RowBgTarget = Enum{ "RowBg0", "RowBg1" }
		local CellBgType = Enum{ "None", "Blue" }
		row_bg_type = ui:_Combo("row bg type", row_bg_type, RowBgType:Ordered())
		row_bg_target = ui:_Combo("row bg target", row_bg_target, RowBgTarget:Ordered()); ui:SameLine(); HelpMarker("Target RowBg0 to override the alternating odd/even colors,\nTarget RowBg1 to blend with them.")
		cell_bg_type = ui:_Combo("cell bg type", cell_bg_type, CellBgType:Ordered()); ui:SameLine(); HelpMarker("We are colorizing cells to B1->C2 here.")
        PopStyleCompact()

        if ui:BeginTable("table1", 5, flags.bgcolor) then
            for row=0,5 do
                ui:TableNextRow()

                -- Demonstrate setting a row background color with 'ui:TableSetBgColor(ui.TableBgTarget.RowBgX, ...)'
                -- We use a transparent color so we can see the one behind in case our target is RowBg1 and RowBg0 was already targeted by the ui.TableFlags.RowBg flag.
                if row_bg_type ~= RowBgType.id.None then
                    local row_bg_color = row_bg_type == RowBgType.id.Red and color(0.7, 0.3, 0.3, 0.65) or color(0.2 + row * 0.1, 0.2, 0.2, 0.65) -- Flat or Gradient?
					local target = row_bg_target == RowBgTarget.id.RowBg0 and ui.TableBgTarget.RowBg0 or ui.TableBgTarget.RowBg1
                    ui:TableSetBgColor(target, row_bg_color)
                end

                -- Fill cells
                for column=0,4 do
                    ui:TableSetColumnIndex(column)
                    ui:Text(string.format("%s%d", string.char(string.byte("A") + row), column))

                    -- Change background of Cells B1->C2
                    -- Demonstrate setting a cell background color with 'ui:TableSetBgColor(ui.TableBgTarget.CellBg, ...)'
                    -- (the CellBg color will be blended over the RowBg and ColumnBg colors)
                    -- We can also pass a column number as a third parameter to TableSetBgColor() and do this outside the column loop.
                    if row >= 1 and row <= 2 and column >= 1 and column <= 2 and cell_bg_type == CellBgType.id.Blue then
                        local cell_bg_color = color(0.3, 0.3, 0.7, 0.65)
                        ui:TableSetBgColor(ui.TableBgTarget.CellBg, cell_bg_color)
                    end
                end
            end
            ui:EndTable()
        end
        ui:TreePop()
    end
end

-- Call functions with similar signatures where it didn't seem useful to
-- provide both. Validate that the one we selected is the more useful one.
local selected = { false, true, false, false }
local show_main_menu = false
local show_window_menu = false
local function AddImguiTestSection_Differentiation()
    local _ = nil

    -- Selectable should return the new state of the selection and not just
    -- whether it was pressed.
    ui:SetNextWindowCollapsed(false)
    if ui:TreeNode("Basic - first") then
        _, selected[1] = ui:Selectable("1. I am selectable", selected[1])
        _, selected[2] = ui:Selectable("2. I am selectable", selected[2])
        ui:Text("3. I am not selectable")
        _, selected[3] = ui:Selectable("4. I am selectable", selected[3])

        local was_pressed, was_selected = ui:Selectable("5. I am double clickable", selected[4], ui.SelectableFlags.AllowDoubleClick)
        if was_pressed and ui:IsMouseDoubleClicked(0) then
            selected[4] = not selected[4]
        end
        ui:TreePop()
    end

    _,show_main_menu = ui:Checkbox("Show Main Menu", show_main_menu)
    -- MenuItem returns whether it was selected.
    if show_main_menu and (ui:BeginMainMenuBar()) then
        if (ui:BeginMenu("File")) then
            _ShowExampleMenuFile()
            ui:EndMenu()
        end
        if (ui:BeginMenu("Edit")) then
            if (ui:MenuItem("Undo", "CTRL+Z")) then end
            if (ui:MenuItem("Redo", "CTRL+Y", false, false)) then end  -- Disabled item
            ui:Separator()
            if (ui:MenuItem("Cut", "CTRL+X")) then end
            if (ui:MenuItem("Copy", "CTRL+C")) then end
            if (ui:MenuItem("Paste", "CTRL+V")) then end
            ui:EndMenu()
        end
        ui:EndMainMenuBar()
    end

    _,show_window_menu = ui:Checkbox("Show Window Menu", show_window_menu)
    -- MenuItem returns whether it was selected.
    if show_window_menu and (ui:BeginMenuBar()) then
        if (ui:BeginMenu("File")) then
            _ShowExampleMenuFile()
            ui:EndMenu()
        end
        if (ui:BeginMenu("Edit")) then
            if (ui:MenuItem("Undo", "CTRL+Z")) then end
            if (ui:MenuItem("Redo", "CTRL+Y", false, false)) then end  -- Disabled item
            ui:Separator()
            if (ui.MenuItem("Cut", "CTRL+X")) then end
            if (ui:MenuItem("Copy", "CTRL+C")) then end
            if (ui:MenuItem("Paste", "CTRL+V")) then end
            ui:EndMenu()
        end
        ui:EndMenuBar()
    end

end


local clipboard = "Copy me"
local clipboard2 = "And me"
function AddImguiTestSection_Input()
    ui:Value("WantCaptureMouse", ui.WantCaptureMouse())
    ui:Value("WantCaptureKeyboard", ui.WantCaptureKeyboard())
    ui:Value("WantTextInput", ui.WantTextInput())

	local value = ui:CopyPasteButtons("++clipboard_demo", "##clipboard", clipboard)
	if value then
		clipboard = value
	end
	ui:SameLineWithSpace()
	clipboard = ui:_InputText("Copyable", clipboard)

	clipboard2 = ui:_CopyPasteButtons("++clipboard_demo", "##clipboard2", clipboard2)
	ui:SameLineWithSpace()
	clipboard2 = ui:_InputText("Copyable##2", clipboard2)
end

local vec4 = { 0.10, 0.20, 0.30, 0.44 }
local vec3 = Vector3(0.10, 0.20, 0.30)
local selected_greeting_idx = nil
local single_line = "blank"
local multi_line = "put\ntext\nhere"
local tick = 0
local color_obj = color(WEBCOLORS.WHITE)
local debug_color = { 1, 0, 0.5, 1 }
local edit_mode = ui.ColorEditFlags.DisplayRGB
local progress = 0
local intval = 0
local popupopen = false
local show_test_window = false
local draw_line = false
local draw_rect = false
local draw_filled_rect = false
local draw_image = false
local draw_image_rounded = false
local draw_text = false
local draw_rect_multicolour = false
local draw_quad = false
local draw_quad_filled = false
local draw_triangle = false
local draw_triangle_filled = false
local draw_circle = false
local draw_circle_filled = false
local draw_ngon = false
local draw_ngon_filled = false
local draw_polyline = false
local polyline_closed = false
local poly_filled = false
local bezier = false
local layer = ui.Layer.Window
local drawpath = false
local path_closed = false
local path_poly = false

local thickness = 1
local floatval = 3.5
local intval = 10
local color_r, color_g, color_b, color_a = 1,1,1,1
local curve = {0,0, 0.1,0.1, 0.2,0.2, 0.3,0.3, 0.4,0.4, 0.5,0.5, 0.6,0.6, 1.0,1.0,}
local numsegs = 12
local uiscale = 1
function AddImguiTestSection_ImguiLuaProxy()
    local _ = nil

    if ui:CollapsingHeader("Floats") then
        local changed,a,b,c = ui:DragFloat3("drag", vec4[1], vec4[2], vec4[3],0.1,0,100)
        if changed then
            vec4[1] = a
            vec4[2] = b
            vec4[3] = c
        end
        changed = ui:DragFloat3List("DragFloat3List", vec4, 0.1,0,100)
        changed = ui:DragVec3f("DragVec3f", vec3, 0.1,0,100) -- vec3 is a Vector3
        changed,a = ui:DragInt("int", vec4[1])
        if changed then
            vec4[1] = a
        end
        changed,a,b,c = ui:InputFloat3("input", vec4[1], vec4[2], vec4[3])
        if changed then
            vec4[1] = a
            vec4[2] = b
            vec4[3] = c
        end
        changed, floatval = ui:SliderFloat("FloatSlider", floatval, 0, 100)
        changed, floatval = ui:SliderFloat("FloatSlider Logarithmic", floatval, 0, 100, nil, ui.SliderFlags.Logarithmic)
        changed, intval = ui:SliderInt("IntSlider", intval, 0, 100, "It's %d!")
        changed, intval = ui:SliderInt("IntSlider AlwaysClamp", intval, 0, 100, "It's %d!", ui.SliderFlags.AlwaysClamp)
    end

    if ui:CollapsingHeader("Vertical Sliders") then
		local sx, sy = 50, 160
		local changed
        changed, floatval = ui:VSliderFloat("##VSliderFloat", sx, sy, floatval, 0, 100, "VSlider\nFloat\n\n%.2f")
		ui:SameLineWithSpace()
        changed, intval = ui:VSliderInt("##VSliderInt", sx, sy, intval, 0, 100, "VSlider\nInt\n\n%d")
		ui:SameLineWithSpace(70)

		-- Port "Vertical Sliders" section from imgui_demo.cpp.
		local function hsv(h, s, v, a)
			-- We don't have an hsv conversion in lua, so whatever return it as rgb.
			return {h, s, v, a}
		end
		for i=1,4 do
			if i > 1 then ui:SameLineWithSpace() end
			ui:PushID(i)
			ui:PushStyleColor(ui.Col.FrameBg, hsv(i / 7.0, 0.5, 0.5))
			ui:PushStyleColor(ui.Col.FrameBgHovered, hsv(i / 7.0, 0.6, 0.5))
			ui:PushStyleColor(ui.Col.FrameBgActive, hsv(i / 7.0, 0.7, 0.5))
			ui:PushStyleColor(ui.Col.SliderGrab, hsv(i / 7.0, 0.9, 0.9))
			vec4[i] = ui:_VSliderFloat("##v", 18, 160, vec4[i], 0.0, 1.0, "")
			if ui:IsItemActive() or ui:IsItemHovered() then
				ui:SetTooltip(string.format("%.3f", vec4[i]))
			end
			ui:PopStyleColor(4)
			ui:PopID()
		end
	end

	if ui:CollapsingHeader("List Box") then
		local GREETING_LIST = {"hi", "hello", "yo"}
		local changed,new_sel_idx = ui:ListBox("ListBox", GREETING_LIST, math.clamp(selected_greeting_idx or 1, 1, #GREETING_LIST))
		if changed and new_sel_idx ~= selected_greeting_idx then
			selected_greeting_idx = new_sel_idx
		end
		changed,new_sel_idx = ui:Combo("Combo", math.clamp(selected_greeting_idx or 1, 1, #GREETING_LIST), GREETING_LIST)
		if changed and new_sel_idx ~= selected_greeting_idx then
			selected_greeting_idx = new_sel_idx
		end
	end

    if ui:CollapsingHeader("Text") then
        ui:TextColored(BGCOLORS.PURPLE, "Colored Text")
        local changed,a = ui:InputText("UTF-8 input", single_line)
        if changed then
            single_line = a
        end
        changed,a = ui:InputTextWithHint("InputTextWithHint", "The Hint", single_line)
        if changed then
            single_line = a
        end
        changed,a = ui:InputTextMultiline("lines of input", multi_line)
        if changed then
            multi_line = a
        end
        ui:TextWrapped("Lorem ipsum dolor sit amet, consectetur adipiscing elit. Ut eu condimentum nisl, eget blandit ante. Praesent nec consequat dolor. Morbi aliquet erat luctus erat euismod convallis. Pellentesque et volutpat lectus.")
        ui:BulletText("Bullet Text")
        ui:Bullet(); ui:Text("Text with separate bullet")
    end

    if ui:CollapsingHeader("Cool Graphs") then
        tick = math.fmod(tick + 1, 1000)
        local arr = {}
        local v = tick / 10
        for i=1,100 do
            v = v + 1
            table.insert(arr, math.sin(v))
        end
        ui:PlotLines("Curve", "", arr)
    end

    if ui:CollapsingHeader("Color") then
        ui:Text("Global color edit mode:")

        _, edit_mode = ui:RadioButton("RGB", edit_mode, ui.ColorEditFlags.DisplayRGB) ; ui.SameLine()
        _, edit_mode = ui:RadioButton("HSV", edit_mode, ui.ColorEditFlags.DisplayHSV) ; ui.SameLine()
        _, edit_mode = ui:RadioButton("HEX", edit_mode, ui.ColorEditFlags.DisplayHex) ; ui.SameLine()
        _, edit_mode = ui:RadioButton("disabled", edit_mode, ui.ColorEditFlags.None)

        local changed

        color_obj = ui:_ColorObjEdit("Color Object", color_obj)

        local r,g,b,a = table.unpack(debug_color)
        changed,r,g,b,a = ui:ColorEdit4("ColorEdit4##edit_1", r,g,b,a, edit_mode)
        if changed then
            debug_color = { r,g,b,a }
        end

        r,g,b,a = table.unpack(debug_color)
        changed,r,g,b = ui:ColorEdit3("ColorEdit3##edit_2", r,g,b, edit_mode)
        if changed then
            debug_color = { r,g,b,a }
        end

        if ui:ColorButton("Color info - click to darken",debug_color) then
            debug_color[1] = debug_color[1] * 0.5
        end
        ui:SameLine() ; ui:Text("ColorButton")
    end
    if ui:CollapsingHeader("Other") then
        ui:Text("ProgressBar")
        ui:ProgressBar(progress)
        ui:ProgressBar(progress,"progress")
        ui:ProgressBar(progress,"progress",100,40)
        ui:ProgressBar(progress,nil,200,10)
        progress = progress + 0.01
        if progress > 1 then
            progress = 0
        end
        _, intval = ui:InputInt("InputInt",intval,1,100)
        ui:Text("Dummy")
        ui:SameLine()
        ui:Dummy(10,0)
        ui:SameLine()
        ui:Text("Dummy")
        ui:SameLine()
        ui:Dummy(20,0)
        ui:SameLine()
        ui:Text("Dummy")
        if ui:Button("Popup") then
            ui:OpenPopup("hello")
        end
        if ui:BeginPopup("hello") then
            ui:Text("Hello World")
            ui:EndPopup()
        end
        if ui:Button("Modal popup") then
            ui:OpenPopup("modal hello")
        end
        if ui:BeginPopupModal("modal hello",false) then
            ui:Text("Hello World")
            if ui:Button("Close") then
                ui:CloseCurrentPopup()
            end
            ui:EndPopup()
        end
        if ui:Button("Show ImGui Test Window (Not Lua, to see features we could have)") then
            show_test_window = true
        end
        if show_test_window then
            show_test_window = ui:ShowTestWindow() -- was close clicked?
        end
        color_r, color_g, color_b, color_a = ui:ColorSelector("Pick a color!",{color_r, color_g, color_b, color_a})

        local changed = ui:CurveEditor("Curve",curve)
        local values = {}
        for t=0.1,1,0.01 do
            local x = EvaluateCurve(curve, t)
            table.insert(values, x)
        end
        ui:PlotLines("Evaluated Curve", "overlay text", values, 0, 0, 1, 100)

        ui:AtlasImage("images/bg_loading.xml","loading.tex",200,200)
        ui:SameLine(); ui:AtlasImage("images/bg_loading.xml","loading.tex",150,150, BGCOLORS.RED)
        ui:SameLine(); ui:AtlasImage("images/bg_loading.xml","loading.tex",200,100,BGCOLORS.RED,BGCOLORS.YELLOW)
        ui:SameLine(); ui:Text("AtlasImage")
        changed, uiscale = ui:SliderFloat("Display Scale:",uiscale, 0.5, 2)
        if not ui:IsItemActive() then
            ui:SetDisplayScale(uiscale)
        end
        ui:ImageButton("buttonlabel", "images/bg_loading.xml","loading.tex",200,200,{1,0,0,1}, BGCOLORS.RED);
        ui:SameLine(); ui:Text("ImageButton")
    end
    if ui:CollapsingHeader("Drawing") then
        _, layer = ui:RadioButton("Window", layer, ui.Layer.Window) ; ui.SameLine()
        _, layer = ui:RadioButton("WindowGlobal", layer, ui.Layer.WindowGlobal) ; ui.SameLine()
        _, layer = ui:RadioButton("Foreground", layer, ui.Layer.Foreground) ; ui.SameLine()
        _, layer = ui:RadioButton("Background", layer, ui.Layer.Background)
        local changed
        _,thickness = ui:DragFloat("thickness", thickness)
        _, numsegs = ui:SliderInt("Num Segments",numsegs,3,32,"%d Segments")
        ui:Columns(2, nil, true)
        _, draw_line = ui:Checkbox("Draw Line", draw_line)
        if draw_line then
            ui:DrawLine(layer, 0, 0, 500, 500, BGCOLORS.YELLOW, thickness)
        end
        ui:NextColumn()
        _, draw_image = ui:Checkbox("Draw Image", draw_image)
        if draw_image then
            ui:DrawImage(layer, "images/bg_loading.xml","loading.tex", 100, 200, 500, 500, BGCOLORS.YELLOW)
        end
        ui:NextColumn()
        _, draw_image_rounded = ui:Checkbox("Draw Image Rounded", draw_image_rounded)
        if draw_image_rounded then
            ui:DrawImageRounded(layer, "images/bg_loading.xml","loading.tex", 100, 200, 500, 500, BGCOLORS.YELLOW, 30.0, imgui.DrawFlags.RoundCornersAll)
        end
        ui:NextColumn()
        _, draw_rect = ui:Checkbox("Draw Rect", draw_rect)
        if draw_rect then
            ui:DrawRect(layer, 100, 200, 500, 500, BGCOLORS.YELLOW, 30.0, imgui.DrawFlags.RoundCornersAll, thickness)
        end
        ui:NextColumn()
        _, draw_filled_rect = ui:Checkbox("Draw Filled Rect", draw_filled_rect)
        if draw_filled_rect then
            ui:DrawRectFilled(layer, 100, 200, 500, 500, BGCOLORS.YELLOW, 30.0, imgui.DrawFlags.RoundCornersAll)
        end
        ui:NextColumn()
        _, draw_text = ui:Checkbox("Draw Text", draw_text)
        if draw_text then
            ui:DrawText(layer, 60, 200, 200, BGCOLORS.PURPLE, "This is a Text")
        end
        ui:NextColumn()
        _, draw_rect_multicolour = ui:Checkbox("Draw Rect MultiColour", draw_rect_multicolour)
        if draw_rect_multicolour then
            ui:DrawRectFilledMultiColor(layer, 100, 200, 500, 500, BGCOLORS.YELLOW, BGCOLORS.PURPLE, BGCOLORS.GREY, BGCOLORS.RED)
        end
        ui:NextColumn()
        _, draw_quad = ui:Checkbox("Draw Quad", draw_quad)
        if draw_quad then
            ui:DrawQuad(layer, 100, 100, 500, 200, 500,500, 300,400, BGCOLORS.PURPLE, thickness)
        end
        ui:NextColumn()
        _, draw_quad_filled = ui:Checkbox("Draw Quad Filled", draw_quad_filled)
        if draw_quad_filled then
            ui:DrawQuadFilled(layer, 100, 100, 500, 200, 500,500, 300,400, BGCOLORS.PURPLE)
        end
        ui:NextColumn()
        _, draw_triangle = ui:Checkbox("Draw Triangle", draw_triangle)
        if draw_triangle then
            ui:DrawTriangle(layer, 100, 100, 500, 200, 500,500, BGCOLORS.PURPLE, thickness)
        end
        ui:NextColumn()
        _, draw_triangle_filled = ui:Checkbox("Draw Triangle Filled", draw_triangle_filled)
        if draw_triangle_filled then
            ui:DrawTriangleFilled(layer, 100, 100, 500, 200, 500,500, BGCOLORS.PURPLE)
        end
        ui:NextColumn()
        _, draw_circle = ui:Checkbox("Draw Circle", draw_circle)
        if draw_circle then
            ui:DrawCircle(layer, 200, 200, 100, BGCOLORS.PURPLE, numsegs, thickness)
        end
        ui:NextColumn()
        _, draw_circle_filled = ui:Checkbox("Draw Circle Filled", draw_circle_filled)
        if draw_circle_filled then
            ui:DrawCircleFilled(layer, 200, 200, 100, BGCOLORS.PURPLE, numsegs)
        end
        ui:NextColumn()
        _, draw_ngon = ui:Checkbox("Draw Ngon", draw_ngon)
        if draw_ngon then
            ui:DrawNgon(layer, 200, 200, 100, BGCOLORS.PURPLE, numsegs, thickness)
        end
        ui:NextColumn()
        _, draw_ngon_filled = ui:Checkbox("Draw Ngon Filled", draw_ngon_filled)
        if draw_ngon_filled then
            ui:DrawNgonFilled(layer, 200, 200, 100, BGCOLORS.PURPLE, numsegs)
        end
        ui:NextColumn()
        _, draw_polyline = ui:Checkbox("Draw Polyline", draw_polyline)
        ui:SameLine() ui:Dummy(10,0) ui:SameLine()
        _, polyline_closed = ui:Checkbox("closed##1", polyline_closed)
        ui:NextColumn()
        _, poly_filled = ui:Checkbox("Draw Convex Poly Filled", poly_filled)
        ui:NextColumn()
        _, bezier = ui:Checkbox("Draw Bezier Curve", bezier)
        ui:NextColumn()
        ui:Columns()
        _, drawpath = ui:Checkbox("Draw Path", drawpath)
        ui:SameLine() ui:Dummy(10,0) ui:SameLine()
        _, path_closed = ui:Checkbox("closed##2", path_closed)
        ui:SameLine() ui:Dummy(10,0) ui:SameLine()
        _, path_poly = ui:Checkbox("Convex Poly", path_poly)

        if draw_polyline then
            ui:DrawPolyline(layer, {200, 200, 300, 100, 500, 10, 600,600}, BGCOLORS.PURPLE, polyline_closed, thickness)
        end
        if poly_filled then
            ui:DrawConvexPolyFilled(layer, {200, 200, 300, 100, 500, 10, 600,600}, BGCOLORS.PURPLE)
        end
        if bezier then
            ui:DrawBezierCurve(layer, 200, 400, 600, 600, 300, 200, 400,600, BGCOLORS.PURPLE, thickness)
        end
        if drawpath then
            ui:PathClear(layer)
            ui:PathLineTo(layer,100,100)
            ui:PathLineTo(layer,400,200)
            ui:PathLineToMergeDuplicate(layer,300,300)
            ui:PathArcTo(layer,300,300, 90, 0, 3, 16);
            ui:PathArcToFast(layer,600,600, 90, 1, 5);
            ui:PathBezierCurveTo(layer, 500, 400, 700, 400, 400, 300)
            ui:PathBezierCurveTo(layer, 500, 200, 500, 100, 400, 100)
            ui:PathRect(layer,400,400, 600, 600, 30, ui.DrawFlags.RoundCornersTop)
            ui:PathRect(layer,200,500, 300, 600, 30, ui.DrawFlags.RoundCornersTop)
            if not path_poly then
                ui:PathStroke(layer, BGCOLORS.PURPLE, path_closed, thickness)
            else
                ui:PathFillConvex(layer, BGCOLORS.PURPLE)
            end
        end
    end
end

local function AddImguiTestSection_DebugPanel(ui, panel)

	ui:Text("DebugPanels use pcall and we clean up imgui so it won't assert and crash.")
	trigger_error = ui:_Checkbox("Trigger error", trigger_error)
	if ui:Button("Open Error-catching Popup") then
		ui:OpenPopup("errorpopup")
	end
	if ui:BeginPopup("errorpopup") then
		ui:PushStyleColor(ui.Col.Button, WEBCOLORS.FUCHSIA)
		ui:PushStyleColor(ui.Col.CheckMark, WEBCOLORS.FUCHSIA)
		ui:Text("Hello")

		ui:PushStyleVar(ui.StyleVar.FramePadding, 0,0)
		ui:Checkbox("ImGuiStyleVar_FramePadding toggle", true)
		if trigger_error then
			ui:DragInt() -- bad argument error
		end
		ui:PopStyleVar()
		ui:Checkbox("regular toggle", true)

		ui:PopStyleColor(2)
		ui:EndPopup()
	end
	ui:Separator()

    local function MakeSpawnMenu()
        local spawn_menu = {}
        local limiter = 100
        for k, v in pairs(Prefabs) do
            limiter = limiter - 1
            if limiter < 0 then
                -- We can't handle too many menu items.
                break
            end
            table.insert(spawn_menu,
                {
                    name = v.name,
					isChecked = function()
						return #v.deps > 1
					end,
					isEnabled = function()
						return v.name:find("arena") == nil
					end,
                    fn = function( wx, wz )
                        if GetDebugPlayer() then
                            local entity = DebugSpawn( v.name )
                            print("SPAWN PREFAB:", v.name, entity)
                        end
                    end
                })
            spawn_menu = lume.sort(spawn_menu, "name")
        end
        return spawn_menu
    end

    -- Important! Must call at beginning of frame for each panel!
    panel:StartFrame()

    panel:AppendTable(ui, TheFrontEnd, "TheFrontEnd")
    ui:Separator()
    panel:AppendKeyValue(ui, "Debug Player as keyvalues", GetDebugPlayer())
    ui:Separator()
    panel:AppendTable(ui, GetDebugPlayer(), "Debug Player as table")
    ui:Separator()
    panel:AppendKeyValue(ui, "imgui constant", ui.constant)

    ui:Separator()
    ui:Text("TabularData")
    panel:AppendTabularData(ui, {"name", "age"}, { {'wilson', 2 }, {'wes', 6} })

	-- We don't support lazily creating menus. imgui does, but our DebugPanel
	-- expects the whole menu to be constructed. Most likely, your menus won't
	-- be too big or totally procedural (otherwise you should use a filterable
	-- alternative).
	panel:CreateDebugMenu("Spawn Prefab", MakeSpawnMenu())
end


local function AddImguiTestSections(ui, panel)

    if ui:CollapsingHeader("Remap") then
        ui:Indent()
        AddImguiTestSection_Remap()
        ui:Unindent()
    end

    if ui:CollapsingHeader("Tables") then
        ui:Indent()
        AddImguiTestSection_Tables(ui, panel)
        ui:Unindent()
    end

    if ui:CollapsingHeader("Differentiation") then
        ui:Indent()
        AddImguiTestSection_Differentiation()
        ui:Unindent()
    end

    if ui:CollapsingHeader("Enum") then
        ui:Indent()
        AddImguiTestSection_Enum()
        ui:Unindent()
    end

    if ui:CollapsingHeader("Font") then
        ui:Indent()
        AddImguiTestSection_Font()
        ui:Unindent()
    end

    if ui:CollapsingHeader("Input") then
        ui:Indent()
        AddImguiTestSection_Input()
        ui:Unindent()
    end

    if ui:CollapsingHeader("ImguiLuaProxy", ui.TreeNodeFlags.DefaultOpen) then
        ui:Indent()
        AddImguiTestSection_ImguiLuaProxy()
        ui:Unindent()
    end

    if ui:CollapsingHeader("DebugPanel") then
        ui:Indent()
        AddImguiTestSection_DebugPanel(ui, panel)
        ui:Unindent()
    end
end

function ImGuiDemo:RenderPanel(ui, panel)
    AddImguiTestSections(ui, panel)
end

DebugNodes.ImGuiDemo = ImGuiDemo

return ImGuiDemo
