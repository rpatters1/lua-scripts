function plugindef()
    finaleplugin.RequireDocument = false
    finaleplugin.RequireSelection = false
    finaleplugin.NoStore = true
    finaleplugin.Author = "Robert Patterson"
    finaleplugin.Copyright = "CC0 https://creativecommons.org/publicdomain/zero/1.0/"
    finaleplugin.Version = "1.0"
    finaleplugin.Date = "September 25, 2024"
    finaleplugin.CategoryTags = "Document"
    finaleplugin.MinJWLuaVersion = 0.74
    finaleplugin.Notes = [[
        Exports settings from the current document into a MuseScore `.mss` style file.
        Only a subset of possible MuseScore settings are exported. You can choose either to modify
        an existing file (e.g., from MuseScore) or create a new file with only the exported settings.

        If you view a part in Finale, the script loads page format and other information for the part
        rather than the score.
    ]]
    return "Export Settings to MuseScore...", "Export Settings to MuseScore", "Export document options from the current document to a MuseScore style file."
end

-- luacheck: ignore 11./global_dialog

local mixin = require("library.mixin")
local enigma_string = require("library.enigma_string")

local text_extension = ".mss"

-- Finale preferences:
local current_is_part
local distance_prefs
local size_prefs
local misc_prefs
local music_character_prefs
local page_prefs
local spacing_prefs
local repeat_prefs

function open_current_prefs()
    current_is_part = finale.FCPart(finale.PARTID_CURRENT):IsPart()
    distance_prefs = finale.FCDistancePrefs()
    distance_prefs:Load(1)
    size_prefs = finale.FCSizePrefs()
    size_prefs:Load(1)
    misc_prefs = finale.FCMiscDocPrefs()
    misc_prefs:Load(1)
    music_character_prefs = finale.FCMusicCharacterPrefs()
    music_character_prefs:Load(1)
    page_prefs = finale.FCPageFormatPrefs()
    if current_is_part then
        page_prefs:LoadParts()
    else
        page_prefs:LoadScore()
    end
    spacing_prefs = finale.FCMusicSpacingPrefs()
    spacing_prefs:Load(1)
    repeat_prefs = finale.FCRepeatPrefs()
    repeat_prefs:Load(1)
end

-- returns Lua strings for path, file name without extension, full file path
function get_file_path_no_extension()
    local path_name = finale.FCString()
    local file_name = finale.FCString()
    local file_path = finale.FCString()
    global_dialog:GetControl("file_path"):GetText(file_path)
    if file_path.Length <= 0 then
        local documents = finale.FCDocuments()
        documents:LoadAll()
        local document = documents:FindCurrent()
            if document then
            document:GetPath(file_path)
        end
    end
    file_path:SplitToPathAndFile(path_name, file_name)
    local full_file_name = file_name.LuaString
    local extension = finale.FCString(file_name.LuaString)
    extension:ExtractFileExtension()
    if extension.Length > 0 then
        file_name:TruncateAt(file_name:FindLast("." .. extension.LuaString))
    end
    return path_name.LuaString, file_name.LuaString, full_file_name
end

function set_element_text(style_element, name, value)
    local setter_func = "SetText"
    if type(value) == "number" then
        if math.type(value) == "float" then
            value = string.format("%.5g", value)
            setter_func = "SetText"
        else
            setter_func = "SetIntText"
        end
    end
    if type(value) == "boolean" then
        value = value and 1 or 0
        setter_func = "SetIntText"
    end
    local element = style_element:FirstChildElement(name)
    if not element then
        element = style_element:InsertNewChildElement(name)
    end
    element[setter_func](element, value)
    return element
end

function muse_font_efx(font_info)
    local retval = 0
    if font_info.Bold then
        retval = retval | 0x01
    end
    if font_info.Italic then
        retval = retval | 0x02
    end
    if font_info.Underline then
        retval = retval | 0x03
    end
    if font_info.Strikethrough then
        retval = retval | 0x04
    end
    return retval
end

local EVPU_PER_INCH = 288
local EVPU_PER_MM = 288 / 25.4
local EVPU_PER_SPACE = 24
local EFIX_PER_SPACE = EVPU_PER_SPACE * 64

