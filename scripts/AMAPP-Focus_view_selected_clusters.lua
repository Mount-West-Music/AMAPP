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
loadfile(mwm_lib_path .. "scripts/AMAPP-Get_selected_region_name.lua")()

reaper.ShowConsoleMsg("")
local function Msg(param)
	if param == nil then reaper.ShowConsoleMsg("") return end
    	reaper.ShowConsoleMsg(tostring(param) .. "\n")
end

local function Item_is_within_cluster(cluster, item_pos, item_len)
	local c_start, c_end = cluster.c_start, cluster.c_end
	if (item_pos < c_start and (item_pos + item_len) <= c_start) and (c_end <= item_pos) then
		return false
	else
		return true
	end
end

local function Activate_Take_From_Item(item_data, cluster, cluster_items)
	if reaper.GetMediaItemNumTakes(item_data.item) > 1 then
		local midi_note_off_will_be_sent = false
		if _itemProps == nil then return end
		local _cluster_item_take = item_data.item_props_table.item_take_guid
		for i = 0, reaper.GetMediaItemNumTakes(item_data) - 1 do
			local _take = reaper.GetTake(item_data, i)
			if _take == nil then goto continue end
			local _, item_take_guid = reaper.GetSetMediaItemTakeInfo_String(_take, "GUID", "", false)
			if tostring(item_take_guid) == _cluster_item_take then
				reaper.SetMediaItemInfo_Value(item_data, "I_CURTAKE", i)
				break
			end
			::continue::
		end
	end
end

local function Active_item_take_is_video(item)
	if item == nil then return false end
	local take = reaper.GetActiveTake(item)
	if take == nil then return false end
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

local function SoloItemsInCluster(cluster, cluster_items)
	if cluster_items == nil then return end
	local table_of_items_in_selected_cluster = {}
	reaper.Main_OnCommand(41185, 0) 
	if cluster_items[cluster.cluster_guid] == nil then goto next end
	for item_guid, item_props_table in pairs(cluster_items[cluster.cluster_guid]) do
		local item = reaper.BR_GetMediaItemByGUID(0, item_guid)
		if item == nil then goto continue end
		local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
		local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
		local is_within_region = Item_is_within_cluster(cluster, item_pos, item_len)
		if is_within_region then
			table.insert(table_of_items_in_selected_cluster, {
				item = item,
				item_guid = item_guid,
				item_props_table = item_props_table
			})
		end
		::continue::
	end
	::next::
	local commandID = reaper.NamedCommandLookup("_SWS_UNSELALL")
	reaper.Main_OnCommand(commandID, 0)
	for key, item_data in pairs(table_of_items_in_selected_cluster) do
		if Active_item_take_is_video(item_data.item) then goto skip end
		Activate_Take_From_Item(item_data, cluster, cluster_items)
		reaper.SetMediaItemInfo_Value(item_data.item, "B_UISEL", 1)
		::skip::
	end
	reaper.Main_OnCommand(41559, 0) 
end

local iterations = 0
local function Show_track_in_cluster(c, item)
	iterations = iterations + 1
	local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
	local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
	local is_within_region = Item_is_within_cluster(c, item_pos, item_len)
	if is_within_region then
		return true
	else
		return false
	end
end

local function Show_saved_tcp_track(track_guid, track_idx)
	local track = reaper.GetTrack(0, track_idx)
	local exisiting_track_guid = reaper.GetTrackGUID(track)
	if exisiting_track_guid ~= track_guid then
		local count_tracks = reaper.GetNumTracks()
		for i = 0, count_tracks - 1, 1 do
			local search_track = reaper.GetTrack(0, i)
			local search_track_guid = reaper.GetTrackGUID(search_track)
			if search_track_guid == track_guid then
				reaper.SetMediaTrackInfo_Value(search_track, "B_SHOWINTCP", 1)
				return
			end
		end
	end
	reaper.SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 1)
end

