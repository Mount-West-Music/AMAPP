--[[
    AMAPP Wwise Export Module
    Copyright (c) 2026 Mount West Music AB. All rights reserved.

    Provides Wwise export functionality using compiled WAAPI binaries.
    Falls back to C++ WWU file generation if binaries unavailable.
--]]

local WwiseExport = {}


local function GetBinaryPath()
    local lib_path = reaper.GetExtState("AMAPP", "lib_path")
    if not lib_path or lib_path == "" then
        return nil
    end

    local os_name = reaper.GetOS()
    local bin_folder = lib_path .. "util/wwise_bin/bin/"

    if os_name:match("Win") then
        return bin_folder, ".exe"
    else
        return bin_folder, ""
    end
end


function WwiseExport.IsBinaryAvailable()
    local bin_path, ext = GetBinaryPath()
    if not bin_path then return false end

    local binary = bin_path .. "amapp_wwise" .. ext
    local f = io.open(binary, "r")
    if f then
        f:close()
        return true
    end
    return false
end


function WwiseExport.IsCppAvailable()
    return reaper.APIExists("AMAPP_Wwise_GetVersion")
end


function WwiseExport.IsAvailable()
    return WwiseExport.IsBinaryAvailable() or WwiseExport.IsCppAvailable()
end


function WwiseExport.GetVersion()
    if WwiseExport.IsCppAvailable() then
        return reaper.AMAPP_Wwise_GetVersion()
    end
    return "1.0.0-binary"
end


local function WriteSchemaFile(schema_table, output_path, filename)
    local file_path = output_path .. filename
    local json_str = Json.encode(schema_table)

    local f = io.open(file_path, "w")
    if not f then
        return nil, "Failed to write schema file: " .. file_path
    end

    f:write(json_str)
    f:close()

    return file_path
end


local function ExecuteBinary(binary_name, schema_path)
    local bin_path, ext = GetBinaryPath()
    if not bin_path then
        return false, "Binary path not found"
    end

    local binary = bin_path .. binary_name .. ext

    
    local schema_dir = schema_path:match("(.*/)")

    
    local cmd
    local os_name = reaper.GetOS()
    if os_name:match("Win") then
        cmd = '"' .. binary .. '" "' .. schema_dir .. '"'
    else
        cmd = '"' .. binary .. '" "' .. schema_dir .. '"'
    end

    
    local handle = io.popen(cmd .. " 2>&1")
    if not handle then
        return false, "Failed to execute binary"
    end

    local result = handle:read("*a")
    local success, exit_type, exit_code = handle:close()

    if exit_code == 0 or success then
        return true, result
    else
        return false, "Binary execution failed: " .. (result or "unknown error")
    end
end







function WwiseExport.Export(schema_table, lib_path, options)
    options = options or {}

    local output_path = schema_table.project and schema_table.project.path or ""
    if output_path == "" then
        return false, "No output path specified"
    end

    
    reaper.RecursiveCreateDirectory(output_path, 0)

    
    if WwiseExport.IsBinaryAvailable() then
        
        local schema_path, err = WriteSchemaFile(schema_table, output_path, "amapp_schema.json")
        if not schema_path then
            return false, err
        end

        
        local success, result = ExecuteBinary("amapp_wwise", schema_path)

        
        os.remove(schema_path)

        if success then
            return true, "Wwise import completed via WAAPI"
        else
            
            reaper.ShowConsoleMsg("WAAPI binary failed: " .. tostring(result) .. "\n")
            reaper.ShowConsoleMsg("Falling back to WWU file generation...\n")
        end
    end

    
    if WwiseExport.IsCppAvailable() then
        return WwiseExport.ExportWWU(schema_table, output_path, options)
    end

    return false, "No Wwise export method available"
end




function WwiseExport.ExportDirect(schema_table, lib_path, options)
    options = options or {}

    local output_path = schema_table.project and schema_table.project.path or ""
    if output_path == "" then
        return false, "No output path specified"
    end

    
    reaper.RecursiveCreateDirectory(output_path, 0)

    
    if WwiseExport.IsBinaryAvailable() then
        
        local schema_path, err = WriteSchemaFile(schema_table, output_path, "amapp_direct_schema.json")
        if not schema_path then
            return false, err
        end

        
        local success, result = ExecuteBinary("amapp_wwise_direct", schema_path)

        
        os.remove(schema_path)

        if success then
            return true, "Wwise direct import completed via WAAPI"
        else
            reaper.ShowConsoleMsg("WAAPI binary failed: " .. tostring(result) .. "\n")
            reaper.ShowConsoleMsg("Falling back to WWU file generation...\n")
        end
    end

    
    if WwiseExport.IsCppAvailable() then
        return WwiseExport.ExportWWU(schema_table, output_path, options)
    end

    return false, "No Wwise export method available"
end


