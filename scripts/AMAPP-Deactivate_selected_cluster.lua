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
dofile(mwm_lib_path .. "util/MWM-Table_serializer.lua")
local Json = dofile(mwm_lib_path .. "util/json/json.lua")

reaper.ShowConsoleMsg("")
local function Msg(param)
	if param == nil then reaper.ShowConsoleMsg("") return end
    	reaper.ShowConsoleMsg(tostring(param) .. "\n")
end


local function parse_item_ext(ext_str)
	if not ext_str or ext_str == "" then
		return nil
	end
	
	local ok, result = pcall(table.deserialize, ext_str)
	if ok and result then
		return result
	end
	
	ok, result = pcall(Json.decode, ext_str)
	if ok and result then
		return result
	end
	return nil
end


local function Active_item_take_is_video(item)
	if item == nil then return false end
	local take = reaper.GetActiveTake(item)
	local source = reaper.GetMediaItemTake_Source(take)
	local typebuf = reaper.GetMediaSourceType(source)
	if typebuf == "SECTION" then
		source = reaper.GetMediaSourceParent(source)
		typebuf = reaper.GetMediaSourceType(source)
	end
	if typebuf == "VIDEO" then
		return true
	else
		return false
	end
end

local function Deactivate_Items(_table, selective_midi_note_off)
	local last_found_track = 0
	for k, item in pairs(_table) do
		if Active_item_take_is_video(item) then goto skip end 
		reaper.SetMediaItemInfo_Value(item, "B_MUTE", 1)
		::skip::
	end
end

local function Item_is_within_cluster(cluster, item_pos, item_len)
	if cluster == nil then return false end
	local c_start, c_end = cluster.c_start, cluster.c_end
	if (item_pos < c_start and (item_pos + item_len) <= c_start) or (c_end <= item_pos) then
		return false
	else
		return true
	end
end


function Deactivate_items_in_cluster(_cluster)
	reaper.Undo_BeginBlock()
	reaper.PreventUIRefresh(1)
    reaper.Main_OnCommand(40345, 0) 

	local _, cluster_table_string = reaper.GetProjExtState(0, "AMAPP", "CLUSTER_TABLE")
	local cluster_table = table.deserialize(cluster_table_string)
	if cluster_table == nil then cluster_table = {} end

	
	if _cluster.c_start == nil or _cluster.c_end == nil then
		for k, v in pairs(cluster_table) do
			if tostring(v.cluster_guid) == _cluster.cluster_guid then
				_cluster.c_start = v.c_start
				_cluster.c_end = v.c_end
				break
			end
		end
	end

	local previously_selected_items = reaper.CountSelectedMediaItems(0)
	local table_saved_selection = {}
	for i = 0, previously_selected_items - 1 do
		table.insert(table_saved_selection, reaper.GetSelectedMediaItem(0, i))
	end

	
	local _, cluster_items_str = reaper.GetProjExtState(0, "AMAPP", "CLUSTER_ITEMS")
	local all_cluster_items = table.deserialize(cluster_items_str)
	local source_items = all_cluster_items and all_cluster_items[_cluster.cluster_guid] or {}

	local table_of_items_in_selected_cluster = {}
	for item_guid, _ in pairs(source_items) do
		local item = reaper.BR_GetMediaItemByGUID(0, item_guid)
		if item then
			table.insert(table_of_items_in_selected_cluster, item)
		end
	end

	Deactivate_Items(table_of_items_in_selected_cluster)

	
	
	for _, item in ipairs(table_of_items_in_selected_cluster) do
		local track = reaper.GetMediaItemTrack(item)
		if track and reaper.GetMediaTrackInfo_Value(track, "I_FREEMODE") == 2 then
			local item_lane = math.floor(reaper.GetMediaItemInfo_Value(item, "I_FIXEDLANE"))
			local lane_still_active = false
			local item_count = reaper.CountTrackMediaItems(track)
			for j = 0, item_count - 1 do
				local other = reaper.GetTrackMediaItem(track, j)
				if other ~= item
					and math.floor(reaper.GetMediaItemInfo_Value(other, "I_FIXEDLANE")) == item_lane
					and reaper.GetMediaItemInfo_Value(other, "B_MUTE") == 0 then
					lane_still_active = true
					break
				end
			end
			if not lane_still_active then
				reaper.SetMediaItemInfo_Value(item, "C_LANEPLAYS", 0)
			end
		end
	end

	local commandID = reaper.NamedCommandLookup("_SWS_UNSELALL")
	reaper.Main_OnCommand(commandID, 0)

	for k, v in pairs(table_saved_selection) do
		reaper.SetMediaItemInfo_Value(v, "B_UISEL", 1)
	end

	reaper.MarkProjectDirty(0)
	reaper.UpdateArrange()
	reaper.PreventUIRefresh(-1)
	reaper.Undo_EndBlock("AMAPP: Activating Render Cluster", -1)
end