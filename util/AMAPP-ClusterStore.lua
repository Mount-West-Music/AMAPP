--[[
    AMAPP Cluster Store
    Copyright (c) 2026 Mount West Music AB. All rights reserved.

    Single source of truth for cluster data persistence using JSON format.
    Handles read/write operations and migration from legacy formats.

    JSON Schema (v3):
    {
        "version": 3,
        "clusters": {
            "<cluster_guid>": {
                "cluster_id": number,
                "name": string,
                "c_start": number,
                "c_end": number,
                "c_entry": number|null,
                "c_exit": number|null,
                "is_loop": boolean,
                "color": number,
                "region_guid": string,
                "region_index": number,
                "parent_guid": string|null,
                "group_visible": boolean,
                "items": {
                    "<item_guid>": {
                        "item_take_guid": string,
                        "time_modified": number
                    }
                }
            }
        }
    }
--]]


local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
local json_path = script_path .. "json/json.lua"
local Json = dofile(json_path)


dofile(script_path .. "MWM-Table_serializer.lua")

local ClusterStore = {}


local EXTSTATE_SECTION = "AMAPP"
local JSON_KEY = "CLUSTER_DATA_JSON"
local LEGACY_TABLE_KEY = "CLUSTER_TABLE"
local LEGACY_ITEMS_KEY = "CLUSTER_ITEMS"
local CURRENT_VERSION = 3





local cache = {
    data = nil,       
    dirty = false,    
    loaded = false    
}





local function safe_json_decode(str)
    if not str or str == "" then
        return nil
    end
    local ok, result = pcall(Json.decode, str)
    if ok then
        return result
    else
        return nil
    end
end

local function safe_json_encode(data)
    if not data then
        return nil
    end
    local ok, result = pcall(Json.encode, data)
    if ok then
        return result
    else
        return nil
    end
end


local function create_empty_data()
    return {
        version = CURRENT_VERSION,
        clusters = {}
    }
end





local function migrate_legacy_data()
    
    local table_serializer_path = script_path .. "MWM-Table_serializer.lua"
    dofile(table_serializer_path)

    
    local _, cluster_table_str = reaper.GetProjExtState(0, EXTSTATE_SECTION, LEGACY_TABLE_KEY)
    if not cluster_table_str or cluster_table_str == "" then
        return nil
    end

    local cluster_table = table.deserialize(cluster_table_str)
    if not cluster_table then
        return nil
    end

    
    local _, cluster_items_str = reaper.GetProjExtState(0, EXTSTATE_SECTION, LEGACY_ITEMS_KEY)
    local cluster_items = nil
    if cluster_items_str and cluster_items_str ~= "" then
        cluster_items = table.deserialize(cluster_items_str)
    end
    if not cluster_items then
        cluster_items = {}
    end

    
    local data = create_empty_data()

    for _, cluster in pairs(cluster_table) do
        if cluster.cluster_guid then
            local guid = cluster.cluster_guid

            
            local items = {}
            if cluster_items[guid] then
                for item_guid, item_data in pairs(cluster_items[guid]) do
                    items[item_guid] = {
                        item_take_guid = item_data.item_take_guid or "",
                        time_modified = item_data.time_modified or os.time()
                    }
                end
            end

            data.clusters[guid] = {
                cluster_id = cluster.cluster_id or 0,
                name = cluster.name or "",
                c_start = cluster.c_start or 0,
                c_end = cluster.c_end or 0,
                c_entry = cluster.c_entry,
                c_exit = cluster.c_exit,
                is_loop = cluster.is_loop or false,
                color = cluster.color or 0,
                region_guid = cluster.region_guid or "",
                region_index = cluster.region_index or -1,
                parent_guid = cluster.parent_guid,
                group_visible = cluster.group_visible ~= false,
                items = items
            }
        end
    end

    return data
end






function ClusterStore.load(force_reload)
    if cache.loaded and not force_reload then
        return cache.data
    end

    
    local _, json_str = reaper.GetProjExtState(0, EXTSTATE_SECTION, JSON_KEY)
    if json_str and json_str ~= "" then
        local data = safe_json_decode(json_str)
        if data and data.version then
            cache.data = data
            cache.loaded = true
            cache.dirty = false
            return cache.data
        end
    end

    
    local legacy_data = migrate_legacy_data()
    if legacy_data then
        cache.data = legacy_data
        cache.loaded = true
        cache.dirty = true  
        return cache.data
    end

    
    cache.data = create_empty_data()
    cache.loaded = true
    cache.dirty = false
    return cache.data