function write_page_prefs(style_element)
    set_element_text(style_element, "pageWidth", page_prefs.PageWidth / EVPU_PER_INCH)
    set_element_text(style_element, "pageHeight", page_prefs.PageHeight / EVPU_PER_INCH)
    set_element_text(style_element, "pagePrintableWidth",
        (page_prefs.PageWidth - page_prefs.LeftPageRightMargin - page_prefs.LeftPageRightMargin) / EVPU_PER_INCH)
    set_element_text(style_element, "pageEvenLeftMargin", page_prefs.LeftPageLeftMargin / EVPU_PER_INCH)
    set_element_text(style_element, "pageOddLeftMargin",
        (page_prefs.UseFacingPages and page_prefs.RightPageLeftMargin or page_prefs.LeftPageLeftMargin) / EVPU_PER_INCH)
    set_element_text(style_element, "pageEvenTopMargin", page_prefs.LeftPageTopMargin / EVPU_PER_INCH)
    set_element_text(style_element, "pageEvenBottomMargin", page_prefs.LeftPageBottomMargin / EVPU_PER_INCH)
    set_element_text(style_element, "pageOddTopMargin",
        (page_prefs.UseFacingPages and page_prefs.RightPageTopMargin or page_prefs.LeftPageTopMargin) / EVPU_PER_INCH)
    set_element_text(style_element, "pageOddBottomMargin",
        (page_prefs.UseFacingPages and page_prefs.RightPageBottomMargin or page_prefs.LeftPageBottomMargin) / EVPU_PER_INCH)
    set_element_text(style_element, "pageTwosided", page_prefs.UseFacingPages)
    set_element_text(style_element, "enableIndentationOnFirstSystem", page_prefs.UseFirstSystemMargins)
    set_element_text(style_element, "firstSystemIndentationValue", page_prefs.FirstSystemLeft / EVPU_PER_SPACE)
    local page_percent = page_prefs.PageScaling / 100
    local staff_percent = (page_prefs.SystemStaffHeight / (EVPU_PER_SPACE * 4 * 16)) * (page_prefs.SystemScaling / 100)
    set_element_text(style_element, "Spatium", (EVPU_PER_SPACE * staff_percent * page_percent) / EVPU_PER_MM)
end

function write_lyrics_prefs(style_element)
    local font_info = finale.FCFontInfo()
    local lyrics_text = finale.FCVerseLyricsText()
    font_info:LoadFontPrefs(finale.FONTPREF_LYRICSVERSE)
    for verse_number, even_odd in ipairs({ "Odd", "Even" }) do
        if lyrics_text:Load(verse_number) then
            local str = lyrics_text:CreateString()
            local font = str and str.Length > 0 and enigma_string.trim_first_enigma_font_tags(str)
            font_info = font or font_info
        end
        set_element_text(style_element, "lyrics" .. even_odd .. "FontFace", font_info.Name)
        set_element_text(style_element, "lyrics" .. even_odd .. "FontSize",
        font_info.Size * (font_info.Absolute and 1 or 0.83333))
        set_element_text(style_element, "lyrics" .. even_odd .. "FontSpatiumDependent", not font_info.Absolute)
        set_element_text(style_element, "lyrics" .. even_odd .. "FontStyle", muse_font_efx(font_info))
    end
end

