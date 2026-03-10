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
	if param == nil then reaper.ShowConsoleMsg("") return end
  	reaper.ShowConsoleMsg(tostring(param).."\n")
end

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
    function Remove_items_in_cluster(cluster)
        if not cluster then return end
        local guid = cluster.cluster_guid or cluster.guid
        if not guid then return end
        reaper.AMAPP_Cluster_DisassociateSelectedItems(guid)
    end
    
    local loader = loadfile(mwm_lib_path .. "scripts/AMAPP-Get_items_in_cluster.lua")
    if loader then loader() end
else
    
    loadfile(mwm_lib_path .. "scripts/AMAPP-Set_items_in_cluster.lua")()
    loadfile(mwm_lib_path .. "scripts/AMAPP-Get_items_in_cluster.lua")()
    loadfile(mwm_lib_path .. "scripts/AMAPP-Remove_items_in_cluster.lua")()
end

loadfile(mwm_lib_path .. "scripts/AMAPP-Get_selected_region_name.lua")()
loadfile(mwm_lib_path .. "scripts/AMAPP-Create_new_render_cluster.lua")()
loadfile(mwm_lib_path .. "util/MWM-Render_config.lua")()
local Json = dofile(mwm_lib_path .. "util/json/json.lua")


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


local AMAPP_Render_API = {
	available = reaper.AMAPP_Render_GetVersion ~= nil,
}


local function BuildItemCacheIfAvailable()
	if AMAPP_Render_API.available then
		reaper.AMAPP_Render_BuildItemCache()
	end
end

local function InvalidateItemCacheIfAvailable()
	if AMAPP_Render_API.available then
		reaper.AMAPP_Render_InvalidateItemCache()
	end
end





local CacheRegionRenderMatrixOptimized
local RestoreRegionRenderMatrixOptimized
local ClearRenderMatrixOptimized
local AddRegionsToMatrixOptimized


CacheRegionRenderMatrixOptimized = function()
	if AMAPP_Render_API.available then
		return reaper.AMAPP_Render_CacheRegionMatrix(), true
	end
	
	return nil, false
end

RestoreRegionRenderMatrixOptimized = function(cache, used_cpp)
	if used_cpp and AMAPP_Render_API.available then
		reaper.AMAPP_Render_RestoreRegionMatrix(cache)
	end
end

ClearRenderMatrixOptimized = function()
	if AMAPP_Render_API.available then
		reaper.AMAPP_Render_ClearMatrix()
	end
	
end

AddRegionsToMatrixOptimized = function(region_guids)
	if AMAPP_Render_API.available then
		local json = '["' .. table.concat(region_guids, '","') .. '"]'
		reaper.AMAPP_Render_AddRegions(json)
	end
	
end


local function File_path_is_absolute(path)
    if package.config:sub(1, 1) == "\\" then
        
        return path:match("^%a:[\\/]")
            or path:match("^\\\\")
    else
        
        return path:sub(1, 1) == "/"
    end
end


function Find_and_replace_wildcards(cluster_id, region_idx, user_template_string)
	local table_of_wildcards = {
		{str = "$projectdir", ret_val = function()
			local project_path = select(2,reaper.EnumProjects(-1)):match("^(.+[\\/])")
			local value = ""
			value = string.gsub(project_path, string.char(92), string.char(47))
			local prune_from = value:match(".*()/") - 1
			local pruned_path = string.sub(value, 1, prune_from)
			local remove_from = pruned_path:match(".*()/") + 1
			local project_dir_name = string.sub(pruned_path, remove_from)
			return project_dir_name
		end},
		{str = "$project", ret_val = function()
			local _, value = reaper.GetSetProjectInfo_String(0, "PROJECT_NAME", "", false)
			local h = {}
			h[1] = value:match("(.+)%..+$")
			return h[1]
		end},
		{str = "$title", ret_val = function()
			local _, value = reaper.GetSetProjectInfo_String(0, "PROJECT_TITLE", "", false)
			return value
		end},
		{str = "$author", ret_val = function()
			local _, value = reaper.GetSetProjectInfo_String(0, "PROJECT_AUTHOR", "", false)
			return value
		end},
		{str = "$notes", ret_val = function()
			return reaper.GetSetProjectNotes(0, false, "")
		end},
		{str = "$regionnumber", ret_val = function() return region_idx or "" end},
		{str = "$region", ret_val = function() return cluster_id end},
		{str = "$cluster", ret_val = function() return cluster_id end},
		{str = "$date", ret_val = function()
			return os.date("%Y-%m-%d")
		end},
		{str = "$tempo", ret_val = function()
			local bpm, bpi = reaper.GetProjectTimeSignature2(0)
			return bpm
		end},
		{str = "$timesignature", ret_val = function()
			local bpm, bpi = reaper.GetProjectTimeSignature2(0)
			return bpi
		end},
	}
	local modified_filename = user_template_string
	for k, wildcard in pairs(table_of_wildcards) do
		if wildcard.ret_val() ~= nil then
			modified_filename = modified_filename:gsub(wildcard.str, wildcard.ret_val())
		end
	end
	return modified_filename
end

local function CreateTemporaryRenderRegion(cluster)
	local cluster_id, StartTimeSel, EndTimeSel, cluster_color = cluster.cluster_id, cluster.c_start, cluster.c_end, cluster.cluster_color
	local region_guid = nil
	reaper.Main_OnCommand(40898, 0) 
	reaper.UpdateTimeline()
	local count_markers = reaper.CountProjectMarkers(0)
	
	local _newMarkerIndexNumber = reaper.AddProjectMarker2(0, true, StartTimeSel, EndTimeSel, cluster_id, count_markers, cluster_color|0x1000000)
	if _newMarkerIndexNumber == -1 then
		reaper.MB("A new region could not be created!"
		, "Something went wrong!", 0)
		return
	end
	
	local num_total = reaper.CountProjectMarkers(0)
	local enum_idx = nil
	for i = 0, num_total - 1 do
		local _, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers2(0, i)
		if isrgn and markrgnindexnumber == _newMarkerIndexNumber then
			enum_idx = i
			break
		end
	end
	if enum_idx == nil then
				return nil
	end
	
	_, region_guid = reaper.GetSetProjectInfo_String(0, "MARKER_GUID:" .. tostring(enum_idx), "", false)
	if region_guid == nil or region_guid == "" then
				return nil
	end
	
	local _, isrgn, pos, rgnend, name, IDnumber, color = reaper.EnumProjectMarkers3(0, enum_idx)
	reaper.SetProjectMarker3(0, IDnumber, isrgn, pos, rgnend, name, cluster_color + 0x1000000)
	reaper.SetProjectMarkerByIndex2(0, enum_idx, isrgn, pos, rgnend, IDnumber, name, cluster_color + 0x1000000, 2)
	return region_guid
end

