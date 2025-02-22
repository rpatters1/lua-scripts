function plugindef()
    finaleplugin.RequireDocument = false
    finaleplugin.RequireSelection = false
    finaleplugin.ExecuteExternalCode = true
    finaleplugin.NoStore = true
    finaleplugin.Author = "Robert Patterson and Carl Vine"
    finaleplugin.Copyright = "CC0 https://creativecommons.org/publicdomain/zero/1.0/"
    finaleplugin.Version = "2.5.2"
    finaleplugin.Date = "December 31, 2024"
    finaleplugin.LoadLuaOSUtils = true
    finaleplugin.CategoryTags = "Document"
    finaleplugin.MinJWLuaVersion = 0.77
    finaleplugin.AdditionalMenuOptions = [[
        Massage MusicXML Single File...
    ]]
    finaleplugin.AdditionalUndoText = [[
        Massage MusicXML Single File
    ]]
    finaleplugin.AdditionalDescriptions = [[
        Massage a MusicXML file to improve importing to Dorico and MuseScore
    ]]
    finaleplugin.AdditionalPrefixes = [[
        do_single_file = true
    ]]
    finaleplugin.ScriptGroupName = "Massage MusicXML"
    finaleplugin.Notes = [[
        This script reads musicxml files exported from Finale and modifies them to
        improve importing into Dorico or MuseScore. The best process is as follows:

        1. Export your document as uncompressed MusicXML.
        2. Run this plugin on the output *.musicxml document.
        3. The massaged file name has ".massaged" appended to the file name.
        3. Import the massaged *.musicxml file into Dorico or MuseScore.

        Here is a list of the changes the script makes:

        - 8va/8vb and 15ma/15mb symbols are extended to include the last note and extended left to include leading grace notes.
        - Remove "real" whole rests from fermata measures. This issue arises when the fermata was attached to a "real" whole rest.
        The fermata is retained in the MusicXML, but the whole rest is removed. This makes for a better import, especially into MuseScore 4.
        - When a parallel `.musx` or `.mus` file is found, changes all rests in the MusicXML to floating if they were floating rests
        in the original Finale file. (You can suppress this by processing your xml files from a different folder than the Finale file.)

        Due to a limitation in the xml parser, all xml processing instructions are removed. These are metadata that neither
        Dorico nor MuseScore use, so their removal should not affect importing into those programs.

        When tracking a Finale document, certain situations will cause the script to log warnings and stop processing a measure/staff cell
        for floating rests. The most common are

        - cross staff notes
        - beams over barlines made with the Beam Over Barline plugin

        The script is as conservative as possible, so generally you can ignore these warnings. Your best bet is to import the resulting massaged
        xml file and see if you prefer it to the original. The log file is named `FinaleMassageMusicXMLLog.txt` and is to be found in the base
        folder from which you started processing.
    ]]
    return "Massage MusicXML Folder...",
        "Massage MusicXML Folder",
        "Massage a folder of MusicXML files to improve importing to Dorico and MuseScore."
end

local lfs = require("lfs")

local utils = require("library.utils")
local mixin = require("library.mixin")
local client = require("library.client")
local ziputils = require("library.ziputils")

do_single_file = do_single_file or false
local XML_EXTENSION <const> = ".musicxml"
local MXL_EXTENSION <const> = ".mxl"
local ADD_TO_FILENAME <const> = ".massaged"
local EDU_PER_QUARTER <const> = 1024
local LOGENTRY_SEPARATOR <const> = "\n\n"

local TIMER_ID <const> = 1 -- value that identifies our timer
local LOGFILE_NAME <const> = "FinaleMassageMusicXMLLog.txt"
local logfile_path
local error_count = 0
local currently_processing
local current_part
local current_staff
local current_staff_offset
local current_measure

local options = {
    { field = "extend-ottavas-right", desc = "Extend ottavas right for MuseScore and Dorico imports. (Uncheck for LilyPond.)", value = true},
    { field = "extend-ottavas-left", desc = "Extend ottavas left to precede grace notes.", value = true},
    { field = "fermata-whole-rests", desc = "Change whole rests under fermatas to full measure if nothing else in measure.", value = true},
    { field = "refloat-rests", desc = "Refloat floating rests in multiple voices (requires Finale document.)", value = true}
}