end


function ClusterStore.save()
    if not cache.data then
        return false
    end

    local json_str = safe_json_encode(cache.data)
    if not json_str then
        return false
    end

    
    reaper.SetProjExtState(0, EXTSTATE_SECTION, JSON_KEY, json_str)

    
    
    ClusterStore._write_legacy_format()

    reaper.MarkProjectDirty(0)

    cache.dirty = false
    return true
end


function ClusterStore._write_legacy_format()
    if not cache.data then
        return
    end

    
    local table_serializer_path = script_path .. "MWM-Table_serializer.lua"
    dofile(table_serializer_path)

    
    local legacy_items = {}
    for cluster_guid, cluster in pairs(cache.data.clusters) do
        if cluster.items and next(cluster.items) then
            legacy_items[cluster_guid] = {}
            for item_guid, item_data in pairs(cluster.items) do
                legacy_items[cluster_guid][item_guid] = {
                    item_guid = item_guid,
                    item_take_guid = item_data.item_take_guid,
                    time_modified = item_data.time_modified
                }
            end
        end
    end

    
    local legacy_str = table.serialize(legacy_items)
    reaper.SetProjExtState(0, EXTSTATE_SECTION, LEGACY_ITEMS_KEY, legacy_str)
end


function ClusterStore.reload()
    return ClusterStore.load(true)
end


function ClusterStore.is_dirty()
    return cache.dirty
end


function ClusterStore.invalidate()
    cache.loaded = false
    cache.data = nil
    cache.dirty = false
end






function ClusterStore.get_clusters()
    local data = ClusterStore.load()
    return data.clusters
end


function ClusterStore.get_cluster(cluster_guid)
    local data = ClusterStore.load()
    return data.clusters[cluster_guid]
end


function ClusterStore.set_cluster(cluster_guid, cluster_data)
    local data = ClusterStore.load()

    
    if not cluster_data.items then
        cluster_data.items = {}
    end

    
    local existing = data.clusters[cluster_guid]
    local changed = false
    if not existing then
        changed = true
    else
        
        if existing.cluster_id ~= cluster_data.cluster_id or
           existing.name ~= cluster_data.name or
           existing.c_start ~= cluster_data.c_start or
           existing.c_end ~= cluster_data.c_end or
           existing.c_entry ~= cluster_data.c_entry or
           existing.c_exit ~= cluster_data.c_exit or
           existing.is_loop ~= cluster_data.is_loop or
           existing.color ~= cluster_data.color or
           existing.region_guid ~= cluster_data.region_guid or
           existing.parent_guid ~= cluster_data.parent_guid or
           existing.group_visible ~= cluster_data.group_visible then
            changed = true
        end
    end

    data.clusters[cluster_guid] = cluster_data
    if changed then
        cache.dirty = true
    end
    return true
end


function ClusterStore.delete_cluster(cluster_guid)
    local data = ClusterStore.load()
    if data.clusters[cluster_guid] then
        data.clusters[cluster_guid] = nil
        cache.dirty = true
        return true
    end
    return false
end






function ClusterStore.get_items(cluster_guid)
    local cluster = ClusterStore.get_cluster(cluster_guid)
    if cluster then
        return cluster.items or {}
    end
    return {}
end


function ClusterStore.add_item(cluster_guid, item_guid, item_take_guid)
    local data = ClusterStore.load()
    local cluster = data.clusters[cluster_guid]
    if not cluster then
        return false
    end

    if not cluster.items then
        cluster.items = {}
    end

    cluster.items[item_guid] = {
        item_take_guid = item_take_guid or "",
        time_modified = os.time()
    }

    cache.dirty = true
    return true
end


function ClusterStore.remove_item(cluster_guid, item_guid)
    local data = ClusterStore.load()
    local cluster = data.clusters[cluster_guid]
    if not cluster or not cluster.items then
        return false
    end

    if cluster.items[item_guid] then
        cluster.items[item_guid] = nil
        cache.dirty = true
        return true
    end
    return false
end


function ClusterStore.is_item_in_cluster(cluster_guid, item_guid)
    local items = ClusterStore.get_items(cluster_guid)
    return items[item_guid] ~= nil
end






