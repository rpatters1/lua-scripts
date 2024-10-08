function plugindef()
    finaleplugin.RequireSelection = false
    finaleplugin.Author = "Carl Vine"
    finaleplugin.AuthorURL = "http://carlvine.com/lua/"
    finaleplugin.Copyright = "https://creativecommons.org/licenses/by/4.0/"
    finaleplugin.Version = "0.08"
    finaleplugin.Date = "2024/07/28"
    finaleplugin.Notes = [[
        Change the assigned playback layer and position for all expressions 
        in the current selection. 
        Layers __1__-__4__ are the _standard_ playback layers. 
        Layer numbers __0__, __5__ and __6__ are interpreted respectively 
        as __Current__, __Chord__ and __Expression__ Layers for playback. 

        Hold down _Shift_ when starting the script to repeat the same action 
        as last time without a confirmation dialog.
    ]]
    return "Expression Playback...",
        "Expression Playback",
        "Change the assigned playback layer for all expressions in the current selection"
end

local start_options = { -- "Begin Playback At:" (ordered)
    {   "Alignment Point",
        "Beginning of Measure",
        "Position in Measure"
    },   -- + corresponding index of EXPRESSION_PLAYBACK_STARTPOINTS:
    {   finale.EXPRPLAYSTART_ALIGNMENTPOINT,
        finale.EXPRPLAYSTART_BEGINNINGOFMEASURE,
        finale.EXPRPLAYSTART_POSINMEASURE
    }
}
local special_layer = {
    [0] = "(\"Current\" Layer)",
    [5] = "(Chord Layer)",
    [6] = "(Expression Layer)",
}
local c = { -- user config values
    layer    = 0,
    start_at = 0, -- {start_options} chosen index (0-based)
    window_pos_x = false,
    window_pos_y = false,
}
local hotkey = { -- customise hotkeys (lowercase only)
    start_at  = "z",
    show_info = "q",
}
local configuration = require("library.configuration")
local mixin = require("library.mixin")
local utils = require("library.utils")
local library = require("library.general_library")
local script_name = library.calc_script_name()
local name = plugindef():gsub("%.%.%.", "")
local refocus_document = false -- set to true if utils.show_notes_dialog is used

local function dialog_set_position(dialog)
    if c.window_pos_x and c.window_pos_y then
        dialog:StorePosition()
        dialog:SetRestorePositionOnlyData(c.window_pos_x, c.window_pos_y)
        dialog:RestorePosition()
    end
end

local function dialog_save_position(dialog)
    dialog:StorePosition()
    c.window_pos_x = dialog.StoredX
    c.window_pos_y = dialog.StoredY
    configuration.save_user_settings(script_name, c)
end

local function user_dialog()
    local y = 0
    local y_off = finenv.UI():IsOnMac() and 3 or 0
    local x_off = 54 -- horiz offset for Layer Number and Radio Group
    local save = c.layer
    local dialog = mixin.FCXCustomLuaWindow():SetTitle(name)

        local function flip_radio()
            local radio = dialog:GetControl("start_at")
            radio:SetSelectedItem((radio:GetSelectedItem() + 1) % 3)
        end
        local function show_info()
            utils.show_notes_dialog(dialog, "About " .. name, 300, 155)
            refocus_document = true
        end
        local function cstat(x, wide, str, id)
            dialog:CreateStatic(x, y, id):SetWidth(wide):SetText(str)
        end
    cstat(0, 190, "Assign Playback of All Expressions")
    y = y + 22
    cstat(0, x_off, "to Layer:")
    dialog:CreateEdit(x_off, y - y_off, "layer"):SetInteger(save):SetWidth(20)
        :AddHandleCommand(function(self)
            local s = self:GetText():lower()
            if s:find("[^0-6]") then
                if     s:find(hotkey.start_at)  then flip_radio()
                elseif s:find(hotkey.show_info) then show_info()
                end
            else
                save = tonumber(s:sub(-1)) or 0
                dialog:GetControl("data"):SetText(special_layer[save] or "")
            end
            self:SetInteger(save):SetKeyboardFocus()
        end)
    cstat(x_off + 28, 110, (special_layer[save] or ""), "data")
    y = y + 22
    cstat(0, 160, "Begin Playback At:")
    dialog:CreateButton(165, y, "q"):SetText("?"):SetWidth(20)
        :AddHandleCommand(function() show_info() end)
    y = y + 16
    local labels = finale.FCStrings()
    labels:CopyFromStringTable(start_options[1])
    dialog:CreateRadioButtonGroup(x_off, y, 3, "start_at")
        :SetText(labels):SetWidth(130)
        :SetSelectedItem(c.start_at)
    y = y + 14
    cstat(x_off / 2, 50, "[" .. hotkey.start_at .. "]")
    dialog:CreateOkButton()
    dialog:CreateCancelButton()
    dialog_set_position(dialog)
    dialog:RegisterInitWindow(function()
        local q = dialog:GetControl("q")
        q:SetFont(q:CreateFontInfo():SetBold(true)) end)
    dialog:RegisterHandleOkButtonPressed(function()
        c.layer = dialog:GetControl("layer"):GetInteger()
        c.start_at = dialog:GetControl("start_at"):GetSelectedItem() -- 0-based
    end)
    dialog:RegisterCloseWindow(function(self) dialog_save_position(self) end)
    return (dialog:ExecuteModal() == finale.EXECMODAL_OK)
end

local function playback_layer()
    if finenv.Region():IsEmpty() then
        finenv.UI():AlertError(
            "Please select some music\nbefore running this script",
            name .. " Error")
        return
    end
    configuration.get_user_settings(script_name, c, true)
    local qim = finenv.QueryInvokedModifierKeys
    local mod_key = qim and (qim(finale.CMDMODKEY_ALT) or qim(finale.CMDMODKEY_SHIFT))

    if mod_key or user_dialog() then
        local start_option = start_options[2][c.start_at + 1] -- user choice -> actual index
        local expressions = finale.FCExpressions()
        expressions:LoadAllForRegion(finenv.Region())
        for exp in each(expressions) do
            if exp.StaffGroupID == 0 then -- exclude "Staff List" expressions
                exp.PlaybackLayerAssignment = c.layer
                exp.PlaybackStart = start_option
                exp:Save()
            end
        end
    end
    if refocus_document then finenv.UI():ActivateDocumentWindow() end
end

playback_layer()