local function Remove_existing_render_files(file_path)
	local string_sub_slash = string.gsub(file_path, string.char(92), string.char(47))
	if string_sub_slash ~= nil and reaper.file_exists(string_sub_slash)==true then
		local suc, e_msg = os.remove(string_sub_slash)
		if suc == false then Error_Message("Could not remove existing assets", "Something went wrong: " .. e_msg, -15) return -1 end
		if reaper.file_exists(string_sub_slash)==true then Error_Message("RenderProject", "renderfilename_with_path", "Couldn't delete file. It's probably still in use.", -14) return -1 end
	end
end

local function ValidationError()
	local retval, errcode, functionname, parmname, errormessage, lastreadtime, err_creation_date, err_creation_timestamp, errorcounter, context_function, context_sourcefile --[ , context_sourceline = ultraschall.GetLastErrorMessage() ]--
		assert(IsValidRenderTable(RenderTable), "RenderTable is not valid")
end

local function CreateStandardRenderTableWithLoopTrueOrFalse(file_path, export_options, isLoop)
	
	local render_cfg_string_primary
	local primary_format = export_options.primary_output_format.format or "WAV"

	if primary_format == "WAV" then
		
		local BitDepth = export_options.primary_output_format.bit_depth or 2  
		local LargeFiles, BWFChunk, IncludeMarkers, EmbedProjectTempo = 0, 1, 0, false
		render_cfg_string_primary = CreateRenderCFG_WAV(BitDepth, LargeFiles, BWFChunk, IncludeMarkers, EmbedProjectTempo)
	elseif primary_format == "FLAC" then
		local BitDepth = export_options.primary_output_format.flac_bit_depth or 1  
		local Compression = export_options.primary_output_format.flac_compression or 5  
		render_cfg_string_primary = CreateRenderCFG_FLAC(BitDepth, Compression)
	elseif primary_format == "OGG" then
		
		local Mode = 0  
		local VBR_Quality = export_options.primary_output_format.ogg_quality or 1.0
		local CBR_KBPS, ABR_KBPS, ABR_KBPS_MIN, ABR_KBPS_MAX = 1, 1, 1, 1
		render_cfg_string_primary = CreateRenderCFG_OGG(Mode, VBR_Quality, CBR_KBPS, ABR_KBPS, ABR_KBPS_MIN, ABR_KBPS_MAX)
	else
		
		local BitDepth, LargeFiles, BWFChunk, IncludeMarkers, EmbedProjectTempo = 2, 0, 1, 0, false
		render_cfg_string_primary = CreateRenderCFG_WAV(BitDepth, LargeFiles, BWFChunk, IncludeMarkers, EmbedProjectTempo)
	end

	local render_cfg_string_OGG
	if export_options.export_secondary then
		
		local Mode, VBR_Quality, CBR_KBPS, ABR_KBPS, ABR_KBPS_MIN, ABR_KBPS_MAX = 0, 1, 1, 1, 1, 1
		render_cfg_string_OGG = CreateRenderCFG_OGG(Mode, VBR_Quality, CBR_KBPS, ABR_KBPS, ABR_KBPS_MIN, ABR_KBPS_MAX)
	else
		render_cfg_string_OGG = ""
	end

	local sample_rate = tonumber(export_options.primary_output_format.sample_rate)
	local tail_flag = 0x000000000
	if export_options.tail_enabled then
		tail_flag = 0x111111111
	end

	
	local Source, Bounds, Startposition, Endposition, TailFlag, TailMS = 8, 5, 0, 0, tail_flag, export_options.tail_ms or 0
	local RenderFile, RenderPattern, SampleRate = file_path, export_options.export_file_name, sample_rate
	local Channels, OfflineOnlineRendering = export_options.channels or 2, 0
	local ProjectSampleRateFXProcessing, RenderResample, OnlyMonoMedia, MultiChannelFiles = true, 3, false, false
	local Dither, RenderString, SilentlyIncrementFilename, AddToProj = 0, render_cfg_string_primary, not export_options.overwrite_existing, false
	local SaveCopyOfProject, RenderQueueDelay, RenderQueueDelaySeconds = false, false, 0
	local CloseAfterRender, EmbedStretchMarkers, RenderString2 = export_options.close_after_render, false, render_cfg_string_OGG
	local EmbedTakeMarkers, DoNotSilentRender, EmbedMetadata = false, false, false
	local Enable2ndPassRender, Normalize_Enabled, Normalize_Method = isLoop, false, 0
	local Normalize_Stems_to_Master_Target, Normalize_Target = false, 0
	local Brickwall_Limiter_Enabled, Brickwall_Limiter_Method =  false, 0
	local Brickwall_Limiter_Target, Normalize_Only_Files_Too_Loud = 0, false
	local FadeIn_Enabled, FadeIn, FadeIn_Shape, FadeOut_Enabled, FadeOut, FadeOut_Shape = false, 0, 0, false, 0, 0
	local OnlyChannelsSentToParent, RenderStems_Prefader = false, false

	local RenderTable = CreateNewRenderTable(
		Source, Bounds, Startposition, Endposition, TailFlag, TailMS,
		RenderFile, RenderPattern, SampleRate, Channels, OfflineOnlineRendering,
		ProjectSampleRateFXProcessing, RenderResample, OnlyMonoMedia, MultiChannelFiles,
		Dither, RenderString, SilentlyIncrementFilename, AddToProj,
		SaveCopyOfProject, RenderQueueDelay, RenderQueueDelaySeconds,
		CloseAfterRender, EmbedStretchMarkers, RenderString2,
		EmbedTakeMarkers, DoNotSilentRender, EmbedMetadata,
		Enable2ndPassRender, Normalize_Enabled, Normalize_Method,
		Normalize_Stems_to_Master_Target, Normalize_Target,
		Brickwall_Limiter_Enabled, Brickwall_Limiter_Method, Brickwall_Limiter_Target, Normalize_Only_Files_Too_Loud,
		FadeIn_Enabled, FadeIn, FadeIn_Shape, FadeOut_Enabled, FadeOut, FadeOut_Shape,
		OnlyChannelsSentToParent, RenderStems_Prefader
	)
	if not IsValidRenderTable(RenderTable) then ValidationError() end

	local preset_name = "AMAPP Render Cluster - Loop"
	if not isLoop then	preset_name = "AMAPP Render Cluster - OneShot" end
	return RenderTable, preset_name
end

local function SelectAttachedRegionInMatrix(region_guid)
	if region_guid == nil then return false end
	local num_total = reaper.CountProjectMarkers(0)
	local masterTrack = reaper.GetMasterTrack(0)
	local i = 0
	while i < num_total do
		local retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers2(0, i)
		if isrgn then
			reaper.SetRegionRenderMatrix(0, markrgnindexnumber, masterTrack, -1)
		end
		i = i + 1
	end
	local retval, region_id_number = reaper.GetSetProjectInfo_String(0, "MARKER_INDEX_FROM_GUID:" .. region_guid, "", false)
	if retval == false then return end
	local _id_number = tonumber(region_id_number)
	if _id_number == nil then return end
	local _, _, _, _, name, markrgnindexnumber = reaper.EnumProjectMarkers2(0, _id_number)
	
	
	reaper.SetRegionRenderMatrix(0, markrgnindexnumber, masterTrack, 1)
end