function ClusterStore.add_selected_items(cluster_guid)
    local cluster = ClusterStore.get_cluster(cluster_guid)
    if not cluster then
        return 0, 0
    end

    local c_start = cluster.c_start or 0
    local c_end = cluster.c_end or 0
    local items_added = 0
    local items_skipped = 0

    local count = reaper.CountSelectedMediaItems(0)
    for i = 0, count - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        if item then
            local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
            local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

            
            local overlaps = not (item_pos + item_len <= c_start or item_pos >= c_end)

            if overlaps then
                local _, item_guid = reaper.GetSetMediaItemInfo_String(item, "GUID", "", false)
                local cur_take_idx = reaper.GetMediaItemInfo_Value(item, "I_CURTAKE")
                local take = reaper.GetTake(item, cur_take_idx)
                local item_take_guid = ""
                if take then
                    _, item_take_guid = reaper.GetSetMediaItemTakeInfo_String(take, "GUID", "", false)
                end

                ClusterStore.add_item(cluster_guid, item_guid, item_take_guid)
                items_added = items_added + 1

                
                ClusterStore._update_item_metadata(item, cluster_guid, cluster.cluster_id, item_take_guid)
            else
                items_skipped = items_skipped + 1
            end
        end
    end

    if items_added > 0 then
        ClusterStore.save()
    end

    return items_added, items_skipped
end


function ClusterStore.remove_selected_items(cluster_guid)
    local cluster = ClusterStore.get_cluster(cluster_guid)
    if not cluster then
        return 0, 0
    end

    local items_removed = 0
    local items_skipped = 0

    local count = reaper.CountSelectedMediaItems(0)
    for i = 0, count - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        if item then
            local _, item_guid = reaper.GetSetMediaItemInfo_String(item, "GUID", "", false)

            if ClusterStore.remove_item(cluster_guid, item_guid) then
                items_removed = items_removed + 1

                
                ClusterStore._remove_item_metadata(item, cluster_guid)
            else
                items_skipped = items_skipped + 1
            end
        end
    end

    if items_removed > 0 then
        ClusterStore.save()
    end

    return items_removed, items_skipped
end







local function parse_item_ext(ext_str)
    if not ext_str or ext_str == "" then
        return {}
    end

    
    local ok, result = pcall(table.deserialize, ext_str)
    if ok and result then
        return result
    end

    
    result = safe_json_decode(ext_str)
    if result then
        return result
    end

    return {}
end

function ClusterStore._update_item_metadata(item, cluster_guid, cluster_id, take_guid)
    local _, ext_str = reaper.GetSetMediaItemInfo_String(item, "P_EXT:AMAPP", "", false)
    local item_clusters = parse_item_ext(ext_str)

    
    local found = false
    for i, ref in ipairs(item_clusters) do
        if type(ref) == "table" and ref.cluster_guid == cluster_guid then
            ref.take = take_guid
            found = true
            break
        end
    end

    if not found then
        table.insert(item_clusters, {
            cluster_guid = cluster_guid,
            cluster_id = cluster_id,
            take = take_guid
        })
    end

    
    local new_ext_str = table.serialize(item_clusters)
    reaper.GetSetMediaItemInfo_String(item, "P_EXT:AMAPP", new_ext_str, true)
end

function ClusterStore._remove_item_metadata(item, cluster_guid)
    local _, ext_str = reaper.GetSetMediaItemInfo_String(item, "P_EXT:AMAPP", "", false)
    if not ext_str or ext_str == "" then
        return
    end

    local item_clusters = parse_item_ext(ext_str)
    if not item_clusters or #item_clusters == 0 then
        return
    end

    
    for i = #item_clusters, 1, -1 do
        if type(item_clusters[i]) == "table" and item_clusters[i].cluster_guid == cluster_guid then
            table.remove(item_clusters, i)
        end
    end

    
    if #item_clusters > 0 then
        local new_ext_str = table.serialize(item_clusters)
        reaper.GetSetMediaItemInfo_String(item, "P_EXT:AMAPP", new_ext_str, true)
    else
        reaper.GetSetMediaItemInfo_String(item, "P_EXT:AMAPP", "", true)
    end
end






