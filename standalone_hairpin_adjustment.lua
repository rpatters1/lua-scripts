function plugindef()
    finaleplugin.RequireSelection = true
    finaleplugin.Author = "CJ Garcia"
    finaleplugin.Copyright = "© 2021 CJ Garcia Music"
    finaleplugin.Version = "1.1"
    finaleplugin.Date = "2/29/2021"
    return "Hairpin and Dynamic Adjustments", "Hairpin and Dynamic Adjustments", "Adjusts hairpins to remove collisions with dynamics and aligns hairpins with dynamics."
end

local path = finale.FCString()
path:SetRunningLuaFolderPath()
package.path = package.path .. ";" .. path.LuaString .. "?.lua"
local expression = require("library.expression")

-- These parameters can be adjusted to suit any user's taste.
-- ToDo: optionally read them in from a text file, maybe?

local left_dynamic_cushion = 9              -- space between a dynamic and a hairpin on the left
local right_dynamic_cushion = -9            -- space between a dynamic and a haripin on the right
local left_selection_cushion = 0            -- currently not used
local right_selection_cushion = 0           -- additional space between a hairpin and the end of its beat region
local extend_to_end_of_right_entry = true   -- if true, extend hairpins through the end of their right note entries

-- end of parameters

function calc_cell_relative_vertical_position(fccell, page_offset)
    local relative_position = page_offset
    local cell_metrics = fccell:CreateCellMetrics()
    if nil ~= cell_metrics then
        relative_position = page_offset - cell_metrics.ReferenceLinePos
        cell_metrics:FreeMetrics()
    end
    return relative_position
end

function expression_calc_relative_vertical_position(fcexpression)
    local arg_point = finale.FCPoint(0, 0)
    if not fcexpression:CalcMetricPos(arg_point) then
        return false, 0
    end
    local cell = finale.FCCell(fcexpression.Measure, fcexpression.Staff)
    local vertical_pos = calc_cell_relative_vertical_position(cell, arg_point:GetY())
    return true, vertical_pos
end

function smartshape_calc_relative_vertical_position(fcsmartshape)
    local arg_point = finale.FCPoint(0, 0)
    -- due to a limitation in Finale, CalcRightCellMetricPos is not reliable, so only check CalcLeftCellMetricPos
    if not fcsmartshape:CalcLeftCellMetricPos(arg_point) then 
        return false, 0
    end
    local ss_seg = fcsmartshape:GetTerminateSegmentLeft()
    local cell = finale.FCCell(ss_seg.Measure, ss_seg.Staff)
    local vertical_pos = calc_cell_relative_vertical_position(cell, arg_point:GetY())
    return true, vertical_pos
end

