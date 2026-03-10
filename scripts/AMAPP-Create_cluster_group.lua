--[[
	Library/Component: AMAPP
	Copyright (c) 2026 Mount West Music AB
	All rights reserved.

	Description:
	This script contains features for the AMAPP, which provides
	functionality for performing specific operations.

	Note:
	- This script is intended for internal use within the AMAPP library/component.
	- Do not modify this file unless you have proper authorization.
	- For inquiries, contact support@mountwestmusic.com.

	(c) 2026 Mount West Music AB. All rights reserved.
--]]

local mwm_lib_path = reaper.GetExtState("AMAPP", "lib_path")
if not mwm_lib_path or mwm_lib_path == "" then
    reaper.MB("Couldn't load the AMAPP Library. Please install the AMAPP by running the AMAPP_installation.lua ReaScript!", "Error!", 0)
    return
end


if reaper.AMAPP_Cluster_GetVersion then
    
    function Set_items_in_cluster(cluster)
        if not cluster then return end
        local guid = cluster.cluster_guid or cluster.guid
        if not guid then return end
        reaper.AMAPP_Cluster_AssociateSelectedItems(guid, '{"time_bounded":false}')
    end
else
    
    local loader = loadfile(mwm_lib_path .. "scripts/AMAPP-Set_items_in_cluster.lua")
    if loader then loader() end
end
loadfile(mwm_lib_path .. "scripts/AMAPP-Create_new_render_cluster.lua")()
dofile(mwm_lib_path .. "util/MWM-Table_serializer.lua")
local ClusterTree = loadfile(mwm_lib_path .. "util/AMAPP-ClusterTree.lua")()

reaper.ShowConsoleMsg("")
local function Msg(param)
	if param == nil then reaper.ShowConsoleMsg("") return end
	reaper.ShowConsoleMsg(tostring(param).."\n")
end



local function reindex_with_children(cluster_table, parent_guid, start_index)
	local visited = {}
	local current_index = start_index

	local function recur_reindex(guid)
		if visited[guid] then
			return
		end
		visited[guid] = true

		if not guid or not cluster_table[guid] then
			return
		end

		cluster_table[guid].idx = current_index
		current_index = current_index + 1

		local children = ClusterTree.get_children(cluster_table, guid)
		for _, child_guid in ipairs(children) do
			recur_reindex(child_guid)
		end
	end

	recur_reindex(parent_guid)
	return current_index
end

local function reindex_items_with_group(items, selected_clusters, group_cluster)
    local group_index = group_cluster.idx
    local group_guid = group_cluster.cluster_guid
    local group_item = group_cluster
    local item_list = {}

    for guid, item in pairs(items) do
        if guid ~= group_guid then
            table.insert(item_list, { guid = guid, item = item })
        end
    end

    table.sort(item_list, function(a, b)
        return a.item.idx < b.item.idx
    end)

    local before = {}
    local after = {}
    local selected = {}

    for _, entry in pairs(item_list) do
        local guid = entry.guid
        local item = entry.item
        if selected_clusters[guid] then
            table.insert(selected, entry)
        elseif item.idx < group_index then
            table.insert(before, entry)
        else
            table.insert(after, entry)
        end
    end

    local new_order = {}
    local current_idx = 1

    for _, entry in pairs(before) do
        entry.item.idx = current_idx
        new_order[entry.guid] = entry.item
        current_idx = current_idx + 1
    end

    group_item.idx = current_idx
    new_order[group_guid] = group_item
    current_idx = current_idx + 1

    for _, entry in pairs(selected) do
        local children = ClusterTree.get_children(new_order, entry.guid)
        if #children > 0 then
            current_idx = reindex_with_children(new_order, entry.guid, current_idx)
        else
            entry.item.idx = current_idx
            new_order[entry.guid] = entry.item
            current_idx = current_idx + 1
        end
    end

    for _, entry in pairs(after) do
        entry.item.idx = current_idx
        new_order[entry.guid] = entry.item
        current_idx = current_idx + 1
    end

    return new_order
end


function Create_Cluster_Group(selected_clusters, wantidx, group_name, create_region, custom_color)
	reaper.PreventUIRefresh(1)
	local _, cluster_table_string = reaper.GetProjExtState(0, "AMAPP", "CLUSTER_TABLE")
	local cluster_table = table.deserialize(cluster_table_string)
	if cluster_table == nil then cluster_table = {} end
    local group_parent_guid

    
    local group_start = math.huge
    local group_end = 0
    for key, cluster_guid in pairs(selected_clusters) do
        local cluster = cluster_table[cluster_guid]
        if cluster then
            if cluster.parent_guid ~= nil and group_parent_guid == nil then
                group_parent_guid = cluster.parent_guid
            end
            if cluster.c_start and cluster.c_start < group_start then
                group_start = cluster.c_start
            end
            if cluster.c_end and cluster.c_end > group_end then
                group_end = cluster.c_end
            end
        end
    end

    
    if create_region and group_start ~= math.huge and group_end > 0 then
        reaper.GetSet_LoopTimeRange(true, false, group_start, group_end, false)
    end

    
    local name = group_name or "Group"
    local parent_guid = CreateNewRenderCluster(name, false, create_region or false, wantidx, group_parent_guid, custom_color)
    if parent_guid == nil then return end

    _, cluster_table_string = reaper.GetProjExtState(0, "AMAPP", "CLUSTER_TABLE")
	cluster_table = table.deserialize(cluster_table_string)
	if cluster_table == nil then cluster_table = {} end

    
    cluster_table[parent_guid].children = {}

    local selected_cluster_map = {}
    for key, cluster_guid in pairs(selected_clusters) do
        cluster_table[cluster_guid].parent_guid = parent_guid
        
        table.insert(cluster_table[parent_guid].children, cluster_guid)
        selected_cluster_map[cluster_guid] = 1
    end

    cluster_table = reindex_items_with_group(cluster_table, selected_cluster_map, cluster_table[parent_guid])

	local cluster_sTable = table.serialize(cluster_table)
	reaper.SetProjExtState(0, "AMAPP", "CLUSTER_TABLE", cluster_sTable)
	reaper.MarkProjectDirty(0)
	reaper.PreventUIRefresh(-1)
end