local function get_option_value(field_name)
    for _, option in ipairs(options) do
        if option.field == field_name then
            return option.value
        end
    end
    error("unknown option value " .. field_name, 2)
end

function log_message(msg, is_error, exclude_currently_processing)
    if is_error then
        error_count = error_count + 1
    end
    local log_entry = "[" .. os.date("%Y-%m-%d %H:%M:%S") .. "] " .. (exclude_currently_processing and "" or currently_processing) .. " "
    if current_staff > 0 and current_measure > 0 then
        local staff_text = (function()
            local retval = "p" .. current_part
            local staff = finale:FCStaff()
            if staff:Load(finale.FCMusicRegion():CalcStaffNumber(current_staff + current_staff_offset)) then
                local name = staff:CreateDisplayFullNameString()
                retval = retval .. "[" .. name.LuaString .. "]"
            end
            return retval
        end)()
        log_entry = log_entry .. "(" .. staff_text .. " m" .. current_measure .. ") "
    end
    if is_error then
        log_entry = log_entry .. "ERROR: "
    end
    log_entry = log_entry .. msg
    if finenv.ConsoleIsAvailable then
        print(log_entry)
    end
    local file <close> = io.open(logfile_path, "a")
    if not file then
        error("unable to append to logfile " .. logfile_path)
    end
    file:write(log_entry .. "\n")
    file:close()
end

local function remove_processing_instructions(input_name, output_name)
    local input_file <close> = io.open(client.encode_with_client_codepage(input_name), "r")
    if not input_file then
        error("Cannot open file: " .. input_name)
    end
    local lines = {} -- assemble the output file line by line
    local number_removed = 0
    for line in input_file:lines() do
        if line:match("^%s*<%?xml") or not line:match("^%s*<%?.*%?>") then
            table.insert(lines, line)
        else
            number_removed = number_removed + 1
        end
    end
    input_file:close()
    local output_file <close> = io.open(client.encode_with_client_codepage(output_name), "w")
    if not output_file then
        error("Cannot open file for writing: " .. output_name)
    end
    for _, line in ipairs(lines) do
        output_file:write(line .. "\n")
    end
    output_file:close()
    if number_removed > 0 then
        log_message("removed " .. number_removed .. " processing instructions.")
    end
end

function staff_number_from_note(xml_note)
    local xml_staff = xml_note:FirstChildElement("staff")
    return xml_staff and xml_staff:IntText(1) or 1
end

-- custom iterator that returns only "octave-shift" direction nodes
-- this allows us to skip the ones we have moved to the right
function directions_of_type(node, node_name)
    local child = node and node:FirstChildElement("direction") or nil
    local node_for_type = nil

    -- Find the next octave-shift element starting from a given node
    local function find_next_octave_shift()
        while child do
            local direction_type = child:FirstChildElement("direction-type")
            if direction_type then
                node_for_type = direction_type:FirstChildElement(node_name)
                if node_for_type then
                    break -- Found the type, stop searching
                end
            end
            child = child:NextSiblingElement("direction") -- move to next direction element
        end
    end

    -- Initialize by finding the first octave-shift element
    find_next_octave_shift()

    return function()
        local current_octave_shift = child
        if child then
            child = child:NextSiblingElement("direction") -- move to the next direction element
            find_next_octave_shift() -- search for the next octave-shift
        end
        return current_octave_shift
    end
end

