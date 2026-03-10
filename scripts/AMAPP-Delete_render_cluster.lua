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
dofile(mwm_lib_path .. "util/MWM-Table_serializer.lua")
local ClusterTree = loadfile(mwm_lib_path .. "util/AMAPP-ClusterTree.lua")()
local Json = dofile(mwm_lib_path .. "util/json/json.lua")

reaper.ShowConsoleMsg("")
local function Msg(param)
	reaper.ShowConsoleMsg(tostring(param).."\n")
end


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




function Delete_Selected_Cluster(cluster, cluster_guid)
	reaper.PreventUIRefresh(1)
	reaper.SelectAllMediaItems(0, true)
	local count_sel_items = reaper.CountSelectedMediaItems(0)
	for _i = 0, count_sel_items - 1 do
		local item = reaper.GetSelectedMediaItem(0, _i)
		local _, stringTable = reaper.GetSetMediaItemInfo_String(item, "P_EXT:AMAPP", "", false)
		local connected_clusters_in_item = parse_item_ext(stringTable)
		if type(connected_clusters_in_item) ~= "table" then goto continue end
		local item_exists_in_cluster = false
		for k, v in pairs(connected_clusters_in_item) do
			if type(v) == "table" and v.cluster_guid == cluster_guid then
				item_exists_in_cluster = true
				table.remove(connected_clusters_in_item, k)
				break
			end
		end
		if item_exists_in_cluster then
			stringTable = table.serialize(connected_clusters_in_item)
			reaper.GetSetMediaItemInfo_String(item, "P_EXT:AMAPP", stringTable, true)
		end
		::continue::
	end

	local _, sTable = reaper.GetProjExtState(0, "AMAPP", "CLUSTER_TABLE")
	local render_cluster_table = table.deserialize(sTable)

	if render_cluster_table == nil then render_cluster_table = {} end

	
	local orphaned_children = ClusterTree.get_children(render_cluster_table, cluster_guid)

	
	render_cluster_table[cluster_guid] = nil

	
	if cluster.region_guid ~= nil then
		local retval, guid_index = reaper.GetSetProjectInfo_String(0, "MARKER_INDEX_FROM_GUID:" .. cluster.region_guid, "", false)
		if retval ~= false then
			local idx = tonumber(guid_index)
			if idx ~= nil then
				local _, _, _, _, _, markrgnindexnumber = reaper.EnumProjectMarkers(idx)
				reaper.DeleteProjectMarker(0, markrgnindexnumber, true)
			end
		end
	end

	
	for _, child_guid in ipairs(orphaned_children) do
		if render_cluster_table[child_guid] then
			render_cluster_table[child_guid].parent_guid = nil
		end
	end

	
	
	local all_clusters = {}
	for guid, c in pairs(render_cluster_table) do
		if type(c) == "table" then
			table.insert(all_clusters, {guid = guid, idx = c.idx or 9999})
		end
	end

	
	table.sort(all_clusters, function(a, b)
		return a.idx < b.idx
	end)

	
	for i, item in ipairs(all_clusters) do
		render_cluster_table[item.guid].idx = i
	end

	sTable = table.serialize(render_cluster_table)
	reaper.SetProjExtState(0, "AMAPP", "CLUSTER_TABLE", sTable)

	if #render_cluster_table == 0 then
		reaper.DeleteExtState("AMAPP", "CLUSTER_TABLE", false)
	end

	local _, cluster_items_string = reaper.GetProjExtState(0, "AMAPP", "CLUSTER_ITEMS")
	local cluster_items = table.deserialize(cluster_items_string)
	cluster_items[cluster_guid] = nil
	local c_string = table.serialize(cluster_items)
	reaper.SetProjExtState(0, "AMAPP", "CLUSTER_ITEMS", c_string)

	reaper.Main_OnCommand(40289, 0) 
	reaper.MarkProjectDirty(0)
	reaper.PreventUIRefresh(-1)
end