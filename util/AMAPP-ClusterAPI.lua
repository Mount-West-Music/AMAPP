--[[
    AMAPP Cluster Management API Wrapper
    Copyright (c) 2026 Mount West Music AB. All rights reserved.

    This module provides a unified API for cluster management.
    - Item persistence: Uses ClusterStore (JSON-based, Lua native)
    - Activation/Render: Uses C++ extension (performance-critical)

    This separation ensures:
    - Data format consistency (JSON everywhere)
    - Debuggability (can inspect ExtState)
    - Performance where it matters (activation logic in C++)
--]]

local ClusterAPI = {}


local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
local ClusterStore = dofile(script_path .. "AMAPP-ClusterStore.lua")






ClusterAPI.available = true


ClusterAPI.cpp_available = (reaper.AMAPP_Cluster_GetVersion ~= nil)


function ClusterAPI.get_version()
    if ClusterAPI.cpp_available then
        return reaper.AMAPP_Cluster_GetVersion() .. " (C++ activation)"
    end
    return "3.0.0 (Lua-only)"
end





local function parse_json_result(json_str)
    if not json_str then return nil end

    
    local result = {}

    
    if json_str:find('"success":true') then
        result.success = true
    elseif json_str:find('"success":false') then
        result.success = false
    end

    
    local error_match = json_str:match('"error":"([^"]*)"')
    if error_match then
        result.error = error_match
    end

    
    for key, val in json_str:gmatch('"([%w_]+)":(%d+)') do
        result[key] = tonumber(val)
    end

    return result
end





--[[
    Associate currently selected items with a cluster.

    @param cluster (table): Cluster object with cluster_guid, c_start, c_end
    @param options (table, optional): Options (currently unused, kept for compatibility)
    @return success (boolean), result (table with counts)

    Note: Items must be within cluster bounds to be associated.
--]]
function ClusterAPI.set_items_in_cluster(cluster, options)
    if not cluster or not cluster.cluster_guid then
        return false, {error = "Invalid cluster"}
    end

    
    local existing = ClusterStore.get_cluster(cluster.cluster_guid)
    if not existing then
        
        ClusterStore.import_legacy_cluster(cluster)
    else
        
        if cluster.c_start and cluster.c_end then
            existing.c_start = cluster.c_start
            existing.c_end = cluster.c_end
            ClusterStore.set_cluster(cluster.cluster_guid, existing)
        end
    end

    
    local items_added, items_skipped = ClusterStore.add_selected_items(cluster.cluster_guid)

    local result = {
        success = true,
        items_associated = items_added,
        items_skipped = items_skipped
    }

    return true, result
end

--[[
    Remove currently selected items from a cluster.

    @param cluster (table): Cluster object with cluster_guid field
    @return success (boolean), result (table with counts)
--]]
function ClusterAPI.remove_items_in_cluster(cluster)
    if not cluster or not cluster.cluster_guid then
        return false, {error = "Invalid cluster"}
    end

    
    local items_removed, items_skipped = ClusterStore.remove_selected_items(cluster.cluster_guid)

    local result = {
        success = true,
        items_disassociated = items_removed,
        items_skipped = items_skipped
    }

    return true, result
end

--[[
    Check if an item belongs to a cluster.

    @param item_guid (string): Item GUID
    @param cluster_guid (string): Cluster GUID
    @return boolean
--]]
function ClusterAPI.is_item_in_cluster(item_guid, cluster_guid)
    return ClusterStore.is_item_in_cluster(cluster_guid, item_guid)
end

--[[
    Get all items associated with a cluster.

    @param cluster_guid (string): Cluster GUID
    @return table: Array of item GUIDs, or empty table if not available
--]]
function ClusterAPI.get_cluster_items(cluster_guid)
    local items = ClusterStore.get_items(cluster_guid)
    local result = {}
    for item_guid, _ in pairs(items) do
        table.insert(result, item_guid)
    end
    return result
end