function Focus_view_selected_clusters(selected_clusters, solo_clusters_on_focus)
	reaper.Undo_BeginBlock()
	reaper.PreventUIRefresh(1)
	local previously_selected_items = reaper.CountSelectedMediaItems(0)
	local table_saved_selection = {}
	for i = 0, previously_selected_items - 1 do
		table.insert(table_saved_selection, reaper.GetSelectedMediaItem(0, i))
	end
	local tcp_state = {}
	local visible_tracks = {}

	local _, cluster_items_sTable = reaper.GetProjExtState(0, "AMAPP", "CLUSTER_ITEMS")
	if cluster_items_sTable == nil then return end
	local cluster_items = table.deserialize(cluster_items_sTable)
	if cluster_items == nil then cluster_items = {} end
	local filter_tracks = {}
	local count_tracks = reaper.GetNumTracks()
	for i = 0, count_tracks - 1, 1 do
		local track = reaper.GetTrack(0, i)
		local tr_guid = reaper.GetTrackGUID(track)
		tcp_state[tr_guid] = {}
		filter_tracks[tr_guid] = track
		tcp_state[tr_guid].visible = reaper.IsTrackVisible(track, false)
		tcp_state[tr_guid].collapsed_state = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT")
		if reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
			reaper.SetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT", 0)
		end
	end

	for _, cluster in pairs(selected_clusters) do
		if cluster_items[cluster.cluster_guid] == nil then goto next end
		for item_guid, item_props_table in pairs(cluster_items[cluster.cluster_guid]) do
			local item = reaper.BR_GetMediaItemByGUID(0, item_guid)
			if item == nil then goto skip end
			local track = reaper.GetMediaItemInfo_Value(item, "P_TRACK")
			if track == type("number") or track == nil then goto skip end
			local track_guid = reaper.GetTrackGUID(track)
			filter_tracks[track_guid] = nil
			Show_track_in_cluster(cluster, item)
			table.insert(visible_tracks, track)
			reaper.SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 1)
			::skip::
		end
		::next::
	end

	if solo_clusters_on_focus then
		reaper.Main_OnCommand(40345, 0) 
		for k, cluster in pairs(selected_clusters) do
			SoloItemsInCluster(cluster, cluster_items)
		end
	end
	reaper.SelectAllMediaItems(0, true)
	local commandID = reaper.NamedCommandLookup("_SWS_UNSELALL")

	for track_guid, track in pairs(filter_tracks) do
		reaper.SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
	end

	for key, track in pairs(visible_tracks) do
		local function SetParentTrackVisible (_track)
			local parent_track = reaper.GetParentTrack(_track)
			if parent_track == nil then
				return
			end
			reaper.SetMediaTrackInfo_Value(parent_track, "B_SHOWINTCP", 1)
			SetParentTrackVisible(parent_track)
		end
		SetParentTrackVisible(track)
	end

	reaper.Main_OnCommand(commandID, 0)
	for k, v in pairs(table_saved_selection) do
		reaper.SetMediaItemInfo_Value(v, "B_UISEL", 1)
	end
	if reaper.GetProjExtState(0, "AMAPP", "TCP_STATE") == 0 then
		local sTable = table.serialize(tcp_state)
		reaper.SetProjExtState(0, "AMAPP", "TCP_STATE", sTable)
	end
	if not solo_clusters_on_focus then
		reaper.Main_OnCommand(40340, 0) 
	end
	reaper.MarkProjectDirty(0)
	reaper.UpdateArrange()
	reaper.TrackList_AdjustWindows(false)
	if reaper.CountTracks(0) > 0 then
		reaper.SetOnlyTrackSelected(reaper.GetTrack(0,0))
	end
	reaper.Main_OnCommand(40913,0)
	reaper.Main_OnCommand(40297,0)
	reaper.PreventUIRefresh(-1)
	reaper.Undo_EndBlock("AMAPP: Focusing Render Cluster Tracks", -1)
end

function Unfocus_view_clusters()
	reaper.Undo_BeginBlock()
	reaper.PreventUIRefresh(1)
	if reaper.GetProjExtState(0, "AMAPP", "TCP_STATE") == nil then return end
	local top_most_track = reaper.GetSelectedTrack(0, 0)
	if top_most_track == nil then
		local count_tracks = reaper.GetNumTracks()
		for i = 0, count_tracks - 1, 1 do
			local track = reaper.GetTrack(0, i)
			if not reaper.IsTrackVisible(track, false) then goto next end
			top_most_track = track
			break
			::next::
		end
	end
	if top_most_track == nil then top_most_track = reaper.GetTrack(0, 0) end
	local _, tcp_visible_string = reaper.GetProjExtState(0, "AMAPP", "TCP_STATE")
	local tcp_state = table.deserialize(tcp_visible_string)
	if type(tcp_state) == "table" then
		for track_guid, props in pairs(tcp_state) do
			local track = reaper.BR_GetMediaTrackByGUID(0, track_guid)
			if props.visible then reaper.SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 1) end
			if props.collapsed_state ~= nil then reaper.SetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT", props.collapsed_state) end
			if props.solo_state ~= nil then reaper.SetMediaTrackInfo_Value(track, "I_SOLO", props.solo_state) end
		end
	end
	reaper.Main_OnCommand(40340, 0) 
	reaper.Main_OnCommand(41185, 0) 
	reaper.SetProjExtState(0, "AMAPP", "TCP_STATE", "")
	reaper.MarkProjectDirty(0)
	reaper.TrackList_AdjustWindows(false)
	if reaper.CountTracks(0) > 0 then
		reaper.SetOnlyTrackSelected(top_most_track)
	end
	reaper.Main_OnCommand(40913,0)
	reaper.Main_OnCommand(40297,0)
	reaper.PreventUIRefresh(-1)
	reaper.Undo_EndBlock("AMAPP: Restoring TCP view", -1)
end