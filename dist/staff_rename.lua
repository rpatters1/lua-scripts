local __imports = {}
local __import_results = {}

function require(item)
    if not __imports[item] then
        error("module '" .. item .. "' not found")
    end

    if __import_results[item] == nil then
        __import_results[item] = __imports[item]()
        if __import_results[item] == nil then
            __import_results[item] = true
        end
    end

    return __import_results[item]
end

__imports["library.utils"] = function()
    --[[
    $module Utility Functions

    A library of general Lua utility functions.
    ]] --
    local utils = {}

    --[[
    % copy_table

    If a table is passed, returns a copy, otherwise returns the passed value.

    @ t (mixed)
    : (mixed)
    ]]
    function utils.copy_table(t)
        if type(t) == "table" then
            local new = {}
            for k, v in pairs(t) do
                new[utils.copy_table(k)] = utils.copy_table(v)
            end
            setmetatable(new, utils.copy_table(getmetatable(t)))
            return new
        else
            return t
        end
    end

    --[[
    % table_remove_first

    Removes the first occurrence of a value from an array table.

    @ t (table)
    @ value (mixed)
    ]]
    function utils.table_remove_first(t, value)
        for k = 1, #t do
            if t[k] == value then
                table.remove(t, k)
                return
            end
        end
    end

    --[[
    % iterate_keys

    Returns an unordered iterator for the keys in a table.

    @ t (table)
    : (function)
    ]]
    function utils.iterate_keys(t)
        local a, b, c = pairs(t)

        return function()
            c = a(b, c)
            return c
        end
    end

    --[[
    % round

    Rounds a number to the nearest whole integer.

    @ num (number)
    : (number)
    ]]
    function utils.round(num)
        return math.floor(num + 0.5)
    end

    --[[ 
    % calc_roman_numeral

    Calculates the roman numeral for the input number. Adapted from https://exercism.org/tracks/lua/exercises/roman-numerals/solutions/Nia11 on 2022-08-13

    @ num (number)
    : (string)
    ]]
    function utils.calc_roman_numeral(num)
        local thousands = {'M','MM','MMM'}
        local hundreds = {'C','CC','CCC','CD','D','DC','DCC','DCCC','CM'}
        local tens = {'X','XX','XXX','XL','L','LX','LXX','LXXX','XC'}	
        local ones = {'I','II','III','IV','V','VI','VII','VIII','IX'}
        local roman_numeral = ''
        if math.floor(num/1000)>0 then roman_numeral = roman_numeral..thousands[math.floor(num/1000)] end
        if math.floor((num%1000)/100)>0 then roman_numeral=roman_numeral..hundreds[math.floor((num%1000)/100)] end
        if math.floor((num%100)/10)>0 then roman_numeral=roman_numeral..tens[math.floor((num%100)/10)] end
        if num%10>0 then roman_numeral = roman_numeral..ones[num%10] end
        return roman_numeral
    end

    --[[ 
    % calc_ordinal

    Calculates the ordinal for the input number (e.g. 1st, 2nd, 3rd).

    @ num (number)
    : (string)
    ]]
    function utils.calc_ordinal(num)
        local units = num % 10
        local tens = num % 100
        if units == 1 and tens ~= 11 then
            return num .. "st"
        elseif units == 2 and tens ~= 12 then
            return num .. "nd"
        elseif units == 3 and tens ~= 13 then
            return num .. "rd"
        end

        return num .. "th"
    end

    --[[ 
    % calc_alphabet

    This returns one of the ways that Finale handles numbering things alphabetically, such as rehearsal marks or measure numbers.

    This function was written to emulate the way Finale numbers saves when Autonumber is set to A, B, C... When the end of the alphabet is reached it goes to A1, B1, C1, then presumably to A2, B2, C2. 

    @ num (number)
    : (string)
    ]]
    function utils.calc_alphabet(num)
        local letter = ((num - 1) % 26) + 1
        local n = math.floor((num - 1) / 26)

        return string.char(64 + letter) .. (n > 0 and n or "")
    end

    return utils


end