local function ClustersOverlap(cluster1, cluster2)
	local start1 = cluster1.c_start or 0
	local end1 = cluster1.c_end or start1
	local start2 = cluster2.c_start or 0
	local end2 = cluster2.c_end or start2
	
	return start1 < end2 and end1 > start2
end







function GroupClustersIntoBatches(queue)
	local sorted_queue = {}
	for _, item in ipairs(queue) do
		table.insert(sorted_queue, item)
	end
	table.sort(sorted_queue, function(a, b)
		return (a.cluster.c_start or 0) < (b.cluster.c_start or 0)
	end)

	local batches = {}

	for _, item in ipairs(sorted_queue) do
		local cluster = item.cluster
		local placed = false

		for _, batch in ipairs(batches) do
			local can_add = true
			for _, batch_item in ipairs(batch) do
				if ClustersOverlap(cluster, batch_item.cluster) then
					can_add = false
					break
				end
			end
			if can_add then
				table.insert(batch, item)
				placed = true
				break
			end
		end

		if not placed then
			table.insert(batches, {item})
		end
	end

	
	
	
	
	
	
	
	batches = SplitBatchesOnItemConflicts(batches)

	return batches
end




local function LoadClusterItemAssignments()
	local _, _sTable = reaper.GetProjExtState(0, "AMAPP", "CLUSTER_ITEMS")
	if not _sTable or _sTable == "" then return {} end
	local all_cluster_items = table.deserialize(_sTable)
	return all_cluster_items or {}
end




local function GetClusterItemExtents(cluster_guid, all_cluster_items)
	local items = all_cluster_items[cluster_guid]
	if not items then return {} end
	local extents = {}
	for item_guid, _ in pairs(items) do
		local item = reaper.BR_GetMediaItemByGUID(0, item_guid)
		if item then
			local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
			local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
			table.insert(extents, {guid = item_guid, pos = pos, end_pos = pos + len})
		end
	end
	return extents
end







local function ClustersHaveItemConflict(item_a, item_b, all_cluster_items)
	local cluster_a = item_a.cluster
	local cluster_b = item_b.cluster

	local b_start = cluster_b.c_start or 0
	local b_end = cluster_b.c_end or b_start
	local a_start = cluster_a.c_start or 0
	local a_end = cluster_a.c_end or a_start

	local items_b_set = all_cluster_items[cluster_b.cluster_guid] or {}
	local items_a_set = all_cluster_items[cluster_a.cluster_guid] or {}

	local extents_a = GetClusterItemExtents(cluster_a.cluster_guid, all_cluster_items)
	local extents_b = GetClusterItemExtents(cluster_b.cluster_guid, all_cluster_items)

	
	for _, ext in ipairs(extents_a) do
		if ext.pos < b_end and ext.end_pos > b_start then
			if not items_b_set[ext.guid] then
				return true
			end
		end
	end

	
	for _, ext in ipairs(extents_b) do
		if ext.pos < a_end and ext.end_pos > a_start then
			if not items_a_set[ext.guid] then
				return true
			end
		end
	end

	return false
end





function SplitBatchesOnItemConflicts(batches)
	local all_cluster_items = LoadClusterItemAssignments()
	if not next(all_cluster_items) then return batches end

	
	local all_items = {}
	for _, batch in ipairs(batches) do
		for _, item in ipairs(batch) do
			table.insert(all_items, item)
		end
	end

	local new_batches = {}

	for _, item in ipairs(all_items) do
		local cluster = item.cluster
		local placed = false

		for _, batch in ipairs(new_batches) do
			local can_add = true
			for _, batch_item in ipairs(batch) do
				if ClustersOverlap(cluster, batch_item.cluster)
					or ClustersHaveItemConflict(item, batch_item, all_cluster_items) then
					can_add = false
					break
				end
			end
			if can_add then
				table.insert(batch, item)
				placed = true
				break
			end
		end

		if not placed then
			table.insert(new_batches, {item})
		end
	end

	return new_batches
end





local function ClearRenderMatrix()
	local num_total = reaper.CountProjectMarkers(0)
	local masterTrack = reaper.GetMasterTrack(0)
	for i = 0, num_total - 1 do
		local _, isrgn, _, _, _, markrgnindexnumber = reaper.EnumProjectMarkers2(0, i)
		if isrgn then
			reaper.SetRegionRenderMatrix(0, markrgnindexnumber, masterTrack, -1)
		end
	end
end





local function AddRegionsToMatrix(region_guids)
	local masterTrack = reaper.GetMasterTrack(0)
	for _, guid in ipairs(region_guids) do
		local retval, region_id_number = reaper.GetSetProjectInfo_String(0, "MARKER_INDEX_FROM_GUID:" .. guid, "", false)
		if retval then
			local _id_number = tonumber(region_id_number)
			if _id_number then
				local _, _, _, _, _, markrgnindexnumber = reaper.EnumProjectMarkers2(0, _id_number)
				reaper.SetRegionRenderMatrix(0, markrgnindexnumber, masterTrack, 1)
			end
		end
	end
end





local function ValidateProjectHasBeenSaved()
	local proj_dir = select(2,reaper.EnumProjects(-1)):match("^(.+[\\/])")
	return proj_dir ~= nil
end






local function CacheRegionRenderMatrix()
	local cache = {}
	local _, _, region_count = reaper.CountProjectMarkers(0)
	if region_count == nil then return cache end
	local k = 0
	while k < region_count + 1 do
		k = k + 1
		table.insert(cache, {region_idx = k, tracks = {}})
		local i = 0
		local mediatrack = reaper.EnumRegionRenderMatrix(0, k, i)
		if mediatrack == nil then goto next end
		local track_idx = reaper.GetMediaTrackInfo_Value(mediatrack, "IP_TRACKNUMBER")
		table.insert(cache[k].tracks, track_idx)
		while mediatrack ~= nil do
			reaper.SetRegionRenderMatrix(0, k, mediatrack, -1)
			mediatrack = reaper.EnumRegionRenderMatrix(0, k, 0)
			if mediatrack == nil then break end
			track_idx = reaper.GetMediaTrackInfo_Value(mediatrack, "IP_TRACKNUMBER")
			table.insert(cache[k].tracks, track_idx)
		end
		::next::
	end
	return cache
end


if not AMAPP_Render_API.available then
	CacheRegionRenderMatrixOptimized = function()
		return CacheRegionRenderMatrix(), false
	end
	ClearRenderMatrixOptimized = function()
		ClearRenderMatrix()
	end
	AddRegionsToMatrixOptimized = function(region_guids)
		AddRegionsToMatrix(region_guids)
	end
end

