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
function Msg(param)
	reaper.ShowConsoleMsg(tostring(param).."\n")
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


local function Item_is_within_cluster(item_pos, item_len, cluster)
	if cluster == nil then
		return
	end
	local markerRetVal, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(_selectedRegionIndex)
	if (item_pos < pos and (item_pos + item_len) <= pos) or (rgnend <= item_pos) then
		return false
	else
		return true
	end
end

local function SearchForExistingRegions(_inputName, _num_total)
	
	local i = 0
	local regionExists = false
	while i < _num_total do
		local retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers( i )
		if isrgn then
				local lower_name = string.lower(name)
				local lower_search_string = string.lower(_inputName)
				if lower_name == lower_search_string then
					
					regionExists = true
					break
				end
		end
		i = i + 1
	end
	return regionExists
end

local function UpdateExistingClusterItemsWithNewName(cluster, _new_cluster_name)
	local count_sel_items = reaper.CountMediaItems(0)
	for i = 0, count_sel_items - 1 do
		local item = reaper.GetSelectedMediaItem(0, i)
		local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
		local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
		local within_region = Item_is_within_cluster(item_pos, item_len, cluster)
		if within_region then
			local _curTake = reaper.GetMediaItemInfo_Value(item, "I_CURTAKE")
			local _take = reaper.GetTake( item, _curTake )
			local _, item_curTake = reaper.GetSetMediaItemTakeInfo_String(_take, "GUID", "", false)
			local _, stringTable = reaper.GetSetMediaItemInfo_String(item, "P_EXT:AMAPP", "", false)
			local _itemProps = parse_item_ext(stringTable)
			if type(_itemProps) == "table" then
				for k, v in pairs(_itemProps) do
					if type(v) == "table" and v.cluster_guid == cluster_guid then
						_itemProps[k].cluster_id = _new_cluster_name
						local _sTable = table.serialize(_itemProps)
						reaper.GetSetMediaItemInfo_String(item, "P_EXT:AMAPP", _sTable, true)
						break
					end
				end
			else
				local new_props = {cluster_guid = cluster.cluster_guid, cluster_id = _new_cluster_name, take = item_curTake}
				local new_sTable = table.serialize(new_props)
				reaper.GetSetMediaItemInfo_String(item, "P_EXT:AMAPP", new_sTable, true)
			end
		end
	end
end

local function UpdateAttachedRegionWithNewName(cluster, _new_name)
	if cluster.region_guid == nil then return end
	local retval, idx = reaper.GetSetProjectInfo_String(0, "MARKER_INDEX_FROM_GUID:" .. cluster.region_guid, "", false)
	if not retval then return end
	local _idx = tonumber(idx)
	if not _idx then return end
	local markerRetVal, isrgn, pos, rgnend, region_name, markrgnindexnumber = reaper.EnumProjectMarkers(_idx)
	reaper.SetProjectMarker(markrgnindexnumber, isrgn, pos, rgnend, _new_name)
end

local function UpdateExistingRenderClusterWithNewName (cluster, _new_name, edit_buf)
	local _, render_cluster_table_string = reaper.GetProjExtState(0, "AMAPP", "CLUSTER_TABLE")
	local render_cluster_table = table.deserialize(render_cluster_table_string)
	if render_cluster_table == nil then render_cluster_table = {} end
	for key, existing_table in pairs(render_cluster_table) do
		if tostring(existing_table.cluster_guid) == cluster.cluster_guid then
			render_cluster_table[key].cluster_id = _new_name
			render_cluster_table[key].is_loop = edit_buf.c.is_loop
			render_cluster_table[key].region_guid = edit_buf.c.region_guid
			render_cluster_table[key].cluster_color = edit_buf.c.cluster_color
			break
		end
	end

	local _sTable = table.serialize(render_cluster_table)
	reaper.SetProjExtState(0, "AMAPP", "CLUSTER_TABLE", _sTable)
end


function Edit_Selected_Cluster(cluster, edit_buffer)
	reaper.PreventUIRefresh(1)
	local previously_selected_items = reaper.CountSelectedMediaItems(0)
	local table_saved_selection = {}
	for i = 0, previously_selected_items - 1 do
		table.insert(table_saved_selection, reaper.GetSelectedMediaItem(0, i))
	end

	local _, cluster_table_string = reaper.GetProjExtState(0, "AMAPP", "CLUSTER_TABLE")
	local cluster_table = table.deserialize(cluster_table_string)
	if cluster_table == nil then cluster_table = {} end
	local exists_in_render_cluster_table = false
	for key, existing_cluster in pairs(cluster_table) do
		if existing_cluster.cluster_guid == cluster.cluster_guid then
			exists_in_render_cluster_table = true
		end
	end
	if not exists_in_render_cluster_table then
		reaper.MB("The cluster could not be found in the saved AMAPP.", "Error!", 0)
		return
	end

	local inputName = edit_buffer.c.cluster_id
	UpdateExistingRenderClusterWithNewName(cluster, inputName, edit_buffer)
	
	local commandID = reaper.NamedCommandLookup("_SWS_UNSELALL")
	reaper.Main_OnCommand(commandID, 0)
	for k, v in pairs(table_saved_selection) do
		reaper.SetMediaItemInfo_Value(v, "B_UISEL", 1)
	end

	reaper.MarkProjectDirty(0)
	reaper.UpdateArrange()
	reaper.PreventUIRefresh(-1)
end