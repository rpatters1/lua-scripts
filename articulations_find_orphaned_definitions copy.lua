function plugindef()
   -- This function and the 'finaleplugin' namespace
   -- are both reserved for the plug-in definition.
    finaleplugin.Author = "Robert Patterson"
    finaleplugin.Copyright = "CC0 https://creativecommons.org/publicdomain/zero/1.0/"
    finaleplugin.Version = "1.0"
    finaleplugin.Date = "June 27, 2020"
    finaleplugin.CategoryTags = "Articulation"
    return "Articulation Find Orphans", "Articulation Find Orphans",
           "Reports any orphaned articulation definitions not visible in the Articulation Selection Dialog."
end

-- The Articulation Selection Dialog expects expression definitions to be stored sequentially and stops looking for definitions
-- once the next value is not found. However, Finale can leave orphaned expression definitions with higher values. These
-- are inaccessible unless you add in dummy articulations to fill in the gaps.

local new_line_string = "\n"

-- :LoadAll() suffers from the same problem that the Articulation Selection Dialog does. It stops looking once it hits a gap.
-- So search all possible values. (It turns out attempting to load non-existent values is not a noticable performance hit.)

local max_value_to_search = 32767

local get_report_string_for_orphans = function(orphaned_artics)
    local type_string = "Articulation"
    local report_string = ""
    local is_first = true
    for k, v in pairs(orphaned_artics) do
        artic_def = finale.FCArticulationDef()
        if artic_def:Load(v) then
            if not is_first then
                report_string = report_string .. new_line_string
            end
            is_first = false
            report_string = report_string .. type_string .. " " .. artic_def.ItemNo
            if not artic_def:IsShapeUsed() then
                if artic_def.AboveSymbolChar < 128 then
                    report_string = report_string .. " " .. string.format("%c", artic_def.AboveSymbolChar)
                end
                if (artic_def.BelowSymbolChar < 128) and (artic_def.AboveSymbolChar ~= artic_def.BelowSymbolChar) then
                    report_string = report_string .. " " .. string.format("%c", artic_def.BelowSymbolChar)
                end
            end
        end
    end
    return report_string
end

local articulation_find_orphans = function()
    local artic_def = finale.FCArticulationDef()
    local count = 0
    local max_valid = 0
    local max_found = 0
    local orphaned_artics = { }
    for try_id = 1, max_value_to_search do
        if artic_def:Load(try_id) then
            max_found = artic_def.ItemNo
            count = count + 1
            if count ~= artic_def.ItemNo then
                table.insert(orphaned_artics, artic_def.ItemNo)
            else
                max_valid = count
            end
        end
    end
    return orphaned_artics, max_valid, max_found
end

function articulation_find_orphaned_definitions()
    local orphaned_artics, max_valid, max_found = articulation_find_orphans()
    local got_orphan = false
    local report_string = ""
    if #orphaned_artics > 0 then
        got_orphan = true
        report_string = report_string .. get_report_string_for_orphans(orphaned_artics)
    end
    if got_orphan then
        report_string = report_string .. new_line_string .. new_line_string .. "Max Valid Articulation = " .. max_valid .. "."
        finenv.UI():AlertInfo(report_string, "Found Orphaned Articulations:")
    else
        finenv.UI():AlertInfo("", "No Orphaned Articulations Found")
    end
end

articulation_find_orphaned_definitions()
