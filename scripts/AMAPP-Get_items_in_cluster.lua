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

reaper.ShowConsoleMsg("")
local function Msg(param)
	if param == nil then reaper.ShowConsoleMsg("") return end
	reaper.ShowConsoleMsg(tostring(param) .. "\n")
end

local tracks_to_send_midi_note_off = {}


local function Check_if_track_should_get_midi_off(item)
	local play_pos = reaper.GetPlayPosition()
	local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
	local item_end = reaper.GetMediaItemInfo_Value(item, "D_LENGTH") + item_pos
	if (play_pos >= item_pos) and (play_pos <= item_end) then
		local current_track = reaper.GetMediaItemTrack(item)
		local track_number = reaper.GetMediaTrackInfo_Value(current_track, "IP_TRACKNUMBER")
		table.insert(tracks_to_send_midi_note_off, track_number)
		return true
	end
	return false
end

local function Send_Midi_Note_Off_To_Tracks(table_of_tracks)
	reaper.Main_OnCommand(40297, 0) 
	for k, v in pairs(tracks_to_send_midi_note_off) do
		local track = reaper.GetTrack(0, math.floor(v-1))
		if track == nil then goto next end
		reaper.SetMediaTrackInfo_Value(track, "I_SELECTED", 1)
		::next::
	end
	local commandID = reaper.NamedCommandLookup("_S&M_CC123_SEL_TRACKS") 
	reaper.Main_OnCommand(commandID, 0)
end

local function Activate_Take_From_Item(item, item_take_guid, selective_midi_note_off)
	if reaper.GetMediaItemNumTakes(item) > 1 then
		local midi_note_off_will_be_sent = false
		for i = 0, reaper.GetMediaItemNumTakes(item) - 1 do
			local _take = reaper.GetTake(item, i)
			if _take == nil then goto continue end
			local _, _take_guid = reaper.GetSetMediaItemTakeInfo_String(_take, "GUID", "", false)
			if item_take_guid == _take_guid then
				if selective_midi_note_off and not midi_note_off_will_be_sent then
					midi_note_off_will_be_sent = Check_if_track_should_get_midi_off()
				end
				reaper.SetMediaItemInfo_Value(item, "I_CURTAKE", i)
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

local function Item_is_within_region(cluster, item_pos, item_len)
	if cluster == nil then
		return
	end
	local c_start, c_end = cluster.c_start, cluster.c_end
	if (item_pos < c_start and (item_pos + item_len) <= c_start) or (c_end <= item_pos) then
		return false
	else
		return true
	end
end

local function Deactivate_Items(cluster, cluster_items_table, selective_midi_note_off)
	local count_items = reaper.CountMediaItems(0)
	for _i = 0, count_items - 1, 1 do
		local item = reaper.GetMediaItem(0, _i)
		if item == nil then goto skip end
		local _guid = reaper.GetSetMediaItemInfo_String(item, "GUID", "", false)
		if cluster_items_table[_guid] ~= nil then goto skip end
		local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
		local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
		local is_within_region = Item_is_within_region(cluster, item_pos, item_len)
		if is_within_region then
			if selective_midi_note_off then Check_if_track_should_get_midi_off(item) end
			reaper.SetMediaItemInfo_Value(item, "B_MUTE", 1)
		end
		::skip::
	end
end

local function Activate_Cluster_Items(cluster_items_table, cluster, selective_midi_note_off)
	local cluster_take_guid_table = {}
	local track_active_lanes = {} 
	for item_guid, items_props_table in pairs(cluster_items_table) do
		if items_props_table == nil then goto skip end
		if selective_midi_note_off then Check_if_track_should_get_midi_off(item) end
		local item = reaper.BR_GetMediaItemByGUID(0, item_guid)
		if item == nil then goto skip end
		reaper.SetMediaItemInfo_Value(item, "B_MUTE", 0)
		local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
		local take_count = reaper.CountTakes(item)
		local i = 0
		local root_take
		while i < take_count and root_take == nil do
			root_take = reaper.GetMediaItemTake(item, i)
			i = i + 1
		end
		local r, take_guid = reaper.GetSetMediaItemTakeInfo_String(root_take, "GUID", "", false)
		table.insert(cluster_take_guid_table, {take_guid = take_guid, item_pos = item_pos})
		if items_props_table.item_take_guid ~= nil then
			Activate_Take_From_Item(item, items_props_table.item_take_guid, selective_midi_note_off)
		end
		
		local track = reaper.GetMediaItemTrack(item)
		if track and reaper.GetMediaTrackInfo_Value(track, "I_FREEMODE") == 2 then
			reaper.SetMediaItemInfo_Value(item, "C_LANEPLAYS", 2)
			if not track_active_lanes[track] then
				track_active_lanes[track] = true
			end
		end
		::skip::
	end
	
	
	
	
	
	
	for track, _ in pairs(track_active_lanes) do
		reaper.SetMediaTrackInfo_Value(track, "C_ALLLANESPLAY", 2)
	end
	return cluster_take_guid_table
end