function fix_direction_brackets(xml_measure, direction_type, extend_left, extend_right)
    if not (extend_left or extend_right) then
        return
    end
    for xml_direction in directions_of_type(xml_measure, direction_type) do
        local xml_direction_type = xml_direction:FirstChildElement("direction-type")
        if xml_direction_type then
            local node_for_type = xml_direction_type:FirstChildElement(direction_type)
            if node_for_type then
                local direction_copy = xml_direction:DeepClone(xml_direction:GetDocument())
                local shift_type = node_for_type:Attribute("type")
                if shift_type == "stop" then
                    if extend_right then
                        local next_note = xml_direction:NextSiblingElement("note")
                        -- skip over extra notes in chords
                        if next_note then
                            local chord_check = next_note:NextSiblingElement("note")
                            while chord_check and chord_check:FirstChildElement("chord") do
                                next_note = chord_check
                                chord_check = chord_check:NextSiblingElement("note")
                            end
                        end
                        if next_note and not next_note:FirstChildElement("rest") then
                            xml_measure:DeleteChild(xml_direction)
                            xml_measure:InsertAfterChild(next_note, direction_copy)
                            current_staff_offset = staff_number_from_note(next_note) - 1
                            if direction_type == "octave-shift" then
                                log_message("extended octave-shift element of size " .. node_for_type:IntAttribute("size", 8) .. " by one note/chord.")
                            else
                                log_message("extended " .. direction_type .. " element by one note/chord.")
                            end
                        end
                    end
                elseif direction_type == "octave-shift" and shift_type == "up" or shift_type == "down" then
                    if extend_left then
                        local sign = shift_type == "down" and 1 or -1
                        local octaves = (node_for_type:IntAttribute("size", 8) - 1) / 7
                        local prev_grace_note
                        local prev_note = xml_direction:PreviousSiblingElement("note")
                        while prev_note do
                            if not prev_note:FirstChildElement("rest") and prev_note:FirstChildElement("grace") then
                                prev_grace_note = prev_note
                                local pitch = prev_note:FirstChildElement("pitch")
                                local octave = pitch and pitch:FirstChildElement("octave")
                                if octave then
                                    octave:SetIntText(octave:IntText() + sign*octaves)
                                end
                            else
                                break
                            end
                            prev_note = prev_note:PreviousSiblingElement("note")
                        end
                        if prev_grace_note then
                            xml_measure:DeleteChild(xml_direction)
                            local prev_element = prev_grace_note:PreviousSiblingElement()
                            if prev_element then
                                xml_measure:InsertAfterChild(prev_element, direction_copy)
                            else
                                xml_measure:InsertFirstChild(direction_copy)
                            end
                            current_staff_offset = staff_number_from_note(prev_grace_note) - 1
                            log_message("adjusted octave-shift element of size " .. node_for_type:IntAttribute("size", 8) .. " to include preceding grace notes.")
                        end
                    end
                end
            end
        end
    end
end

function fix_fermata_whole_rests(xml_measure)
    if xml_measure:ChildElementCount("note") == 1 then
        local xml_note = xml_measure:FirstChildElement("note")
        if xml_note:FirstChildElement("rest") then
            local note_type = xml_note:FirstChildElement("type")
            if note_type and note_type:GetText() == "whole" then
                for notations in xmlelements(xml_note, "notations") do
                    if notations:FirstChildElement("fermata") then
                        xml_note:DeleteChild(note_type)
                        current_staff_offset = staff_number_from_note(xml_note) - 1
                        log_message("removed real whole rest under fermata.")
                        break
                    end
                end
            end
        end
    end
end

local duration_types = {
    maxima = EDU_PER_QUARTER * 32,
    long = EDU_PER_QUARTER * 16,
    breve = EDU_PER_QUARTER * 8,
    whole = EDU_PER_QUARTER * 4,
    half = EDU_PER_QUARTER * 2,
    quarter = EDU_PER_QUARTER * 1,
    eighth = EDU_PER_QUARTER / 2,
    ["16th"] = EDU_PER_QUARTER / 4,
    ["32nd"] = EDU_PER_QUARTER / 8,
    ["64th"] = EDU_PER_QUARTER / 16,
    ["128th"] = EDU_PER_QUARTER / 32,
    ["256th"] = EDU_PER_QUARTER / 64,
    ["512th"] = EDU_PER_QUARTER / 128,
    ["1024th"] = EDU_PER_QUARTER / 256,
}

