function plugindef()
   -- This function and the 'finaleplugin' namespace
   -- are both reserved for the plug-in definition.
   finaleplugin.Author = "Robert Patterson"
   finaleplugin.Copyright = "CC0 https://creativecommons.org/publicdomain/zero/1.0/"
   finaleplugin.Version = "1.0"
   finaleplugin.Date = "June 10, 2020"
   finaleplugin.CategoryTags = "Staff"
   return "Group Copy Score to Part", "Group Copy Score to Part", "Copies any applicable groups from the score to the current part in view."
end

function staff_groups_copy_score_to_part()

    local parts = finale.FCParts()
    parts:LoadAll()
    local current_part = parts:GetCurrent()
    local score = parts:GetScore()
    if current_part:IsScore() then
        finenv.UI():AlertInfo("This script is only valid when viewing a part.", "Not In Part View")
        return
    end

    score:SwitchTo()
    local staff_groups = finale.FCStaffGroups()
    staff_groups:LoadAll()
    for staff_group in each(staff_groups) do
        local start_staff = staff_group.StartStaff
        local end_staff = staff_group.EndStaff
        current_part:SwitchTo()
        if current_part:IsStaffIncluded(start_staff) and current_part:IsStaffIncluded(end_staff) then
            local new_group = finale.FCStaffGroup()
            new_group.
        end
        
    end
    
    

end

staff_groups_copy_score_to_part()
