function plugindef()
    finaleplugin.RequireSelection = true
    finaleplugin.Author = "Carl Vine"
    finaleplugin.AuthorURL = "http://carlvine.com/?cv=lua"
    finaleplugin.Copyright = "CC0 https://creativecommons.org/publicdomain/zero/1.0/"
    finaleplugin.Version = "v1.04"
    finaleplugin.Date = "2022/06/15"
    finaleplugin.CategoryTags = "Note"
    finaleplugin.Notes = [[
        Clear all music from the chosen layer in the surrently selected region. 
        (Note that all of a measure's layer will be cleared even if it is partially selected).
    ]]
    return "Clear layer selective", "Clear layer selective", "Clear the chosen layer"
end

-- RetainLuaState will return global variable: clear_layer_number
--[[
$module Layer
]] --
local layer = {}

--[[
% copy

Duplicates the notes from the source layer to the destination. The source layer remains untouched.

@ region (FCMusicRegion) the region to be copied
@ source_layer (number) the number (1-4) of the layer to duplicate
@ destination_layer (number) the number (1-4) of the layer to be copied to
]]
function layer.copy(region, source_layer, destination_layer)
    local start = region.StartMeasure
    local stop = region.EndMeasure
    local sysstaves = finale.FCSystemStaves()
    sysstaves:LoadAllForRegion(region)
    source_layer = source_layer - 1
    destination_layer = destination_layer - 1
    for sysstaff in each(sysstaves) do
        staffNum = sysstaff.Staff
        local noteentry_source_layer = finale.FCNoteEntryLayer(source_layer, staffNum, start, stop)
        noteentry_source_layer:Load()
        local noteentry_destination_layer = noteentry_source_layer:CreateCloneEntries(
                                                destination_layer, staffNum, start)
        noteentry_destination_layer:Save()
        noteentry_destination_layer:CloneTuplets(noteentry_source_layer)
        noteentry_destination_layer:Save()
    end
end -- function layer_copy

--[[
% clear

Clears all entries from a given layer.

@ region (FCMusicRegion) the region to be cleared
@ layer_to_clear (number) the number (1-4) of the layer to clear
]]
function layer.clear(region, layer_to_clear)
    layer_to_clear = layer_to_clear - 1 -- Turn 1 based layer to 0 based layer
    local start = region.StartMeasure
    local stop = region.EndMeasure
    local sysstaves = finale.FCSystemStaves()
    sysstaves:LoadAllForRegion(region)
    for sysstaff in each(sysstaves) do
        staffNum = sysstaff.Staff
        local noteentrylayer = finale.FCNoteEntryLayer(layer_to_clear, staffNum, start, stop)
        noteentrylayer:Load()
        noteentrylayer:ClearAllEntries()
    end
end

--[[
% swap

Swaps the entries from two different layers (e.g. 1-->2 and 2-->1).

@ region (FCMusicRegion) the region to be swapped
@ swap_a (number) the number (1-4) of the first layer to be swapped
@ swap_b (number) the number (1-4) of the second layer to be swapped
]]
function layer.swap(region, swap_a, swap_b)
    local start = region.StartMeasure
    local stop = region.EndMeasure
    local sysstaves = finale.FCSystemStaves()
    sysstaves:LoadAllForRegion(region)
    -- Set layers for 0 based
    swap_a = swap_a - 1
    swap_b = swap_b - 1
    for sysstaff in each(sysstaves) do
        staffNum = sysstaff.Staff
        local noteentrylayer_1 = finale.FCNoteEntryLayer(swap_a, staffNum, start, stop)
        noteentrylayer_1:Load()
        noteentrylayer_1.LayerIndex = swap_b
        --
        local noteentrylayer_2 = finale.FCNoteEntryLayer(swap_b, staffNum, start, stop)
        noteentrylayer_2:Load()
        noteentrylayer_2.LayerIndex = swap_a
        noteentrylayer_1:Save()
        noteentrylayer_2:Save()
    end
end




function get_user_choice()
    local vertical = 10
    local horizontal = 110
    local mac_offset = finenv.UI():IsOnMac() and 3 or 0 -- extra y-offset for Mac text box
    
    local dialog = finale.FCCustomWindow()
    local str = finale.FCString()
    str.LuaString = plugindef()
    dialog:SetTitle(str)

    str.LuaString = "Clear Layer (1-4):"
    local static = dialog:CreateStatic(0, vertical)
    static:SetText(str)
    static:SetWidth(horizontal)

    local layer_choice = dialog:CreateEdit(horizontal, vertical - mac_offset)
    layer_choice:SetInteger(clear_layer_number or 1)  -- default layer 1
    layer_choice:SetWidth(50)

    dialog:CreateOkButton()
    dialog:CreateCancelButton()
    return (dialog:ExecuteModal(nil) == finale.EXECMODAL_OK), layer_choice:GetInteger()
end

function clear_layers()
    local is_ok = false
    is_ok, clear_layer_number = get_user_choice()
    if not is_ok then -- user cancelled
        return
    end
    if clear_layer_number < 1 or clear_layer_number > 4 then
        finenv.UI():AlertNeutral("script: " .. plugindef(),
            "The layer number must be\nan integer between 1 and 4\n(not " .. clear_layer_number .. ")")
        return
    end
    if finenv.RetainLuaState ~= nil then
        finenv.RetainLuaState = true
    end
    layer.clear(finenv.Region(), clear_layer_number)
end

clear_layers()