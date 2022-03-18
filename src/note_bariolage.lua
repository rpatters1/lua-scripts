
function plugindef()
  -- This function and the 'finaleplugin' namespace
  -- are both reserved for the plug-in definition.
  finaleplugin.Author = "Jacob Winkler"
  finaleplugin.Copyright = "2022"
  finaleplugin.Version = "1.0"
  finaleplugin.Date = "2/13/2022"
  return "Bariolage", "Bariolage", "Bariolage: Creates alternating layer pattern from layer 1. Doesn't play nicely with odd numbered groups!"
end
--[[
% note_bariolage()

This function creates bariolage-style notation where layers 1 and 2 interlock. It works well for material that has even-numbered beam groups like 4x 16th notes or 6x 16th notes (in compound meters). 32nd notes also work. Odd numbers of notes produce undesirable results.

To use, create a suitable musical passage in layer 1, then run the script. The script does the following:
- Duplicates layer 1 to layer 2.
- Mutes playback of layer 2.
- Iterates through the notes in layer 1. For even-numbered notes (i.e. the 2nd and 4th 16ths in a group of 4) it replaces the stem with a blank shape, effectively hiding it.
- Any note in layer 1 that is the last note of a beamed group is hidden.
- Iterates through the notes in layer 2 and changes the stems of the odd-numbered notes.
- Any note in layer 2 that is the beginning of a beamed group is hidden.
]]
function layer_copy(src, dest)
    local region = finenv.Region()
    local start=region.StartMeasure
    local stop=region.EndMeasure
    local sysstaves = finale.FCSystemStaves()
    sysstaves:LoadAllForRegion(region)
    src = src - 1
    dest = dest - 1
    for sysstaff in each(sysstaves) do
        staffNum = sysstaff.Staff
        local noteentrylayerSrc = finale.FCNoteEntryLayer(src,staffNum,start,stop)
        noteentrylayerSrc:Load()     
        local noteentrylayerDest = noteentrylayerSrc:CreateCloneEntries(dest,staffNum,start)
        noteentrylayerDest:Save()
        noteentrylayerDest:CloneTuplets(noteentrylayerSrc)
        noteentrylayerDest:Save()
    end
end -- function layer_copy

function stems_hide(entry)
    local stem = finale.FCCustomStemMod()        
    stem:SetNoteEntry(entry)
    stem:UseUpStemData(entry:CalcStemUp())
    if stem:LoadFirst() then
        stem.ShapeID = 0    
        stem:Save()
    else
        stem.ShapeID = 0
        stem:SaveNew()
    end   
end -- function stems_hide
---

function bariolage()
    layer_copy(1, 2)
    local layer1_ct = 1
    local layer2_ct = 1
    for entry in eachentrysaved(finenv.Region()) do
        if entry:IsNote() then
            if entry.LayerNumber == 1 then
                if entry:CalcBeamedGroupEnd() then
                    entry.Visible = false
                end
                if layer1_ct % 2 == 0 then
                    print()
                    stems_hide(entry)
                end
                layer1_ct = layer1_ct + 1
            elseif entry.LayerNumber == 2 then
                if entry:GetBeamBeat() then
                    entry.Visible = false
                end
                if layer2_ct % 2 == 1 then
                    print()
                    stems_hide(entry)
                end
                entry:SetPlayback(false)
                layer2_ct = layer2_ct + 1
            end
        end
    end
end -- function bariolage

bariolage()