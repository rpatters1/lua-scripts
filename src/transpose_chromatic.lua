function plugindef(locale)
    finaleplugin.RequireSelection = false
    finaleplugin.HandlesUndo = true -- not recognized by JW Lua or RGP Lua v0.55
    finaleplugin.Author = "Robert Patterson"
    finaleplugin.Copyright = "CC0 https://creativecommons.org/publicdomain/zero/1.0/"
    finaleplugin.Version = "1.2"
    finaleplugin.Date = "January 9, 2024"
    finaleplugin.CategoryTags = "Pitch"
    finaleplugin.Notes = [[
        This script transposes the selected region by a chromatic interval. It works correctly even with
        microtone scales defined by custom key signatures.

        Normally the script opens a modeless window. However, if you invoke the plugin with a shift, option, or
        alt key pressed, it skips opening a window and uses the last settings you entered into the window.
        (This works with RGP Lua version 0.60 and higher.)

        If you are using custom key signatures with JW Lua or an early version of RGP Lua, you must create
        a custom_key_sig.config.txt file in a folder called `script_settings` within the same folder as the script.
        It should contains the following two lines that define the custom key signature you are using. Unfortunately,
        the JW Lua and early versions of RGP Lua do not allow scripts to read this information from the Finale document.

        (This example is for 31-EDO.)

        ```
        number_of_steps = 31
        diatonic_steps = {0, 5, 10, 13, 18, 23, 28}
        ```

        Later versions of RGP Lua (0.58 or higher) ignore this configuration file (if it exists) and read the correct
        information from the Finale document.
    ]]
    local loc = {}
    loc.en = {
        menu = "Transpose Chromatic",
        desc = "Chromatic transposition of selected region (supports microtone systems)."
    }
    loc.es = {
        menu = "Trasponer cromático",
        desc = "Trasposición cromática de la región seleccionada (soporta sistemas de microtono)."
    }
    loc.de = {
        menu = "Transponieren chromatisch",
        desc = "Chromatische Transposition des ausgewählten Abschnittes (unterstützt Mikrotonsysteme)."
    }
    local t = locale and loc[locale:sub(1,2)] or loc.en
    return t.menu .. "...", t.menu, t.desc
end

if not finenv.IsRGPLua then
    local path = finale.FCString()
    path:SetRunningLuaFolderPath()
    package.path = package.path .. ";" .. path.LuaString .. "?.lua"
end

local transposition = require("library.transposition")
local mixin = require("library.mixin")
local loc = require("library.localization")
local utils = require("library.utils")