function vertical_dynamic_adjustment(region, direction)
    local lowest_item = {}
    local staff_pos = {}
    local has_dynamics = false
    local has_hairpins = false

    local expressions = finale.FCExpressions()
    expressions:LoadAllForRegion(region)
    for e in each(expressions) do
        local create_def = e:CreateTextExpressionDef()
        local cd = finale.FCCategoryDef()
        if cd:Load(create_def:GetCategoryID()) then
            if ((cd:GetID() == finale.DEFAULTCATID_DYNAMICS) or (string.find(cd:CreateName().LuaString, "Dynamic"))) then
                local success, staff_offset = expression_calc_relative_vertical_position(e)
                if success then
                    has_dynamics = true
                    table.insert(lowest_item, staff_offset)
                end
            end
        end
    end

    local ssmm = finale.FCSmartShapeMeasureMarks()
    ssmm:LoadAllForRegion(region, true)
    for mark in each(ssmm) do
        local smart_shape = mark:CreateSmartShape()
        if smart_shape:IsHairpin() then
            has_hairpins = true
            local success, staff_offset = smartshape_calc_relative_vertical_position(smart_shape)
            if success then 
                table.insert(lowest_item, staff_offset)
            end
        end
    end

    table.sort(lowest_item)

    if has_dynamics then
        local expressions = finale.FCExpressions()
        expressions:LoadAllForRegion(region)
        for e in each(expressions) do
            local create_def = e:CreateTextExpressionDef()
            local cd = finale.FCCategoryDef()
            if cd:Load(create_def:GetCategoryID()) then
                if ((cd:GetID() == finale.DEFAULTCATID_DYNAMICS) or (string.find(cd:CreateName().LuaString, "Dynamic"))) then
                    local success, staff_offset = expression_calc_relative_vertical_position(e)
                    if success then
                        local difference_pos =  staff_offset - lowest_item[1]
                        if direction == "near" then
                            difference_pos = lowest_item[#lowest_item] - staff_offset
                        end
                        local current_pos = e:GetVerticalPos()
                        if direction == "far" then
                            e:SetVerticalPos(current_pos - difference_pos)
                        else
                            e:SetVerticalPos(current_pos + difference_pos)
                        end
                        e:Save()
                    end
                end
            end
        end
    else
        for noteentry in eachentry(region) do
            if noteentry:IsNote() then
                for note in each(noteentry) do
                    table.insert(staff_pos, note:CalcStaffPosition())
                end
            end
        end

        table.sort(staff_pos)

        if staff_pos[1] ~= nil then
            if staff_pos[1] > -7 then
                lowest_item[1] = -160
            else
                local below_note_cushion = 45
                lowest_item[1] = (staff_pos[1] * 12) - below_note_cushion
            end
        end
    end

    if has_hairpins then
        local ssmm = finale.FCSmartShapeMeasureMarks()
        ssmm:LoadAllForRegion(region, true)
        for mark in each(ssmm) do
            local smart_shape = mark:CreateSmartShape()
            if smart_shape:IsHairpin() then
                local success, staff_offset = smartshape_calc_relative_vertical_position(smart_shape)
                if success then 
                    local left_seg = smart_shape:GetTerminateSegmentLeft()
                    local right_seg = smart_shape:GetTerminateSegmentRight()
                    local current_pos = left_seg:GetEndpointOffsetY()
                    local difference_pos = staff_offset - lowest_item[1]
                    if direction == "near" then
                        difference_pos = lowest_item[#lowest_item] - staff_offset
                    end
                    if has_dynamics then
                        if direction == "far" then
                            left_seg:SetEndpointOffsetY((current_pos - difference_pos) + 12)
                            right_seg:SetEndpointOffsetY((current_pos - difference_pos) + 12)
                        else
                            left_seg:SetEndpointOffsetY((current_pos + difference_pos) + 12)
                            right_seg:SetEndpointOffsetY((current_pos + difference_pos) + 12)
                        end
                    else
                        left_seg:SetEndpointOffsetY(lowest_item[1])
                        right_seg:SetEndpointOffsetY(lowest_item[1])
                    end
                    smart_shape:Save()
                end
            end
        end
    end
end

function horizontal_hairpin_adjustment(left_or_right, hairpin, region_settings, cushion_bool, multiple_hairpin_bool)
    local the_seg = hairpin:GetTerminateSegmentLeft()

    if left_or_right == "left" then
        the_seg = hairpin:GetTerminateSegmentLeft()
    end
    if left_or_right == "right" then
        the_seg = hairpin:GetTerminateSegmentRight()
    end

    local region = finale.FCMusicRegion()
    region:SetStartStaff(region_settings[1])
    region:SetEndStaff(region_settings[1])

    if multiple_hairpin_bool then
        region:SetStartMeasure(the_seg:GetMeasure())
        region:SetStartMeasurePos(the_seg:GetMeasurePos())
        region:SetEndMeasure(the_seg:GetMeasure())
        region:SetEndMeasurePos(the_seg:GetMeasurePos())
    else
        region:SetStartMeasure(region_settings[2])
        region:SetEndMeasure(region_settings[2])
        region:SetStartMeasurePos(region_settings[3])
        region:SetEndMeasurePos(region_settings[3])
        the_seg:SetMeasurePos(region_settings[3])
    end

    local expressions = finale.FCExpressions()
    expressions:LoadAllForRegion(region)
    local expression_list = {}
    for e in each(expressions) do
        local create_def = e:CreateTextExpressionDef()
        local cd = finale.FCCategoryDef()
        if cd:Load(create_def:GetCategoryID()) then
            if ((cd:GetID() == finale.DEFAULTCATID_DYNAMICS) or (string.find(cd:CreateName().LuaString, "Dynamic"))) then
                local text_met = finale.FCTextMetrics()
                local string = create_def:CreateTextString()
                local font_info = string:CreateLastFontInfo()
                string:TrimEnigmaTags()
                text_met:LoadString(string, font_info, 100)
                table.insert(expression_list, {text_met:GetAdvanceWidthEVPUs(), e, e:GetItemInci()})
            end
        end
    end
    if #expression_list > 0 then
        local dyn_exp = expression_list[1][2]
        local dyn_def = dyn_exp:CreateTextExpressionDef()
        local dyn_width = expression_list[1][1] -- the full value is needed for finale.EXPRJUSTIFY_LEFT
        if finale.EXPRJUSTIFY_CENTER == dyn_def.HorizontalJustification then
            dyn_width = dyn_width / 2
        elseif finale.EXPRJUSTIFY_RIGHT == dyn_def.HorizontalJustification then
            dyn_width = 0
        end
        local total_offset = expression.calc_handle_offset_for_smart_shape(dyn_exp)
        if left_or_right == "left" then
            local total_x = dyn_width + left_dynamic_cushion + total_offset
            the_seg:SetEndpointOffsetX(total_x)
        elseif left_or_right == "right" then
            cushion_bool = false
            local total_x = (0 - dyn_width) + right_dynamic_cushion + total_offset
            the_seg:SetEndpointOffsetX(total_x)
        end
    end
    if cushion_bool then
        the_seg = hairpin:GetTerminateSegmentRight()
        local entry_width = 0
        if extend_to_end_of_right_entry then
            region:SetStartMeasure(the_seg:GetMeasure())
            region:SetStartMeasurePos(the_seg:GetMeasurePos())
            region:SetEndMeasure(the_seg:GetMeasure())
            region:SetEndMeasurePos(the_seg:GetMeasurePos())
            for noteentry in eachentry(region) do
                local this_width =  note_entry.calc_right_of_all_noteheads(noteentry)
                if this_width > entry_width then
                    entry_width = this_width
                end
            end
        end
        the_seg:SetEndpointOffsetX(right_selection_cushion + entry_width)
    end
    hairpin:Save()
end

function hairpin_adjustments(range_settings, adjustment_type)

    local music_reg = finale.FCMusicRegion()
    music_reg:SetCurrentSelection()
    music_reg:SetStartStaff(range_settings[1])
    music_reg:SetEndStaff(range_settings[1])
    music_reg:SetStartMeasure(range_settings[2])
    music_reg:SetEndMeasure(range_settings[3])

    local hairpin_list = {}

    local ssmm = finale.FCSmartShapeMeasureMarks()
    ssmm:LoadAllForRegion(music_reg, true)
    for mark in each(ssmm) do
        local smartshape = mark:CreateSmartShape()
        if smartshape:IsHairpin() then
            table.insert(hairpin_list, smartshape)
        end
    end

    function has_dynamic(region)
        
        local expressions = finale.FCExpressions()
        expressions:LoadAllForRegion(region)
        local expression_list = {}
        for e in each(expressions) do
            local create_def = e:CreateTextExpressionDef()
            local cd = finale.FCCategoryDef()
            if cd:Load(create_def:GetCategoryID()) then
                if ((cd:GetID() == finale.DEFAULTCATID_DYNAMICS) or (string.find(cd:CreateName().LuaString, "Dynamic"))) then
                    table.insert(expression_list, e)
                end
            end
        end
        if #expression_list > 0 then
            return true
        else
            return false
        end
    end

    local end_pos = range_settings[5]
    local end_cushion = false

    local notes_in_region = {}
    for noteentry in eachentry(music_reg) do
        if noteentry:IsNote() then
            table.insert(notes_in_region, noteentry)
        end
    end

    music_reg:SetStartMeasure(notes_in_region[#notes_in_region]:GetMeasure())
    music_reg:SetEndMeasure(notes_in_region[#notes_in_region]:GetMeasure())
    music_reg:SetStartMeasurePos(notes_in_region[#notes_in_region]:GetMeasurePos())
    music_reg:SetEndMeasurePos(notes_in_region[#notes_in_region]:GetMeasurePos())
    
    if (has_dynamic(music_reg)) and (#notes_in_region > 1) then
        local last_note = notes_in_region[#notes_in_region]
        end_pos = last_note:GetMeasurePos() + last_note:GetDuration()
    elseif (has_dynamic(music_reg)) and (#notes_in_region == 1) then
        end_pos = range_settings[5]
    else
        end_cushion = true
    end

    music_reg:SetStartStaff(range_settings[1])
    music_reg:SetEndStaff(range_settings[1])
    music_reg:SetStartMeasure(range_settings[2])
    music_reg:SetEndMeasure(range_settings[3])
    music_reg:SetStartMeasurePos(range_settings[4])
    music_reg:SetEndMeasurePos(end_pos)

    if adjustment_type == "both" then
        for key, value in pairs(hairpin_list) do
            horizontal_hairpin_adjustment("left", value, {range_settings[1], range_settings[2], range_settings[4]}, end_cushion, true)
            horizontal_hairpin_adjustment("right", value, {range_settings[1], range_settings[3], end_pos}, end_cushion, true)
        end
        vertical_dynamic_adjustment(music_reg, "far")
    else 
        vertical_dynamic_adjustment(music_reg, adjustment_type)
    end
end

function set_first_last_note_in_range(staff)

    local music_region = finale.FCMusicRegion()
    local range_settings = {}
    music_region:SetCurrentSelection()
    music_region:SetStartStaff(staff)
    music_region:SetEndStaff(staff)

    local notes_in_region = {}

    for noteentry in eachentry(music_region) do
        if noteentry:IsNote() then
            table.insert(notes_in_region, noteentry)
        end
    end

    if #notes_in_region > 0 then
        
        local start_pos = notes_in_region[1]:GetMeasurePos()
        
        local end_pos = notes_in_region[#notes_in_region]:GetMeasurePos() 

        local start_measure = notes_in_region[1]:GetMeasure()

        local end_measure = notes_in_region[#notes_in_region]:GetMeasure()
        
        if notes_in_region[#notes_in_region]:GetDuration() >= 2048 then
            end_pos = end_pos + notes_in_region[#notes_in_region]:GetDuration() 
        end

        return {staff, start_measure, end_measure, start_pos, end_pos}
    end
    return nil
end

function dynamics_align_hairpins_and_dynamics()
    local staves = finale.FCStaves()
    staves:LoadAll()
    for staff in each(staves) do
        local music_region = finale.FCMusicRegion()
        music_region:SetCurrentSelection()
        if music_region:IsStaffIncluded(staff:GetItemNo()) then
            local range_settings = set_first_last_note_in_range(staff:GetItemNo())
            if nil ~= range_settings then
                hairpin_adjustments(range_settings, "both")
            end
        end
    end
end

dynamics_align_hairpins_and_dynamics()