--[[
    Activate a cluster (mute non-cluster items, set correct takes).

    @param cluster (table): Cluster object with cluster_guid, c_start, c_end
    @param suspend_deactivate (boolean, optional): Don't mute non-cluster items
    @param selective_midi_off (boolean, optional): Only send note-off to affected tracks
    @return success (boolean), result (table)

    This replaces the legacy Get_items_in_cluster() function.
--]]
function ClusterAPI.get_items_in_cluster(cluster, suspend_deactivate, selective_midi_off)
    if not cluster or not cluster.cluster_guid then
        return false, {error = "Invalid cluster"}
    end

    
    ClusterStore.sync_from_legacy_table()

    
    if ClusterAPI.cpp_available then
        local options_json = nil
        local parts = {}
        if suspend_deactivate then
            table.insert(parts, '"suspend_deactivation":true')
        end
        if selective_midi_off then
            table.insert(parts, '"selective_midi_off":true')
        end
        if #parts > 0 then
            options_json = "{" .. table.concat(parts, ",") .. "}"
        end

        local result_json = reaper.AMAPP_Cluster_ActivateCluster(
            cluster.cluster_guid,
            options_json
        )

        local result = parse_json_result(result_json)
        if result and result.success then
            
            local cluster_take_guid_table = {}
            local items = ClusterAPI.get_cluster_items(cluster.cluster_guid)
            for _, item_guid in ipairs(items) do
                local item = reaper.BR_GetMediaItemByGUID(0, item_guid)
                if item then
                    local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
                    local take = reaper.GetActiveTake(item)
                    if take then
                        local _, take_guid = reaper.GetSetMediaItemTakeInfo_String(take, "GUID", "", false)
                        table.insert(cluster_take_guid_table, {
                            take_guid = take_guid,
                            item_pos = item_pos
                        })
                    end
                end
            end
            return true, cluster_take_guid_table
        end
    end

    
    return ClusterAPI._activate_cluster_lua(cluster, suspend_deactivate, selective_midi_off)
end


function ClusterAPI._activate_cluster_lua(cluster, suspend_deactivate, selective_midi_off)
    local c_start = cluster.c_start or 0
    local c_end = cluster.c_end or 0

    reaper.PreventUIRefresh(1)

    if not selective_midi_off then
        reaper.Main_OnCommand(40345, 0)  
    end

    
    local cluster_items = ClusterStore.get_items(cluster.cluster_guid)
    local cluster_item_set = {}
    for item_guid, _ in pairs(cluster_items) do
        cluster_item_set[item_guid] = true
    end

    local cluster_take_guid_table = {}

    
    local item_count = reaper.CountMediaItems(0)
    for i = 0, item_count - 1 do
        local item = reaper.GetMediaItem(0, i)
        if item then
            local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
            local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

            
            local within_bounds = not (item_pos + item_len <= c_start or item_pos >= c_end)

            if within_bounds then
                local _, item_guid = reaper.GetSetMediaItemInfo_String(item, "GUID", "", false)

                if cluster_item_set[item_guid] then
                    
                    reaper.SetMediaItemInfo_Value(item, "B_MUTE", 0)

                    local take = reaper.GetActiveTake(item)
                    if take then
                        local _, take_guid = reaper.GetSetMediaItemTakeInfo_String(take, "GUID", "", false)
                        table.insert(cluster_take_guid_table, {
                            take_guid = take_guid,
                            item_pos = item_pos
                        })
                    end
                elseif not suspend_deactivate then
                    
                    reaper.SetMediaItemInfo_Value(item, "B_MUTE", 1)
                end
            end
        end
    end

    reaper.MarkProjectDirty(0)
    reaper.UpdateArrange()
    reaper.PreventUIRefresh(-1)

    return true, cluster_take_guid_table
end

--[[
    Deactivate all clusters (unmute all items).

    @return success (boolean), result (table)
--]]
function ClusterAPI.deactivate_all()
    if ClusterAPI.cpp_available then
        local result_json = reaper.AMAPP_Cluster_DeactivateAllClusters()
        local result = parse_json_result(result_json)
        return result and result.success, result
    end

    
    reaper.PreventUIRefresh(1)
    local item_count = reaper.CountMediaItems(0)
    for i = 0, item_count - 1 do
        local item = reaper.GetMediaItem(0, i)
        if item then
            reaper.SetMediaItemInfo_Value(item, "B_MUTE", 0)
        end
    end
    reaper.MarkProjectDirty(0)
    reaper.UpdateArrange()
    reaper.PreventUIRefresh(-1)
    return true, {success = true}
end





--[[
    Prepare a cluster for rendering (solo items, set takes).

    @param cluster (table): Cluster object with cluster_guid
    @param selective_midi_off (boolean, optional): Only send note-off to affected tracks
    @return success (boolean), result (table)

    This replaces the legacy Solo_items_in_cluster() function.
--]]
function ClusterAPI.solo_items_in_cluster(cluster, selective_midi_off)
    if not cluster or not cluster.cluster_guid then
        return false, {error = "Invalid cluster"}
    end

    
    if ClusterAPI.cpp_available then
        local options_json = nil
        if selective_midi_off then
            options_json = '{"selective_midi_off":true}'
        end

        local result_json = reaper.AMAPP_Cluster_PrepareClusterForRender(
            cluster.cluster_guid,
            options_json
        )

        local result = parse_json_result(result_json)
        if result and result.success then
            
            local cluster_take_guid_table = {}
            local items = ClusterAPI.get_cluster_items(cluster.cluster_guid)
            for _, item_guid in ipairs(items) do
                local item = reaper.BR_GetMediaItemByGUID(0, item_guid)
                if item then
                    local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
                    local take = reaper.GetActiveTake(item)
                    if take then
                        local _, take_guid = reaper.GetSetMediaItemTakeInfo_String(take, "GUID", "", false)
                        table.insert(cluster_take_guid_table, {
                            take_guid = take_guid,
                            item_pos = item_pos
                        })
                    end
                end
            end
            return true, cluster_take_guid_table
        end
    end

    
    return ClusterAPI._activate_cluster_lua(cluster, false, selective_midi_off)
