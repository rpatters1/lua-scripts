--[[
$module Localization

This library provides localization services to scripts. Note that this library cannot be used inside
a `plugindef` function, because the Lua plugin does not load any dependencies when it calls `plugindef`.

To use the library, scripts must define each localization
as a table appended to this library table. If you provide region-specific localizations, you should also
provide a generic localization for the 2-character language code as a fallback.

```
local localization = require("library.localization")
--
-- append localizations to the table returned by `require`:
--
localization.en = localization.en or {
    ["Hello"] = "Hello",
    ["Goodbye"] = "Goodbye",
    ["Computer"] = "Computer"
}

localization.es = localization.es or {
    ["Hello"] = "Hola",
    ["Goodbye"] = "Adiós",
    ["Computer"] = "Computadora"
}

-- specific localization for Spain
-- it is only necessary to specify items that are different than the fallback language table.
localization.es_ES = localization.es_ES or {
    ["Computer"] = "Ordenador"
}

localization.jp = localization.jp or {
    ["Hello"] = "今日は",
    ["Goodbye"] = "さようなら",
    ["Computer"] =  "コンピュータ" 
}
```

The keys do not have to be in English, but they should be the same in all tables. You can embed the localizations
in your script or include them with `require`. Example:

```
local region_code = "de_CH" -- get this from `finenv.UI():GetUserLocaleName(): you could also strip out just the language code "de"
local localization_table_name = "localization_" region_code
localization[region_code] = require(localization_table_name)
```

In this case, `localization_de_CH.lua` could be installed in the folder alongside the localized script. This is just
one possible approach. You can manage the dependencies in the manner that is best for your script. The easiest
deployment will always be to avoid dependencies and embed the localizations in your script.

The `library.localization_developer` library provides tools for automatically generating localization tables to
copy into scripts. You can then edit them to suit your needs.
]]

local localization = {}

local library = require("library.general_library")

local locale = (function()
        if finenv.UI().GetUserLocaleName then
            local fcstr = finale.FCString()
            finenv.UI():GetUserLocaleName(fcstr)
            return fcstr.LuaString:gsub("-", "_")
        end
        return "en_US"
    end)()

local script_name = library.calc_script_name()

--[[
% set_locale

Sets the locale to a specified value. By default, the locale language is the same value as finenv.UI():GetUserLocaleName.
If you are running a version of Finale Lua that does not have GetUserLocaleName, you can either manually set the locale
from your script or accept the default, "en_US".

This function can also be used to test different localizations without the need to switch user preferences in the OS.

@ input_locale (string) the 2-letter lowercase language code or 5-character regional locale code
]]
function localization.set_locale(input_locale)
    locale = input_locale:gsub("-", "_")
end

--[[
% get_locale

Returns the locale value that the localization library is using. Normally it matches the value returned by
`finenv.UI():GetUserLocaleName`, however it returns a value in any Lua plugin version including JW Lua.

: (string) the current locale string that the localization library is using
]]
function localization.get_locale()
    return locale
end

-- This function finds a localization string table if it exists or requires it if it doesn't.
local function get_localized_table(try_locale)
    if type(localization[try_locale]) == "table" then
        return localization[try_locale]
    end
    local require_library = "localization" .. "." .. script_name .. "_" .. try_locale
    local success, result = pcall(function() return require(require_library) end)
    if success and type(result) == "table" then
        localization[try_locale] = result
    else
        print("unable to require " .. require_library)
        print(result)
        -- doing this allows us to only try to require it once
        localization[try_locale] = {}
    end
    return localization[try_locale]
end

--[[
% localize

Localizes a string based on the localization language

@ input_string (string) the string to be localized
: (string) the localized version of the string or input_string if not found
]]
function localization.localize(input_string)
    assert(type(input_string) == "string", "expected string, got " .. type(input_string))

    if locale == nil then
        return input_string
    end
    assert(type(locale) == "string", "invalid locale setting " .. tostring(locale))
    
    local t = get_localized_table(locale)
    if t and t[input_string] then
        return t[input_string]
    end

    if #locale > 2 then
        t = get_localized_table(locale:sub(1, 2))
    end
    
    return t and t[input_string] or input_string
end

return localization