function write_line_measure_prefs(style_element)
    set_element_text(style_element, "barWidth", size_prefs.ThinBarlineThickness / EFIX_PER_SPACE)
    set_element_text(style_element, "doubleBarWidth", size_prefs.ThinBarlineThickness / EFIX_PER_SPACE)
    set_element_text(style_element, "endBarWidth", size_prefs.HeavyBarlineThickness / EFIX_PER_SPACE)
    -- Finale's double bar distance is measured from the beginning of the thin line
    set_element_text(style_element, "doubleBarDistance", (distance_prefs.BarlineDoubleSpace - size_prefs.ThinBarlineThickness) / EFIX_PER_SPACE)
    -- Finale's final bar distance is the separatioln amount
    set_element_text(style_element, "endBarDistance", (distance_prefs.BarlineFinalSpace) / EFIX_PER_SPACE)
    set_element_text(style_element, "repeatBarlineDotSeparation", repeat_prefs.ForwardSpace / EVPU_PER_SPACE)
    set_element_text(style_element, "repeatBarTips", repeat_prefs.WingStyle ~= finale.REPWING_NONE)
    set_element_text(style_element, "startBarlineSingle", misc_prefs.LeftBarlineDisplaySingle)
    set_element_text(style_element, "startBarlineMultiple", misc_prefs.LeftBarlineDisplayMultiple)
    set_element_text(style_element, "bracketWidth", 0.5) -- hard-coded in Finale
    set_element_text(style_element, "bracketDistance", -distance_prefs.GroupBracketDefaultDistance / EVPU_PER_SPACE)
    set_element_text(style_element, "akkoladeBarDistance", -distance_prefs.GroupBracketDefaultDistance / EVPU_PER_SPACE)
    set_element_text(style_element, "clefLeftMargin", distance_prefs.ClefSpaceBefore / EVPU_PER_SPACE)
    set_element_text(style_element, "keysigLeftMargin", distance_prefs.KeySpaceBefore / EVPU_PER_SPACE)
    local time_sig_space_before = current_is_part and distance_prefs.TimeSigPartsSpaceBefore or distance_prefs.TimeSigSpaceBefore
    set_element_text(style_element, "timesigLeftMargin", time_sig_space_before / EVPU_PER_SPACE)
    set_element_text(style_element, "clefKeyDistance", (distance_prefs.ClefSpaceAfter + distance_prefs.ClefKeyExtraSpace + distance_prefs.KeySpaceBefore) / EVPU_PER_SPACE)
    set_element_text(style_element, "clefTimesigDistance", (distance_prefs.ClefSpaceAfter + distance_prefs.ClefTimeExtraSpace + time_sig_space_before) / EVPU_PER_SPACE)
    set_element_text(style_element, "keyTimesigDistance", (distance_prefs.KeySpaceAfter + distance_prefs.KeyTimeExtraSpace + time_sig_space_before) / EVPU_PER_SPACE)
    set_element_text(style_element, "keyBarlineDistance", repeat_prefs.AfterKeySpace / EVPU_PER_SPACE)
    -- differences in how MuseScore and Finale interpret these settings means the following two are better off left alone
    -- set_element_text(style_element, "systemHeaderDistance", distance_prefs.KeySpaceAfter / EVPU_PER_SPACE)
    -- set_element_text(style_element, "systemHeaderTimeSigDistance", distance_prefs.TimeSigSpaceAfter / EVPU_PER_SPACE)
    set_element_text(style_element, "clefBarlineDistance", repeat_prefs.AfterClefSpace / EVPU_PER_SPACE)
    set_element_text(style_element, "timesigBarlineDistance", repeat_prefs.AfterClefSpace / EVPU_PER_SPACE)  
    set_element_text(style_element, "measureRepeatNumberPos", -(music_character_prefs.VerticalTwoMeasureRepeatOffset + 0.5) / EVPU_PER_SPACE)
    set_element_text(style_element, "staffLineWidth", size_prefs.StaffLineThickness / EFIX_PER_SPACE)
    set_element_text(style_element, "ledgerLineWidth", size_prefs.LedgerLineThickness / EFIX_PER_SPACE)
    set_element_text(style_element, "ledgerLineLength", (size_prefs.LedgerLeftHalf + size_prefs.LedgerRightHalf) / (2 * EVPU_PER_SPACE))

end

-- keysigAccidentalDistance fudge factor +4 EVPU
-- keysigNaturalDistance    fudge factor +6 EVPU

function write_stem_prefs(style_element)
    set_element_text(style_element, "useStraightNoteFlags", music_character_prefs.UseStraightFlags)
    set_element_text(style_element, "stemWidth", size_prefs.StemLineThickness / EFIX_PER_SPACE)
    set_element_text(style_element, "shortenStem", true)
    set_element_text(style_element, "stemLength", size_prefs.NormalStemLength / EVPU_PER_SPACE)
    set_element_text(style_element, "shortestStem", size_prefs.ShortenedStemLength / EVPU_PER_SPACE)
end

function write_spacing_prefs(style_element)
    set_element_text(style_element, "minMeasureWidth", spacing_prefs.MinMeasureWidth / EVPU_PER_SPACE) 
    set_element_text(style_element, "minNoteDistance", spacing_prefs.MinimumItemDistance / EVPU_PER_SPACE)
    set_element_text(style_element, "measureSpacing", spacing_prefs.ScalingFactor)
end

