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

reaper.ShowConsoleMsg("")
local function Msg(param)
	if param == nil then reaper.ShowConsoleMsg("") return end
	reaper.ShowConsoleMsg(tostring(param) .. "\n")
end

local mwm_lib_path = reaper.GetExtState("AMAPP", "lib_path")
if not mwm_lib_path or mwm_lib_path == "" then
	reaper.MB("Couldn't load the AMAPP Library. Please install the AMAPP by running the AMAPP_installation.lua ReaScript!", "Error!", 0)
	return
end
dofile(mwm_lib_path .. "util/MWM-Table_serializer.lua")
local Json = dofile(mwm_lib_path .. "util/json/json.lua")


local function parse_item_ext(ext_str)
	if not ext_str or ext_str == "" then
		return {}
	end
	
	local ok, result = pcall(table.deserialize, ext_str)
	if ok and result then
		return result
	end
	
	ok, result = pcall(Json.decode, ext_str)
	if ok and result then
		return result
	end
	return {}
end

local function Item_is_within_cluster(cluster, _mediaItem)
	local pos, rgnend = cluster.c_start, cluster.c_end
	local item_pos = reaper.GetMediaItemInfo_Value(_mediaItem, "D_POSITION")
	local item_len = reaper.GetMediaItemInfo_Value(_mediaItem, "D_LENGTH")
	if (item_pos < pos and (item_pos + item_len) <= pos) or (rgnend <= item_pos) then
		return false
	else
		return true
	end
end

local function AttachClusterToExistingRegion(_name, markrgnindexnumber)
	local _, render_cluster_table_string = reaper.GetProjExtState(0, "AMAPP", "CLUSTER_TABLE")
	local render_cluster_table = table.deserialize(render_cluster_table_string)
	if render_cluster_table == nil then render_cluster_table = {} end	
	for key, existing_table in pairs(render_cluster_table) do
		if tostring(existing_table.cluster_id) == _name then
			reaper.MB("Can not override existing connections between a render cluster and its region. Please enter a unique render cluster name that is not connected to a region index"
				, "Override error!", 0)
			return
		end
	end

	local _sTable = table.serialize(render_cluster_table)
	reaper.SetProjExtState(0, "AMAPP", "CLUSTER_TABLE", _sTable)
	Set_items_in_cluster(_name, markrgnindexnumber)
end

local function SearchForExistingRegions(_inputName, _num_total, _startTime, _endTime)
	local i = 0
	local regionExists = false
	local error_msg
	while i < _num_total do
		local retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3( 0, i )
		if isrgn then
               local lower_name = string.lower(name)
               local lower_search_string = string.lower(_inputName)
               if lower_name == lower_search_string then
				error_msg = "A region with that name already exists. Duplicated cluster needs a unique name."
                    regionExists = true
                    break
               end
		end
          i = i + 1
	end
	return regionExists, error_msg
end

local function SearchForExistingClusters(cluster_id, new_cluster_name)
	local _, cluster_table_string = reaper.GetProjExtState(0, "AMAPP", "CLUSTER_TABLE")
	local cluster_table = table.deserialize(cluster_table_string)
	if cluster_table == nil then cluster_table = {} end
	local exists_in_render_cluster_table = false
	for key, existing_cluster in pairs(cluster_table) do
		if tostring(existing_cluster.cluster_id) == cluster_id then
			exists_in_render_cluster_table = true
			break
		end
		if tostring(existing_cluster.cluster_id) == new_cluster_name then
			local error_msg = "Cannot create a duplicate with a name that is already being used."
			return false, error_msg
		end
	end
	if not exists_in_render_cluster_table then
		local error_msg = "Cannot duplicate a Render Cluster that doesn't exist in PEXT."
		return false, error_msg
	end
	return true
end