function plugindef()
    -- This function and the 'finaleplugin' namespace
    -- are both reserved for the plug-in definition.
    finaleplugin.Author = "Jacob Winkler"
    finaleplugin.Copyright = "2022"
    finaleplugin.Version = "2.0"
    finaleplugin.Date = "8/13/2022"
    finaleplugin.MinJWLuaVersion = 0.63 -- https://robertgpatterson.com/-fininfo/-rgplua/rgplua.html
    finaleplugin.Notes = [[
USING THE 'STAFF RENAME' SCRIPT

This script creates a dialog containing the full and abbreviated names of all selected instruments, including multi-staff instruments such as organ or piano. This allows for quick renaming of staves, with far less mouse clicking than trying to rename them from the Score Manager.

If there is no selection, all staves will be loaded.

There are buttons for each instrument that will copy the full name into the abbreviated name field.

There is a popup at the bottom of the list that will automatically set all transposing instruments to show either the instrument and then the transposition (e.g. "Clarinet in Bb"), or the transposition and then the instrument (e.g. "Bb Clarinet").

Speaking of the Bb Clarinet... Accidentals are displayed with square brackets, so the dialog will show "B[b] Clarinet". This is then converted into symbols using the appropriate Enigma tags. All other font info is retained.
]]
    return "Rename Staves", "Rename Staves", "Renames selected staves"
end

local utils = require("library.utils")

