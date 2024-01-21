--[[
$module Utility Functions

A library of general Lua utility functions.
]] --
local utils = {}

--[[
% copy_table

If a table is passed, returns a copy, otherwise returns the passed value.

@ t (mixed)
: (mixed)
]]
---@generic T
---@param t T
---@return T
function utils.copy_table(t)
    if type(t) == "table" then
        local new = {}
        for k, v in pairs(t) do
            new[utils.copy_table(k)] = utils.copy_table(v)
        end
        setmetatable(new, utils.copy_table(getmetatable(t)))
        return new
    else
        return t
    end
end

--[[
% table_remove_first

Removes the first occurrence of a value from an array table.

@ t (table)
@ value (mixed)
]]
function utils.table_remove_first(t, value)
    for k = 1, #t do
        if t[k] == value then
            table.remove(t, k)
            return
        end
    end
end

--[[
% iterate_keys

Returns an unordered iterator for the keys in a table.

@ t (table)
: (function)
]]
function utils.iterate_keys(t)
    local a, b, c = pairs(t)

    return function()
        c = a(b, c)
        return c
    end
end

--[[
% round

Rounds a number to the nearest integer or the specified number of decimal places.

@ num (number)
@ [places] (number) If specified, the number of decimal places to round to. If omitted or 0, will round to the nearest integer.
: (number)
]]
function utils.round(value, places)
    places = places or 0
    local multiplier = 10^places
    local ret = math.floor(value * multiplier + 0.5)
    -- Ensures that a real integer type is returned as needed
    return places == 0 and ret or ret / multiplier
end

--[[
% to_integer_if_whole

Takes a number and if it is an integer or whole float (eg 12 or 12.0), returns an integer.
All other floats will be returned as passed.

@ value (number)
: (number)
]]
function utils.to_integer_if_whole(value)
    local int = math.floor(value)
    return value == int and int or value
end

--[[ 
% calc_roman_numeral

Calculates the roman numeral for the input number. Adapted from https://exercism.org/tracks/lua/exercises/roman-numerals/solutions/Nia11 on 2022-08-13

@ num (number)
: (string)
]]
function utils.calc_roman_numeral(num)
    local thousands = {'M','MM','MMM'}
    local hundreds = {'C','CC','CCC','CD','D','DC','DCC','DCCC','CM'}
    local tens = {'X','XX','XXX','XL','L','LX','LXX','LXXX','XC'}	
    local ones = {'I','II','III','IV','V','VI','VII','VIII','IX'}
    local roman_numeral = ''
    if math.floor(num/1000)>0 then roman_numeral = roman_numeral..thousands[math.floor(num/1000)] end
    if math.floor((num%1000)/100)>0 then roman_numeral=roman_numeral..hundreds[math.floor((num%1000)/100)] end
    if math.floor((num%100)/10)>0 then roman_numeral=roman_numeral..tens[math.floor((num%100)/10)] end
    if num%10>0 then roman_numeral = roman_numeral..ones[num%10] end
    return roman_numeral
end

--[[ 
% calc_ordinal

Calculates the ordinal for the input number (e.g. 1st, 2nd, 3rd).

@ num (number)
: (string)
]]
function utils.calc_ordinal(num)
    local units = num % 10
    local tens = num % 100
    if units == 1 and tens ~= 11 then
        return num .. "st"
    elseif units == 2 and tens ~= 12 then
        return num .. "nd"
    elseif units == 3 and tens ~= 13 then
        return num .. "rd"
    end

    return num .. "th"
end

--[[ 
% calc_alphabet

This returns one of the ways that Finale handles numbering things alphabetically, such as rehearsal marks or measure numbers.

This function was written to emulate the way Finale numbers saves when Autonumber is set to A, B, C... When the end of the alphabet is reached it goes to A1, B1, C1, then presumably to A2, B2, C2. 

@ num (number)
: (string)
]]
function utils.calc_alphabet(num)
    local letter = ((num - 1) % 26) + 1
    local n = math.floor((num - 1) / 26)

    return string.char(64 + letter) .. (n > 0 and n or "")
end

--[[
% clamp

Clamps a number between two values.

@ num (number) The number to clamp.
@ minimum (number) The minimum value.
@ maximum (number) The maximum value.
: (number)
]]
function utils.clamp(num, minimum, maximum)
    return math.min(math.max(num, minimum), maximum)
end

--[[
% ltrim

Removes whitespace from the start of a string.

@ str (string)
: (string)
]]
function utils.ltrim(str)
    return string.match(str, "^%s*(.*)")