if finenv.IsRGPLua then
    loc.en = loc.en or {
        ["Finale is unable to represent some of the transposed pitches. These pitches were left unchanged."] =
            "Finale is unable to represent some of the transposed pitches. These pitches were left unchanged.",
        ["Augmented Fifth"] = "Augmented Fifth",
        ["Augmented Fourth"] = "Augmented Fourth",
        ["Augmented Second"] = "Augmented Second",
        ["Augmented Seventh"] = "Augmented Seventh",
        ["Augmented Sixth"] = "Augmented Sixth",
        ["Augmented Third"] = "Augmented Third",
        ["Augmented Unison"] = "Augmented Unison",
        ["Diminished Fifth"] = "Diminished Fifth",
        ["Diminished Fourth"] = "Diminished Fourth",
        ["Diminished Octave"] = "Diminished Octave",
        ["Diminished Second"] = "Diminished Second",
        ["Diminished Seventh"] = "Diminished Seventh",
        ["Diminished Sixth"] = "Diminished Sixth",
        ["Diminished Third"] = "Diminished Third",
        ["Direction"] = "Direction",
        ["Down"] = "Down",
        ["Interval"] = "Interval",
        ["Major Second"] = "Major Second",
        ["Major Seventh"] = "Major Seventh",
        ["Major Sixth"] = "Major Sixth",
        ["Major Third"] = "Major Third",
        ["Minor Second"] = "Minor Second",
        ["Minor Seventh"] = "Minor Seventh",
        ["Minor Sixth"] = "Minor Sixth",
        ["Minor Third"] = "Minor Third",
        ["Perfect Fifth"] = "Perfect Fifth",
        ["Perfect Fourth"] = "Perfect Fourth",
        ["Perfect Octave"] = "Perfect Octave",
        ["Perfect Unison"] = "Perfect Unison",
        ["Pitch"] = "Pitch",
        ["Plus Octaves"] = "Plus Octaves",
        ["Preserve Existing Notes"] = "Preserve Existing Notes",
        ["Simplify Spelling"] = "Simplify Spelling",
        ["Transposition Error"] = "Transposition Error",
        ["Up"] = "Up",
        ["OK"] = "OK",
        ["Cancel"] = "Cancel",
    }
    loc.es = loc.es or {
        ["Finale is unable to represent some of the transposed pitches. These pitches were left unchanged."] =
            "Finale no puede representar algunas de las notas traspuestas. Estas notas no se han cambiado.",
        ["Augmented Fifth"] = "Quinta aumentada",
        ["Augmented Fourth"] = "Cuarta aumentada",
        ["Augmented Second"] = "Segunda aumentada",
        ["Augmented Seventh"] = "Séptima aumentada",
        ["Augmented Sixth"] = "Sexta aumentada",
        ["Augmented Third"] = "Tercera aumentada",
        ["Augmented Unison"] = "Unísono aumentado",
        ["Diminished Fifth"] = "Quinta disminuida",
        ["Diminished Fourth"] = "Cuarta disminuida",
        ["Diminished Octave"] = "Octava disminuida",
        ["Diminished Second"] = "Segunda disminuida",
        ["Diminished Seventh"] = "Séptima disminuida",
        ["Diminished Sixth"] = "Sexta disminuida",
        ["Diminished Third"] = "Tercera disminuida",
        ["Direction"] = "Dirección",
        ["Down"] = "Abajo",
        ["Interval"] = "Intervalo",
        ["Major Second"] = "Segunda mayor",
        ["Major Seventh"] = "Séptima mayor",
        ["Major Sixth"] = "Sexta mayor",
        ["Major Third"] = "Tercera mayor",
        ["Minor Second"] = "Segunda menor",
        ["Minor Seventh"] = "Séptima menor",
        ["Minor Sixth"] = "Sexta menor",
        ["Minor Third"] = "Tercera menor",
        ["Perfect Fifth"] = "Quinta justa",
        ["Perfect Fourth"] = "Cuarta justa",
        ["Perfect Octave"] = "Octava justa",
        ["Perfect Unison"] = "Unísono justo",
        ["Pitch"] = "Tono",
        ["Plus Octaves"] = "Más Octavas",
        ["Preserve Existing Notes"] = "Preservar notas existentes",
        ["Simplify Spelling"] = "Simplificar enarmonización",
        ["Transposition Error"] = "Error de trasposición",
        ["Up"] = "Arriba",
        ["OK"] = "Aceptar",
        ["Cancel"] = "Cancelar",
    }
    loc.de = loc.de or {
        ["Finale is unable to represent some of the transposed pitches. These pitches were left unchanged."] =
            "Finale kann einige der transponierten Tönhöhen nicht darstellen. Diese Tönhöhen wurden unverändert gelassen.",
        ["Augmented Fifth"] = "Übermäßige Quinte",
        ["Augmented Fourth"] = "Übermäßige Quarte",
        ["Augmented Second"] = "Übermäßige Sekunde",
        ["Augmented Seventh"] = "Übermäßige Septime",
        ["Augmented Sixth"] = "Übermäßige Sexte",
        ["Augmented Third"] = "Übermäßige Terz",
        ["Augmented Unison"] = "Übermäßige Prime",
        ["Diminished Fifth"] = "Verminderte Quinte",
        ["Diminished Fourth"] = "Verminderte Quarte",
        ["Diminished Octave"] = "Verminderte Oktave",
        ["Diminished Second"] = "Verminderte Sekunde",
        ["Diminished Seventh"] = "Verminderte Septime",
        ["Diminished Sixth"] = "Verminderte Sexte",
        ["Diminished Third"] = "Verminderte Terz",
        ["Direction"] = "Richtung",
        ["Down"] = "Runter",
        ["Interval"] = "Intervall",
        ["Major Second"] = "Große Sekunde",
        ["Major Seventh"] = "Große Septime",
        ["Major Sixth"] = "Große Sexte",
        ["Major Third"] = "Große Terz",
        ["Minor Second"] = "Kleine Sekunde",
        ["Minor Seventh"] = "Kleine Septime",
        ["Minor Sixth"] = "Kleine Sexte",
        ["Minor Third"] = "Kleine Terz",
        ["Perfect Fifth"] = "Reine Quinte",
        ["Perfect Fourth"] = "Reine Quarte",
        ["Perfect Octave"] = "Reine Oktave",
        ["Perfect Unison"] = "Reine Prime",
        ["Pitch"] = "Tonhöhe",
        ["Plus Octaves"] = "Plus Oktaven",
        ["Preserve Existing Notes"] = "Bestehende Noten beibehalten",
        ["Simplify Spelling"] = "Notation vereinfachen",
        ["Transposition Error"] = "Transpositionsfehler",
        ["Up"] = "Hoch",
        ["OK"] = "OK",
        ["Cancel"] = "Abbrechen",
    }
