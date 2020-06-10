function plugindef()
   -- This function and the 'finaleplugin' namespace
   -- are both reserved for the plug-in definition.
   finaleplugin.Author = "Robert Patterson"
   finaleplugin.Copyright = "CC0 https://creativecommons.org/publicdomain/zero/1.0/"
   finaleplugin.Version = "1.0"
   finaleplugin.Date = "June 9, 2020"
   finaleplugin.CategoryTags = "Staff"
   finaleplugin.ParameterTypes = [[
Boolean
Boolean
]]
   finaleplugin.ParameterInitValues = [[
false
false
]]
   finaleplugin.ParameterDescriptions = [[
is for group name prefs
is for abbreviated name prefs
]]
   return "Reset Name Fonts", "Reset Name Fonts", "Reset group or staff name fonts to default."
end

--Unfortunately the JW PDK Framework does not provide good support for changing a font
--in a Finale string. So this will not be a script unless it can be enhanced to do so.

function prefs_reset_name_fonts(is_for_group, is_for_abbreviated_names)
    local prefs_number = 0
    if is_for_group then
        print ("is for group")
        if is_for_abbreviated_names then
            prefs_number = finale.FONTPREF_ABRVGROUPNAME
        else
            prefs_number = finale.FONTPREF_GROUPNAME
        end
    else
        print ("is for staff")
        if is_for_abbreviated_names then
            prefs_number = finale.FONTPREF_ABRVSTAFFNAME
        else
            prefs_number = finale.FONTPREF_STAFFNAME
        end
    end
    if is_for_abbreviated_names then
        print ("is for abbrev")
    else
        print ("is for full")
    end
    local font_info = finale.FCFontInfo()
    font_info:LoadFontPrefs(prefs_number)
end
    
local is_for_group = false
local is_for_abbreviated_names = false
local parameters = {...}
if parameters[1] then is_for_group = parameters[1] end
if parameters[2] then is_for_abbreviated_names = parameters[2] end

prefs_reset_name_fonts(is_for_group, is_for_abbreviated_names)
