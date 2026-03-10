
local function Msg(param)
    if param == nil then reaper.ShowConsoleMsg("") return end
    reaper.ShowConsoleMsg(tostring(param) .. "\n")
end


local Logger
local function get_logger()
    if Logger then return Logger end
    local lib_path = reaper.GetExtState("AMAPP", "lib_path")
    if lib_path and lib_path ~= "" then
        local loader = loadfile(lib_path .. "util/AMAPP-Logger.lua")
        if loader then Logger = loader() end
    end
    
    if not Logger then
        Logger = {
            debug = function() end,
            info = function(msg, ...) end,
            warn = function(msg, ...)
                if reaper then reaper.ShowConsoleMsg("[WARN] " .. string.format(msg, ...) .. "\n") end
            end,
            error = function(msg, ...)
                if reaper then reaper.ShowConsoleMsg("[ERROR] " .. string.format(msg, ...) .. "\n") end
            end,
        }
    end
    return Logger
end


local function escape_powershell_string(str)
    if not str then return "" end
    
    return str:gsub("'", "''")
end

local function escape_shell_string(str)
    if not str then return "" end
    
    return str:gsub("'", "'\\''")
end

local function escape_double_quote_string(str)
    if not str then return "" end
    
    return str:gsub('\\', '\\\\'):gsub('"', '\\"')
end

local mwm_lib_path = reaper.GetExtState("AMAPP", "lib_path")
if not mwm_lib_path or mwm_lib_path == "" then
    reaper.MB("Couldn't load the AMAPP Library. Please install the AMAPP by running the AMAPP_installation.lua ReaScript!", "Error!", 0)
    return
end

local function clear_temp_directory(dir)
    local log = get_logger()
    if not dir:match("[/\\]$") then dir = dir .. "/" end
    local command
    if package.config:sub(1,1) == "\\" then
        command = 'dir /b /a-d "' .. dir .. '"'
    else
        command = 'ls -A "' .. dir .. '"'
    end
    local file_list, err = io.popen(command)
    if not file_list then
        log.warn("Failed to list temp directory: %s", err or "unknown")
        return
    end
    for file in file_list:lines() do
        local full_path = dir .. file
        local success, remove_err = os.remove(full_path)
        if not success then
            log.debug("Failed to remove temp file %s: %s", file, remove_err or "unknown")
        end
    end
    file_list:close()
end
clear_temp_directory(mwm_lib_path .. "util/tmp")

local function convertToWindowsCurl(command)
    command = command:gsub("'", '"')
    command = command:gsub("([a-zA-Z]):\\([^&]+)", function(drive, path)
        return drive .. ":\\\\" .. path:gsub("\\", "\\\\")
    end)
    command = command:gsub("%s+&&%s*$", "")

    return command
end

local function ensureDirectoryExists(file_path)
    local log = get_logger()

    local function getDirectoryPath(path)
        return path:match("(.*)[/\\]")
    end

    local dir_path = getDirectoryPath(file_path)
    local function directoryExists(path)
        local file = io.open(path, "r")
        if file then
            file:close()
            return true
        else
            return false
        end
    end

    if not directoryExists(dir_path) then
        local create_dir_command
        if reaper.GetOS() == "Win32" or reaper.GetOS() == "Win64" then
            create_dir_command = 'mkdir "' .. dir_path .. '"'
        else
            create_dir_command = 'mkdir -p "' .. dir_path .. '"'
        end
        local result = os.execute(create_dir_command)
        if not result then
            log.warn("Failed to create directory: %s", dir_path)
        end
    end

    return file_path
end

return function(url, method, data, headers, response_file)
    local log = get_logger()
    method = method or "GET"

    
    local safe_url = escape_double_quote_string(url)
    local safe_data = escape_double_quote_string(data or "")

    local command
    if method == "POST" then
        command = string.format('curl -s -X POST -d "%s" "%s"', safe_data, safe_url)
    else
        command = string.format('curl -s -X %s "%s"', method, safe_url)
    end

    local ps_header_string = "@{"
    if reaper.GetOS() == "Win32" or reaper.GetOS() == "Win64" then
        for i, header in pairs(headers) do
            local key, value = header:match("^(.-):%s*(.*)$")
            if key and value then
                
                local safe_key = escape_powershell_string(key)
                local safe_value = escape_powershell_string(value)
                ps_header_string = ps_header_string .. string.format("'%s' = '%s'; ", safe_key, safe_value)
            end
        end
        ps_header_string = ps_header_string:sub(1, -3) .. "}"
    else
        for _, header in ipairs(headers or {}) do
            
            local safe_header = escape_double_quote_string(header)
            command = command .. string.format(' -H "%s"', safe_header)
        end
    end

    response_file = ensureDirectoryExists(response_file)
    if reaper.GetOS() == "Win32" or reaper.GetOS() == "Win64" then
        response_file = response_file:gsub("/", "\\")
        response_file = response_file:gsub("\\$", "")
        local unique_id = os.time() .. "_" .. math.random(1000, 9999)
        local exec_file = mwm_lib_path .. "util\\tmp\\exec-" .. unique_id .. ".bat"
        exec_file = convertToWindowsCurl(exec_file)

        
        local ps_safe_data = escape_powershell_string(data or "")
        local ps_safe_url = escape_powershell_string(url)
        local ps_safe_response_file = escape_powershell_string(response_file)

        local ps_command
        if method == "POST" then
            ps_command = string.format(
                '$body = \'%s\'; $response = Invoke-WebRequest -Uri \'%s\' '
                .. '-Method POST -Body $body -Headers %s ; '
                .. '$jsonContent = $response.Content | ConvertFrom-Json | ConvertTo-Json -Depth 10; '
                .. '$jsonContent | Out-File -FilePath \'%s\' -Encoding utf8; '
                .. 'Write-Output $jsonContent',
                ps_safe_data, ps_safe_url, ps_header_string, ps_safe_response_file
            )
        else
            ps_command = string.format(
                '$response = Invoke-WebRequest -Uri \'%s\' '
                .. '-Method GET -Headers %s ; '
                .. '$jsonContent = $response.Content | ConvertFrom-Json | ConvertTo-Json -Depth 10; '
                .. '$jsonContent | Out-File -FilePath  \'%s\' -Encoding utf8; '
                .. 'Write-Output $jsonContent',
                ps_safe_url, ps_header_string, ps_safe_response_file
            )
        end
        local debug = false
        local debug_path = mwm_lib_path .. "util\\tmp\\debug_log.txt"
        if debug then
            debug_path = debug_path:gsub("\\$", "")
            ps_command = ps_command ..  string.format(' 2>&1 | Out-File -FilePath  \'%s\' -Encoding utf8', debug_path)
        end
        local cmd = string.format(
            'powershell -nologo -noprofile -WindowStyle Hidden -ExecutionPolicy Bypass -Command \"%s\"',
            ps_command
        )
        reaper.defer(function ()
            local r = reaper.ExecProcess(cmd, 0)
        end)
        
        
        
        
        
        
        
        
        return true  
    else
        
        local safe_response_file = escape_shell_string(response_file)
        command = command .. " > '" .. safe_response_file .. "'" .. " &"
        local result = os.execute(command)
        if not result then
            log.error("Async request failed for %s %s", method, url)
            return false
        end
        return true
    end
end