end

interval_names = interval_names or {
    loc.localize("Perfect Unison"),
    loc.localize("Augmented Unison"),
    loc.localize("Diminished Second"),
    loc.localize("Minor Second"),
    loc.localize("Major Second"),
    loc.localize("Augmented Second"),
    loc.localize("Diminished Third"),
    loc.localize("Minor Third"),
    loc.localize("Major Third"),
    loc.localize("Augmented Third"),
    loc.localize("Diminished Fourth"),
    loc.localize("Perfect Fourth"),
    loc.localize("Augmented Fourth"),
    loc.localize("Diminished Fifth"),
    loc.localize("Perfect Fifth"),
    loc.localize("Augmented Fifth"),
    loc.localize("Diminished Sixth"),
    loc.localize("Minor Sixth"),
    loc.localize("Major Sixth"),
    loc.localize("Augmented Sixth"),
    loc.localize("Diminished Seventh"),
    loc.localize("Minor Seventh"),
    loc.localize("Major Seventh"),
    loc.localize("Augmented Seventh"),
    loc.localize("Diminished Octave"),
    loc.localize("Perfect Octave")
}

interval_disp_alts = interval_disp_alts or {
    {0,0},  {0,1},                      -- unisons
    {1,-2}, {1,-1}, {1,0}, {1,1},       -- 2nds
    {2,-2}, {2,-1}, {2,0}, {2,1},       -- 3rds
    {3,-1}, {3,0},  {3,1},              -- 4ths
    {4,-1}, {4,0},  {4,1},              -- 5ths
    {5,-2}, {5,-1}, {5,0}, {5,1},       -- 6ths
    {6,-2}, {6,-1}, {6,0}, {6,1},       -- 7ths
    {7,-1}, {7,0}                       -- octaves
}

function do_transpose_chromatic(direction, interval_index, simplify, plus_octaves, preserve_originals)
    if finenv.Region():IsEmpty() then
        return
    end
    local interval = direction * interval_disp_alts[interval_index][1]
    local alteration = direction * interval_disp_alts[interval_index][2]
    plus_octaves = direction * plus_octaves
    local undostr = ({plugindef(loc.get_locale())})[2] .. " " .. tostring(finenv.Region().StartMeasure)
    if finenv.Region().StartMeasure ~= finenv.Region().EndMeasure then
        undostr = undostr .. " - " .. tostring(finenv.Region().EndMeasure)
    end
    finenv.StartNewUndoBlock(undostr, false) -- this works on both JW Lua and RGP Lua
    local success = true
    for entry in eachentrysaved(finenv.Region()) do
        if not transposition.entry_chromatic_transpose(entry, interval, alteration, simplify, plus_octaves, preserve_originals) then
            success = false
        end
    end
    if finenv.EndUndoBlock then -- EndUndoBlock only exists on RGP Lua 0.56 and higher
        finenv.EndUndoBlock(true)
        finenv.Region():Redraw()
    else
        finenv.StartNewUndoBlock(undostr, true) -- JW Lua automatically terminates the final undo block we start here
    end
    if not success then
        finenv.UI():AlertError(
            loc.localize("Finale is unable to represent some of the transposed pitches. These pitches were left unchanged."),
            loc.localize("Transposition Error")
        )
    end
    return success