function process_xml_with_finale_document(xml_measure, staff_slot, measure, duration_unit, staff_num)
    local region = finale.FCMusicRegion()
    region.StartSlot = staff_slot
    region.StartMeasure = measure
    region:SetStartMeasurePosLeft()
    region.EndSlot = staff_slot
    region.EndMeasure = measure
    region:SetEndMeasurePosRight()
    local next_note
    for entry in eachentry(region) do
        if entry.Visible then -- Dolet does not create note elements for invisible entries
            next_note = (function()
                local retval = next_note
                repeat
                    if not retval then
                        retval = xml_measure:FirstChildElement("note")
                    else
                        retval = retval:NextSiblingElement("note")
                    end
                    if retval and staff_num == staff_number_from_note(retval) then
                        break
                    end
                until not retval
                return retval
            end)()
            if not next_note then
                log_message("WARNING: xml notes do not match open document")
                return false
            end
            local note_type_node = next_note:FirstChildElement("type")
            local note_type_duration = note_type_node and duration_types[note_type_node:GetText()]
            local num_dots = next_note:ChildElementCount("dot")
            note_type_duration = note_type_duration and (note_type_duration* (2 - 1 / (2 ^ num_dots))) or -1
            if note_type_duration ~= entry.Duration then
                -- try actual durations
                local EPSILON <const> = 1.001 -- allow actual durations to be off by a single EDU, to account for tuplets, plus 0.001 rounding slop
                local duration_node = next_note:FirstChildElement("duration")
                local xml_duration = (duration_node and duration_node:DoubleText() or 0) * duration_unit
                if math.abs(entry.ActualDuration - xml_duration) > EPSILON then
                    log_message("WARNING: xml durations do not match document: [" .. entry.Duration .. ", " .. note_type_duration .. "])")
                    return false
                end    
            end
            -- refloat floating rests
            if entry:IsRest() then
                local rest_element = next_note:FirstChildElement("rest")
                if not rest_element then
                    log_message("WARNING: xml corresponding note value in document is not a rest")
                    return false
                end
                if entry.FloatingRest then
                    local function delete_element(element_name)
                        local element = rest_element:FirstChildElement(element_name)
                        if element then
                            rest_element:DeleteChild(element)
                            return true
                        end
                        return false
                    end
                    local deleted_pitch = delete_element("display-step")
                    local deleted_octave = delete_element("display-octave")
                    if deleted_pitch or deleted_octave then
                        log_message("refloated rest of duration " ..
                            entry.Duration / EDU_PER_QUARTER .. " quarter notes.")
                    end
                end
            end
            -- skip over extra notes in chords
            local chord_check = next_note:NextSiblingElement("note")
            while chord_check and chord_check:FirstChildElement("chord") do
                next_note = chord_check
                chord_check = chord_check:NextSiblingElement("note")
            end
        end
    end
    return true
end

function process_xml(score_partwise, document)
    if not document and get_option_value("refloat-rests") then
        log_message("WARNNG: corresponding Finale document not found")
    end
    current_part = 1
    current_staff = 1
    current_staff_offset = 0
    for xml_part in xmlelements(score_partwise, "part") do
        current_measure = 0
        local duration_unit = EDU_PER_QUARTER
        local staves_used = 1
        for xml_measure in xmlelements(xml_part, "measure") do
            local attributes = tinyxml2.XMLHandle(xml_measure)
                :FirstChildElement("attributes")
            local divisions = attributes:FirstChildElement("divisions")
                :ToElement()
            if divisions then
                duration_unit = EDU_PER_QUARTER / divisions:DoubleText(1)
            end
            local staves = attributes:FirstChildElement("staves")
                :ToElement()
            local num_staves = staves and staves:IntText(1) or 1
            if num_staves > staves_used then
                staves_used = num_staves
            end
            current_measure = current_measure + 1
            if document and get_option_value("refloat-rests") then
                for staff_num = 1, num_staves do
                    current_staff_offset = staff_num - 1
                    process_xml_with_finale_document(xml_measure, current_staff + current_staff_offset, current_measure, duration_unit, staff_num)
                end
            end
            fix_direction_brackets(xml_measure, "octave-shift", get_option_value("extend-ottavas-left"), get_option_value("extend-ottavas-right"))
            --it turns out extending brackets is of questionable benefit in both MuseScore and Dorico, so omit for now
            --fix_direction_brackets(xml_measure, "bracket")
            if get_option_value("fermata-whole-rests") then
                fix_fermata_whole_rests(xml_measure)
            end
        end
        current_part = current_part + 1
        current_staff = current_staff + staves_used
        current_staff_offset = 0
    end
    current_staff = 0
    current_measure = 0
