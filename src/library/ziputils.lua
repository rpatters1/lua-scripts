--[[
$module ziputils

Functions for unzipping files. (Future may include zipping as well.)

Dependencies:

- The Windows version uses `PowerShell`.
- The macOS version uses `unzip` and `gunzip`.
- In both cases the necessary tools are pre-installed with a typical installation of any version
of the OS that supports 64-bit Finale.

Pay careful attention to the comments about how strings are encoded. They are either encoded
**platform** or **utf8**. On macOS, platform encoding is always utf8, but on Windows it can
be any number of encodings depending on the locale settings and version of Windows. You can use
`luaosutils.text` to convert them back and forth. (Use the `get_default_codepage` function to get
the platform encoding.) The `luaosutils.process.execute` function requires platform encoding as do
`lfs` and all built-in Lua `os` and `io` functions that take strings as input.

Note that many functions require later versions of RGP Lua that include `luaosutils`
and/or `lfs`. But the these dependencies are embedded in each function so that any version
of Lua for Finale can at least load the library.
]] --
local ziputils = {}

local utils = require("library.utils")

-- This variable allows us to check if we are supported when we load and the functions
-- can throw out based on it.
local not_supported_message
if finenv.MajorVersion <= 0 and finenv.MinorVersion < 68 then
    not_supported_message = "ziputils requires at least RGP Lua v0.68."
elseif finenv.TrustedMode == finenv.TrustedModeType.UNTRUSTED then
    not_supported_message = "ziputils must run in Trusted mode."
elseif not finaleplugin.ExecuteExternalCode then
    not_supported_message = "ziputils.extract_enigmaxml must have finaleplugin.ExecuteExternalCode set to true."
end

--[[
% calc_rmdir_command

Returns the platform-dependent command to remove a directory. It can be passed
to `luaosutils.process.execute`.

**WARNING** The command, if executed, permanently deletes the contents of the directory.
You would normally call this on the temporary directory name from `calc_temp_output_path`.
But it works on any directory.

@ path_to_remove (string) platform-encoded path of directory to remove.
: (string) platform-encoded command string to execute.
]]
function ziputils.calc_rmdir_command(path_to_remove)
    return (finenv.UI():IsOnMac() and "rm -r " or "cmd /c rmdir /s /q ") .. path_to_remove
end

--[[
% calc_delete_file_command

Returns the platform-dependent command to delete a file. It can be passed
to `luaosutils.process.execute`.

**WARNING** The command, if executed, permanently deletes the file.
You would normally call this on the temporary directory name from `calc_temp_output_path`.
But it works on any directory.

@ path_to_remove (string) platform-encoded path of directory to remove.
: (string) platform-encoded command string to execute.
]]
function ziputils.calc_delete_file_command(path_to_remove)
    return (finenv.UI():IsOnMac() and "rm " or "cmd /c del ") .. path_to_remove
end


--[[
% calc_temp_output_path

Returns a path that can be used as a temporary target for unzipping. The caller may create it
either as a file or a directory, because it is guaranteed not to exist when it is returned and it does
not have a terminating path delimiter. Also returns a platform-dependent unzip command that can be
passed to `luaosutils.process.execute` to unzip the input archive into the temporary name as a directory.

This function requires `luaosutils`.

@ [archive_path] (string) platform-encoded filepath to the zip archive that is included in the zip command.
: (string) platform-encoded temporary path generated by the system.
: (string) platform-encoded unzip command that can be used to unzip a multifile archived directory structure into the temporary path.
]]
function ziputils.calc_temp_output_path(archive_path)
    if not_supported_message then
        error(not_supported_message, 2)
    end

    archive_path = archive_path or ""

    local process = require("luaosutils").process

    local output_dir = os.tmpname()
    local rmcommand = ziputils.calc_delete_file_command(output_dir)
    process.execute(rmcommand)

    local zipcommand
    if finenv.UI():IsOnMac() then
        zipcommand = "unzip \"" .. archive_path .. "\" -d " .. output_dir
    else
        zipcommand = [[
            $archivePath = '%s'
            $outputDir = '%s'
            $zipPath = $archivePath + '.zip'
            Copy-Item -Path $archivePath -Destination $zipPath
            Expand-Archive -Path $zipPath -DestinationPath $outputDir
            Remove-Item -Path $zipPath
        ]]
        zipcommand = string.format(zipcommand, archive_path, output_dir)
        zipcommand = string.format("powershell -c & { %s }", zipcommand)
    end
    return output_dir, zipcommand
end