local function SoloItemsInCluster(cluster)
	local table_of_items_in_selected_cluster = {}
	local table_of_non_existing_items_in_selected_cluster = {}
	local all_items = reaper.SelectAllMediaItems(0, true)
	local count_sel_items = reaper.CountMediaItems(0)
	reaper.Main_OnCommand(41185, 0) 
	for _i = 0, count_sel_items - 1, 1 do
		local item = reaper.GetSelectedMediaItem(0, _i)
		local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
		local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
		local is_within_region = Item_is_within_cluster(cluster, item_pos, item_len)
		if is_within_region then
			local _, stringTable = reaper.GetSetMediaItemInfo_String(item, "P_EXT:AMAPP", "", false)
			local connected_clusters_in_item = parse_item_ext(stringTable)
			if connected_clusters_in_item == nil then
				table.insert(table_of_non_existing_items_in_selected_cluster, item)
				goto continue
			end
			local _exists_in_cluster = false
			for k, v in pairs(connected_clusters_in_item) do
				if type(v) == "table" and v.cluster_guid == cluster.cluster_guid then
					table.insert(table_of_items_in_selected_cluster, item)
					_exists_in_cluster = true
				end
			end
			if _exists_in_cluster == false then
				table.insert(table_of_non_existing_items_in_selected_cluster, item)
			end
		end
		::continue::
	end
	local commandID = reaper.NamedCommandLookup("_SWS_UNSELALL")
	reaper.Main_OnCommand(commandID, 0)
	for key, item in pairs(table_of_items_in_selected_cluster) do
		if Active_item_take_is_video(item) then goto skip end
		Activate_Take_From_Item(item, cluster)
		reaper.SetMediaItemInfo_Value(item, "B_UISEL", 1)
		::skip::
	end
	reaper.Main_OnCommand(41559, 0) 
end