end

--[[
% rtrim

Removes whitespace from the end of a string.

@ str (string)
: (string)
]]
function utils.rtrim(str)
    return string.match(str, "(.-)%s*$")
end

--[[
% trim

Removes whitespace from the start and end of a string.

@ str (string)
: (string)
]]
function utils.trim(str)
    return utils.ltrim(utils.rtrim(str))
end

--[[
% call_and_rethrow

Calls a function and returns any returned values. If any errors are thrown at the level this function is called, they will be rethrown at the specified level with new level information.
If the error message contains the rethrow placeholder enclosed in single quotes (see `utils.rethrow_placeholder`), it will be replaced with the correct function name for the new level.

*The first argument must have the same name as the `rethrow_placeholder`, chosen for uniqueness.*

@ levels (number) Number of levels to rethrow.
@ tryfunczzz (function) The function to call.
@ ... (any) Any arguments to be passed to the function.
: (any) If no error is caught, returns the returned values from `tryfunczzz`
]]
local pcall_wrapper
local rethrow_placeholder = "tryfunczzz" -- If changing this, make sure to do a search and replace for all instances in this file, including the argument to `rethrow_error`
local pcall_line = debug.getinfo(1, "l").currentline + 2 -- This MUST refer to the pcall 2 lines below
function utils.call_and_rethrow(levels, tryfunczzz, ...)
    return pcall_wrapper(levels, pcall(function(...) return 1, tryfunczzz(...) end, ...))
    -- ^Tail calls aren't counted as levels in the call stack. Adding an additional return value (in this case, 1) forces this level to be included, which enables the error to be accurately captured
end

-- Get the name of this file.
local source = debug.getinfo(1, "S").source
local source_is_file = source:sub(1, 1) == "@"
if source_is_file then
    source = source:sub(2)
end

-- Processes the results from the pcall in catch_and_rethrow
pcall_wrapper = function(levels, success, result, ...)
    if not success then
        local file
        local line
        local msg
        file, line, msg = result:match("([a-zA-Z]-:?[^:]+):([0-9]+): (.+)")
        msg = msg or result

        local file_is_truncated = file and file:sub(1, 3) == "..."
        file = file_is_truncated and file:sub(4) or file

        -- Conditions for rethrowing at a higher level:
        -- Ignore errors thrown with no level info (ie. level = 0), as we can't make any assumptions
        -- Both the file and line number indicate that it was thrown at this level
        if file
            and line
            and source_is_file
            and (file_is_truncated and source:sub(-1 * file:len()) == file or file == source)
            and tonumber(line) == pcall_line
        then
            local d = debug.getinfo(levels, "n")

            -- Replace the method name with the correct one, for bad argument errors etc
            msg = msg:gsub("'" .. rethrow_placeholder .. "'", "'" .. (d.name or "") .. "'")

            -- Shift argument numbers down by one for colon function calls
            if d.namewhat == "method" then
                local arg = msg:match("^bad argument #(%d+)")

                if arg then
                    msg = msg:gsub("#" .. arg, "#" .. tostring(tonumber(arg) - 1), 1)
                end
            end

            error(msg, levels + 1)

        -- Otherwise, it's either an internal function error or we couldn't be certain that it isn't
        -- So, rethrow with original file and line number to be 'safe'
        else
            error(result, 0)
        end
    end

    return ...
end

--[[
% rethrow_placeholder

Returns the function name placeholder (enclosed in single quotes, the same as in Lua's internal errors) used in `call_and_rethrow`.

Use this in error messages where the function name is variable or unknown (eg because the error is thrown up multiple levels) and needs to be replaced with the correct one at runtime by `call_and_rethrow`.

: (string)
]]
function utils.rethrow_placeholder()
    return "'" .. rethrow_placeholder .. "'"
end

--[[
% require_embedded

Bypasses the deployment rewrite of `require` to allow for requiring of libraries embedded in RGP Lua.

: (string) The name of the embedded library to require.
]]
function utils.require_embedded(library_name)
    return require(library_name)
end

--[[
% win_mac

Returns the winval or the macval depending on which operating system the script is running on.

@ windows_value (any) The Windows value to return
@ mac_value (any) The macOS value to return
: (any) The windows_value or mac_value based on finenv.UI()IsOnWindows()
]]

function utils.win_mac(windows_value, mac_value)
    if finenv.UI():IsOnWindows() then
        return windows_value
    end
    return mac_value
end

return utils