end

--[[
    Restore state after rendering.

    @return success (boolean), result (table)
--]]
function ClusterAPI.restore_after_render()
    if ClusterAPI.cpp_available then
        local result_json = reaper.AMAPP_Cluster_RestoreAfterRender()
        local result = parse_json_result(result_json)
        return result and result.success, result
    end

    
    return ClusterAPI.deactivate_all()
end





--[[
    Load cluster data from project.
    Uses ClusterStore with automatic migration from legacy formats.

    @return success (boolean), result (table)
--]]
function ClusterAPI.load_from_project()
    local data = ClusterStore.load(true)  
    local stats = ClusterStore.get_stats()
    return true, {
        success = true,
        clusters_loaded = stats.cluster_count,
        format = "json"
    }
end

--[[
    Save cluster data to project.
    Uses JSON format via ClusterStore.

    @return success (boolean), result (table)
--]]
function ClusterAPI.save_to_project()
    local success = ClusterStore.save()
    local stats = ClusterStore.get_stats()
    return success, {
        success = success,
        clusters_saved = stats.cluster_count
    }
end

--[[
    Invalidate internal caches (call when items change externally).
--]]
function ClusterAPI.invalidate_cache()
    ClusterStore.invalidate()
    if ClusterAPI.cpp_available then
        reaper.AMAPP_Cluster_InvalidateCache()
    end
end

--[[
    Rebuild internal caches from project state.

    @return success (boolean), result (table with cluster_count, association_count)
--]]
function ClusterAPI.rebuild_cache()
    ClusterStore.reload()
    local stats = ClusterStore.get_stats()
    return true, {
        success = true,
        cluster_count = stats.cluster_count,
        association_count = stats.item_count
    }
end





--[[
    Check if project has legacy Lua-format cluster data.

    @return boolean
--]]
function ClusterAPI.has_legacy_data()
    local _, legacy_str = reaper.GetProjExtState(0, "AMAPP", "CLUSTER_TABLE")
    return legacy_str and legacy_str ~= "" and legacy_str:sub(1, 1) == "{"
end

--[[
    Migrate legacy data to new JSON format.

    @return success (boolean), result (table)
--]]
function ClusterAPI.migrate_legacy_data()
    
    local data = ClusterStore.load(true)
    if ClusterStore.is_dirty() then
        ClusterStore.save()
    end
    local stats = ClusterStore.get_stats()
    return true, {
        success = true,
        clusters_migrated = stats.cluster_count,
        format = "migrated_to_json"
    }
end






ClusterAPI.store = ClusterStore


function ClusterAPI.get_legacy_items_table()
    return ClusterStore.get_legacy_items_table()
end


function ClusterAPI.get_legacy_cluster_table()
    return ClusterStore.get_legacy_cluster_table()
end





--[[
    Get cluster data by GUID.

    @param cluster_guid (string): Cluster GUID
    @return table: Cluster data or nil
--]]
function ClusterAPI.get_cluster_data(cluster_guid)
    
    return ClusterStore.get_cluster(cluster_guid)
end

--[[
    Set cluster time bounds.

    @param cluster_guid (string): Cluster GUID
    @param start_time (number): Start time in seconds
    @param end_time (number): End time in seconds
    @param entry_point (number, optional): Entry transition point (-1 to skip)
    @param exit_point (number, optional): Exit transition point (-1 to skip)
    @return success (boolean), result (table)
--]]
function ClusterAPI.set_cluster_bounds(cluster_guid, start_time, end_time, entry_point, exit_point)
    local cluster = ClusterStore.get_cluster(cluster_guid)
    if not cluster then
        return false, {error = "Cluster not found"}
    end

    cluster.c_start = start_time
    cluster.c_end = end_time
    if entry_point and entry_point >= 0 then
        cluster.c_entry = entry_point
    end
    if exit_point and exit_point >= 0 then
        cluster.c_exit = exit_point
    end

    ClusterStore.set_cluster(cluster_guid, cluster)
    ClusterStore.save()

    return true, {success = true}
end





return ClusterAPI
