-- A collection of helpful JW Lua transposition scripts
-- Simply import this file to another Lua script to use any of these scripts
-- 
-- THIS MODULE IS INCOMPLETE
-- 
-- Structure
-- 1. Helper functions
-- 2. Diatonic Transpositions (listed by interval - ascending)
-- 3. Chromatic Transpositions (listed by interval - ascending)
-- 
local transposition = {}

local configuration = require("library.configuration")

local standard_key_number_of_steps          = 12
local standard_key_major_diatonic_steps     = { 0, 2, 4, 5, 7, 9, 11 }
local standard_key_minor_diatonic_steps     = { 0, 2, 3, 5, 7, 8, 10 }

--first number is plus_fifths
--second number is minus_octaves
local diatonic_interval_adjustments         = { {0,0}, {2,-1}, {4,-2}, {-1,1}, {1,0}, {3,-1}, {5,-2}, {0,1} }

local custom_key_sig_config = {
    number_of_steps                         = standard_key_number_of_steps,
    diatonic_steps                          = standard_key_major_diatonic_steps
}

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

-- this is necessary becuase the % operator in lua appears always to return a positive value,
-- unlike the % operator in c++
local signed_modulus = function(n, d)
    return sign(n) * (math.abs(n) % d)
end

-- return number of steps, diatonic steps map, and number of steps in fifth
local get_key_info = function(key)
    local number_of_steps = standard_key_number_of_steps
    local diatonic_steps = standard_key_major_diatonic_steps
    if not key:IsPredefined() then
        number_of_steps = custom_key_sig_config.number_of_steps
        diatonic_steps = custom_key_sig_config.diatonic_steps
    elseif key:IsMinor() then
        diatonic_steps = standard_key_minor_diatonic_steps
    end
    -- 0.5849625 is log(3/2)/log(2), which is how to calculate the 5th per Ere Lievonen.
    -- For most key sigs this calculation comes out to the 5th scale degree, which is 7 steps for standard keys
    local fifth_steps = math.floor((number_of_steps*0.5849625) + 0.5) 
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
    local number_of_steps = sign(second_disp - first_disp) * (diatonic_steps[second_scale_degree+1] - diatonic_steps[first_scale_degree+1])
    if number_of_steps < 0 then
        number_of_steps = number_of_steps + number_of_steps_in_key
    end
    return number_of_steps
end

local calc_steps_in_alteration = function(key, interval, alteration)
    local number_of_steps_in_key, _, fifth_steps = get_key_info(key)
    local plus_fifths = sign(interval) * alteration * 7 -- number of fifths to add for alteration
    local minus_octaves = sign(interval) * alteration * -4 -- number of octaves to subtract for alteration
    local new_alteration = sign(interval) * ((plus_fifths*fifth_steps) + (minus_octaves*number_of_steps_in_key)) -- new alteration for chromatic interval
    return new_alteration
end

local calc_steps_in_normalized_interval = function(key, interval_normalized)
    local number_of_steps_in_key, _, fifth_steps = get_key_info(key)
    local plus_fifths = diatonic_interval_adjustments[math.abs(interval_normalized)+1][1] -- number of fifths to add for interval
    local minus_octaves = diatonic_interval_adjustments[math.abs(interval_normalized)+1][2] -- number of octaves to subtract for alteration
    local number_of_steps_in_interval = sign(interval_normalized) * ((plus_fifths*fifth_steps) + (minus_octaves*number_of_steps_in_key))
    return number_of_steps_in_interval
end

-- 
-- DIATONIC transposition (affect only Displacement)
-- 

function transposition.diatonic_transpose(note, interval)
    note.Displacement = note.Displacement + interval
end

function transposition.change_octave(note, n)
    transposition.diatonic_transpose(note, 7*n)
end

-- 
-- CHROMATIC transposition (affect Displacement and RaiseLower)
-- 

function transposition.chromatic_transpose(note, interval, alteration)
    local cell = finale.FCCell(note.Entry.Measure, note.Entry.Staff)
    local key = cell:GetKeySignature()
    local number_of_steps, diatonic_steps, fifth_steps = get_key_info(key)
    local interval_normalized = signed_modulus(interval, #diatonic_steps)
    local steps_in_alteration = calc_steps_in_alteration(key, interval, alteration)
    local steps_in_interval = calc_steps_in_normalized_interval(key, interval_normalized)
    local steps_in_diatonic_interval = calc_steps_between_scale_degrees(key, note.Displacement, note.Displacement + interval_normalized)
    local effective_alteration = steps_in_alteration + steps_in_interval - sign(interval)*steps_in_diatonic_interval
    transposition.diatonic_transpose(note, interval)
    note.RaiseLower = note.RaiseLower + effective_alteration
end

function transposition.set_notes_to_same_pitch(note_a, note_b)
    note_b.Displacement = note_a.Displacement
    note_b.RaiseLower = note_a.RaiseLower
end

function transposition.chromatic_major_third_down(note)
    transposition.chromatic_transpose(note, -2, -0)
end 

function transposition.chromatic_perfect_fourth_up(note)
    transposition.chromatic_transpose(note, 3, 0)
end

function transposition.chromatic_perfect_fifth_down(note)
    transposition.chromatic_transpose(note, -4, -0)
end

return transposition
