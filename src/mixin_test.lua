function plugindef()
    finaleplugin.RequireSelection = false
    finaleplugin.RequireDocument = false
end

if finenv.IsRGPLua then
    require("mobdebug").start()
end

if not finenv.RetainLuaState then
    altval = finale.CMDMODKEY_ALT
    shiftval = finale.CMDMODKEY_SHIFT
end

if finenv.QueryInvokedModifierKeys and (finenv.QueryInvokedModifierKeys(altval) or finenv.QueryInvokedModifierKeys(shiftval)) then
    finenv.RetainLuaState = false
    return
end

local mixin = require("library.mixin")
local dialog1 = finale.FCCustomLuaWindow()
print("ClassName of dialog1 is "..dialog1:ClassName())
local dialog2 = finale.FCCustomLuaWindow()
print("ClassName of dialog2 is "..dialog2:ClassName())
    
if finenv.IsRGPLua then
    --finenv.RetainLuaState = true
end
