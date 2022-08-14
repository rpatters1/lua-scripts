local __imports = {}
local __import_results = {}

function require(item)
    if not __imports[item] then
        error("module '" .. item .. "' not found")
    end

    if __import_results[item] == nil then
        __import_results[item] = __imports[item]()
        if __import_results[item] == nil then
            __import_results[item] = true
        end
    end

    return __import_results[item]
end

__imports["library.client"] = function()
    --[[
    $module Client

    Get information about the current client. For the purposes of Finale Lua, the client is
    the Finale application that's running on someones machine. Therefore, the client has
    details about the user's setup, such as their Finale version, plugin version, and
    operating system.

    One of the main uses of using client details is to check its capabilities. As such,
    the bulk of this library is helper functions to determine what the client supports.
    ]] --
    local client = {}

    local function to_human_string(feature)
        return string.gsub(feature, "_", " ")
    end

    local function requires_later_plugin_version(feature)
        if feature then
            return "This script uses " .. to_human_string(feature) .. "which is only available in a later version of RGP Lua. Please update RGP Lua instead to use this script."
        end
        return "This script requires a later version of RGP Lua. Please update RGP Lua instead to use this script."
    end

    local function requires_rgp_lua(feature)
        if feature then
            return "This script uses " .. to_human_string(feature) .. " which is not available on JW Lua. Please use RGP Lua instead to use this script."
        end
        return "This script requires RGP Lua, the successor of JW Lua. Please use RGP Lua instead to use this script."
    end

    local function requires_plugin_version(version, feature)
        if tonumber(version) <= 0.54 then
            if feature then
                return "This script uses " .. to_human_string(feature) .. " which requires RGP Lua or JW Lua version " .. version ..
                           " or later. Please update your plugin to use this script."
            end
            return "This script requires RGP Lua or JW Lua version " .. version .. " or later. Please update your plugin to use this script."
        end
        if feature then
            return "This script uses " .. to_human_string(feature) .. " which requires RGP Lua version " .. version .. " or later. Please update your plugin to use this script."
        end
        return "This script requires RGP Lua version " .. version .. " or later. Please update your plugin to use this script."
    end

    local function requires_finale_version(version, feature)
        return "This script uses " .. to_human_string(feature) .. ", which is only available on Finale " .. version .. " or later"
    end

    --[[
    % get_raw_finale_version
    Returns a raw Finale version from major, minor, and (optional) build parameters. For 32-bit Finale
    this is the internal major Finale version, not the year.

    @ major (number) Major Finale version
    @ minor (number) Minor Finale version
    @ [build] (number) zero if omitted

    : (number)
    ]]
    function client.get_raw_finale_version(major, minor, build)
        local retval = bit32.bor(bit32.lshift(math.floor(major), 24), bit32.lshift(math.floor(minor), 20))
        if build then
            retval = bit32.bor(retval, math.floor(build))
        end
        return retval
    end

    --[[
    % get_lua_plugin_version
    Returns a number constructed from `finenv.MajorVersion` and `finenv.MinorVersion`. The reason not
    to use `finenv.StringVersion` is that `StringVersion` can contain letters if it is a pre-release
    version.

    : (number)
    ]]
    function client.get_lua_plugin_version()
        local num_string = tostring(finenv.MajorVersion) .. "." .. tostring(finenv.MinorVersion)
        return tonumber(num_string)
    end

    local features = {
        clef_change = {
            test = client.get_lua_plugin_version() >= 0.60,
            error = requires_plugin_version("0.58", "a clef change"),
        },
        ["FCKeySignature::CalcTotalChromaticSteps"] = {
            test = finenv.IsRGPLua and finale.FCKeySignature.__class.CalcTotalChromaticSteps,
            error = requires_later_plugin_version("a custom key signature"),
        },
        ["FCCategory::SaveWithNewType"] = {
            test = client.get_lua_plugin_version() >= 0.58,
            error = requires_plugin_version("0.58"),
        },
        ["finenv.QueryInvokedModifierKeys"] = {
            test = finenv.IsRGPLua and finenv.QueryInvokedModifierKeys,
            error = requires_later_plugin_version(),
        },
        ["FCCustomLuaWindow::ShowModeless"] = {
            test = finenv.IsRGPLua,
            error = requires_rgp_lua("a modeless dialog")
        },
        ["finenv.RetainLuaState"] = {
            test = finenv.IsRGPLua and finenv.RetainLuaState ~= nil,
            error = requires_later_plugin_version(),
        },
        smufl = {
            test = finenv.RawFinaleVersion >= client.get_raw_finale_version(27, 1),
            error = requires_finale_version("27.1", "a SMUFL font"),
        },
    }

    --[[
    % supports

    Checks the client supports a given feature. Returns true if the client
    supports the feature, false otherwise.

    To assert the client must support a feature, use `client.assert_supports`.

    For a list of valid features, see the [`features` table in the codebase](https://github.com/finale-lua/lua-scripts/blob/master/src/library/client.lua#L52).

    @ feature (string) The feature the client should support.
    : (boolean)
    ]]
    function client.supports(feature)
        if features[feature].test == nil then
            error("a test does not exist for feature " .. feature, 2)
        end
        return features[feature].test
    end

    --[[
    % assert_supports

    Asserts that the client supports a given feature. If the client doesn't
    support the feature, this function will throw an friendly error then
    exit the program.

    To simply check if a client supports a feature, use `client.supports`.

    For a list of valid features, see the [`features` table in the codebase](https://github.com/finale-lua/lua-scripts/blob/master/src/library/client.lua#L52).

    @ feature (string) The feature the client should support.
    : (boolean)
    ]]
    function client.assert_supports(feature)
        local error_level = finenv.DebugEnabled and 2 or 0
        if not client.supports(feature) then
            if features[feature].error then
                error(features[feature].error, error_level)
            end
            -- Generic error message
            error("Your Finale version does not support " .. to_human_string(feature), error_level)
        end
        return true
    end

    return client

end

__imports["library.configuration"] = function()
    --  Author: Robert Patterson
    --  Date: March 5, 2021
    --[[
    $module Configuration

    This library implements a UTF-8 text file scheme for configuration and user settings as follows:

    - Comments start with `--`
    - Leading, trailing, and extra whitespace is ignored
    - Each parameter is named and delimited as follows:

    ```
    <parameter-name> = <parameter-value>
    ```

    Parameter values may be:

    - Strings delimited with either single- or double-quotes
    - Tables delimited with `{}` that may contain strings, booleans, or numbers
    - Booleans (`true` or `false`)
    - Numbers

    Currently the following are not supported:

    - Tables embedded within tables
    - Tables containing strings that contain commas

    A sample configuration file might be:

    ```lua
    -- Configuration File for "Hairpin and Dynamic Adjustments" script
    --
    left_dynamic_cushion 		= 12		--evpus
    right_dynamic_cushion		= -6		--evpus
    ```

    ## Configuration Files

    Configuration files provide a way for power users to modify script behavior without
    having to modify the script itself. Some users track their changes to their configuration files,
    so scripts should not create or modify them programmatically.

    - The user creates each configuration file in a subfolder called `script_settings` within
    the folder of the calling script.
    - Each script that has a configuration file defines its own configuration file name.
    - It is entirely appropriate over time for scripts to transition from configuration files to user settings,
    but this requires implementing a user interface to modify the user settings from within the script.
    (See below.)

    ## User Settings Files

    User settings are written by the scripts themselves and reside in the user's preferences folder
    in an appropriately-named location for the operating system. (The naming convention is a detail that the
    configuration library handles for the caller.) If the user settings are to be changed from their defaults,
    the script itself should provide a means to change them. This could be a (preferably optional) dialog box
    or any other mechanism the script author chooses.

    User settings are saved in the user's preferences folder (on Mac) or AppData folder (on Windows).

    ## Merge Process

    Files are _merged_ into the passed-in list of default values. They do not _replace_ the list. Each calling script contains
    a table of all the configurable parameters or settings it recognizes along with default values. An example:

    `sample.lua:`

    ```lua
    parameters = {
       x = 1,
       y = 2,
       z = 3
    }

    configuration.get_parameters(parameters, "script.config.txt")

    for k, v in pairs(parameters) do
       print(k, v)
    end
    ```

    Suppose the `script.config.text` file is as follows:

    ```
    y = 4
    q = 6
    ```

    The returned parameters list is:


    ```lua
    parameters = {
       x = 1,       -- remains the default value passed in
       y = 4,       -- replaced value from the config file
       z = 3        -- remains the default value passed in
    }
    ```

    The `q` parameter in the config file is ignored because the input paramater list
    had no `q` parameter.

    This approach allows total flexibility for the script add to or modify its list of parameters
    without having to worry about older configuration files or user settings affecting it.
    ]]

    local configuration = {}

    local script_settings_dir = "script_settings" -- the parent of this directory is the running lua path
    local comment_marker = "--"
    local parameter_delimiter = "="
    local path_delimiter = "/"

    local file_exists = function(file_path)
        local f = io.open(file_path, "r")
        if nil ~= f then
            io.close(f)
            return true
        end
        return false
    end

    local strip_leading_trailing_whitespace = function(str)
        return str:match("^%s*(.-)%s*$") -- lua pattern magic taken from the Internet
    end

    local parse_table = function(val_string)
        local ret_table = {}
        for element in val_string:gmatch("[^,%s]+") do -- lua pattern magic taken from the Internet
            local parsed_element = parse_parameter(element)
            table.insert(ret_table, parsed_element)
        end
        return ret_table
    end

    parse_parameter = function(val_string)
        if "\"" == val_string:sub(1, 1) and "\"" == val_string:sub(#val_string, #val_string) then -- double-quote string
            return string.gsub(val_string, "\"(.+)\"", "%1") -- lua pattern magic: "(.+)" matches all characters between two double-quote marks (no escape chars)
        elseif "'" == val_string:sub(1, 1) and "'" == val_string:sub(#val_string, #val_string) then -- single-quote string
            return string.gsub(val_string, "'(.+)'", "%1") -- lua pattern magic: '(.+)' matches all characters between two single-quote marks (no escape chars)
        elseif "{" == val_string:sub(1, 1) and "}" == val_string:sub(#val_string, #val_string) then
            return parse_table(string.gsub(val_string, "{(.+)}", "%1"))
        elseif "true" == val_string then
            return true
        elseif "false" == val_string then
            return false
        end
        return tonumber(val_string)
    end

    local get_parameters_from_file = function(file_path, parameter_list)
        local file_parameters = {}

        if not file_exists(file_path) then
            return false
        end

        for line in io.lines(file_path) do
            local comment_at = string.find(line, comment_marker, 1, true) -- true means find raw string rather than lua pattern
            if nil ~= comment_at then
                line = string.sub(line, 1, comment_at - 1)
            end
            local delimiter_at = string.find(line, parameter_delimiter, 1, true)
            if nil ~= delimiter_at then
                local name = strip_leading_trailing_whitespace(string.sub(line, 1, delimiter_at - 1))
                local val_string = strip_leading_trailing_whitespace(string.sub(line, delimiter_at + 1))
                file_parameters[name] = parse_parameter(val_string)
            end
        end

        for param_name, _ in pairs(parameter_list) do
            local param_val = file_parameters[param_name]
            if nil ~= param_val then
                parameter_list[param_name] = param_val
            end
        end

        return true
    end

    --[[
    % get_parameters

    Searches for a file with the input filename in the `script_settings` directory and replaces the default values in `parameter_list`
    with any that are found in the config file.

    @ file_name (string) the file name of the config file (which will be prepended with the `script_settings` directory)
    @ parameter_list (table) a table with the parameter name as key and the default value as value
    : (boolean) true if the file exists
    ]]
    function configuration.get_parameters(file_name, parameter_list)
        local path = ""
        if finenv.IsRGPLua then
            path = finenv.RunningLuaFolderPath()
        else
            local str = finale.FCString()
            str:SetRunningLuaFolderPath()
            path = str.LuaString
        end
        local file_path = path .. script_settings_dir .. path_delimiter .. file_name
        return get_parameters_from_file(file_path, parameter_list)
    end

    -- Calculates a filepath in the user's preferences folder using recommended naming conventions
    --
    local calc_preferences_filepath = function(script_name)
        local str = finale.FCString()
        str:SetUserOptionsPath()
        local folder_name = str.LuaString
        if not finenv.IsRGPLua and finenv.UI():IsOnMac() then
            -- works around bug in SetUserOptionsPath() in JW Lua
            folder_name = os.getenv("HOME") .. folder_name:sub(2) -- strip '~' and replace with actual folder
        end
        if finenv.UI():IsOnWindows() then
            folder_name = folder_name .. path_delimiter .. "FinaleLua"
        end
        local file_path = folder_name .. path_delimiter
        if finenv.UI():IsOnMac() then
            file_path = file_path .. "com.finalelua."
        end
        file_path = file_path .. script_name .. ".settings.txt"
        return file_path, folder_name
    end

    --[[
    % save_user_settings

    Saves the user's preferences for a script from the values provided in `parameter_list`.

    @ script_name (string) the name of the script (without an extension)
    @ parameter_list (table) a table with the parameter name as key and the default value as value
    : (boolean) true on success
    ]]
    function configuration.save_user_settings(script_name, parameter_list)
        local file_path, folder_path = calc_preferences_filepath(script_name)
        local file = io.open(file_path, "w")
        if not file and finenv.UI():IsOnWindows() then -- file not found
            os.execute('mkdir "' .. folder_path ..'"') -- so try to make a folder (windows only, since the folder is guaranteed to exist on mac)
            file = io.open(file_path, "w") -- try the file again
        end
        if not file then -- still couldn't find file
            return false -- so give up
        end
        file:write("-- User settings for " .. script_name .. ".lua\n\n")
        for k,v in pairs(parameter_list) do -- only number, boolean, or string values
            if type(v) == "string" then
                v = "\"" .. v .."\""
            else
                v = tostring(v)
            end
            file:write(k, " = ", v, "\n")
        end
        file:close()
        return true -- success
    end

    --[[
    % get_user_settings

    Find the user's settings for a script in the preferences directory and replaces the default values in `parameter_list`
    with any that are found in the preferences file. The actual name and path of the preferences file is OS dependent, so
    the input string should just be the script name (without an extension).

    @ script_name (string) the name of the script (without an extension)
    @ parameter_list (table) a table with the parameter name as key and the default value as value
    @ [create_automatically] (boolean) if true, create the file automatically (default is `true`)
    : (boolean) `true` if the file already existed, `false` if it did not or if it was created automatically
    ]]
    function configuration.get_user_settings(script_name, parameter_list, create_automatically)
        if create_automatically == nil then create_automatically = true end
        local exists = get_parameters_from_file(calc_preferences_filepath(script_name), parameter_list)
        if not exists and create_automatically then
            configuration.save_user_settings(script_name, parameter_list)
        end
        return exists
    end

    return configuration

end

__imports["library.transposition"] = function()
    --[[
    $module Transposition

    A collection of helpful JW Lua transposition scripts.

    This library allows configuration of custom key signatures by means
    of a configuration file called "custom_key_sig.config.txt" in the
    "script_settings" subdirectory. However, RGP Lua (starting with version 0.58)
    can read the correct custom key signature information directly from
    Finale. Therefore, when you run this script with RGP Lua 0.58+, the configuration file
    is ignored.
    ]] --
    -- Structure
    -- 1. Helper functions
    -- 2. Diatonic Transposition
    -- 3. Enharmonic Transposition
    -- 3. Chromatic Transposition
    --
    local transposition = {}

    local client = require("library.client")
    local configuration = require("library.configuration")

    local standard_key_number_of_steps = 12
    local standard_key_major_diatonic_steps = {0, 2, 4, 5, 7, 9, 11}
    local standard_key_minor_diatonic_steps = {0, 2, 3, 5, 7, 8, 10}

    local max_allowed_abs_alteration = 7 -- Finale cannot represent an alteration outside +/- 7

    -- first number is plus_fifths
    -- second number is minus_octaves
    local diatonic_interval_adjustments = {{0, 0}, {2, -1}, {4, -2}, {-1, 1}, {1, 0}, {3, -1}, {5, -2}, {0, 1}}

    local custom_key_sig_config = {number_of_steps = standard_key_number_of_steps, diatonic_steps = standard_key_major_diatonic_steps}

    configuration.get_parameters("custom_key_sig.config.txt", custom_key_sig_config)

    --
    -- HELPER functions
    --

    local sign = function(n)
        if n < 0 then
            return -1
        end
        return 1
    end

    -- this is necessary because the % operator in lua appears always to return a positive value,
    -- unlike the % operator in c++
    local signed_modulus = function(n, d)
        return sign(n) * (math.abs(n) % d)
    end

    local get_key = function(note)
        local cell = finale.FCCell(note.Entry.Measure, note.Entry.Staff)
        return cell:GetKeySignature()
    end

    -- These local functions that take FCKeySignature (key) as their first argument should
    -- perhaps move to a key_signature library someday.

    -- return number of steps, diatonic steps map, and number of steps in fifth
    local get_key_info = function(key)
        local number_of_steps = standard_key_number_of_steps
        local diatonic_steps = standard_key_major_diatonic_steps
        if client.supports("FCKeySignature::CalcTotalChromaticSteps") then
            number_of_steps = key:CalcTotalChromaticSteps()
            diatonic_steps = key:CalcDiatonicStepsMap()
        else
            if not key:IsPredefined() then
                number_of_steps = custom_key_sig_config.number_of_steps
                diatonic_steps = custom_key_sig_config.diatonic_steps
            elseif key:IsMinor() then
                diatonic_steps = standard_key_minor_diatonic_steps
            end
        end
        -- 0.5849625 is log(3/2)/log(2), which is how to calculate the 5th per Ere Lievonen.
        -- For basically any practical key sig this calculation comes out to the 5th scale degree,
        -- which is 7 chromatic steps for standard keys
        local fifth_steps = math.floor((number_of_steps * 0.5849625) + 0.5)
        return number_of_steps, diatonic_steps, fifth_steps
    end

    local calc_scale_degree = function(interval, number_of_diatonic_steps_in_key)
        local interval_normalized = signed_modulus(interval, number_of_diatonic_steps_in_key)
        if interval_normalized < 0 then
            interval_normalized = interval_normalized + number_of_diatonic_steps_in_key
        end
        return interval_normalized
    end

    local calc_steps_between_scale_degrees = function(key, first_disp, second_disp)
        local number_of_steps_in_key, diatonic_steps = get_key_info(key)
        local first_scale_degree = calc_scale_degree(first_disp, #diatonic_steps)
        local second_scale_degree = calc_scale_degree(second_disp, #diatonic_steps)
        local number_of_steps = sign(second_disp - first_disp) * (diatonic_steps[second_scale_degree + 1] - diatonic_steps[first_scale_degree + 1])
        if number_of_steps < 0 then
            number_of_steps = number_of_steps + number_of_steps_in_key
        end
        return number_of_steps
    end

    local calc_steps_in_alteration = function(key, interval, alteration)
        local number_of_steps_in_key, _, fifth_steps = get_key_info(key)
        local plus_fifths = sign(interval) * alteration * 7 -- number of fifths to add for alteration
        local minus_octaves = sign(interval) * alteration * -4 -- number of octaves to subtract for alteration
        local new_alteration = sign(interval) * ((plus_fifths * fifth_steps) + (minus_octaves * number_of_steps_in_key)) -- new alteration for chromatic interval
        return new_alteration
    end

    local calc_steps_in_normalized_interval = function(key, interval_normalized)
        local number_of_steps_in_key, _, fifth_steps = get_key_info(key)
        local plus_fifths = diatonic_interval_adjustments[math.abs(interval_normalized) + 1][1] -- number of fifths to add for interval
        local minus_octaves = diatonic_interval_adjustments[math.abs(interval_normalized) + 1][2] -- number of octaves to subtract for alteration
        local number_of_steps_in_interval = sign(interval_normalized) * ((plus_fifths * fifth_steps) + (minus_octaves * number_of_steps_in_key))
        return number_of_steps_in_interval
    end

    local simplify_spelling = function(note, min_abs_alteration)
        while math.abs(note.RaiseLower) > min_abs_alteration do
            local curr_sign = sign(note.RaiseLower)
            local curr_abs_disp = math.abs(note.RaiseLower)
            local direction = curr_sign
            local success = transposition.enharmonic_transpose(note, direction, true) -- true: ignore errors (success is always true)
            if not success then
                return false
            end
            if math.abs(note.RaiseLower) >= curr_abs_disp then
                return transposition.enharmonic_transpose(note, -1 * direction)
            end
            if curr_sign ~= sign(note.RaiseLower) then
                break
            end
        end
        return true
    end

    --
    -- DIATONIC transposition (affect only Displacement)
    --

    --[[
    % diatonic_transpose

    Transpose the note diatonically by the given interval displacement.

    @ note (FCNote) input and modified output
    @ interval (number) 0 = unison, 1 = up a diatonic second, -2 = down a diatonic third, etc.
    ]]
    function transposition.diatonic_transpose(note, interval)
        note.Displacement = note.Displacement + interval
    end

    --[[
    % change_octave

    Transpose the note by the given number of octaves.

    @ note (FCNote) input and modified output
    @ number_of_octaves (number) 0 = no change, 1 = up an octave, -2 = down 2 octaves, etc.
    ]]
    function transposition.change_octave(note, number_of_octaves)
        transposition.diatonic_transpose(note, 7 * number_of_octaves)
    end

    --
    -- ENHARMONIC transposition
    --

    --[[
    % enharmonic_transpose

    Transpose the note enharmonically in the given direction. In some microtone systems this yields a different result than transposing by a diminished 2nd.
    Failure occurs if the note's `RaiseLower` value exceeds an absolute value of 7. This is a hard-coded limit in Finale.

    @ note (FCNote) input and modified output
    @ direction (number) positive = up, negative = down (normally 1 or -1, but any positive or negative numbers work)
    @ [ignore_error] (boolean) default false. If true, always return success. External callers should omit this parameter.
    : (boolean) success or failure
    ]]
    function transposition.enharmonic_transpose(note, direction, ignore_error)
        ignore_error = ignore_error or false
        local curr_disp = note.Displacement
        local curr_alt = note.RaiseLower
        local key = get_key(note)
        local key_step_enharmonic = calc_steps_between_scale_degrees(key, note.Displacement, note.Displacement + sign(direction))
        transposition.diatonic_transpose(note, sign(direction))
        note.RaiseLower = note.RaiseLower - sign(direction) * key_step_enharmonic
        if ignore_error then
            return true
        end
        if math.abs(note.RaiseLower) > max_allowed_abs_alteration then
            note.Displacement = curr_disp
            note.RaiseLower = curr_alt
            return false
        end
        return true
    end

    --
    -- CHROMATIC transposition (affect Displacement and RaiseLower)
    --

    --[[
    % chromatic_transpose

    Transposes a note chromatically by the input chromatic interval. Supports custom key signatures
    and microtone systems by means of a `custom_key_sig.config.txt` file. In Finale, chromatic intervals
    are defined by a diatonic displacement (0 = unison, 1 = second, 2 = third, etc.) and a chromatic alteration.
    Major and perfect intervals have a chromatic alteration of 0. So for example, `{2, -1}` is up a minor third, `{3, 0}`
    is up a perfect fourth, `{5, 1}` is up an augmented sixth, etc. Reversing the signs of both values in the pair
    allows for downwards transposition.

    @ note (FCNote) the note to transpose
    @ interval (number) the diatonic displacement (negative for transposing down)
    @ alteration (number) the chromatic alteration that defines the chromatic interval (reverse sign for transposing down)
    @ [simplify] (boolean) if present and true causes the spelling of the transposed note to be simplified
    : (boolean) success or failure (see `enharmonic_transpose` for what causes failure)
    --]]
    function transposition.chromatic_transpose(note, interval, alteration, simplify)
        simplify = simplify or false
        local curr_disp = note.Displacement
        local curr_alt = note.RaiseLower

        local key = get_key(note)
        local number_of_steps, diatonic_steps, fifth_steps = get_key_info(key)
        local interval_normalized = signed_modulus(interval, #diatonic_steps)
        local steps_in_alteration = calc_steps_in_alteration(key, interval, alteration)
        local steps_in_interval = calc_steps_in_normalized_interval(key, interval_normalized)
        local steps_in_diatonic_interval = calc_steps_between_scale_degrees(key, note.Displacement, note.Displacement + interval_normalized)
        local effective_alteration = steps_in_alteration + steps_in_interval - sign(interval) * steps_in_diatonic_interval
        transposition.diatonic_transpose(note, interval)
        note.RaiseLower = note.RaiseLower + effective_alteration

        local min_abs_alteration = max_allowed_abs_alteration
        if simplify then
            min_abs_alteration = 0
        end
        local success = simplify_spelling(note, min_abs_alteration)
        if not success then -- if Finale can't represent the transposition, revert it to original value
            note.Displacement = curr_disp
            note.RaiseLower = curr_alt
        end
        return success
    end

    --[[
    % stepwise_transpose

    Transposes the note by the input number of steps and simplifies the spelling.
    For predefined key signatures, each step is a half-step.
    For microtone systems defined with custom key signatures and matching options in the `custom_key_sig.config.txt` file,
    each step is the smallest division of the octave defined by the custom key signature.

    @ note (FCNote) input and modified output
    @ number_of_steps (number) positive = up, negative = down
    : (boolean) success or failure (see `enharmonic_transpose` for what causes failure)
    ]]
    function transposition.stepwise_transpose(note, number_of_steps)
        local curr_disp = note.Displacement
        local curr_alt = note.RaiseLower
        note.RaiseLower = note.RaiseLower + number_of_steps
        local success = simplify_spelling(note, 0)
        if not success then -- if Finale can't represent the transposition, revert it to original value
            note.Displacement = curr_disp
            note.RaiseLower = curr_alt
        end
        return success
    end

    --[[
    % chromatic_major_third_down

    Transpose the note down by a major third.

    @ note (FCNote) input and modified output
    ]]
    function transposition.chromatic_major_third_down(note)
        transposition.chromatic_transpose(note, -2, -0)
    end

    --[[
    % chromatic_perfect_fourth_up

    Transpose the note up by a perfect fourth.

    @ note (FCNote) input and modified output
    ]]
    function transposition.chromatic_perfect_fourth_up(note)
        transposition.chromatic_transpose(note, 3, 0)
    end

    --[[
    % chromatic_perfect_fifth_down

    Transpose the note down by a perfect fifth.

    @ note (FCNote) input and modified output
    ]]
    function transposition.chromatic_perfect_fifth_down(note)
        transposition.chromatic_transpose(note, -4, -0)
    end

    return transposition

end

function plugindef()
    finaleplugin.RequireSelection = true
    finaleplugin.Author = "Robert Patterson"
    finaleplugin.Copyright = "CC0 https://creativecommons.org/publicdomain/zero/1.0/"
    finaleplugin.Version = "1.0"
    finaleplugin.Date = "March 25, 2021"
    finaleplugin.CategoryTags = "Pitch"
    finaleplugin.Notes = [[
        In normal 12-note music, enharmonically transposing is the same as transposing by a diminished 2nd.
        However, in some microtone systems (specifically 19-EDO and 31-EDO), enharmonic transposition produces a different result
        than chromatic transposition. As an example, C is equivalent to Dbb in 12-tone systems. But in 31-EDO, C is five microsteps
        lower than D whereas Dbb is four microsteps lower than D. Transposing C up a diminished 2nd gives Dbb in either system, but
        in 31-EDO, Dbb is not the same pitch as C.
        
        If you are using custom key signatures with JW Lua or an early version of RGP Lua, you must create
        a `custom_key_sig.config.txt` file in a folder called `script_settings` within the same folder as the script.
        It should contains the following two lines that define the custom key signature you are using. Unfortunately,
        the JW Lua and early versions of RGP Lua do not allow scripts to read this information from the Finale document.
        
        (This example is for 31-EDO.)
        
        ```
        number_of_steps = 31
        diatonic_steps = {0, 5, 10, 13, 18, 23, 28}
        ```
        Later versions of RGP Lua (0.58 or higher) ignore this configuration file (if it exists) and read the correct
        information from the Finale document.
    ]]
    return "Enharmonic Transpose Down", "Enharmonic Transpose Down",
           "Transpose down enharmonically all notes in selected regions."
end

local transposition = require("library.transposition")

function transpose_enharmonic_down()
    local success = true
    for entry in eachentrysaved(finenv.Region()) do
        for note in each(entry) do
            if not transposition.enharmonic_transpose(note, -1) then
                success = false
            end
        end
    end
    if not success then
        finenv.UI():AlertError("Finale is unable to represent some of the transposed pitches. These pitches were left at their original value.", "Transposition Error")
    end
end

transpose_enharmonic_down()
