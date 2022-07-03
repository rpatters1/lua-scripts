function plugindef()
    finaleplugin.RequireSelection = false
    finaleplugin.RequireDocument = false
    finaleplugin.HandlesUndo = true -- not recognized by JW Lua or RGP Lua v0.55
    finaleplugin.Author = "Robert Patterson"
    finaleplugin.Copyright = "CC0 https://creativecommons.org/publicdomain/zero/1.0/"
    finaleplugin.Version = "1.0"
    finaleplugin.Date = "July 3, 2022"
    finaleplugin.CategoryTags = "Note"
    finaleplugin.MinJWLuaVersion = 0.63
    return "Layer Monitor...", "Layer Monitor", "Monitors the currently selected and displays it in large type."
end

local mixin = require("library.mixin")

function calc_current_layer_string()
    local misc_prefs = finale.FCMiscDocPrefs()
    if misc_prefs:Load(1) then
        if misc_prefs.ShowActiveLayerOnly then
            for layer_number = 1, finenv.UI():GetMaxLayers() do
                if finenv.UI():IsLayerVisible(layer_number) then
                    return tostring(layer_number)
                end
            end
        else
            return "All"
        end
    else
        return "N/A"
    end
    return "Err"
end

--[[
-- This function cannot currently be a library function due to the fact that it
-- modifies the document and therefore has to be rolled back. Hopefully a future
-- version of Finale will provide the current layer in the PDK, and this rather
-- messy technique will not then be required.
function calc_current_layer_string()
    local retval = "E"
    finenv.StartNewUndoBlock("Layer check", false)
    local misc_prefs = finale.FCMiscDocPrefs()
    if misc_prefs:Load(1) then
        local original_value = misc_prefs.ShowActiveLayerOnly
        misc_prefs.ShowActiveLayerOnly = true
        misc_prefs:Save()
        for layer_number = 1, finenv.UI():GetMaxLayers() do
            if finenv.UI():IsLayerVisible(layer_number) then
                retval = tostring(layer_number)
                break
            end
        end
        misc_prefs.ShowActiveLayerOnly = original_value
        misc_prefs:Save()
    else
        retval = "N"
    end
    finenv.EndUndoBlock(false)
    return retval
end
]]

global_timer_id = 1         -- per docs, we supply the timer id, starting at 1

function create_dialog_box()
    local dialog = mixin.FCXCustomLuaWindow():SetTitle("Layer")
    local font = finale.FCFontInfo()
    font.Name = "Helvetica"
    font.Size = 36
    font.Bold = true
    dialog:CreateStatic(0, 10, "layer_string")
                :SetText(calc_current_layer_string())
                :SetFont(font)
                :SetWidth(80)
                :SetHeight(40)
    dialog:CreateOkButton():SetText("Close")
    dialog:RegisterHandleTimer(function(timer_id)
            global_dialog:GetControl("layer_string"):SetText(calc_current_layer_string())
        end
    )
    dialog:RegisterInitWindow(function(self)
            self.OkButtonCanClose = true -- override default behavior
            self:SetTimer(global_timer_id, 100) -- timer can't be set until window is created
        end
    )
    dialog:RegisterCloseWindow(function(self)
            self:StopTimer(global_timer_id)
        end
    )
    return dialog
end

function layer_monitor()
    global_dialog = global_dialog or create_dialog_box()
    global_dialog:RunModeless(true) -- true: no selection required
    --global_dialog:StartTimer(global_timer_id, 100) -- timer can't be set until window is created
end

layer_monitor()