function staff_rename()
    local staff_count = 0
    local multi_inst = finale.FCMultiStaffInstruments()
    multi_inst:LoadAll()
    local multi_inst_grp = {}
    local multi_fullnames = {}
    local multi_full_fonts = {}
    local multi_abbnames = {}
    local multi_abb_fonts = {}
    local multi_added = {}
    local omit_staves = {}
    local multi_staff = {}
    local multi_staves = {}
    local fullnames = {}
    local abbnames = {}
    local full_fonts = {}
    local abb_fonts = {}
    local staves = {}
    local autonumber_bool = {}
    local autonumber_style = {}
    --  tables for dialog controls
    local static_staff = {}
    local edit_fullname = {}
    local edit_abbname = {}
    local copy_button = {}
    local autonumber_check = {}
    local autonumber_popup = {}
    -- Transposing instruments (Finale 27)
    local form0_names = {"Clarinet in B[b]", "Clarinet in A", "Clarinet in E[b]","Horn in F", "Trumpet in B[b]", "Trumpet in C", "Horn in E[b]", "Piccolo Trumpet in A", "Trumpet in D", "Cornet in E[b]", "Pennywhistle in D", "Pennywhistle in G", "Tin Whistle in B[b]", "Melody Sax in C"}
    local form1_names = {"B[b] Clarinet", "A Clarinet", "E[b] Clarinet", "F Horn", "B[b] Trumpet", "C Trumpet", "E[b] Horn", "A Piccolo Trumpet", "D Trumpet", "E[b] Cornet", "D Pennywhistle", "G Pennywhistle", "B[b] Tin Whistle", "C Melody Sax"}

    function enigma_to_accidental(str)
        str.LuaString = string.gsub(str.LuaString, "%^flat%(%)", "[b]")
        str.LuaString = string.gsub(str.LuaString, "%^natural%(%)", "[n]")
        str.LuaString = string.gsub(str.LuaString, "%^sharp%(%)", "[#]")
        str:TrimEnigmaTags()
        return str
    end

    function accidental_to_enigma(s)
        s.LuaString = string.gsub(s.LuaString, "%[b%]", "^flat()")
        s.LuaString = string.gsub(s.LuaString, "%[n%]", "^natural()")
        s.LuaString = string.gsub(s.LuaString, "%[%#%]", "^sharp()")
        return s
    end

    for inst in each(multi_inst) do
        table.insert(multi_inst_grp, inst.GroupID)
        local grp = finale.FCGroup()
        grp:Load(0, inst.GroupID)
        local str = grp:CreateFullNameString()
        local font = str:CreateLastFontInfo()
        enigma_to_accidental(str)

        table.insert(multi_fullnames, str.LuaString)
        local font_enigma = finale.FCString()
        font_enigma = font:CreateEnigmaString(nil)
        table.insert(multi_full_fonts, font_enigma.LuaString)
        --
        str = grp:CreateAbbreviatedNameString()
        font = str:CreateLastFontInfo()
        font_enigma = font:CreateEnigmaString(nil)
        enigma_to_accidental(str)
        table.insert(multi_abbnames, str.LuaString)
        table.insert(multi_abb_fonts, font_enigma.LuaString)
        table.insert(multi_added, false)
        table.insert(omit_staves, inst:GetFirstStaff())
        table.insert(omit_staves, inst:GetSecondStaff())
        if inst:GetThirdStaff() ~= 0 then
            table.insert(omit_staves, inst:GetThirdStaff())
        end
        table.insert(multi_staff, inst:GetFirstStaff())
        table.insert(multi_staff, inst:GetSecondStaff())
        table.insert(multi_staff, inst:GetThirdStaff())
        table.insert(multi_staves, multi_staff)
        multi_staff = {}
    end

    local sysstaves = finale.FCSystemStaves()
    local region = finale.FCMusicRegion()
    region = finenv.Region()
    if region:IsEmpty() then
        region:SetFullDocument()
    end
    sysstaves:LoadAllForRegion(region)

    for sysstaff in each(sysstaves) do
        -- Process multi-staff instruments
        for i,j in pairs(multi_staves) do

            for k,l in pairs(multi_staves[i]) do
                if multi_staves[i][k] == sysstaff.Staff and multi_staves[i][k] ~= 0 then
                    if multi_added[i] == false then
                        table.insert(fullnames, multi_fullnames[i])
                        staff_count = staff_count + 1
                        table.insert(abbnames, multi_abbnames[i])
                        table.insert(full_fonts, multi_full_fonts[i])
                        table.insert(abb_fonts, multi_abb_fonts[i])
                        table.insert(staves, sysstaff.Staff)
                        table.insert(autonumber_bool, sysstaff.UseAutoNumberingStyle) -- ?
                        table.insert(autonumber_style, sysstaff.AutoNumberingStyle) -- ?
                        multi_added[i] = true
                        goto done
                    elseif multi_added == true then
                        goto done
                    end
                end
            end
        end
        for i, j in pairs(omit_staves) do
            if omit_staves[i] == sysstaff.Staff then
                goto done
            end
        end

        -- Process single-staff instruments
        local staff = finale.FCStaff()
        staff:Load(sysstaff.Staff)
        local str = staff:CreateFullNameString()
        local font = str:CreateLastFontInfo()
        enigma_to_accidental(str)
        table.insert(fullnames, str.LuaString)
        staff_count = staff_count + 1
        local font_enigma = finale.FCString()
        font_enigma = font:CreateEnigmaString(nil)
        table.insert(full_fonts, font_enigma.LuaString)
        str = staff:CreateAbbreviatedNameString()
        font = str:CreateLastFontInfo()
        enigma_to_accidental(str)
        table.insert(abbnames, str.LuaString)
        font_enigma = font:CreateEnigmaString(nil)
        table.insert(abb_fonts, font_enigma.LuaString)
        table.insert(staves, sysstaff.Staff)
        table.insert(autonumber_bool, staff.UseAutoNumberingStyle)
        table.insert(autonumber_style, staff.AutoNumberingStyle)
        ::done::
    end

    function dialog(title)
        local row_h = 20
        local row_count = 1
        local col_w = 140
        local col_gap = 20
        local str = finale.FCString()
        str.LuaString = title
        local dialog = finale.FCCustomLuaWindow()
        dialog:SetTitle(str)
        --
        local row = {}
        for i = 1, (staff_count + 5) do
            row[i] = (i -1) * row_h
        end
        --
        local col = {}
        for i = 1, 5 do
            col[i] = (i - 1) * col_w
            col[i] = col[i] + 40
        end
        --
        function add_ctrl(dialog, ctrl_type, text, x, y, h, w, min, max)
            str.LuaString = text
            local ctrl = ""
            if ctrl_type == "button" then
                ctrl = dialog:CreateButton(x, y + 2)
            elseif ctrl_type == "popup" then
                ctrl = dialog:CreatePopup(x, y)
            elseif ctrl_type == "checkbox" then
                ctrl = dialog:CreateCheckbox(x, y)
            elseif ctrl_type == "edit" then
                ctrl = dialog:CreateEdit(x, y)
            elseif ctrl_type == "horizontalline" then
                ctrl = dialog:CreateHorizontalLine(x, y, w)
            elseif ctrl_type == "static" then
                ctrl = dialog:CreateStatic(x, y + 4)
            elseif ctrl_type == "verticalline" then
                ctrl = dialog:CreateVerticalLine(x, y, h)
            end
            if ctrl_type == "edit" then
                ctrl:SetHeight(h - 2)
                ctrl:SetWidth(w - col_gap)
            elseif ctrl_type == "horizontalline" then
                ctrl:SetWidth(w)
            else
                ctrl:SetHeight(h)
                ctrl:SetWidth(w)
            end
            ctrl:SetText(str)
            return ctrl
        end

        local autonumber_style_list = {"Instrument 1, 2, 3", "Instrument I, II, II", "1st, 2nd, 3rd Instrument",
            "Instrument A, B, C", "1., 2., 3. Instrument"}
        local auto_x_width = 40
        local staff_num_static = add_ctrl(dialog, "static", "Staff", 0, row[1], row_h, col_w, 0, 0)
        local staff_name_full_static = add_ctrl(dialog, "static", "Full Name", col[1], row[1], row_h, col_w, 0, 0)
        local staff_name_abb_static = add_ctrl(dialog, "static", "Abbr. Name", col[2], row[1], row_h, col_w, 0, 0)
        local copy_all = add_ctrl(dialog, "button", "→", col[2] - col_gap + 2, row[1], row_h-4, 16, 0, 0)
        local master_autonumber_static = add_ctrl(dialog, "static", "Auto #", col[3] , row[1], row_h, auto_x_width, 0, 0)
        local master_autonumber_check = add_ctrl(dialog, "checkbox", "Auto #", col[3] + auto_x_width, row[1], row_h, 13, 0, 0)
        master_autonumber_check:SetCheck(1)
        local master_autonumber_popup = add_ctrl(dialog, "popup", "", col[3] + 60, row[1], row_h, col_w - col_gap, 0, 0)
        for i, k in pairs(autonumber_style_list) do
            str.LuaString = autonumber_style_list[i]
            master_autonumber_popup:AddString(str)
        end
        add_ctrl(dialog, "horizontalline", "", 0, row[2] + 8, 0, col_w * 3.5 + 20, 0, 0)
        str.LuaString = "*Custom*"
        master_autonumber_popup:AddString(str)
        --
        for i, j in pairs(staves) do
            static_staff[i] = add_ctrl(dialog, "static", staves[i], 10, row[i + 2], row_h, col_w, 0, 0)
            edit_fullname[i] = add_ctrl(dialog, "edit", fullnames[i], col[1], row[i + 2], row_h, col_w, 0, 0)
            edit_abbname[i] = add_ctrl(dialog, "edit", abbnames[i], col[2], row[i + 2], row_h, col_w, 0, 0)
            copy_button[i] = add_ctrl(dialog, "button", "→", col[2] - col_gap + 2, row[i + 2], row_h-4, 16, 0, 0)
            autonumber_check[i] = add_ctrl(dialog, "checkbox", "", col[3] + auto_x_width, row[i+2], row_h, 13, 0, 0)
            autonumber_popup[i] = add_ctrl(dialog, "popup", "", col[3] + 60, row[i+2], row_h, col_w - 20, 0, 0)
            for key, val in pairs(autonumber_style_list) do
                str.LuaString = autonumber_style_list[key]
                autonumber_popup[i]:AddString(str)
            end
            if autonumber_bool[i] then
                autonumber_check[i]:SetCheck(1)
                autonumber_popup[i]:SetEnable(true)
            else
                autonumber_check[i]:SetCheck(0)
                autonumber_popup[i]:SetEnable(false)
                master_autonumber_check:SetCheck(0)
                master_autonumber_popup:SetEnable(false)
            end
            autonumber_popup[i]:SetSelectedItem(autonumber_style[i])
            row_count = row_count + 1
        end
        --
        local form_select = add_ctrl(dialog, "popup", "", col[1], row[row_count + 2] + row_h/2, row_h, col_w - col_gap, 0, 0)
        local forms = {"Instrument in Trn.","Trn. Instrument"}
        for i,j in pairs(forms) do
            str.LuaString = forms[i]
            form_select:AddString(str)
        end   
        local hardcode_autonumber_btn = add_ctrl(dialog, "button", "Hardcode Autonumbers", col[3] + auto_x_width, row[row_count + 2], row_h, col_w, 0, 0)
        --
        dialog:CreateOkButton()
        dialog:CreateCancelButton()
        --
        function hardcode_autonumbers()
            local staff_name = {}
            local inst_nums = {}
            local inst_num = 1
            for i,k in pairs(staves) do
                edit_fullname[i]:GetText(str)
                local is_present = false
                for j, l in pairs(staff_name) do
                    if staff_name[j] == str.LuaString then
                        is_present = true
                    end
                end
                if not is_present then
                    table.insert(staff_name, str.LuaString)
                    table.insert(inst_nums, 1)
                end
            end
            for i,k in pairs(staves) do
                local is_match = false
                edit_fullname[i]:GetText(str)
                for j, l in pairs(staff_name) do
                    if (staff_name[j] == str.LuaString) and (autonumber_check[i]:GetCheck() == 1) then
                        is_match = true
                        inst_num = inst_nums[j]
                        inst_nums[j] = inst_nums[j] + 1
                    end
                end
                if is_match and (autonumber_check[i]:GetCheck() == 1) then
                    if autonumber_popup[i]:GetSelectedItem() == 0 then
                        str.LuaString = str.LuaString.." "..inst_num
                    elseif autonumber_popup[i]:GetSelectedItem() == 1 then
                        str.LuaString = str.LuaString.." "..utils.calc_roman_numeral(inst_num)
                    elseif autonumber_popup[i]:GetSelectedItem() == 2 then
                        str.LuaString = utils.calc_ordinal(inst_num).." "..str.LuaString
                    elseif autonumber_popup[i]:GetSelectedItem() == 3 then
                        str.LuaString = str.LuaString.." "..utils.calc_alphabet(inst_num)
                    elseif autonumber_popup[i]:GetSelectedItem() == 4 then
                        str.LuaString = inst_num..". "..str.LuaString
                    end
                end
                edit_fullname[i]:SetText(str)
                autonumber_check[i]:SetCheck(0)
                autonumber_popup[i]:SetEnable(false)
                is_match = false
            end
        end
        --
        function callback(ctrl)
            if ctrl:GetControlID() == form_select:GetControlID() then
                local form = form_select:GetSelectedItem()
                local search = {}
                local replace = {}
                if form == 0 then
                    search = form1_names
                    replace = form0_names
                elseif form == 1 then
                    search = form0_names
                    replace = form1_names
                end

                for a,b in pairs(search) do
                    search[a] = string.gsub(search[a], "%[", "%%[")
                    search[a] = string.gsub(search[a], "%]", "%%]")
                    replace[a] = string.gsub(replace[a], "%%", "")
                end

                for i,j in pairs(fullnames) do
                    edit_fullname[i]:GetText(str)
                    for k,l in pairs(search) do
                        str.LuaString = string.gsub(str.LuaString, search[k], replace[k])
                    end                    
                    edit_fullname[i]:SetText(str)
                    --
                    edit_abbname[i]:GetText(str)
                    for k,l in pairs(search) do
                        str.LuaString = string.gsub(str.LuaString, search[k], replace[k])
                    end                    
                    edit_abbname[i]:SetText(str)
                end
            end

            for i, j in pairs(edit_fullname) do
                if ctrl:GetControlID() == copy_button[i]:GetControlID() then
                    edit_fullname[i]:GetText(str)
                    edit_abbname[i]:SetText(str)
                elseif ctrl:GetControlID() == autonumber_check[i]:GetControlID() then
                    if autonumber_check[i]:GetCheck() == 1 then
                        autonumber_bool[i] = true
                        autonumber_popup[i]:SetEnable(true)
                    else
                        autonumber_bool[i] = false
                        autonumber_popup[i]:SetEnable(false)
                        master_autonumber_check:SetCheck(0)
                    end
                elseif ctrl:GetControlID() == autonumber_popup[i]:GetControlID() then    
                    autonumber_style[i] = autonumber_popup[i]:GetSelectedItem()
                    master_autonumber_popup:SetSelectedItem(5)
                end
            end

            if ctrl:GetControlID() == copy_all:GetControlID() then
                for i,j in pairs(edit_fullname) do
                    edit_fullname[i]:GetText(str)
                    edit_abbname[i]:SetText(str)
                end
            elseif ctrl:GetControlID() == master_autonumber_check:GetControlID() then
                if master_autonumber_check:GetCheck() == 1 then
                    master_autonumber_popup:SetEnable(true)
                    for i, k in pairs(edit_fullname) do
                        autonumber_check[i]:SetCheck(1)
                        autonumber_popup[i]:SetEnable(true)
                    end
                else
                    master_autonumber_popup:SetEnable(false)
                    for i, k in pairs(edit_fullname) do
                        autonumber_check[i]:SetCheck(0)
                        autonumber_popup[i]:SetEnable(false)
                    end
                end
            elseif ctrl:GetControlID() == master_autonumber_popup:GetControlID() then
                if master_autonumber_popup:GetSelectedItem() < 5 then
                    for i, k in pairs(edit_fullname) do
                        autonumber_popup[i]:SetSelectedItem(master_autonumber_popup:GetSelectedItem())
                    end
                end
            elseif ctrl:GetControlID() == hardcode_autonumber_btn:GetControlID() then
                hardcode_autonumbers()
            end
        end -- callback

        dialog:RegisterHandleCommand(callback)

        if dialog:ExecuteModal(nil) == finale.EXECMODAL_OK then
            local str = finale.FCString()
            for i, j in pairs(staves) do
                for k, l in pairs(multi_staves) do 
                    for m, n in pairs(multi_staves[k]) do
                        if staves[i] == multi_staves[k][m] then
                            local grp = finale.FCGroup()
                            grp:Load(0, multi_inst_grp[k])
                            edit_fullname[i]:GetText(str)
                            accidental_to_enigma(str)
                            str.LuaString = full_fonts[i]..str.LuaString
                            grp:SaveNewFullNameBlock(str)
                            edit_abbname[i]:GetText(str)
                            accidental_to_enigma(str)
                            str.LuaString = abb_fonts[i]..str.LuaString
                            grp:SaveNewAbbreviatedNameBlock(str)
                            grp:Save()
                        end
                    end
                end
                for k, l in pairs(omit_staves) do
                    if staves[i] == omit_staves[k] then
                        goto done2
                    end
                end
                local staff = finale.FCStaff()
                staff:Load(staves[i])
                edit_fullname[i]:GetText(str)
                accidental_to_enigma(str)
                str.LuaString = full_fonts[i]..str.LuaString
                staff:SaveNewFullNameString(str)
                edit_abbname[i]:GetText(str)
                accidental_to_enigma(str)

                str.LuaString = abb_fonts[i]..str.LuaString
                staff:SaveNewAbbreviatedNameString(str)
                if autonumber_check[i]:GetCheck() == 1 then
                    staff.UseAutoNumberingStyle = true
                else
                    staff.UseAutoNumberingStyle = false
                end
                staff.AutoNumberingStyle = autonumber_popup[i]:GetSelectedItem()
                staff:Save()
                ::done2::
            end
        end
    end -- function
    dialog("Rename Staves")
end -- rename_staves()

staff_rename()