function WwiseExport.ExportWWU(schema_table, output_path, options)
    if not WwiseExport.IsCppAvailable() then
        return false, "C++ Wwise module not available"
    end

    
    local v2_schema = WwiseExport.ConvertToV2Schema(schema_table)
    local schema_json = Json.encode(v2_schema)

    
    local transform_result = reaper.AMAPP_Wwise_TransformSchema(schema_json)
    if not transform_result or transform_result:find('"success":false') then
        local error_msg = transform_result and transform_result:match('"error":"([^"]*)"') or "Unknown error"
        return false, "Transform failed: " .. error_msg
    end

    
    local options_json = options and Json.encode(options) or "{}"
    local export_result = reaper.AMAPP_Wwise_GenerateWorkUnits(output_path, options_json)

    if export_result and export_result:find('"success":true') then
        return true, "WWU files generated (manual import required)"
    else
        local error_msg = export_result and export_result:match('"error":"([^"]*)"') or "Unknown error"
        return false, "Export failed: " .. error_msg
    end
end


function WwiseExport.ConvertToV2Schema(schema_table)
    local v2 = {
        projectName = schema_table.project and schema_table.project.name or "Untitled",
        exportPath = schema_table.project and schema_table.project.path or "",
        clusters = {},
        groups = {},
        connections = {}
    }

    
    if schema_table.clusters then
        for _, c in ipairs(schema_table.clusters) do
            local cluster = {
                guid = c.guid or "",
                name = c.name or "",
                parentGuid = "",
                startTime = (c.c_start or 0) / 1000,
                endTime = (c.c_end or 0) / 1000,
                entryPoint = c.entry and (c.entry / 1000) or -1,
                exitPoint = c.exit and (c.exit / 1000) or -1,
                isLoop = c.loop or false,
                color = 0,
                audioFile = c.file_path or ""
            }
            table.insert(v2.clusters, cluster)
        end
    end

    
    if schema_table.sets then
        for _, s in ipairs(schema_table.sets) do
            local group = {
                guid = s.guid or reaper.genGuid(),
                name = s.name or "Group",
                parentGuid = "",
                type = s.loop and "horizontal" or "container",
                childGuids = s.clusters or {},
                color = 0
            }

            for _, cluster_guid in ipairs(group.childGuids) do
                for _, c in ipairs(v2.clusters) do
                    if c.guid == cluster_guid then
                        c.parentGuid = group.guid
                    end
                end
            end

            table.insert(v2.groups, group)
        end
    end

    
    if schema_table.group and schema_table.group.name then
        local group = {
            guid = reaper.genGuid(),
            name = schema_table.group.name,
            parentGuid = "",
            type = "horizontal",
            childGuids = {},
            color = 0
        }

        for _, c in ipairs(v2.clusters) do
            table.insert(group.childGuids, c.guid)
            c.parentGuid = group.guid
        end

        table.insert(v2.groups, group)
    end

    return v2
end


function WwiseExport.Preview(schema_table, options)
    if not WwiseExport.IsCppAvailable() then
        return false, "Preview requires C++ module"
    end

    local v2_schema = WwiseExport.ConvertToV2Schema(schema_table)
    local schema_json = Json.encode(v2_schema)

    local transform_result = reaper.AMAPP_Wwise_TransformSchema(schema_json)
    if not transform_result or transform_result:find('"success":false') then
        return false, "Transform failed"
    end

    local options_json = options and Json.encode(options) or "{}"
    local preview_result = reaper.AMAPP_Wwise_PreviewExport(options_json)

    return true, preview_result
end


function WwiseExport.GetDefaultOptions()
    if WwiseExport.IsCppAvailable() then
        local result = reaper.AMAPP_Wwise_GetDefaultOptions()
        return Json.decode(result)
    end

    return {
        outputPath = "",
        projectName = "AMAPP_Export",
        copyAudioFiles = true,
        audioSubfolder = "Audio",
        createEvents = true,
        createSoundBank = true,
        flattenHierarchy = false,
        defaultTransition = "NextGrid",
        defaultFadeTime = 500.0,
        defaultFadeCurve = "Linear",
        eventPrefix = "Play_",
        segmentSuffix = ""
    }
end


function WwiseExport.MapGroupType(group_type)
    if WwiseExport.IsCppAvailable() then
        return reaper.AMAPP_Wwise_MapGroupTypeToContainer(group_type)
    end

    local mapping = {
        horizontal = "MusicPlaylistContainer",
        vertical = "BlendContainer",
        switch = "MusicSwitchContainer",
        random = "RandomSequenceContainer",
        oneshot = "RandomSequenceContainer",
        container = "ActorMixer"
    }
    return mapping[group_type] or "ActorMixer"
end


function WwiseExport.GenerateGUID()
    if WwiseExport.IsCppAvailable() then
        return reaper.AMAPP_Wwise_GenerateGUID()
    end
    return reaper.genGuid()
end

return WwiseExport