function RenderClusters(_selectedClusters, focus_and_solo, focused_clusters, progress_callback)
	focus_and_solo = focus_and_solo or false
	reaper.PreventUIRefresh(1)
	if ValidateProjectHasBeenSaved() == false then
		return reaper.MB("Project has not been saved!\n\nThe Reaper project needs to be saved before the AMAPP can start rendering. Please save your project!", "IMPORTANT!", 0)
	end
	reaper.Main_OnCommand(40898, 0) 
	local region_render_matrix_cache = CacheRegionRenderMatrix()
	local tab_visible = reaper.GetToggleCommandState(42072)
	local master_track = reaper.GetMasterTrack()
	local master_track_fx_count = reaper.TrackFX_GetRecCount(master_track)
	if tab_visible == 1 and master_track_fx_count == 0 then
		reaper.Main_OnCommand(42072, 0) 
	end
	
	
	
	
	
	local fx_index = reaper.TrackFX_AddByName(master_track, "Container", true, -1)
	reaper.TrackFX_SetPinMappings(master_track, fx_index+0x1000000, 0x0000000, 0x0000001, 0x0000000, 0x0000000)
	reaper.TrackFX_SetPinMappings(master_track, fx_index+0x1000000, 0x0000000, 0x0000000, 0x0000000, 0x0000000)
	reaper.TrackFX_SetNamedConfigParm(master_track, fx_index+0x1000000, "renamed_name", "Mute Monitor Out While Render")

	local return_value, export_options_string = reaper.GetProjExtState(0, "AMAPP", "EXPORT_OPTIONS")
	if return_value == 0 then
		return reaper.MB("No export options have been set. Please set export options inside AMAPP.", "Error!", 0)
	end
	local export_options = table.deserialize(export_options_string)
	if export_options == nil then
		return reaper.MB("No export options have been set. Please set export options inside AMAPP.", "Error!", 0)
	end
	local render_file_name_def = string.gsub(export_options.export_file_name or "$cluster", "$cluster", "$region")
	if render_file_name_def == nil or render_file_name_def == "" then
		render_file_name_def = "$region"
	end
	export_options.export_file_name = render_file_name_def
	local render_file_path = export_options.file_path
	render_file_path = Find_and_replace_wildcards("", nil, render_file_path)
	local project_render_folder_path
	if File_path_is_absolute(render_file_path) then
		project_render_folder_path = render_file_path
	else
		local proj_dir = select(2,reaper.EnumProjects(-1)):match("^(.+[\\/])")
		project_render_folder_path = proj_dir .. render_file_path
	end
	
	if not project_render_folder_path:match("[\\/]$") then
		project_render_folder_path = project_render_folder_path .. "/"
	end

	if io.open(reaper.GetResourcePath() .. "/reaper-render.ini", "r") == nil then
		local new_ini = io.open(reaper.GetResourcePath() .. "/reaper-render.ini", "w+")
		if new_ini ~= nil then new_ini:close() end
	end
	local bounds_presets, bounds_names, options_format_presets, options_format_names, both_presets, both_names = GetRenderPreset_Names()
	local loop_preset_exists, oneshot_preset_exists = false, false
	if both_names == nil then both_names = {} end
	for i, preset_name in pairs(both_names) do
		if preset_name == "AMAPP Render Cluster - Loop" then
			local retval = DeleteRenderPreset_Both(preset_name)
		elseif preset_name == "AMAPP Render Cluster - OneShot" then
			local retval = DeleteRenderPreset_Both(preset_name)
		end
	end
	
	
	
	
	
	
	
	
	
	
	local loops, open_loops, oneShots = {}, {}, {}
	for key, value in pairs(_selectedClusters) do
		if value.children then goto continue end
		if value.is_loop and (value.c_entry ~= nil) and (value.c_exit ~= nil) and (value.c_start < value.c_entry or value.c_end > value.c_exit) then
			table.insert(open_loops, value)
		elseif value.is_loop then
			table.insert(loops, value)
		else
			table.insert(oneShots, value)
		end
		::continue::
	end
	local table_of_item_state = {}
	local table_of_track_lane_state = {}
	if focus_is_activated then Unfocus_view_clusters() end
	for i = 0, reaper.CountMediaItems() - 1, 1 do
		local _item = reaper.GetMediaItem(0, i)
		table.insert(table_of_item_state, {item = _item, state = reaper.GetMediaItemInfo_Value(_item, "B_MUTE")})
	end
	for i = 0, reaper.CountTracks(0) - 1 do
		local track = reaper.GetTrack(0, i)
		if reaper.GetMediaTrackInfo_Value(track, "I_FREEMODE") == 2 then
			local num_lanes = reaper.GetMediaTrackInfo_Value(track, "I_NUMFIXEDLANES")
			local lane_states = {}
			for lane = 0, num_lanes - 1 do
				lane_states[lane] = reaper.GetMediaTrackInfo_Value(track, "C_LANEPLAYS:" .. lane)
			end
			table.insert(table_of_track_lane_state, {
				track = track,
				alllanesplay = reaper.GetMediaTrackInfo_Value(track, "C_ALLLANESPLAY"),
				lane_states = lane_states
			})
		end
	end
	
	local srate = export_options.primary_output_format.sample_rate or 48000
	reaper.GetSetProjectInfo(0, "RENDER_SRATE", srate, true)
	if not export_options.export_secondary then
		reaper.GetSetProjectInfo_String(0, "RENDER_FORMAT2", "", true)
	end
	
	
	
	
	
	
	
	local overall_cluster_index = 0

	if #oneShots > 0 then
		local RenderTable = CreateStandardRenderTableWithLoopTrueOrFalse(render_file_path, export_options, false)
		ApplyRenderTable_Project(RenderTable)
		for i, cluster in pairs(oneShots) do
			overall_cluster_index = overall_cluster_index + 1
			if progress_callback then
				progress_callback(overall_cluster_index, cluster, "oneshot")
			end
			Get_items_in_cluster(cluster)
			local _regionIndex = -1
			local retval
			local region_guid
			if cluster.region_guid then
				retval, _ = reaper.GetSetProjectInfo_String(0, "MARKER_INDEX_FROM_GUID:" .. cluster.region_guid, "", false)
			end
			if retval then
				region_guid = cluster.region_guid
			else
				region_guid = CreateTemporaryRenderRegion(cluster)
			end
			if region_guid == nil then
				Msg("Warning: Could not create region for cluster '" .. (cluster.cluster_id or "unknown") .. "', skipping render")
			else
				SelectAttachedRegionInMatrix(region_guid)
				local modified_filename = Find_and_replace_wildcards(cluster.cluster_id, _regionIndex, export_options.export_file_name)
				if export_options.overwrite_existing then
					local primary_format = export_options.primary_output_format and export_options.primary_output_format.format or "WAV"
					local primary_ext = primary_format == "FLAC" and ".flac" or (primary_format == "OGG" and ".ogg" or ".wav")
					local path_name_check_primary = project_render_folder_path .. modified_filename .. primary_ext
					Remove_existing_render_files(path_name_check_primary)
					if export_options.export_secondary then
						local path_name_check_OGG = project_render_folder_path .. modified_filename .. ".ogg"
						Remove_existing_render_files(path_name_check_OGG)
					end
				end
				reaper.Main_OnCommand(41824, 0) 
				if not retval then
					local r, enum_idx_str = reaper.GetSetProjectInfo_String(0, "MARKER_INDEX_FROM_GUID:" .. region_guid, "", false)
					if r == false then goto skip end
					local enum_idx = tonumber(enum_idx_str)
					if enum_idx == nil then goto skip end
					reaper.DeleteProjectMarkerByIndex(0, enum_idx)
					reaper.Main_OnCommand(40898, 0) 
					::skip::
				end
			end
			if gfx.getchar() == 27 then goto abort_render end
		end
	end
	if #open_loops > 0 then
		local RenderTable = CreateStandardRenderTableWithLoopTrueOrFalse(render_file_path, export_options, false)
		ApplyRenderTable_Project(RenderTable)
		for i, cluster in pairs(open_loops) do
			overall_cluster_index = overall_cluster_index + 1
			if progress_callback then
				progress_callback(overall_cluster_index, cluster, "open_loop")
			end
			Get_items_in_cluster(cluster)
			local _regionIndex = -1
			local retval
			local region_guid
			if cluster.region_guid then
				retval, _ = reaper.GetSetProjectInfo_String(0, "MARKER_INDEX_FROM_GUID:" .. cluster.region_guid, "", false)
			end
			if retval then
				region_guid = cluster.region_guid
			else
				region_guid = CreateTemporaryRenderRegion(cluster)
			end
			if region_guid == nil then
				Msg("Warning: Could not create region for cluster '" .. (cluster.cluster_id or "unknown") .. "', skipping render")
			else
				SelectAttachedRegionInMatrix(region_guid)
				local modified_filename = Find_and_replace_wildcards(cluster.cluster_id, _regionIndex, export_options.export_file_name)
				if export_options.overwrite_existing then
					local primary_format = export_options.primary_output_format and export_options.primary_output_format.format or "WAV"
					local primary_ext = primary_format == "FLAC" and ".flac" or (primary_format == "OGG" and ".ogg" or ".wav")
					local path_name_check_primary = project_render_folder_path .. modified_filename .. primary_ext
					Remove_existing_render_files(path_name_check_primary)
					if export_options.export_secondary then
						local path_name_check_OGG = project_render_folder_path .. modified_filename .. ".ogg"
						Remove_existing_render_files(path_name_check_OGG)
					end
				end
				reaper.Main_OnCommand(41824, 0) 
				if not retval then
					local r, enum_idx_str = reaper.GetSetProjectInfo_String(0, "MARKER_INDEX_FROM_GUID:" .. region_guid, "", false)
					if r == false then goto skip end
					local enum_idx = tonumber(enum_idx_str)
					if enum_idx == nil then goto skip end
					reaper.DeleteProjectMarkerByIndex(0, enum_idx)
					reaper.Main_OnCommand(40898, 0) 
					::skip::
				end
			end
			if gfx.getchar() == 27 then goto abort_render end
		end
	end
	if #loops > 0 then
		local RenderTable = CreateStandardRenderTableWithLoopTrueOrFalse(render_file_path, export_options, true)
		ApplyRenderTable_Project(RenderTable)
		for i, cluster in pairs(loops) do
			overall_cluster_index = overall_cluster_index + 1
			if progress_callback then
				progress_callback(overall_cluster_index, cluster, "loop")
			end
			Get_items_in_cluster(cluster)
			local _regionIndex = -1
			local retval
			local region_guid
			if cluster.region_guid then
				retval, _ = reaper.GetSetProjectInfo_String(0, "MARKER_INDEX_FROM_GUID:" .. cluster.region_guid, "", false)
			end
			if retval then
				region_guid = cluster.region_guid
			else
				region_guid = CreateTemporaryRenderRegion(cluster)
			end
			if region_guid == nil then
				Msg("Warning: Could not create region for cluster '" .. (cluster.cluster_id or "unknown") .. "', skipping render")
			else
				SelectAttachedRegionInMatrix(region_guid)
				local modified_filename = Find_and_replace_wildcards(cluster.cluster_id, _regionIndex, export_options.export_file_name)
				if export_options.overwrite_existing then
					local primary_format = export_options.primary_output_format and export_options.primary_output_format.format or "WAV"
					local primary_ext = primary_format == "FLAC" and ".flac" or (primary_format == "OGG" and ".ogg" or ".wav")
					local path_name_check_primary = project_render_folder_path .. modified_filename .. primary_ext
					Remove_existing_render_files(path_name_check_primary)
					if export_options.export_secondary then
						local path_name_check_OGG = project_render_folder_path .. modified_filename .. ".ogg"
						Remove_existing_render_files(path_name_check_OGG)
					end
				end
				reaper.Main_OnCommand(41824, 0) 
				if not retval then
					local r, enum_idx_str = reaper.GetSetProjectInfo_String(0, "MARKER_INDEX_FROM_GUID:" .. region_guid, "", false)
					if r == false then goto skip end
					local enum_idx = tonumber(enum_idx_str)
					if enum_idx == nil then goto skip end
					reaper.DeleteProjectMarkerByIndex(0, enum_idx)
					reaper.Main_OnCommand(40898, 0) 
					::skip::
				end
			end
			if gfx.getchar() == 27 then goto abort_render end
		end
	end
	::abort_render::
	for _, m in pairs(region_render_matrix_cache) do
		local region_idx = m.region_idx
		local track = reaper.GetMasterTrack(0)
		reaper.SetRegionRenderMatrix(0, region_idx, track, -1)
	end
	for _, m in pairs(region_render_matrix_cache) do
		local region_idx = m.region_idx
		for _, track_idx in pairs(m.tracks) do
			local track = reaper.GetTrack(0, track_idx-1)
			if track_idx == -1 then track = reaper.GetMasterTrack(0) end
			reaper.SetRegionRenderMatrix(0, region_idx, track, 1)
		end
	end

	
	for key, v in pairs(table_of_item_state) do
		reaper.SetMediaItemInfo_Value(v.item, "B_MUTE", v.state)
	end
	for _, v in pairs(table_of_track_lane_state) do
		reaper.SetMediaTrackInfo_Value(v.track, "C_ALLLANESPLAY", v.alllanesplay)
		for lane, state in pairs(v.lane_states) do
			reaper.SetMediaTrackInfo_Value(v.track, "C_LANEPLAYS:" .. lane, state)
		end
	end
	if focus_is_activated then Focus_view_selected_clusters(focused_clusters, focus_and_solo) end

	reaper.TrackFX_Delete(master_track, fx_index+0x1000000)
	if tab_visible == 1 and master_track_fx_count == 0 then
		reaper.Main_OnCommand(42072, 0) 
	end
	reaper.MarkProjectDirty(0)
	reaper.PreventUIRefresh(-1)
	