--[[
% calc_gunzip_command

Returns the platform-dependent command to gunzip a file to `stdout`. It can be passed
to `luaosutils.process.execute`, which will then return the text directly.

@ archive_path (string) platform-encoded path of source gzip archive.
: (string) platform-encoded command string to execute.
]]
function ziputils.calc_gunzip_command(archive_path)
    if finenv.UI():IsOnMac() then
        return "gunzip -c " .. archive_path
    else
        local command = [[
            $fs = New-Object IO.Filestream('%s',([IO.FileMode]::Open),([IO.FileAccess]::Read),([IO.FileShare]::Read))
            $gz = New-Object IO.Compression.GzipStream($fs,[IO.Compression.CompressionMode]::Decompress)
            $sr = New-Object IO.StreamReader($gz)
            while (-not $sr.EndOfStream) { Write-Output $sr.ReadLine() }
            $sr.Close()
        ]]
        command = string.format(command, archive_path)
        return string.format("powershell -c & { %s }", command)
    end
end

--[[
% calc_is_gzip

Detects if an input buffer is a gzip archive.

@ buffer (string) binary data to check if it is a gzip archive
: (boolean) true if the buffer is a gzip archive
]]
function ziputils.calc_is_gzip(buffer)
    local byte1, byte2, byte3, byte4 = string.byte(buffer, 1, 4)
    return byte1 == 0x1F and byte2 == 0x8B and byte3 == 0x08 and byte4 == 0x00
end

-- symmetrical encryption/decryption function for EnigmaXML
local function crypt_enigmaxml_buffer(buffer)
    local INITIAL_STATE <const> = 0x28006D45 -- this value was determined empirically
    local state = INITIAL_STATE
    local result = {}
    
    for i = 1, #buffer do
        -- BSD rand()
        if (i - 1) % 0x20000 == 0 then
            state = INITIAL_STATE
        end
        state = (state * 0x41c64e6d + 0x3039) & 0xFFFFFFFF  -- Simulate 32-bit overflow
        local upper = state >> 16
        local c = upper + math.floor(upper / 255)
        
        local byte = string.byte(buffer, i)
        byte = byte ~ (c & 0xFF)  -- XOR operation on the byte
        
        table.insert(result, string.char(byte))
    end
    
    return table.concat(result)
end

--[[
% extract_enigmaxml

EnigmaXML is the underlying file format of a Finale `.musx` file. It is undocumented
by MakeMusic and must be extracted from the `.musx` file. There is an effort to document
it underway at the [EnigmaXML Documentation](https://github.com/finale-lua/ziputils-documentation)
repository.

This function extracts the EnigmaXML buffer from a `.musx` file. Note that it does not work with Finale's
older `.mus` format.

@ filepath (string) utf8-encoded file path to a `.musx` file.
: (string) utf8-encoded buffer of xml data containing the EnigmaXml extracted from the `.musx`.
]]
function ziputils.extract_enigmaxml(filepath)
    if not_supported_message then
        error(not_supported_message, 2)
    end
    local _, _, extension = utils.split_file_path(filepath)
    if extension ~= ".musx" then
        error(filepath .. " is not a .musx file.", 2)
    end

    -- Steps to extract:
    --      Unzip the `.musx` (which is `.zip` in disguise)
    --      Run the `score.dat` file through `crypt_enigmaxml_buffer` to get a gzip archive of the EnigmaXML file.
    --      Gunzip the extracted EnigmaXML gzip archive into a string and return it.

    local text = require("luaosutils").text
    local process = require("luaosutils").process
    
    local os_filepath = text.convert_encoding(filepath, text.get_utf8_codepage(), text.get_default_codepage())
    local output_dir, zipcommand = ziputils.calc_temp_output_path(os_filepath)
    if not process.execute(zipcommand) then
        error(zipcommand .. " failed")
    end

    local file <close> = io.open(output_dir .. "/score.dat", "rb")
    if not file then
        error("unable to read " .. output_dir .. "/score.dat")
    end
    local buffer = file:read("*all")
    file:close()

    local delcommand = ziputils.calc_rmdir_command(output_dir)
    process.execute(delcommand)

    buffer = crypt_enigmaxml_buffer(buffer)
    if ziputils.calc_is_gzip(buffer) then
        local gzip_path = ziputils.calc_temp_output_path()
        local gzip_file <close> = io.open(gzip_path, "wb")
        if not gzip_file then
            error("unable to create " .. gzip_file)
        end
        gzip_file:write(buffer)
        gzip_file:close()
        local gunzip_command = ziputils.calc_gunzip_command(gzip_path)
        buffer = process.execute(gunzip_command)
        process.execute(ziputils.calc_delete_file_command(gzip_path))
        if not buffer or buffer == "" then
            error(gunzip_command .. "failed")
        end
    end
    
    return buffer
end

return ziputils