end

function create_dialog_box()
    local dialog = mixin.FCXCustomLuaWindow()
        :SetTitle(plugindef(loc.get_locale()):gsub("%.%.%.", ""))
    local current_y = 0
    local y_increment = 26
    local x_increment = 85
    -- direction
    dialog:CreateStatic(0, current_y + 2, "direction_label")
        :SetText(loc.localize("Direction"))
        :_FallbackCall("DoAutoResizeWidth", nil, true)
    dialog:CreatePopup(x_increment, current_y, "direction_choice")
        :AddStrings(loc.localize("Up"), loc.localize("Down")):SetWidth(x_increment)
        :SetSelectedItem(0)
        :_FallbackCall("DoAutoResizeWidth", nil, true)
        :_FallbackCall("AssureNoHorizontalOverlap", nil, dialog:GetControl("direction_label"), 5)
    current_y = current_y + y_increment
    -- interval
    static = dialog:CreateStatic(0, current_y + 2, "interval_label")
        :SetText(loc.localize("Interval"))
        :_FallbackCall("DoAutoResizeWidth", nil, true)
    dialog:CreatePopup(x_increment, current_y, "interval_choice")
        :AddStrings(table.unpack(interval_names))
        :SetWidth(140)
        :SetSelectedItem(0)
        :_FallbackCall("DoAutoResizeWidth", nil, true)
        :_FallbackCall("AssureNoHorizontalOverlap", nil, dialog:GetControl("interval_label"), 5)
        :_FallbackCall("HorizontallyAlignLeftWith", nil, dialog:GetControl("direction_choice"))
    current_y = current_y + y_increment
    -- simplify checkbox
    dialog:CreateCheckbox(0, current_y + 2, "do_simplify")
        :SetText(loc.localize("Simplify Spelling"))
        :SetWidth(140)
        :SetCheck(0)
        :_FallbackCall("DoAutoResizeWidth", nil, true)
    current_y = current_y + y_increment
    -- plus octaves
    dialog:CreateStatic(0, current_y + 2, "plus_octaves_label")
        :SetText(loc.localize("Plus Octaves"))
        :_FallbackCall("DoAutoResizeWidth", nil, true)
    local edit_x = x_increment + utils.win_mac(0, 4)
    dialog:CreateEdit(edit_x, current_y, "plus_octaves")
        :SetText("")
        :_FallbackCall("AssureNoHorizontalOverlap", nil, dialog:GetControl("plus_octaves_label"), 5)
        :_FallbackCall("HorizontallyAlignLeftWith", nil, dialog:GetControl("direction_choice"))
    current_y = current_y + y_increment
    -- preserve existing notes
    dialog:CreateCheckbox(0, current_y + 2, "do_preserve")
        :SetText(loc.localize("Preserve Existing Notes"))
        :SetWidth(140)
        :SetCheck(0)
        :_FallbackCall("DoAutoResizeWidth", nil, true)
    current_y = current_y + y_increment
    -- OK/Cxl
    dialog:CreateOkButton()
        :SetText(loc.localize(loc.localize("OK")))
        :_FallbackCall("DoAutoResizeWidth", nil, true)
    dialog:CreateCancelButton()
        :SetText(loc.localize(loc.localize("Cancel")))
        :_FallbackCall("DoAutoResizeWidth", nil, true)
    -- registrations
    dialog:RegisterHandleOkButtonPressed(function(self)
            local direction = 1 -- up
            if self:GetControl("direction_choice"):GetSelectedItem() > 0 then
                direction = -1 -- down
            end
            local interval_choice = 1 + self:GetControl("interval_choice"):GetSelectedItem()
            local do_simplify = (0 ~= self:GetControl("do_simplify"):GetCheck())
            local plus_octaves = self:GetControl("plus_octaves"):GetInteger()
            local preserve_originals = (0 ~= self:GetControl("do_preserve"):GetCheck())
            do_transpose_chromatic(direction, interval_choice, do_simplify, plus_octaves, preserve_originals)
        end
    )
    return dialog
end

function transpose_chromatic()
    global_dialog = global_dialog or create_dialog_box()
    global_dialog:RunModeless()
end

transpose_chromatic()