end






render_session = {
	active = false,
	export_options = nil,
	project_render_folder_path = nil,
	render_file_path = nil,
	region_render_matrix_cache = nil,
	used_cpp_matrix_cache = false,  
	render_settings_cache = nil,
	table_of_item_state = nil,
	table_of_track_lane_state = nil,
	master_track = nil,
	fx_index = nil,
	tab_visible = nil,
	master_track_fx_count = nil,
	start_time = nil,
	region_id_cache = nil,  
}





local function CacheRegionIDs()
	local cache = {}
	local num_total = reaper.CountProjectMarkers(0)
	for i = 0, num_total - 1 do
		local retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, i)
		if isrgn then
			local _, guid = reaper.GetSetProjectInfo_String(0, "MARKER_GUID:" .. tostring(i), "", false)
			if guid and guid ~= "" then
				cache[guid] = {
					index_number = markrgnindexnumber,
					pos = pos,
					rgnend = rgnend,
					name = name,
					color = color
				}
			end
		end
	end
	return cache
end




local function RestoreRegionIDs(cache)
	if not cache then return end

	local num_total = reaper.CountProjectMarkers(0)
	for i = 0, num_total - 1 do
		local retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, i)
		if isrgn then
			local _, guid = reaper.GetSetProjectInfo_String(0, "MARKER_GUID:" .. tostring(i), "", false)
			if guid and guid ~= "" and cache[guid] then
				local cached = cache[guid]
				
				
				if markrgnindexnumber ~= cached.index_number then
					reaper.SetProjectMarkerByIndex2(0, i, true, pos, rgnend, cached.index_number, name, color, 2)
				end
			end
		end
	end
end






function CheckClusterFileExists(cluster, export_options, project_render_folder_path, start_time)
	if not cluster or not export_options or not project_render_folder_path then
		return {exists = false, path = nil, modified_time = nil}
	end
	local filename_template = export_options.export_file_name or "$cluster"
	local modified_filename = Find_and_replace_wildcards(cluster.cluster_id, -1, filename_template)
	local primary_format = export_options.primary_output_format and export_options.primary_output_format.format or "WAV"
	local primary_ext = primary_format == "FLAC" and ".flac" or (primary_format == "OGG" and ".ogg" or ".wav")
	local full_path = project_render_folder_path .. modified_filename .. primary_ext
	full_path = string.gsub(full_path, string.char(92), string.char(47))
	if not reaper.file_exists(full_path) then
		return {exists = false, path = full_path, modified_time = nil}
	end
	local file_handle = io.open(full_path, "r")
	if not file_handle then
		return {exists = false, path = full_path, modified_time = nil}
	end
	file_handle:close()
	local file_size = nil
	file_handle = io.open(full_path, "rb")
	if file_handle then
		file_size = file_handle:seek("end")
		file_handle:close()
	end
	
	
	
	
	local modified_time = nil
	if reaper.JS_File_Stat then
		local retval, _, _, modifiedTime = reaper.JS_File_Stat(full_path)
		if retval == 0 and modifiedTime then
			
			local y, mo, d, h, mi, s = modifiedTime:match("(%d+)[-](%d+)[-](%d+)[T ](%d+):(%d+):(%d+)")
			if y then
				modified_time = os.time({
					year = tonumber(y), month = tonumber(mo), day = tonumber(d),
					hour = tonumber(h), min = tonumber(mi), sec = tonumber(s)
				})
			end
		end
	end

	
	local was_modified_after_start = true
	if start_time and modified_time then
		was_modified_after_start = modified_time >= start_time
	end

	return {
		exists = was_modified_after_start and (file_size and file_size > 0) or false,
		path = full_path,
		modified_time = modified_time,
		file_size = file_size
	}
end





function VerifyRenderedFiles(results, export_options, project_render_folder_path, start_time)
	if not results or #results == 0 then
		return results
	end
	local verified_results = {}
	for _, result in ipairs(results) do
		local cluster = {
			cluster_id = result.cluster_id,
			cluster_guid = result.cluster_guid,
			cluster_color = result.cluster_color,
			c_start = result.c_start,
			c_end = result.c_end
		}

		local file_check = CheckClusterFileExists(cluster, export_options, project_render_folder_path, start_time)

		local verified_result = {
			cluster_id = result.cluster_id,
			cluster_guid = result.cluster_guid,
			cluster_color = result.cluster_color,
			c_start = result.c_start,
			c_end = result.c_end,
			success = file_check.exists,  
			output_path = file_check.path,
			file_exists = file_check.exists,
			duration = result.duration
		}

		table.insert(verified_results, verified_result)
	end

	return verified_results
end