function Duplicate_cluster(cluster, new_cluster_name)
	local cluster_name_granted, error_msg = SearchForExistingClusters(cluster.cluster_id, new_cluster_name)
	if not cluster_name_granted then
		return reaper.MB(tostring(error_msg), "Error!", 0)
	end
	local region_guid = nil
	if cluster.region_guid then
		local pos, rgnend, name, color = cluster.c_start, cluster.c_end, new_cluster_name, cluster.cluster_color
		local wantidx = reaper.CountProjectMarkers(0)
		local idx = reaper.AddProjectMarker2(0, true, pos, rgnend, name, wantidx, color|0x1000000)
		local newRegionIndex, isRgn, _, _, _, mrkidx = reaper.EnumProjectMarkers2(0, idx)
		local num_total = reaper.CountProjectMarkers(0)
		local i = 0
		while i < num_total do
			i = i + 1
			local new_region_idx = i - 1
			local _, _, _pos = reaper.EnumProjectMarkers3(0, i)
			if pos < _pos then
				_, region_guid = reaper.GetSetProjectInfo_String(0, "MARKER_GUID:"..tostring(new_region_idx), "", false)
				break
			end
		end
		if region_guid == nil then
			_, region_guid = reaper.GetSetProjectInfo_String(0, "MARKER_GUID:"..tostring(num_total-1), "", false)
		end
	end
	local _, cluster_table_string = reaper.GetProjExtState(0, "AMAPP", "CLUSTER_TABLE")
	local cluster_table = table.deserialize(cluster_table_string)
	if cluster_table == nil then cluster_table = {} end
	local new_cluster_guid = reaper.genGuid()
	
	local source_cluster = nil
	for k, v in pairs(cluster_table) do
		if v.cluster_guid == cluster.cluster_guid then
			source_cluster = v
			break
		end
	end
	if source_cluster then
		
		local new_idx = (source_cluster.idx or 1) + 1
		
		for k, v in pairs(cluster_table) do
			if v.idx and v.idx >= new_idx then
				v.idx = v.idx + 1
			end
		end
		local new_cluster = {
			idx = new_idx,
			cluster_id = new_cluster_name,
			cluster_guid = new_cluster_guid,
			is_loop = source_cluster.is_loop,
			c_start = source_cluster.c_start,
			c_end = source_cluster.c_end,
			c_entry = source_cluster.c_entry,
			c_exit = source_cluster.c_exit,
			c_qn_start = source_cluster.c_qn_start,
			c_qn_end = source_cluster.c_qn_end,
			c_qn_entry = source_cluster.c_qn_entry,
			c_qn_exit = source_cluster.c_qn_exit,
			cluster_color = source_cluster.cluster_color,
			region_guid = region_guid
		}
		
		cluster_table[new_cluster_guid] = new_cluster
	end
	local cluster_sTable = table.serialize(cluster_table)
	reaper.SetProjExtState(0, "AMAPP", "CLUSTER_TABLE", cluster_sTable)
	local previously_selected_items = reaper.CountSelectedMediaItems(0)
	local table_saved_selection = {}
	for i = 0, previously_selected_items - 1 do
		table.insert(table_saved_selection, reaper.GetSelectedMediaItem(0, i))
	end

	
	local _, cluster_items_str = reaper.GetProjExtState(0, "AMAPP", "CLUSTER_ITEMS")
	local all_cluster_items = table.deserialize(cluster_items_str)
	local source_items = all_cluster_items and all_cluster_items[cluster.cluster_guid] or {}

	local items_in_cluster = {}
	for item_guid, _ in pairs(source_items) do
		local item = reaper.BR_GetMediaItemByGUID(0, item_guid)
		if item then
			items_in_cluster[item_guid] = item
		end
	end
	
	
	local track_lane_map = {}
	local new_items_table = {}
	local new_items_list = {}

	for item_guid, item in pairs(items_in_cluster) do
		local track = reaper.GetMediaItemTrack(item)

		
		if reaper.GetMediaTrackInfo_Value(track, "I_FREEMODE") ~= 2 then
			reaper.SetMediaTrackInfo_Value(track, "I_FREEMODE", 2)
		end

		
		if not track_lane_map[track] then
			local num_lanes = reaper.GetMediaTrackInfo_Value(track, "I_NUMFIXEDLANES")
			track_lane_map[track] = num_lanes
			reaper.SetMediaTrackInfo_Value(track, "I_NUMFIXEDLANES", num_lanes + 1)
		end
		local target_lane = track_lane_map[track]

		
		local _, chunk = reaper.GetItemStateChunk(item, "", false)
		local new_item = reaper.AddMediaItemToTrack(track)
		reaper.SetItemStateChunk(new_item, chunk, false)

		
		local new_guid = reaper.genGuid()
		reaper.GetSetMediaItemInfo_String(new_item, "GUID", new_guid, true)

		
		reaper.SetMediaItemInfo_Value(new_item, "I_FIXEDLANE", target_lane)

		
		local cur_take_idx = reaper.GetMediaItemInfo_Value(new_item, "I_CURTAKE")
		local cur_take = reaper.GetTake(new_item, cur_take_idx)
		local new_take_guid
		if cur_take then
			_, new_take_guid = reaper.GetSetMediaItemTakeInfo_String(cur_take, "GUID", "", false)
		end

		
		local new_item_ext = {{cluster_guid = new_cluster_guid, cluster_id = new_cluster_name}}
		local ext_str = table.serialize(new_item_ext)
		reaper.GetSetMediaItemInfo_String(new_item, "P_EXT:AMAPP", ext_str, true)

		new_items_table[new_guid] = {
			item_take_guid = new_take_guid,
			time_modified = os.time()
		}
		table.insert(new_items_list, new_item)
	end

	
	reaper.SelectAllMediaItems(0, false)
	for _, new_item in ipairs(new_items_list) do
		reaper.SetMediaItemInfo_Value(new_item, "B_UISEL", 1)
	end
	reaper.Main_OnCommand(41613, 0) 
	reaper.SelectAllMediaItems(0, false)

	reaper.UpdateTimeline()

	
	local _, cluster_items_string = reaper.GetProjExtState(0, "AMAPP", "CLUSTER_ITEMS")
	local cluster_items = table.deserialize(cluster_items_string)
	if cluster_items == nil then cluster_items = {} end
	cluster_items[new_cluster_guid] = new_items_table
	local c_string = table.serialize(cluster_items)
	reaper.SetProjExtState(0, "AMAPP", "CLUSTER_ITEMS", c_string)

	
	local commandID = reaper.NamedCommandLookup("_SWS_UNSELALL")
	reaper.Main_OnCommand(commandID, 0)
	for k, v in pairs(table_saved_selection) do
		reaper.SetMediaItemInfo_Value(v, "B_UISEL", 1)
	end
	reaper.MarkProjectDirty(0)
	reaper.UpdateArrange()
	reaper.PreventUIRefresh(-1)
end