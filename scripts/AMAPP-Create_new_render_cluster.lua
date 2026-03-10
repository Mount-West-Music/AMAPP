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

local mwm_lib_path
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


function CreateNewRenderCluster(new_cluster_id, isLoop, isRegion, wantidx, parent_guid, custom_color)
	reaper.PreventUIRefresh(1)
	local count_sel_items = reaper.CountSelectedMediaItems(0)
	
	
	
	
	
	if count_sel_items > 0 then
		reaper.Main_OnCommand(40290, 0)
	end
	local StartTimeSel, EndTimeSel = reaper.GetSet_LoopTimeRange(false,false,0,0,false)
	local _, cluster_table_string = reaper.GetProjExtState(0, "AMAPP", "CLUSTER_TABLE")
	local cluster_table = table.deserialize(cluster_table_string)
	if cluster_table == nil then cluster_table = {} end
	local len = 0
	for k, v in pairs(cluster_table) do
		len = len + 1
		if v.cluster_id == new_cluster_id then
			local r = reaper.MB("A cluster with that name already exists. Do you want to continue?"
			, "Not a unique name!", 1)
			if r == 2 then
				return
			end
		end
	end
	local cluster_guid = reaper.genGuid()
	
	local cluster_color = custom_color or reaper.ColorToNative(math.random(50, 255), math.random(50, 255), math.random(50, 255))
	local reorder_table = false
	if wantidx == nil then
		wantidx = len + 1
	else
		reorder_table = true
	end
	local new_cluster = {
		idx = wantidx,
		cluster_guid = cluster_guid,
		cluster_id = new_cluster_id,
		c_start = StartTimeSel,
		c_end = EndTimeSel,
		c_entry = nil or StartTimeSel,
		c_exit = nil or EndTimeSel,
		c_qn_start = reaper.TimeMap2_timeToQN(0, StartTimeSel),
		c_qn_end = reaper.TimeMap2_timeToQN(0, EndTimeSel),
		c_qn_entry = nil or reaper.TimeMap2_timeToQN(0, StartTimeSel),
		c_qn_exit = nil or reaper.TimeMap2_timeToQN(0, EndTimeSel),
		is_loop = isLoop,
		cluster_color = cluster_color,
		group_visible = true,
		parent_guid = parent_guid
	}
	if isRegion then
		reaper.Main_OnCommand(40898, 0) 
		reaper.UpdateTimeline()
		local count_markers = reaper.CountProjectMarkers(0)
		local _newRegionIndex = reaper.AddProjectMarker2(0, true, StartTimeSel, EndTimeSel, new_cluster_id, count_markers, cluster_color|0x1000000)
		if _newRegionIndex == -1 then
			reaper.MB("A new region could not be created!"
			, "Something went wrong!", 0)
			return
		end
		local num_total, num_markers, num_regions = reaper.CountProjectMarkers(0)
		local i = 0
		while i < num_total do
			i = i + 1
			local new_region_idx = i - 1
			local _, _, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, i)
			if StartTimeSel < pos then
				local _, region_guid = reaper.GetSetProjectInfo_String(0, "MARKER_GUID:"..tostring(new_region_idx), "", false)
				new_cluster.region_guid = region_guid
				break
			end
		end
		if new_cluster.region_guid == nil then
			local _, region_guid = reaper.GetSetProjectInfo_String(0, "MARKER_GUID:"..tostring(count_markers), "", false)
			new_cluster.region_guid = region_guid
		end
		if new_cluster.region_guid == nil then goto skip end
		local _, guid_index = reaper.GetSetProjectInfo_String(0, "MARKER_INDEX_FROM_GUID:" .. new_cluster.region_guid, "", false)
		if guid_index == nil then goto skip end
		local _r_idx = tonumber(guid_index)
		if _r_idx == nil then goto skip end
		local _, isrgn, pos, rgnend, name, IDnumber, color = reaper.EnumProjectMarkers3(0, _r_idx)
		reaper.SetProjectMarker3(0, IDnumber, isrgn, pos, rgnend, name, new_cluster.cluster_color + 0x1000000)
		reaper.SetProjectMarkerByIndex2(0, _r_idx, isrgn, pos, rgnend, IDnumber, new_cluster.cluster_id, new_cluster.cluster_color + 0x1000000, 2)
		::skip::
	end
	if reorder_table then
		for key, cluster in pairs(cluster_table) do
			
			if wantidx <= cluster.idx then
				
				local children = ClusterTree.get_children(cluster_table, key)
				
				if #children > 0 then
					reindex_with_children(cluster_table, key, cluster.idx + 1)
				else
					cluster.idx = cluster.idx + 1
				end
			end
		end
	end
	cluster_table[cluster_guid] = new_cluster
	local cluster_sTable = table.serialize(cluster_table)
	reaper.SetProjExtState(0, "AMAPP", "CLUSTER_TABLE", cluster_sTable)

	Set_items_in_cluster(new_cluster)

	reaper.MarkProjectDirty(0)
	reaper.UpdateTimeline()
	reaper.PreventUIRefresh(-1)
	return cluster_guid
end