function InitRenderSession()
	if render_session.active then return false end
	
	
	
	if ValidateProjectHasBeenSaved() == false then
		reaper.MB("Project has not been saved!\n\nThe Reaper project needs to be saved before the AMAPP can start rendering. Please save your project!", "IMPORTANT!", 0)
		return false
	end

	
	reaper.PreventUIRefresh(1)

	
	render_session.region_id_cache = CacheRegionIDs()

	reaper.Main_OnCommand(40898, 0) 

	
	BuildItemCacheIfAvailable()

	
	local cache, used_cpp = CacheRegionRenderMatrixOptimized()
	render_session.region_render_matrix_cache = cache
	render_session.used_cpp_matrix_cache = used_cpp
	render_session.render_settings_cache = GetRenderTable_Project()  
	render_session.tab_visible = reaper.GetToggleCommandState(42072)
	render_session.master_track = reaper.GetMasterTrack()
	render_session.master_track_fx_count = reaper.TrackFX_GetRecCount(render_session.master_track)

	if render_session.tab_visible == 1 and render_session.master_track_fx_count == 0 then
		reaper.Main_OnCommand(42072, 0) 
	end

	render_session.fx_index = reaper.TrackFX_AddByName(render_session.master_track, "Container", true, -1)
	reaper.TrackFX_SetPinMappings(render_session.master_track, render_session.fx_index + 0x1000000, 0x0000000, 0x0000001, 0x0000000, 0x0000000)
	reaper.TrackFX_SetPinMappings(render_session.master_track, render_session.fx_index + 0x1000000, 0x0000000, 0x0000000, 0x0000000, 0x0000000)
	reaper.TrackFX_SetNamedConfigParm(render_session.master_track, render_session.fx_index + 0x1000000, "renamed_name", "Mute Monitor Out While Render")

	reaper.PreventUIRefresh(-1)

	local return_value, export_options_string = reaper.GetProjExtState(0, "AMAPP", "EXPORT_OPTIONS")
	if return_value == 0 then
		reaper.MB("No export options have been set. Please set export options inside AMAPP.", "Error!", 0)
		return false
	end
	render_session.export_options = table.deserialize(export_options_string)
	if render_session.export_options == nil then
		reaper.MB("No export options have been set. Please set export options inside AMAPP.", "Error!", 0)
		return false
	end

	local render_file_name_def = string.gsub(render_session.export_options.export_file_name or "$cluster", "$cluster", "$region")
	if render_file_name_def == nil or render_file_name_def == "" then
		render_file_name_def = "$region"
	end
	render_session.export_options.export_file_name = render_file_name_def
	render_session.render_file_path = render_session.export_options.file_path
	render_session.render_file_path = Find_and_replace_wildcards("", nil, render_session.render_file_path)

	if File_path_is_absolute(render_session.render_file_path) then
		render_session.project_render_folder_path = render_session.render_file_path
	else
		local proj_dir = select(2, reaper.EnumProjects(-1)):match("^(.+[\\/])")
		render_session.project_render_folder_path = proj_dir .. render_session.render_file_path
	end
	if not render_session.project_render_folder_path:match("[\\/]$") then
		render_session.project_render_folder_path = render_session.project_render_folder_path .. "/"
	end

	if io.open(reaper.GetResourcePath() .. "/reaper-render.ini", "r") == nil then
		local new_ini = io.open(reaper.GetResourcePath() .. "/reaper-render.ini", "w+")
		if new_ini ~= nil then new_ini:close() end
	end

	local bounds_presets, bounds_names, options_format_presets, options_format_names, both_presets, both_names = GetRenderPreset_Names()
	if both_names == nil then both_names = {} end
	for i, preset_name in pairs(both_names) do
		if preset_name == "AMAPP Render Cluster - Loop" then
			DeleteRenderPreset_Both(preset_name)
		elseif preset_name == "AMAPP Render Cluster - OneShot" then
			DeleteRenderPreset_Both(preset_name)
		end
	end

	
	reaper.PreventUIRefresh(1)

	render_session.table_of_item_state = {}
	render_session.table_of_track_lane_state = {}
	if focus_is_activated then Unfocus_view_clusters() end
	for i = 0, reaper.CountMediaItems() - 1 do
		local _item = reaper.GetMediaItem(0, i)
		table.insert(render_session.table_of_item_state, {item = _item, state = reaper.GetMediaItemInfo_Value(_item, "B_MUTE")})
	end
	for i = 0, reaper.CountTracks(0) - 1 do
		local track = reaper.GetTrack(0, i)
		if reaper.GetMediaTrackInfo_Value(track, "I_FREEMODE") == 2 then
			local num_lanes = reaper.GetMediaTrackInfo_Value(track, "I_NUMFIXEDLANES")
			local lane_states = {}
			for lane = 0, num_lanes - 1 do
				lane_states[lane] = reaper.GetMediaTrackInfo_Value(track, "C_LANEPLAYS:" .. lane)
			end
			table.insert(render_session.table_of_track_lane_state, {
				track = track,
				alllanesplay = reaper.GetMediaTrackInfo_Value(track, "C_ALLLANESPLAY"),
				lane_states = lane_states
			})
		end
	end

	reaper.PreventUIRefresh(-1)

	local srate = render_session.export_options.primary_output_format.sample_rate or 48000
	reaper.GetSetProjectInfo(0, "RENDER_SRATE", srate, true)
	if not render_session.export_options.export_secondary then
		reaper.GetSetProjectInfo_String(0, "RENDER_FORMAT2", "", true)
	end

	render_session.start_time = os.time()
	render_session.active = true
	return true
end




function RenderSingleCluster(cluster, cluster_type)
	if not render_session.active then return false end
	local export_options = render_session.export_options
	local project_render_folder_path = render_session.project_render_folder_path
	local render_file_path = render_session.render_file_path
	local is_loop = (cluster_type == "loop")
	local RenderTable = CreateStandardRenderTableWithLoopTrueOrFalse(render_file_path, export_options, is_loop)
	ApplyRenderTable_Project(RenderTable)

	
	reaper.PreventUIRefresh(1)

	Get_items_in_cluster(cluster)
	local _regionIndex = -1
	local retval
	local region_guid

	if cluster.region_guid then
		retval, _ = reaper.GetSetProjectInfo_String(0, "MARKER_INDEX_FROM_GUID:" .. cluster.region_guid, "", false)
	end

	if retval then
		region_guid = cluster.region_guid
	else
		region_guid = CreateTemporaryRenderRegion(cluster)
	end

	if region_guid == nil then
		reaper.PreventUIRefresh(-1)
		Msg("Warning: Could not create region for cluster '" .. (cluster.cluster_id or "unknown") .. "', skipping render")
		return false
	end

	SelectAttachedRegionInMatrix(region_guid)

	
	reaper.PreventUIRefresh(-1)
	local modified_filename = Find_and_replace_wildcards(cluster.cluster_id, _regionIndex, export_options.export_file_name)

	if export_options.overwrite_existing then
		local primary_format = export_options.primary_output_format and export_options.primary_output_format.format or "WAV"
		local primary_ext = primary_format == "FLAC" and ".flac" or (primary_format == "OGG" and ".ogg" or ".wav")
		local path_name_check_primary = project_render_folder_path .. modified_filename .. primary_ext
		Remove_existing_render_files(path_name_check_primary)
		if export_options.export_secondary then
			local path_name_check_OGG = project_render_folder_path .. modified_filename .. ".ogg"
			Remove_existing_render_files(path_name_check_OGG)
		end
	end
	reaper.Main_OnCommand(41824, 0) 

	
	if not retval then
		reaper.PreventUIRefresh(1)
		local r, enum_idx_str = reaper.GetSetProjectInfo_String(0, "MARKER_INDEX_FROM_GUID:" .. region_guid, "", false)
		if r then
			local enum_idx = tonumber(enum_idx_str)
			if enum_idx then
				
				reaper.DeleteProjectMarkerByIndex(0, enum_idx)
			end
		end
		reaper.Main_OnCommand(40898, 0) 
		reaper.PreventUIRefresh(-1)
	end

	return true
end