function ClusterStore.get_legacy_items_table()
    local data = ClusterStore.load()
    local result = {}

    for cluster_guid, cluster in pairs(data.clusters) do
        if cluster.items and next(cluster.items) then
            result[cluster_guid] = {}
            for item_guid, item_data in pairs(cluster.items) do
                result[cluster_guid][item_guid] = {
                    item_guid = item_guid,
                    item_take_guid = item_data.item_take_guid,
                    time_modified = item_data.time_modified
                }
            end
        end
    end

    return result
end


function ClusterStore.get_legacy_cluster_table()
    local data = ClusterStore.load()
    local result = {}

    for cluster_guid, cluster in pairs(data.clusters) do
        result[cluster_guid] = {
            cluster_guid = cluster_guid,
            cluster_id = cluster.cluster_id,
            name = cluster.name,
            c_start = cluster.c_start,
            c_end = cluster.c_end,
            c_entry = cluster.c_entry,
            c_exit = cluster.c_exit,
            is_loop = cluster.is_loop,
            color = cluster.color,
            region_guid = cluster.region_guid,
            region_index = cluster.region_index,
            parent_guid = cluster.parent_guid,
            group_visible = cluster.group_visible
        }
    end

    return result
end


function ClusterStore.import_legacy_cluster(cluster)
    if not cluster or not cluster.cluster_guid then
        return false
    end

    local existing = ClusterStore.get_cluster(cluster.cluster_guid)
    local items = existing and existing.items or {}

    ClusterStore.set_cluster(cluster.cluster_guid, {
        cluster_id = cluster.cluster_id or 0,
        name = cluster.name or "",
        c_start = cluster.c_start or 0,
        c_end = cluster.c_end or 0,
        c_entry = cluster.c_entry,
        c_exit = cluster.c_exit,
        is_loop = cluster.is_loop or false,
        color = cluster.color or 0,
        region_guid = cluster.region_guid or "",
        region_index = cluster.region_index or -1,
        parent_guid = cluster.parent_guid,
        group_visible = cluster.group_visible ~= false,
        items = items
    })

    return true
end


function ClusterStore.sync_from_legacy_table()
    local _, cluster_table_str = reaper.GetProjExtState(0, EXTSTATE_SECTION, LEGACY_TABLE_KEY)
    if not cluster_table_str or cluster_table_str == "" then
        return false
    end

    
    local table_serializer_path = script_path .. "MWM-Table_serializer.lua"
    dofile(table_serializer_path)

    local cluster_table = table.deserialize(cluster_table_str)
    if not cluster_table then
        return false
    end

    
    for _, cluster in pairs(cluster_table) do
        ClusterStore.import_legacy_cluster(cluster)
    end

    
    local _, cluster_items_str = reaper.GetProjExtState(0, EXTSTATE_SECTION, LEGACY_ITEMS_KEY)
    if cluster_items_str and cluster_items_str ~= "" then
        local cluster_items = table.deserialize(cluster_items_str)
        if cluster_items then
            local data = ClusterStore.load()
            for cluster_guid, items in pairs(cluster_items) do
                if data.clusters[cluster_guid] then
                    
                    if not data.clusters[cluster_guid].items then
                        data.clusters[cluster_guid].items = {}
                        cache.dirty = true
                    end
                    for item_guid, item_data in pairs(items) do
                        local existing_item = data.clusters[cluster_guid].items[item_guid]
                        local new_take_guid = item_data.item_take_guid or ""
                        local new_time = item_data.time_modified or os.time()
                        
                        if not existing_item or
                           existing_item.item_take_guid ~= new_take_guid or
                           existing_item.time_modified ~= new_time then
                            data.clusters[cluster_guid].items[item_guid] = {
                                item_take_guid = new_take_guid,
                                time_modified = new_time
                            }
                            cache.dirty = true
                        end
                    end
                end
            end
        end
    end

    
    if cache.dirty then
        ClusterStore.save()
    end
    return true
end





function ClusterStore.get_stats()
    local data = ClusterStore.load()
    local cluster_count = 0
    local item_count = 0

    for _, cluster in pairs(data.clusters) do
        cluster_count = cluster_count + 1
        if cluster.items then
            for _ in pairs(cluster.items) do
                item_count = item_count + 1
            end
        end
    end

    return {
        version = data.version,
        cluster_count = cluster_count,
        item_count = item_count,
        dirty = cache.dirty,
        loaded = cache.loaded
    }
end

function ClusterStore.dump_json()
    local data = ClusterStore.load()
    return safe_json_encode(data)
end

return ClusterStore