end

-- return document, close_required, switchback_required
function open_finale_document(document_path)
    local documents = finale.FCDocuments()
    documents:LoadAll()
    for document in each(documents) do
        local this_path = finale.FCString()
        document:GetPath(this_path)
        if this_path:IsEqual(document_path) then
            local switchback_required = false
            if not document:IsCurrent() then
                document:SwitchTo()
                document:DisplayVisually()
                switchback_required = true
            end
            return document, false, switchback_required
        end
    end
    local document = finale.FCDocument()
    if not document:Open(finale.FCString(document_path), true, nil, false, false, true) then
        log_message("unable to open Finale document " .. document_path, true)
        return nil, false, false
    end
    -- on Windows we have to keep at least one document open or else our modeless window is closed without warning
    local close_required = finenv.UI():IsOnMac() or documents.Count > 0 -- this count was before we called document:Open, so 0 is correct
    return document, close_required, true
end

function process_one_file(path, full_file_name)
    currently_processing = path .. full_file_name
    current_staff = 0
    current_measure = 0
    error_count = 0

    local _, filename, extension = utils.split_file_path(full_file_name)
    assert(#path > 0 and #filename > 0 and #extension > 0, "invalid file path format")
    local output_file = path .. filename .. ADD_TO_FILENAME .. XML_EXTENSION
    local document_path = (function()
        if not get_option_value("refloat-rests") then
            return nil
        end
        local function exist(try_path)
            local attr = lfs.attributes(client.encode_with_client_codepage(try_path))
            return attr and attr.mode == "file"
        end
        local try_path = path .. filename .. ".musx"
        if exist(try_path) then return try_path end
        try_path = path .. filename .. ".mus"
        if exist(try_path) then return try_path end
        try_path = path .. "../" .. filename .. ".musx"
        if exist(try_path) then return try_path end
        try_path = path .. "../" .. filename .. ".mus"
        if exist(try_path) then return try_path end
        return nil
    end)()

    local input_file, zip_directory = (function()
        local input_file = path .. full_file_name
        if extension ~= MXL_EXTENSION then
            return input_file, nil
        end
        local zip_directory, zip_command = ziputils.calc_temp_output_path(input_file)
        if not client.execute(zip_command) then
            return nil, zip_command .. " failed"
        end
        return client.encode_with_utf8_codepage(zip_directory) .. "/" .. filename .. XML_EXTENSION, zip_directory
    end)()

    if not input_file then
        log_message(zip_directory, true)
        return false
    end

    local document, close_required, switchback_required
    if document_path then
        document, close_required, switchback_required = open_finale_document(document_path)
    end

    local function close_document()
        if document then
            if close_required then
                document:CloseCurrentDocumentAndWindow()
            end
            if switchback_required then
                document:SwitchBack()
            end
        end
    end

    local function clean_up()
        close_document()
        if zip_directory then
            local rmdircmd = ziputils.calc_rmdir_command(zip_directory)
            client.execute(rmdircmd)
        end
    end
    
    local function abort_if(condition, msg)
        if condition then
            log_message(msg .. LOGENTRY_SEPARATOR, true)
            os.remove(client.encode_with_client_codepage(output_file)) -- delete erroneous file
            clean_up()
            return true
        end
        return false
    end

    log_message("***** START OF PROCESSING *****", false, true)
    remove_processing_instructions(input_file, output_file)
    local musicxml <close> = tinyxml2.XMLDocument()
    local result = musicxml:LoadFile(output_file)
    if abort_if(result ~= tinyxml2.XML_SUCCESS, "error parsing XML: " .. musicxml:ErrorStr()) then
        return
    end
    local score_partwise = musicxml:FirstChildElement("score-partwise")
    if abort_if(not score_partwise, "file does not appear to be exported from Finale") then
        return
    end
    local information_element = tinyxml2.XMLHandle(score_partwise):FirstChildElement("identification"):ToElement()
    local encoding_element = tinyxml2.XMLHandle(information_element):FirstChildElement("encoding"):ToElement()
    
    local software_element = encoding_element and encoding_element:FirstChildElement("software")
    local encoding_date_element = encoding_element and encoding_element:FirstChildElement("encoding-date")
    if abort_if(not software_element or not encoding_date_element, "missing required element 'software' and/or 'encoding-date'") then
        return
    end
    local creator_software = software_element and software_element:GetText() or "Unspecified"
    if abort_if(creator_software:sub(1, 6) ~= "Finale", "skipping file exported by " .. creator_software) then
        return
    end
    software_element:SetText("Massage Finale MusicXML Script " ..
        finaleplugin.Version .. " for " .. (finenv.UI():IsOnMac() and "Mac" or "Windows"))
    local original_encoding_date = encoding_date_element:GetText()
    encoding_date_element:SetText(os.date("%Y-%m-%d"))
    local miscellaneous_element = information_element:FirstChildElement("miscellaneous")
    if not miscellaneous_element then
        miscellaneous_element = information_element:InsertNewChildElement("miscellaneous")
    end
    local function insert_miscellaneous_field(name, value)
        local element = miscellaneous_element:InsertNewChildElement("miscellaneous-field")
        element:SetAttribute("name", name)
        element:SetText(tostring(value))
    end
    insert_miscellaneous_field("original-software", creator_software)
    insert_miscellaneous_field("original-encoding-date", original_encoding_date)
    for _, option in ipairs(options) do
        insert_miscellaneous_field(option.field, option.value)
    end
    process_xml(score_partwise, document)
    currently_processing = output_file
    if musicxml:SaveFile(output_file) then
        if error_count > 0 then
            log_message("successfully saved file with " .. error_count .. " processing errors." .. LOGENTRY_SEPARATOR)
        else
            log_message("successfully saved file" .. LOGENTRY_SEPARATOR)
        end
    else
        log_message("unable to save massaged file: " .. musicxml:ErrorStr() .. LOGENTRY_SEPARATOR, true)
    end
    clean_up()
end

function process_files(file_list, selected_path)
    local dialog = mixin.FCXCustomLuaWindow()
        :SetTitle("Massage MusicXML Files")
    local current_y = 0
    -- processing folder
    dialog:CreateStatic(0, current_y + 2, "folder_label")
        :SetText("Folder:")
        :DoAutoResizeWidth(0)
    dialog:CreateStatic(0, current_y + 2, "folder")
        :SetText(selected_path)
        :SetWidth(700)
        :AssureNoHorizontalOverlap(dialog:GetControl("folder_label"), 5)
        :StretchToAlignWithRight()
    current_y = current_y + 20
    -- processing file
    dialog:CreateStatic(0, current_y + 2, "file_path_label")
        :SetText("File:")
        :DoAutoResizeWidth(0)
    dialog:CreateStatic(0, current_y + 2, "file_path")
        :SetText("")
        :SetWidth(300)
        :AssureNoHorizontalOverlap(dialog:GetControl("file_path_label"), 5)
        :HorizontallyAlignLeftWith(dialog:GetControl("folder"))
        :StretchToAlignWithRight()
    current_y = current_y + 30
    dialog:CreateHorizontalLine(0, current_y, 100)
        :StretchToAlignWithRight()
    -- options
    for _, option in ipairs(options) do
        current_y = current_y + 20
        dialog:CreateCheckbox(0, current_y, option.field)
            :SetText(option.desc)
            :SetCheck(option.value and 1 or 0)
            :DoAutoResizeWidth(0)
            :StretchToAlignWithRight()
    end
    -- process/cancel
    dialog:CreateOkButton("process")
        :SetText("Process")
    dialog:CreateCancelButton("cancel")
    -- registrations
    dialog:RegisterHandleOkButtonPressed(function(self)
        self:GetControl("process"):SetEnable(false)
        for _, option in ipairs(options) do
            local checkbox = self:GetControl(option.field)
            option.value = checkbox:GetCheck() == 1
            checkbox:SetEnable(false)
        end
        logfile_path = client.encode_with_client_codepage(selected_path) .. LOGFILE_NAME
        local file <close> = io.open(logfile_path, "w")
        if not file then
            error("unable to create logfile " .. logfile_path)
        end
        file:close()
        self:SetTimer(TIMER_ID, 100) -- 100 milliseconds
    end)
    dialog:RegisterHandleTimer(function(self, timer)
        assert(timer == TIMER_ID, "incorrect timer id value " .. timer)
        if #file_list <= 0 then
            self:StopTimer(TIMER_ID)
            self:GetControl("folder"):SetText(selected_path)
            self:GetControl("file_path_label"):SetText("Log:")
            self:GetControl("file_path"):SetText(LOGFILE_NAME .. " (processing complete)")
            currently_processing = selected_path
            log_message("processing complete")
            self:GetControl("cancel"):SetText("Close")
            return
        end
        self:GetControl("folder"):SetText("..." .. file_list[1].folder:sub(#selected_path))
            :RedrawImmediate()
        self:GetControl("file_path"):SetText(file_list[1].name)
            :RedrawImmediate()
        process_one_file(file_list[1].folder, file_list[1].name)
        table.remove(file_list, 1)
    end)
    dialog:RegisterCloseWindow(function(self)
        self:StopTimer(TIMER_ID)
        if #file_list > 0 then
            currently_processing = selected_path
            log_message("processing aborted by user", true)
        end
        finenv.RetainLuaState = false
    end)
    dialog:RunModeless()
end

function process_directory(path_name)
    local folder_dialog = finale.FCFolderBrowseDialog(finenv.UI())
    folder_dialog:SetWindowTitle(finale.FCString("Select Folder of MusicXML Files:"))
    folder_dialog:SetFolderPath(path_name)
    folder_dialog:SetUseFinaleAPI(finenv:UI():IsOnMac())
    if not folder_dialog:Execute() then
        return false -- user cancelled
    end
    local selected_directory = finale.FCString()
    folder_dialog:GetFolderPath(selected_directory)
    selected_directory:AssureEndingPathDelimiter()

    local file_list = {}
    for dir_name, file_name in utils.eachfile(selected_directory.LuaString, true) do
        if file_name:sub(-XML_EXTENSION:len()) == XML_EXTENSION or file_name:sub(-MXL_EXTENSION:len()) == MXL_EXTENSION then
            table.insert(file_list, { name = file_name, folder = dir_name })
        end
    end
    if #file_list <= 0 then
        finenv.UI():AlertInfo("No MusicXML files found.", "Nothing To Process")
        return false
    end
    process_files(file_list, selected_directory.LuaString)
    return true
end

function do_open_dialog(path_name)
    local open_dialog = finale.FCFileOpenDialog(finenv.UI())
    open_dialog:SetWindowTitle(finale.FCString("Select a MusicXML File:"))
    open_dialog:AddFilter(finale.FCString("*" .. MXL_EXTENSION), finale.FCString("MusicXML Compressed File"))
    open_dialog:AddFilter(finale.FCString("*" .. XML_EXTENSION), finale.FCString("MusicXML File"))
    open_dialog:SetInitFolder(path_name)
    if not open_dialog:Execute() then
        return nil
    end
    local selected_file_name = finale.FCString()
    open_dialog:GetFileName(selected_file_name)
    return selected_file_name.LuaString
end

function music_xml_massage_export()
    local documents = finale.FCDocuments()
    documents:LoadAll()
    local document = documents:FindCurrent()
    local path_name = finale.FCString()
    if document then -- extract active pathname
        document:GetPath(path_name)
        path_name:SplitToPathAndFile(path_name, nil)
    else
        path_name:SetMusicFolderPath()
    end
    path_name:AssureEndingPathDelimiter()

    if do_single_file then
        local xml_file = do_open_dialog(path_name)
        if xml_file then
            local path, name, extension = utils.split_file_path(xml_file)
            assert(extension == XML_EXTENSION or extension == MXL_EXTENSION, "incorrect file type selected")
            process_files({{ folder = path, name = name .. extension }}, path)
        end
    else
        process_directory(path_name)
    end
end

music_xml_massage_export()