function write_xml()
    local mssxml <close> = tinyxml2.XMLDocument()
    local existing_path = global_dialog:GetControl("file_path"):GetText()
    if #existing_path > 0 then
        local result = mssxml:LoadFile(existing_path)
        if result ~= tinyxml2.XML_SUCCESS then
            error("Unable to parse " .. existing_path .. ". " .. mssxml:ErrorStr())
            return
        end
    else
        mssxml:InsertEndChild(mssxml:NewDeclaration(nil))
        local ms_element = mssxml:NewElement("museScore")
        ms_element:SetAttribute("version", "4.40")
        mssxml:InsertEndChild(ms_element)
        ms_element:InsertNewChildElement("Style")
    end
    local style_element = tinyxml2.XMLHandle(mssxml):FirstChildElement("museScore"):FirstChildElement("Style"):ToElement()
    if not style_element then
        error(existing_path .. " is not a valid .mss file.")
    end
    open_current_prefs()
    write_page_prefs(style_element)
    write_lyrics_prefs(style_element)
    write_line_measure_prefs(style_element)
    write_stem_prefs(style_element)
    write_spacing_prefs(style_element)
    local output_path = select_target()
    if output_path then
        if mssxml:SaveFile(output_path) ~= tinyxml2.XML_SUCCESS then
            error("Unable to save " .. existing_path .. ". " .. mssxml:ErrorStr())
        end
    end
end

function select_target()
    local path_name, file_name = get_file_path_no_extension()
    file_name = file_name .. text_extension
    local save_dialog = finale.FCFileSaveAsDialog(finenv.UI())
    save_dialog:SetWindowTitle(finale.FCString("Save MuseScore style settings as"))
    save_dialog:AddFilter(finale.FCString("*" .. text_extension), finale.FCString("MuseScore Style Settings File"))
    save_dialog:SetInitFolder(finale.FCString(path_name))
    save_dialog:SetFileName(finale.FCString(file_name))
    save_dialog:AssureFileExtension(text_extension)
    if not save_dialog:Execute() then
        return nil
    end
    local selected_file_name = finale.FCString()
    save_dialog:GetFileName(selected_file_name)
    return selected_file_name.LuaString
end

function select_existing_target()
    local path_name, file_name, full_file_name = get_file_path_no_extension()
    file_name = file_name .. text_extension
    local open_dialog = finale.FCFileOpenDialog(finenv.UI())
    open_dialog:SetWindowTitle(finale.FCString("Open MuseScore style settings for " .. full_file_name))
    open_dialog:AddFilter(finale.FCString("*" .. text_extension), finale.FCString("MuseScore Style Settings File"))
    open_dialog:SetInitFolder(path_name)
    open_dialog:SetFileName(file_name)
    open_dialog:AssureFileExtension(text_extension)
    if not open_dialog:Execute() then
        return nil
    end
    local selected_file_name = finale.FCString()
    open_dialog:GetFileName(selected_file_name)
    return selected_file_name.LuaString
end

function create_dialog_box()
    local dialog = mixin.FCXCustomLuaWindow()
        :SetTitle("Export Settings to MuseScore")
    local current_y = 0
    -- file to process
    dialog:CreateStatic(0, current_y + 2, "file_path_label")
        :SetText("Use Existing:")
        :DoAutoResizeWidth(0)
    dialog:CreateStatic(0, current_y + 2, "file_path")
        :SetText("")
        :SetWidth(400)
        :AssureNoHorizontalOverlap(dialog:GetControl("file_path_label"), 5)
    dialog:CreateButton(0, current_y, "choose_file")
        :SetText("Select...")
        :DoAutoResizeWidth(0)
        :AssureNoHorizontalOverlap(dialog:GetControl("file_path"), 5)
        :AddHandleCommand(function(_control)
            local filepath = select_existing_target()
            if filepath then
                dialog:GetControl("file_path"):SetText(filepath)
            end
        end)
    -- ok/cancel
    dialog:CreateOkButton()
    dialog:CreateCancelButton()
    -- registrations
    dialog:RegisterHandleOkButtonPressed(function(self)
        if finale.FCDocuments():LoadAll() <= 0 then
            self:CreateChildUI():AlertInfo("Please open a document to pull settings from.", "No Open Document")
            return
        end
        write_xml()
    end)
    dialog:RegisterInitWindow(function(self)
        self:GetControl("file_path"):SetText("")
    end)
    return dialog
end

function document_options_to_musescore()
    global_dialog = global_dialog or create_dialog_box()
    global_dialog:RunModeless()
end

document_options_to_musescore()