function RenderBatch(batch, batch_type)
	if not render_session.active then return {} end
	if #batch == 0 then return {} end

	local export_options = render_session.export_options
	local project_render_folder_path = render_session.project_render_folder_path
	local render_file_path = render_session.render_file_path

	local is_loop = (batch_type == "loop")
	local RenderTable = CreateStandardRenderTableWithLoopTrueOrFalse(render_file_path, export_options, is_loop)
	ApplyRenderTable_Project(RenderTable)

	
	
	reaper.PreventUIRefresh(1)

	
	ClearRenderMatrixOptimized()

	local region_guids = {}
	local temp_regions = {}

	for _, item in ipairs(batch) do
		local cluster = item.cluster
		Get_items_in_cluster(cluster)

		local retval
		local region_guid

		if cluster.region_guid then
			retval, _ = reaper.GetSetProjectInfo_String(0, "MARKER_INDEX_FROM_GUID:" .. cluster.region_guid, "", false)
		end

		if retval then
			region_guid = cluster.region_guid
		else
			region_guid = CreateTemporaryRenderRegion(cluster)
			if region_guid then
				table.insert(temp_regions, region_guid)
			end
		end

		if region_guid then
			table.insert(region_guids, region_guid)
		else
			Msg("Warning: Could not create region for cluster '" .. (cluster.cluster_id or "unknown") .. "', skipping")
		end
	end

	if #region_guids == 0 then
		reaper.PreventUIRefresh(-1)
		return {}
	end

	
	AddRegionsToMatrixOptimized(region_guids)

	
	reaper.PreventUIRefresh(-1)

	if export_options.overwrite_existing then
		local primary_format = export_options.primary_output_format and export_options.primary_output_format.format or "WAV"
		local primary_ext = primary_format == "FLAC" and ".flac" or (primary_format == "OGG" and ".ogg" or ".wav")

		for _, item in ipairs(batch) do
			local cluster = item.cluster
			local modified_filename = Find_and_replace_wildcards(cluster.cluster_id, -1, export_options.export_file_name)
			local path_name_check_primary = project_render_folder_path .. modified_filename .. primary_ext
			Remove_existing_render_files(path_name_check_primary)
			if export_options.export_secondary then
				local path_name_check_OGG = project_render_folder_path .. modified_filename .. ".ogg"
				Remove_existing_render_files(path_name_check_OGG)
			end
		end
	end

	local batch_start_time = reaper.time_precise()
	reaper.Main_OnCommand(41824, 0) 
	local batch_duration = reaper.time_precise() - batch_start_time

	
	if #temp_regions > 0 then
		reaper.PreventUIRefresh(1)
		
		for i = #temp_regions, 1, -1 do
			local guid = temp_regions[i]
			
			local r, enum_idx_str = reaper.GetSetProjectInfo_String(0, "MARKER_INDEX_FROM_GUID:" .. guid, "", false)
			if r then
				local enum_idx = tonumber(enum_idx_str)
				if enum_idx then
					
					reaper.DeleteProjectMarkerByIndex(0, enum_idx)
				end
			end
		end
		reaper.Main_OnCommand(40898, 0) 
		reaper.PreventUIRefresh(-1)
	end

	local results = {}
	local time_per_cluster = batch_duration / #batch
	local primary_format = export_options.primary_output_format and export_options.primary_output_format.format or "WAV"
	local primary_ext = primary_format == "FLAC" and ".flac" or (primary_format == "OGG" and ".ogg" or ".wav")

	for _, item in ipairs(batch) do
		local cluster = item.cluster
		local filename_template = export_options.export_file_name or "$cluster"
		local modified_filename = Find_and_replace_wildcards(cluster.cluster_id, -1, filename_template)
		local output_path = project_render_folder_path .. modified_filename .. primary_ext
		output_path = string.gsub(output_path, string.char(92), string.char(47))

		table.insert(results, {
			cluster_id = cluster.cluster_id or "Unknown",
			cluster_guid = cluster.cluster_guid,
			cluster_color = cluster.cluster_color,
			c_start = cluster.c_start,
			c_end = cluster.c_end,
			success = true,  
			output_path = output_path,
			duration = time_per_cluster
		})
	end

	return results
end





function CleanupRenderSession(focused_clusters, focus_and_solo)
	if not render_session.active then return end

	
	InvalidateItemCacheIfAvailable()

	if render_session.render_settings_cache then
		ApplyRenderTable_Project(render_session.render_settings_cache, true)
	end

	
	reaper.PreventUIRefresh(1)

	
	if render_session.region_render_matrix_cache then
		if render_session.used_cpp_matrix_cache and AMAPP_Render_API.available then
			reaper.AMAPP_Render_ClearMatrix()
			reaper.AMAPP_Render_RestoreRegionMatrix(render_session.region_render_matrix_cache)
		elseif type(render_session.region_render_matrix_cache) == "table" then
			for _, m in pairs(render_session.region_render_matrix_cache) do
				local region_idx = m.region_idx
				local track = reaper.GetMasterTrack(0)
				reaper.SetRegionRenderMatrix(0, region_idx, track, -1)
			end
			for _, m in pairs(render_session.region_render_matrix_cache) do
				local region_idx = m.region_idx
				for _, track_idx in pairs(m.tracks) do
					local track = reaper.GetTrack(0, track_idx - 1)
					if track_idx == -1 then track = reaper.GetMasterTrack(0) end
					reaper.SetRegionRenderMatrix(0, region_idx, track, 1)
				end
			end
		end
	end
	if render_session.table_of_item_state then
		for _, v in pairs(render_session.table_of_item_state) do
			reaper.SetMediaItemInfo_Value(v.item, "B_MUTE", v.state)
		end
	end
	if render_session.table_of_track_lane_state then
		for _, v in pairs(render_session.table_of_track_lane_state) do
			reaper.SetMediaTrackInfo_Value(v.track, "C_ALLLANESPLAY", v.alllanesplay)
			for lane, state in pairs(v.lane_states) do
				reaper.SetMediaTrackInfo_Value(v.track, "C_LANEPLAYS:" .. lane, state)
			end
		end
	end
	if focus_is_activated and focused_clusters then
		Focus_view_selected_clusters(focused_clusters, focus_and_solo or false)
	end
	if render_session.master_track and render_session.fx_index then
		reaper.TrackFX_Delete(render_session.master_track, render_session.fx_index + 0x1000000)
	end
	if render_session.tab_visible == 1 and render_session.master_track_fx_count == 0 then
		reaper.Main_OnCommand(42072, 0) 
	end

	
	if render_session.region_id_cache then
		RestoreRegionIDs(render_session.region_id_cache)
	end

	reaper.PreventUIRefresh(-1)
	reaper.MarkProjectDirty(0)
	render_session.active = false
	render_session.export_options = nil
	render_session.project_render_folder_path = nil
	render_session.render_file_path = nil
	render_session.region_render_matrix_cache = nil
	render_session.used_cpp_matrix_cache = false
	render_session.render_settings_cache = nil
	render_session.table_of_item_state = nil
	render_session.table_of_track_lane_state = nil
	render_session.master_track = nil
	render_session.fx_index = nil
	render_session.tab_visible = nil
	render_session.master_track_fx_count = nil
	render_session.start_time = nil
	render_session.region_id_cache = nil
	
	
end