local function Iterate_Automation_Items(cluster_id, track_env, count_sel_auto_items, region_index, suspend_deactivation)
	local table_of_selected_autoitems = {}
	for autoitem_idx = 0, count_sel_auto_items - 1, 1 do
		local retval, stringTable = reaper.GetSetAutomationItemInfo_String(track_env, autoitem_idx, "P_POOL_NAME", "", false)
		if not retval then goto continue end
		local cluster_table = table.deserialize(stringTable)
		if cluster_table == nil then goto continue end
		for k, v in pairs(cluster_table) do
			if not v.cluster_id == cluster_id then goto next end
			local item_pos	= reaper.GetSetAutomationItemInfo(track_env, autoitem_idx, "D_POSITION", 0, false)
			local item_len	= reaper.GetSetAutomationItemInfo(track_env, autoitem_idx, "D_LENGTH", 0, false)
			local is_within_region = Item_is_within_region(item_pos, item_len, region_index)
			if not is_within_region then goto next end
			local sel = reaper.GetSetAutomationItemInfo(track_env, autoitem_idx, "D_UISEL", 0, false)
			if not sel == 0 then table.insert(table_of_selected_autoitems, {track_env = track_env, autoitem_idx = autoitem_idx}) end

			::next::
		end
		::continue::
	end
end

local function Activate_Automation_Items(cluster_id, region_index, suspend_deactivation)
	local count_tracks = reaper.CountTracks(0)
	for track_idx = 0, count_tracks - 1, 1 do
		local track = reaper.GetTrack(0, track_idx)
		local count_track_env = reaper.CountTrackEnvelopes(track)
		if count_track_env < 1 then goto continue end
		for env_idx = 0, count_track_env - 1, 1 do
			local track_env = reaper.GetTrackEnvelope(track, env_idx)
			local count_sel_auto_items = reaper.CountAutomationItems(track_env)
			Iterate_Automation_Items(cluster_id, track_env, count_sel_auto_items, region_index, suspend_deactivation)
		end
		::continue::
	end
end







function Reset_fixed_lane_states()
	for i = 0, reaper.CountTracks(0) - 1 do
		local track = reaper.GetTrack(0, i)
		if reaper.GetMediaTrackInfo_Value(track, "I_FREEMODE") == 2 then
			reaper.SetMediaTrackInfo_Value(track, "C_ALLLANESPLAY", 0)
			local item_count = reaper.CountTrackMediaItems(track)
			for j = 0, item_count - 1 do
				local item = reaper.GetTrackMediaItem(track, j)
				reaper.SetMediaItemInfo_Value(item, "C_LANEPLAYS", 0)
			end
		end
	end
end


function Get_items_in_cluster(cluster, _suspendDeactivateItems, selective_midi_note_off)
	local _, _sTable = reaper.GetProjExtState(0, "AMAPP", "CLUSTER_ITEMS")
	if _sTable == nil then
		return false, {}
	end
	local cluster_items_table = table.deserialize(_sTable)
	if cluster_items_table == nil then return false, {} end

	cluster_items_table = cluster_items_table[cluster.cluster_guid]
	if cluster_items_table == nil then return false, {} end

	_suspendDeactivateItems = _suspendDeactivateItems or false
	reaper.Undo_BeginBlock()
	reaper.PreventUIRefresh(1)
	if not selective_midi_note_off then
		reaper.Main_OnCommand(40345, 0) 
	end
	tracks_to_send_midi_note_off = {}
	local _, cluster_table_string = reaper.GetProjExtState(0, "AMAPP", "CLUSTER_TABLE")
	local cluster_table = table.deserialize(cluster_table_string)

	if cluster_table == nil then cluster_table = {} end
	if cluster.c_start == nil or cluster.c_end == nil then
		for k, v in pairs(cluster_table) do
			if tostring(v.cluster_guid) == cluster.cluster_guid then
				cluster.c_start = v.c_start
				cluster.c_end = v.c_end
				break
			end
		end
	end

	local previously_selected_items = reaper.CountSelectedMediaItems(0)
	local table_saved_selection = {}
	for i = 0, previously_selected_items - 1 do
		table.insert(table_saved_selection, reaper.GetSelectedMediaItem(0, i))
	end

	if _suspendDeactivateItems == false or _suspendDeactivateItems == nil then Deactivate_Items(cluster, cluster_items_table, selective_midi_note_off) end
	local clusterItem_guid_table = Activate_Cluster_Items(cluster_items_table, cluster, selective_midi_note_off)
	if selective_midi_note_off then Send_Midi_Note_Off_To_Tracks(tracks_to_send_midi_note_off) end
	

	for k, v in pairs(table_saved_selection) do
		reaper.SetMediaItemInfo_Value(v, "B_UISEL", 1)
	end

	reaper.MarkProjectDirty(0)
	reaper.UpdateArrange()
	reaper.PreventUIRefresh(-1)
	reaper.Undo_EndBlock("AMAPP: Activating Render Cluster", -1)
	return true, clusterItem_guid_table
end