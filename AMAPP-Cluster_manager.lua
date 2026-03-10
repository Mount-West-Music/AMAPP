-- @description AMAPP - Adaptive Music Application
-- @author Mount West Music
-- @version 0.5.0
-- @changelog
--   v0.5.0 (2026-04)
--   - 11 action scripts for hotkey binding
--   - C++ extension for performance-critical operations
--   - Fixed Lanes support for clusters
--   - Wildcards in export file paths
--   - Timeline overlay and minimap improvements
--   - Audition playback improvements

-- @provides
-- [main] AMAPP-Cluster_manager.lua
-- [main] actions/AMAPP-Action_Add_Item.lua
-- [main] actions/AMAPP-Action_Create_Cluster.lua
-- [main] actions/AMAPP-Action_Edit_Cluster.lua
-- [main] actions/AMAPP-Action_Focus_Toggle.lua
-- [main] actions/AMAPP-Action_Group_Clusters.lua
-- [main] actions/AMAPP-Action_Remove_Item.lua
-- [main] actions/AMAPP-Action_Render_All.lua
-- [main] actions/AMAPP-Action_Render_Selected.lua
-- [main] actions/AMAPP-Action_Select_Items.lua
-- [main] actions/AMAPP-Action_Toggle_Arm.lua
-- [main] actions/AMAPP-Action_Toggle_Overlay.lua
-- scripts/*.lua
-- util/*.lua
-- util/json/*.lua
-- util/luatoxml/src/luatoxml.lua
-- img/*
-- init/*
-- [darwin extension] extension/reaper_amapp.dylib
-- [win64 extension] extension/reaper_amapp.dll
-- Changelog.txt
-- README.txt
--   LICENSE.txt
-- Install Guide.txt
-- @donate cfillion https://github.com/sponsors/cfillion
-- @donate Mespotine https://www.youtube.com/@TheRealMespotine
-- @link Website https://amapp.io
-- @link Forum https://forum.cockos.com/showthread.php?t=308478
-- @link Discord https://discord.gg/xs8AEhx6h2
-- @about
-- # AMAPP - Adaptive Music Application

--
--   **Requirements:** SWS/S&M, Dear ImGui, js_ReaScriptAPI
--
-- **Features:**
-- - Render cluster management for batch audio processing
-- - Timeline overlay for visual cluster management

--[[
	Library/Component: AMAPP
	Copyright (c) 2026 Mount West Music AB
	All rights reserved.

	Description:
	This script contains the implementation of the GUI class, which provides
	an interface for performing the various functions and actions using AMAPP.

	Dependencies:
	- SWS/S&M
	- ReaImGUI
		- v0.9.3

	Note:
	- This script is intended for internal use within AMAPP library/component.
	- Do not modify this file unless you have proper authorization.
	- For inquiries:
		- Join my Discord server:	https://discord.gg/xs8AEhx6h2
		- Or contact:				support@mountwestmusic.com

	(c) 2026 Mount West Music AB. All rights reserved.
--]]
local VERSION = "0.5.0"
local amapp = {}


local function normalize_path(path)
	if not path then return path end
	local sep = package.config:sub(1, 1)
	if sep == "\\" then
		return path:gsub("/", "\\")
	else
		return path:gsub("\\", "/")
	end
end





local function path_join(...)
	local sep = package.config:sub(1, 1)
	local joined = table.concat({...}, "/")
	if sep == "\\" then
		joined = joined:gsub("[/\\]+", "\\")
	else
		joined = joined:gsub("[/\\]+", "/")
	end
	return joined
end
amapp.path_join = path_join

------------- SETUP SEQUENCE --------------
reaper.ShowConsoleMsg("")
local function Msg(param)
	if param == nil then reaper.ShowConsoleMsg("") return end
	reaper.ShowConsoleMsg(tostring(param) .. "\n")
end


local function compare_version(version_a, version_b)
	local function split_version(version)
		local parts = {}
		for num in version:gmatch("(%d+)") do
			table.insert(parts, tonumber(num))
		end
		return parts
	end
    local a_parts = split_version(version_a)
    local b_parts = split_version(version_b)
    for i = 1, math.max(#a_parts, #b_parts) do
        local a_num = a_parts[i] or 0
        local b_num = b_parts[i] or 0

        if a_num < b_num then
            return -1
        elseif a_num > b_num then
            return 1
        end
    end
    return 0
end

amapp.lib_path = normalize_path(reaper.GetExtState("AMAPP", "lib_path"))
amapp.registered_version = reaper.GetExtState("AMAPP", "version")
amapp.license_accepted_date = reaper.GetExtState("AMAPP", "amapp.license_accepted_date")
amapp.authorized_date = reaper.GetExtState("AMAPP", "authorized_date")
amapp.session = reaper.GetExtState("AMAPP", "session")


amapp.license_key = reaper.GetExtState("AMAPP", "license_key")
amapp.trial_start = reaper.GetExtState("AMAPP", "trial_start")
amapp.open_count = tonumber(reaper.GetExtState("AMAPP", "open_count")) or 0
amapp.welcome_shown = reaper.GetExtState("AMAPP", "welcome_shown") == "true"
amapp.installed = false
amapp.info = debug.getinfo(1,'S')
amapp.script_path = normalize_path(amapp.info.source:match[[^@?(.*[\/])[^\/]-$]])


do
	local function Install_AMAPP(pkg_version)
		local function MissingDependencies()
			local deps = {}

			---@diagnostic disable-next-line: undefined-field
			if not reaper.ImGui_GetVersion then
				table.insert(deps, '"Dear Imgui"')
			end
			if not reaper.BR_GetMediaItemByGUID then
				table.insert(deps, '"SWS/S&M"')
			end
			if not reaper.JS_Window_FindChildByID then
				table.insert(deps, '"js_ReaScriptAPI: API functions for ReaScripts"')
			end

			if #deps ~= 0 then
				local filter = table.concat(deps, ' OR ')
				reaper.MB("You need additional packages for increased REAPER functionality.\nPlease Install them in the next window", "MISSING DEPENDENCIES", 0)
				reaper.ReaPack_BrowsePackages(filter)
				return true
			else
				return false
			end
		end

		if MissingDependencies() then return false end

		local info = debug.getinfo(1,'S')
		local script_path = info.source:match[[^@?(.*[\/])[^\/]-$]]
		reaper.SetExtState("AMAPP", "lib_path", script_path, true)
		reaper.SetExtState("AMAPP", "version", pkg_version, true)
		return true
	end

	if not amapp.lib_path or amapp.lib_path == "" or amapp.lib_path ~= amapp.script_path then
		amapp.installed = Install_AMAPP(VERSION)
		if not amapp.installed then return end
		amapp.lib_path = normalize_path(reaper.GetExtState("AMAPP", "lib_path"))
	end
end

local function is_guid(str)
    return type(str) == "string" and str:match("^[0-9a-fA-F]{8}%-[0-9a-fA-F]{4}%-[0-9a-fA-F]{4}%-[0-9a-fA-F]{4}%-[0-9a-fA-F]{12}$") ~= nil
end


local Update_AMAPP
do
	
	local function Recur_SelectedClusters(cluster_table, parent_guid)
		parent_guid = parent_guid
		local selected_clusters = {}
		for k, c in pairs(cluster_table) do
			if c.is_selected then
				table.insert(selected_clusters, {
					cluster = c,
					parent_guid = parent_guid
				})
			end
			if c.children ~= nil then Recur_SelectedClusters(c.children, c.cluster_guid) end
		end
		return selected_clusters
	end

	Update_AMAPP = function(_lib_path, old_version, new_version)
	local retval = reaper.MB("Do you want to save a unique version of your project file?\n\nYou are attempting to open a project that was created with an older version (v"..old_version..") of AMAPP. To avoid potential conflicts, it is suggested that you save a new version of your project.\n\nNo: Update existing project file\n\nYes: Save a new version", "Save project with new AMAPP version " ..new_version, 4)
	if retval == 6 then
		reaper.Main_OnCommand(41895, 0) 
	end
	dofile(normalize_path(_lib_path .. "util/MWM-Table_serializer.lua"))
	local ret, sTable = reaper.GetProjExtState(0, "AMAPP", "CLUSTER_TABLE")
	if ret == nil or ret == 0 then
		ret, sTable = reaper.GetProjExtState(0, "MWM-RENDER_CLUSTER", "CLUSTER_TABLE")
	end
	if sTable == nil then return end
	local cluster_table = table.deserialize(sTable)
	if cluster_table == nil then cluster_table = {} end
	for keys, cluster in pairs(cluster_table) do
		
		if cluster.region_idx ~= nil then
			local region_info = RegionManager.GetRegionByName(cluster.cluster_id)
			if region_info then
				cluster.cluster_color = region_info.color
				cluster.region_guid = region_info.guid
				if cluster.c_start == nil or cluster.c_end == nil then
					cluster.c_start, cluster.c_end = region_info.position, region_info.regionEnd
				end
			end
			cluster.region_idx = nil
		end
		if cluster.c_qn_start == nil or cluster.c_qn_end == nil then
			cluster.c_qn_start = reaper.TimeMap2_timeToQN(0, cluster.c_start)
			cluster.c_qn_end = reaper.TimeMap2_timeToQN(0, cluster.c_end)
		end
		if cluster.c_entry ~= nil then
			cluster.c_qn_entry = reaper.TimeMap2_timeToQN(0, cluster.c_entry)
		end
		if cluster.c_exit ~= nil then
			cluster.c_qn_exit = reaper.TimeMap2_timeToQN(0, cluster.c_exit)
		end
	end
	sTable = table.serialize(cluster_table)
	reaper.SetProjExtState(0, "AMAPP", "CLUSTER_TABLE", sTable)
	local retval, set_table_string = reaper.GetProjExtState(0, "AMAPP", "SET_TABLE")
	if retval == nil or retval == 0 then
		retval, set_table_string = reaper.GetProjExtState(0, "MWM-RENDER_CLUSTER", "SET_TABLE")
	end
	if retval then
		reaper.SetProjExtState(0, "AMAPP", "SET_TABLE", set_table_string)
	end
	for i = 0, reaper.CountMediaItems(0) - 1 do
		local item = reaper.GetMediaItem(0, i)
		local r, string = reaper.GetSetMediaItemInfo_String(item, "P_EXT:AMAPP", "", false)
		if not r then
			r, string = reaper.GetSetMediaItemInfo_String(item, "P_EXT:MWM-RENDER_CLUSTER", "", false)
			if not r then goto continue end
		else goto continue end
		reaper.GetSetMediaItemInfo_String(item, "P_EXT:AMAPP", string, true)
		::continue::
	end
	reaper.SetProjExtState(0, "AMAPP", "PROJECT_VERSION", VERSION)
	reaper.MarkProjectDirty(0)
	if retval == 7 then
		reaper.Main_OnCommand(40026, 0) 
	end
	return true
	end
end  


 -- ========== Profiler ===========
package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.10.0.2'




local ErrorHandling
do
	
	local function safe_load_file(path, name)
		local f = io.open(path, "r")
		if not f then
			reaper.MB("Failed to open " .. name .. ":\n" .. path .. "\n\nPlease reinstall AMAPP.", "AMAPP Load Error", 0)
			return nil
		end
		local content = f:read("*a")
		f:close()
		local loader, err = load(content, "@" .. path, "t")
		if not loader then
			reaper.MB("Failed to load " .. name .. ":\n" .. (err or "unknown error") .. "\n\nPlease reinstall AMAPP.", "AMAPP Load Error", 0)
			return nil
		end
		return loader
	end

	
	local constants_path = normalize_path(amapp.lib_path .. "util/AMAPP-Constants.lua")
	local constants_loader = safe_load_file(constants_path, "AMAPP Constants")
	if not constants_loader then return end
	constants_loader()

	
	local eh_path = normalize_path(amapp.lib_path .. "util/AMAPP-ErrorHandling.lua")
	local eh_loader = safe_load_file(eh_path, "Error Handling module")
	if not eh_loader then return end
	ErrorHandling = eh_loader()
end


local function load_script(relative_path, description)
	local full_path = normalize_path(amapp.lib_path .. relative_path)
	ErrorHandling.safe_loadfile(full_path, description or relative_path)
end





load_script("scripts/AMAPP-Get_items_in_cluster.lua", "Get Items in Cluster")
load_script("scripts/AMAPP-Solo_items_in_cluster.lua", "Solo Items in Cluster")
load_script("scripts/AMAPP-Deactivate_selected_cluster.lua", "Deactivate Selected Cluster")

load_script("scripts/AMAPP-Get_selected_region_name.lua", "Get Selected Region Name")
load_script("scripts/AMAPP-Create_new_render_cluster.lua", "Create New Render Cluster")
load_script("scripts/AMAPP-Create_cluster_group.lua", "Create Cluster Group")
load_script("scripts/AMAPP-Duplicate_cluster.lua", "Duplicate Cluster")
load_script("scripts/AMAPP-Edit_render_cluster.lua", "Edit Render Cluster")
load_script("scripts/AMAPP-Delete_render_cluster.lua", "Delete Render Cluster")
load_script("scripts/AMAPP-Render_clusters.lua", "Render Clusters")
load_script("scripts/AMAPP-Set_cluster_loop.lua", "Set Cluster Loop")
load_script("scripts/AMAPP-Update_render_cluster_table_ext_proj_state.lua", "Update Cluster Table State")
load_script("scripts/AMAPP-Focus_view_selected_clusters.lua", "Focus View Selected Clusters")
load_script("scripts/AMAPP-Set_cluster_boundaries.lua", "Set Cluster Boundaries")
load_script("scripts/AMAPP-Get_cluster.lua", "Get Cluster")
load_script("scripts/AMAPP-Implementation_design.lua", "Implementation Design")

load_script("scripts/AMAPP-Create_new_set.lua", "Create New Set")
load_script("scripts/AMAPP-New_cluster_color.lua", "New Cluster Color")
load_script("scripts/AMAPP-Implement_to_WAXML.lua", "Implement to WAXML")


local async_request = ErrorHandling.safe_loadfile(amapp.lib_path .. "util/AMAPP-Async_request.lua", "Async Request")
local json = ErrorHandling.safe_loadfile(amapp.lib_path .. "util/json/json.lua", "JSON Parser")
local UndoManager = ErrorHandling.safe_loadfile(amapp.lib_path .. "util/AMAPP-UndoManager.lua", "Undo Manager")
local RegionManager = ErrorHandling.safe_loadfile(amapp.lib_path .. "util/AMAPP-RegionManager.lua", "Region Manager")
local ClusterTree = ErrorHandling.safe_loadfile(amapp.lib_path .. "util/AMAPP-ClusterTree.lua", "Cluster Tree")
local ClusterAPI = ErrorHandling.safe_loadfile(amapp.lib_path .. "util/AMAPP-ClusterAPI.lua", "Cluster API")


local function parse_item_ext(ext_str)
	if not ext_str or ext_str == "" then
		return nil
	end
	
	local ok, result = pcall(table.deserialize, ext_str)
	if ok and result then
		return result
	end
	
	if json then
		ok, result = pcall(json.decode, ext_str)
		if ok and result then
			return result
		end
	end
	return nil
end


local Cluster = {}
Cluster.__index = Cluster

function Cluster:start()
	
	return {}
end

function Cluster:new(name)
	local c = {
		cluster_guid = reaper.genGuid(),
		cluster_id = name
	}
	setmetatable(c, self:start())
	return c
end

function Cluster.tostring (set)
	local _s = "{"
	local sep = "\n"
	for e, v in pairs(set) do
		_s = _s .. sep .. e .. ": " .. tostring(v)
		sep = ", "
	end
	return _s .. "}"
end





local project_data
do
	local function load_project_data()
		local data = {}

		local _, cluster_table_str = reaper.GetProjExtState(0, "AMAPP", "CLUSTER_TABLE")
		data.render_cluster_table = ErrorHandling.safe_deserialize(cluster_table_str, "CLUSTER_TABLE", {})

		local _, cluster_list_str = reaper.GetProjExtState(0, "AMAPP", "CLUSTER_LIST")
		data.render_cluster_list = ErrorHandling.safe_deserialize(cluster_list_str, "CLUSTER_LIST", {})

		local _, set_table_str = reaper.GetProjExtState(0, "AMAPP", "SET_TABLE")
		data.set_table = ErrorHandling.safe_deserialize(set_table_str, "SET_TABLE", {})

		
		if ClusterAPI and ClusterAPI.store then
			data.cluster_items_table = ClusterAPI.get_legacy_items_table()
		else
			local _, cluster_items_str = reaper.GetProjExtState(0, "AMAPP", "CLUSTER_ITEMS")
			data.cluster_items_table = ErrorHandling.safe_deserialize(cluster_items_str, "CLUSTER_ITEMS", {})
		end

		local _, cluster_graph_str = reaper.GetProjExtState(0, "AMAPP", "CLUSTER_GRAPH")
		data.cluster_graph = ErrorHandling.safe_deserialize(cluster_graph_str, "CLUSTER_GRAPH", {})

		return data
	end
	project_data = load_project_data()
end

local gui = {}



local RequireLicense

gui.triggerFunction = false
gui.toggleLoop = false
gui.toggleActivate = true
gui.toggleDeactivate = false
gui.update_clusters_is_toggled = true
gui.focus_activated = false
gui.hotkeys_enabled = reaper.GetExtState("AMAPP", "hotkeys_enabled") ~= "false" 
gui.solo_clusters_on_focus = true
gui.last_selected_item_idx = 1
gui.timeline_gui_visible = true
gui.item_overlay = true
gui.gui_settings_overlay_inverse = true
gui.minimap_visible = true
gui.all_items = 0
gui.projectStateChangeCount = reaper.GetProjectStateChangeCount(0)
gui.cluster_dragging = false
gui.app_open = false
gui.cluster_armed = false
gui.timeline_gui_edit_clicked = false
gui.timeline_context_menu_clicked = false
gui.delete_cluster_clicked = false
gui.new_cluster_btn_clicked = false
gui.last_hovered_item = ""
gui.last_hovered_item_index = 0
gui.last_hovered_item_is_group = false
gui.last_hovered_item_parent_guid = nil
gui.last_hovered_item_is_last_in_group = false
gui.drop_into_group = false
gui.drop_out_of_group = false
gui.hovering_own_child = false
gui.hovering_below_list = false
gui.last_rendered_item_max_y = 0
gui.clear_debug_each_frame = false
gui.debug_cluster_table_visible = false
gui.font_stack_depth = 0
gui.open_export_options = false
gui.show_render_summary = false
gui.render_summary_data = nil
gui.show_audition_popup = false
gui.audition_cluster = nil  


gui.waveform_selected_result = nil   
gui.waveform_peaks_cache = nil       
gui.waveform_preview_start = 0       
gui.waveform_preview_length = 0      
gui.current_preview = nil            
gui.current_preview_src = nil        


gui.last_undo_state = reaper.Undo_CanUndo2(0) or ""
gui.last_redo_state = reaper.Undo_CanRedo2(0) or ""


gui.license_modal_open = false
gui.license_key_input = ""
gui.license_nag_shown_this_session = false
gui.show_trial_reminder = false
gui.show_welcome_modal = false
gui.trial_countdown_start = 0  
gui.trial_countdown_speed = 1.0  
gui._lv1 = 0  
gui._lv2 = 0  
gui._lv3 = 0  


gui.email_input = ""
gui.email_verification_status = nil  
gui.email_verification_error = ""


gui.license_sheen_active = false
gui.license_sheen_start_time = 0
gui.license_sheen_duration = 0.8  
gui.license_sheen_startup_checked = false  
gui.license_sheen_color = 0xFFFFFF  
gui.license_sheen_tier = nil  



gui.guide_active = false
gui.guide_step = 0 
gui.guide_flash_timer = 0 
gui.guide_element_rects = {} 


gui.help_tooltips_enabled = reaper.GetExtState("AMAPP", "help_tooltips") == "true"


gui.cached_frame_count = -1
gui.ctx_valid_this_frame = false
gui.ctx_validated_this_frame = false


gui.modal_rv = false
gui.modal_new_loop_toggle = false
gui.modal_new_region_toggle = false
gui.modal_buf = ""
gui.detected_item_groups = nil
gui.multi_cluster_buf = ""
gui.multi_loop_toggle = false
gui.multi_region_toggle = false
gui.multi_create_group_toggle = true
gui.show_variation_prompt = false
gui.open_single_cluster_modal = false
gui.open_multi_cluster_modal = false


local function Update_all_cluster_items_with_GUID(cluster)
	local total_tracks = reaper.CountTracks(0)
	local hidden_tcp_list = {}
	local collapsed_tcp_list = {}
	for id = 0, total_tracks-1, 1 do
		local track = reaper.GetTrack(0, id)
		if not reaper.IsTrackVisible(track, false) then
			table.insert(hidden_tcp_list, track)
			reaper.SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 1)
		end
		if reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
			local collapsed_state = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
			table.insert(collapsed_tcp_list, {track = track, collapsed_state = collapsed_state})
			reaper.SetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT", 0)
		end
	end
	local previously_selected_items = reaper.CountSelectedMediaItems(0)
	local table_saved_selection = {}
	for i = 0, previously_selected_items - 1 do
		table.insert(table_saved_selection, reaper.GetSelectedMediaItem(0, i))
	end
	reaper.SelectAllMediaItems(0, true)
	local count_sel_items = reaper.CountSelectedMediaItems(0)
	for _i = 0, count_sel_items - 1, 1 do
		local item = reaper.GetSelectedMediaItem(0, _i)
		local _, stringTable = reaper.GetSetMediaItemInfo_String(item, "P_EXT:AMAPP", "", false)
		local connected_clusters_in_item = parse_item_ext(stringTable)
		if connected_clusters_in_item == nil then goto continue end
		for k, v in pairs(connected_clusters_in_item) do
			if type(v) == "table" and v.cluster == cluster.cluster_id then
				v.cluster_guid = cluster.cluster_guid
				v.cluster_id = v.cluster
			end
		end
		stringTable = table.serialize(connected_clusters_in_item)
		reaper.GetSetMediaItemInfo_String(item, "P_EXT:AMAPP", stringTable, true)
		::continue::
	end
	local commandID = reaper.NamedCommandLookup("_SWS_UNSELALL")
	reaper.Main_OnCommand(commandID, 0)
	for k, v in pairs(table_saved_selection) do
		reaper.SetMediaItemInfo_Value(v, "B_UISEL", 1)
	end
	for key, track in pairs(hidden_tcp_list) do
		reaper.SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
	end
	for key, t in pairs(collapsed_tcp_list) do
		reaper.SetMediaTrackInfo_Value(t.track, "I_FOLDERCOMPACT", t.collapsed_state)
	end
end

local function Init_export_options()
	local export_options = {
		file_path = "AMAPP Exports",
		export_file_name = "$cluster",
		export_secondary = true,
		overwrite_existing = false,
		channels = 2,
		channels_code = 1,
		primary_output_format = {
			format = "WAV",
			format_code = 0,           
			sample_rate_code = 1,
			sample_rate = "48000",
			
			bit_depth = 2,             
			bit_depth_code = 2,        
			
			flac_bit_depth = 1,        
			flac_bit_depth_code = 1,
			flac_compression = 5,      
			
			ogg_quality = 1.0,         
		},
		secondary_output_format = {
			format = "OGG",
		},
		tail_enabled = false,
		tail_ms = 1000,
		close_after_render = true
	}
	return export_options
end


local function Migrate_export_options_early(export_options)
	if export_options == nil then return nil end
	if export_options.primary_output_format.format_code == nil then
		export_options.primary_output_format.format_code = 0
		export_options.primary_output_format.format = "WAV"
		export_options.primary_output_format.bit_depth = 2
		export_options.primary_output_format.bit_depth_code = 2
		export_options.primary_output_format.flac_bit_depth = 1
		export_options.primary_output_format.flac_bit_depth_code = 1
		export_options.primary_output_format.flac_compression = 5
	end
	return export_options
end

if 0 == reaper.GetProjExtState(0, "AMAPP", "EXPORT_OPTIONS") then
	local export_options = Init_export_options()
	if reaper.HasExtState("AMAPP", "DEFAULT_EXPORT_OPTIONS") then
		local def_export_options = reaper.GetExtState("AMAPP", "DEFAULT_EXPORT_OPTIONS")
		export_options = table.deserialize(def_export_options) or export_options
		export_options = Migrate_export_options_early(export_options) or export_options
	end
	reaper.SetProjExtState(0, "AMAPP", "EXPORT_OPTIONS", table.serialize(export_options))
end

local function Update_Cluster_Item_System()
	local _, cluster_sTable = reaper.GetProjExtState(0, "AMAPP", "CLUSTER_TABLE")
	if cluster_sTable == nil then return end
	local cluster_table = table.deserialize(cluster_sTable)

	local retval, cluster_item_sTable = reaper.GetProjExtState(0, "AMAPP", "CLUSTER_ITEMS")
	if cluster_item_sTable ~= "" then return end

	local cluster_item_table = {}
	local count_items = reaper.CountMediaItems(0)
	for _i = 0, count_items - 1, 1 do
		local item = reaper.GetMediaItem(0, _i)
		local _, stringTable = reaper.GetSetMediaItemInfo_String(item, "P_EXT:AMAPP", "", false)
		local connected_clusters_in_item = parse_item_ext(stringTable)
		if connected_clusters_in_item == nil then goto continue end
		for k, v in pairs(connected_clusters_in_item) do
			if type(v) == "table" then
				local _, item_guid = reaper.GetSetMediaItemInfo_String(item, "GUID", "", false)
				if cluster_item_table[v.cluster_guid] == nil then cluster_item_table[v.cluster_guid] = {} end
				cluster_item_table[v.cluster_guid][item_guid] = {
					item_guid = item_guid,
					time_modified = os.time(),
					item_take_guid = v.take
				}
			end
		end
		::continue::
	end

	cluster_item_sTable = table.serialize(cluster_item_table)
	reaper.SetProjExtState(0, "AMAPP", "CLUSTER_ITEMS", cluster_item_sTable)
end

local function Verify_cluster_GUID()
	local retval, _cluster_sTable = reaper.GetProjExtState(0, "AMAPP", "CLUSTER_TABLE")
	if retval == 0 then
		retval, _cluster_sTable = reaper.GetProjExtState(0, "MWM-RENDER_CLUSTER", "CLUSTER_TABLE")
	end
	project_data.render_cluster_table = table.deserialize(_cluster_sTable)
	if project_data.render_cluster_table == nil then return end
	local temp_table = {}
	for idx, cluster in pairs(project_data.render_cluster_table) do
		if cluster.cluster_guid == nil or cluster.cluster_guid == "" then
			cluster.cluster_guid = reaper.genGuid()
			Update_all_cluster_items_with_GUID(cluster)
		end
		if cluster.idx == nil and type(idx) == "number" then cluster.idx = idx end
		temp_table[cluster.cluster_guid] = cluster
	end
	project_data.render_cluster_table = temp_table
	local cluster_sTable = table.serialize(project_data.render_cluster_table)
	reaper.SetProjExtState(0, "AMAPP", "CLUSTER_TABLE", cluster_sTable)
end

local function ProjectVersionCheck()
	if reaper.GetProjectName(0) == "" then
		reaper.SetProjExtState(0, "AMAPP", "PROJECT_VERSION", VERSION)
		return true
	end
	local ret, amapp_project_version = reaper.GetProjExtState(0, "AMAPP", "PROJECT_VERSION")
	local cluster_exists = reaper.GetProjExtState(0, "AMAPP", "CLUSTER_TABLE")
	if ret == 0 then
		cluster_exists = reaper.GetProjExtState(0, "MWM-RENDER_CLUSTER", "CLUSTER_TABLE")
	end
	local diff = compare_version(amapp_project_version, VERSION)
	if ret == 0 and cluster_exists == 1 then
		Update_AMAPP(amapp.lib_path, amapp_project_version, VERSION)
		Verify_cluster_GUID()
		Update_Cluster_Item_System()
		return true
	end
	if amapp_project_version == nil or amapp_project_version == 0 or diff == -1 then
		Update_AMAPP(amapp.lib_path, amapp_project_version, VERSION)
		Verify_cluster_GUID()
		Update_Cluster_Item_System()
		return true
	elseif diff == 0 then
		return true
	elseif diff == 1 then
		reaper.MB("This project was created with a newer version of AMAPP (v"..amapp_project_version.."). You are running v"..VERSION..".\n\nTo update, go to Extensions > ReaPack > Synchronize Packages.", "Newer Version Detected", 0)
		if reaper.MB("You can continue with your current version, but some features may not work as expected.\n\nA copy of the project will be saved to avoid modifying the original.\n\nContinue?", "Open Project", 1) == 1 then
			reaper.SetProjExtState(0, "AMAPP", "PROJECT_VERSION", VERSION)
			reaper.Main_OnCommand(41895, 0) 
			return true
		else
			return false
		end
	else
		return true
	end
end

local function Remove_FX_monitor_mute()
	local tab_visible = reaper.GetToggleCommandState(42072)
	local master_track = reaper.GetMasterTrack()
	local master_track_fx_count = reaper.TrackFX_GetRecCount(master_track)
	local fx_index = reaper.TrackFX_AddByName(master_track, "Mute Monitor Out While Render", true, 0)
	if master_track_fx_count == 0 or fx_index == -1 then return false end
	for i = 1, master_track_fx_count, 1 do
		fx_index = reaper.TrackFX_AddByName(master_track, "Mute Monitor Out While Render", true, 0)
		if fx_index == -1 then return true end
		reaper.TrackFX_Delete(master_track, fx_index+0x1000000)
	end
end

local function Verify_cluster_table()
	local _, sTable = reaper.GetProjExtState(0, "AMAPP", "CLUSTER_TABLE")
	local render_cluster_table = table.deserialize(sTable)
	if render_cluster_table == nil then render_cluster_table = {} end
	local table_modified = false
	for guid, c in pairs(render_cluster_table) do
		if not is_guid(guid) then
			render_cluster_table[guid] = nil
			render_cluster_table[c.cluster_guid] = c
			table_modified = true
		end
	end
	if not table_modified then return end
	sTable = table.serialize(render_cluster_table)
	reaper.SetProjExtState(0, "AMAPP", "CLUSTER_TABLE", sTable)
end

local function Startup_sequence()
	reaper.PreventUIRefresh(1)
	Remove_FX_monitor_mute()
	Verify_cluster_table()

	
	
	if ClusterAPI and ClusterAPI.store then
		ClusterAPI.store.load()  
		if ClusterAPI.store.is_dirty() then
			ClusterAPI.store.save()  
		end
	end

	
	if 0 == reaper.GetProjExtState(0, "AMAPP", "EXPORT_OPTIONS") then
		local export_options = Init_export_options()
		if reaper.HasExtState("AMAPP", "DEFAULT_EXPORT_OPTIONS") then
			local def_export_options = reaper.GetExtState("AMAPP", "DEFAULT_EXPORT_OPTIONS")
			export_options = table.deserialize(def_export_options) or export_options
		end
		reaper.SetProjExtState(0, "AMAPP", "EXPORT_OPTIONS", table.serialize(export_options))
		
		gui.projectStateChangeCount = reaper.GetProjectStateChangeCount(0)
	end

	reaper.PreventUIRefresh(-1)

	
	if amapp.trial_start == "" then
		amapp.trial_start = tostring(os.time())
		reaper.SetExtState("AMAPP", "trial_start", amapp.trial_start, true)
	end

	
	amapp.open_count = amapp.open_count + 1
	reaper.SetExtState("AMAPP", "open_count", tostring(amapp.open_count), true)

	
	
	if amapp.license_key ~= "" then
		local k = amapp.license_key
		gui._lv1 = (string.byte(k, 1) or 0) + (string.byte(k, 6) or 0) + (string.byte(k, 11) or 0)
	end
end




local function build_graph(list)
	return ClusterTree.build_graph(list, project_data.render_cluster_table)
end

local function build_tree(flat_list)
	local result, orphans_fixed = ClusterTree.build_tree_from_list(
		flat_list,
		project_data.render_cluster_table
	)

	
	if orphans_fixed then
		local sTable = table.serialize(project_data.render_cluster_table)
		reaper.SetProjExtState(0, "AMAPP", "CLUSTER_TABLE", sTable)
	end

	return result
end

local function UpdateRenderClusterTable()
	
	if gui.cluster_dragging then return end
	local selected_clusters = {}
	for k, v in pairs(project_data.render_cluster_list) do
		if v.is_selected then
			table.insert(selected_clusters, { cluster_id = v.cluster_id, cluster_guid = v.cluster_guid })
		end
	end
	project_data.render_cluster_list = {}
	local _, sTable = reaper.GetProjExtState(0, "AMAPP", "CLUSTER_TABLE")
	project_data.render_cluster_table = table.deserialize(sTable)
	if project_data.render_cluster_table == nil then project_data.render_cluster_table = {} end
	
	local clusters_need_fix = false
	local used_indices = {}
	local next_available_idx = 1

	
	for _, c in pairs(project_data.render_cluster_table) do
		if type(c) == "table" and type(c.idx) == "number" then
			if c.idx >= next_available_idx then
				next_available_idx = c.idx + 1
			end
		end
	end

	
	for guid_key, cluster in pairs(project_data.render_cluster_table) do
		if type(cluster) ~= "table" then goto continue end
		if cluster.idx == nil then
			cluster.idx = next_available_idx
			next_available_idx = next_available_idx + 1
			clusters_need_fix = true
		elseif used_indices[cluster.idx] then
			
			cluster.idx = next_available_idx
			next_available_idx = next_available_idx + 1
			clusters_need_fix = true
		end
		used_indices[cluster.idx] = true
		::continue::
	end

	
	for guid_key, cluster in pairs(project_data.render_cluster_table) do
		if type(cluster) == "table" and cluster.parent_guid then
			local parent = project_data.render_cluster_table[cluster.parent_guid]
			if parent then
				if not parent.children then
					parent.children = {}
					clusters_need_fix = true
				end
				
				local found = false
				for _, child_guid in ipairs(parent.children) do
					if child_guid == cluster.cluster_guid then
						found = true
						break
					end
				end
				if not found then
					table.insert(parent.children, cluster.cluster_guid)
					clusters_need_fix = true
				end
			end
		end
	end

	if clusters_need_fix then
		reaper.SetProjExtState(0, "AMAPP", "CLUSTER_TABLE", table.serialize(project_data.render_cluster_table))
		
		gui.projectStateChangeCount = reaper.GetProjectStateChangeCount(0)
	end
	for guid_key, cluster in pairs(project_data.render_cluster_table) do
		if cluster.region_guid ~= nil then
			
			if not RegionManager.ValidateRegionGUID(cluster.region_guid) then
				cluster.region_guid = nil
				reaper.SetProjExtState(0, "AMAPP", "CLUSTER_TABLE", table.serialize(project_data.render_cluster_table))
				
				gui.projectStateChangeCount = reaper.GetProjectStateChangeCount(0)
			end
		end
		local item = {
			idx = cluster.idx,
			cluster_guid = cluster.cluster_guid,
			cluster_id = cluster.cluster_id,
			cluster_color = cluster.cluster_color,
			parent_guid = cluster.parent_guid,
			children = cluster.children,
			group_visible = cluster.group_visible,
			is_loop = cluster.is_loop,
			is_selected = false,
			c_start = cluster.c_start,
			c_end = cluster.c_end,
			c_entry = cluster.c_entry,
			c_exit = cluster.c_exit,
			c_qn_start = cluster.c_qn_start,
			c_qn_end = cluster.c_qn_end,
			c_qn_entry = cluster.c_qn_entry,
			c_qn_exit = cluster.c_qn_exit,
			region_guid = cluster.region_guid
		}
		
		project_data.render_cluster_list[item.idx] = item
	end
	for k, v in pairs(project_data.render_cluster_list) do
		for key, value in pairs(selected_clusters) do
			if v.cluster_guid == value.cluster_guid then
				project_data.render_cluster_list[k].is_selected = true
			end
		end
	end

	if reaper.GetProjExtState(0, "AMAPP", "TCP_VISIBLE") == 1 then
		gui.focus_activated = true
	end
	gui.triggerFunction = false

	local _, set_sTable = reaper.GetProjExtState(0, "AMAPP", "SET_TABLE")
	project_data.set_table = table.deserialize(set_sTable)
	if project_data.set_table == nil then project_data.set_table = {} end

	
	if ClusterAPI and ClusterAPI.store then
		
		
		ClusterAPI.store.sync_from_legacy_table()
		project_data.cluster_items_table = ClusterAPI.get_legacy_items_table()
	else
		local _, items_sTable = reaper.GetProjExtState(0, "AMAPP", "CLUSTER_ITEMS")
		project_data.cluster_items_table = table.deserialize(items_sTable)
		if project_data.cluster_items_table == nil then project_data.cluster_items_table = {} end
	end

	project_data.render_cluster_list = build_tree(project_data.render_cluster_list)
	project_data.cluster_graph = build_graph(project_data.render_cluster_list)

	
	local _ck = amapp.license_key or ""
	if #_ck > 16 then
		gui._lv2 = tonumber(string.sub(_ck, 12, 15)) or 0
		gui._lv3 = (string.byte(_ck, 18) or 0) + (string.byte(_ck, 19) or 0)
	end
end


local function GetItemsFunc(cluster_list, force_deactivate)
	if cluster_list == nil then cluster_list = project_data.render_cluster_list end
	local selected_clusters_amount = 0
	reaper.PreventUIRefresh(1)
	for k, v in pairs(project_data.render_cluster_list) do
		if not v.is_selected then goto continue end
		selected_clusters_amount = 1 + selected_clusters_amount
		local suspendDeactivate = not gui.toggleDeactivate
		if force_deactivate ~= nil then
			suspendDeactivate = force_deactivate
		end
		if selected_clusters_amount > 1 then suspendDeactivate = true end
		Get_items_in_cluster(v, suspendDeactivate)
		::continue::
	end
	gui.triggerFunction = false
	reaper.PreventUIRefresh(-1)
end

local function SoloClusterItemsFunc(cluster_list)
	if cluster_list == nil then cluster_list = project_data.render_cluster_list end
	local selected_clusters_amount = 0
	reaper.PreventUIRefresh(1)
	for k, v in pairs(project_data.render_cluster_list) do
		if not v.is_selected then goto continue end
		
		
		
		
		
		

		
		Solo_items_in_cluster(v)
		::continue::
	end
	gui.triggerFunction = false
	reaper.PreventUIRefresh(-1)
end

local function ActivateAllClusters()
	local cluster_list = {}
	for k, v in pairs(project_data.render_cluster_list) do
		v.is_selected = true
		table.insert(cluster_list, v)
	end
	GetItemsFunc(cluster_list)
end

local function DeactivateSelectedClusters()
	reaper.PreventUIRefresh(1)
	for k, v in pairs(project_data.render_cluster_list) do
		if not v.is_selected then goto continue end
		Deactivate_items_in_cluster(v)
		::continue::
	end
	gui.triggerFunction = false
	reaper.PreventUIRefresh(-1)
end

local function SelectItemsInSelectedClusters()
	reaper.Undo_BeginBlock()
	reaper.PreventUIRefresh(1)
	
	reaper.SelectAllMediaItems(0, false)
	
	local _, items_sTable = reaper.GetProjExtState(0, "AMAPP", "CLUSTER_ITEMS")
	local cluster_items_table = table.deserialize(items_sTable)
	if cluster_items_table == nil then
		reaper.PreventUIRefresh(-1)
		reaper.Undo_EndBlock("AMAPP: Select Items in Clusters", -1)
		return
	end
	
	for k, cluster in pairs(project_data.render_cluster_list) do
		if not cluster.is_selected then goto continue end
		local items_in_cluster = cluster_items_table[cluster.cluster_guid]
		if items_in_cluster == nil then goto continue end
		for item_guid, item_props in pairs(items_in_cluster) do
			local item = reaper.BR_GetMediaItemByGUID(0, item_guid)
			if item then
				reaper.SetMediaItemSelected(item, true)
			end
		end
		::continue::
	end
	reaper.UpdateArrange()
	reaper.PreventUIRefresh(-1)
	reaper.Undo_EndBlock("AMAPP: Select Items in Clusters", -1)
end

local function UpdateActiveItems()
	if gui.toggleActivate or gui.update_clusters_is_toggled then
		GetItemsFunc()
	end
	gui.triggerFunction = false
end

local function ProjectChanged()
    local changeCount = reaper.GetProjectStateChangeCount(0)
    if changeCount ~= gui.projectStateChangeCount then
        gui.projectStateChangeCount = changeCount
        return true
	end
	return false
end

local function ToggleClusterLoop()
	if UndoManager then UndoManager:push("AMAPP: Toggle Cluster Loop") end
	for k, c in pairs(project_data.render_cluster_list) do
		if not c.is_selected then goto continue end
		if c.is_loop == gui.toggleLoop then goto continue end
		Set_Cluster_Loop(c.cluster_guid, gui.toggleLoop)
		UpdateRenderClusterTable()
		::continue::
	end
	reaper.Undo_OnStateChange("AMAPP: Toggle Cluster Loop")
end

local function SetClusterEntry()
	if UndoManager then UndoManager:push("AMAPP: Set Cluster Entry Point") end
	for k, c in pairs(project_data.render_cluster_list) do
		if not c.is_selected then goto continue end
		local pos, rgn_end = c.c_start, c.c_end
		local edit_pos = reaper.GetCursorPosition()
		local _in, _out
		if edit_pos > pos and edit_pos < rgn_end then
			_in = edit_pos
			_out = edit_pos
		end
		c.is_loop = false
		c.c_start, c.c_end, c.c_entry, c.c_exit = pos, rgn_end, _in, _out
		c.c_qn_start = reaper.TimeMap2_timeToQN(0, c.c_start)
		c.c_qn_end = reaper.TimeMap2_timeToQN(0, c.c_end)
		if _in then c.c_qn_entry = reaper.TimeMap2_timeToQN(0, c.c_entry) end
		if _out then c.c_qn_exit = reaper.TimeMap2_timeToQN(0, c.c_exit) end
		Set_Cluster_Boundaries(c)
		UpdateRenderClusterTable()
		::continue::
	end
	reaper.Undo_OnStateChange("AMAPP: Set Cluster Entry Point")
end

local function SetClusterLoopPoints()
	if UndoManager then UndoManager:push("AMAPP: Set Cluster Loop Points") end
	for k, c in pairs(project_data.render_cluster_list) do
		if not c.is_selected then goto continue end
		local pos, rgn_end = c.c_start, c.c_end
		local _in, _out = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
		if _in < pos or _in > rgn_end then
			_in = pos
		end
		if _out < pos or _out > rgn_end then
			_out = rgn_end
		end
		if pos ~= rgn_end then c.is_loop = true else c.is_loop = false end
		c.c_start, c.c_end, c.c_entry, c.c_exit = pos, rgn_end, _in, _out
		c.c_qn_start = reaper.TimeMap2_timeToQN(0, c.c_start)
		c.c_qn_end = reaper.TimeMap2_timeToQN(0, c.c_end)
		if _in then c.c_qn_entry = reaper.TimeMap2_timeToQN(0, c.c_entry) end
		if _out then c.c_qn_exit = reaper.TimeMap2_timeToQN(0, c.c_exit) end
		Set_Cluster_Boundaries(c)
		reaper.GetSetRepeat(1)
		UpdateRenderClusterTable()
		::continue::
	end
	reaper.Undo_OnStateChange("AMAPP: Set Cluster Loop Points")
end

local function ClearClusterBoundaries()
	if UndoManager then UndoManager:push("AMAPP: Clear Cluster Boundaries") end
	for k, c in pairs(project_data.render_cluster_list) do
		if not c.is_selected then goto continue end
		c.c_entry, c.c_exit, c.c_qn_entry, c.c_qn_exit = nil, nil, nil ,nil
		Set_Cluster_Boundaries(c)
		UpdateRenderClusterTable()
		::continue::
	end
	reaper.Undo_OnStateChange("AMAPP: Clear Cluster Boundaries")
end


local function FormatDuration(seconds)
	local mins = math.floor(seconds / 60)
	local secs = math.floor(seconds % 60)
	return string.format("%d:%02d", mins, secs)
end

local function InitRenderProgress(queue)
	local p = project_data.render_progress
	p.active = true
	p.current_index = 0
	p.total_count = #queue
	p.current_cluster = nil
	p.cluster_type = nil
	p.start_time = reaper.time_precise()
	p.anim_start_frame = nil  

	
	p.cluster_lengths = {}
	p.total_length = 0
	for i, item in ipairs(queue) do
		local cluster = item.cluster
		local length = (cluster.c_end or 0) - (cluster.c_start or 0)
		if length < 0 then length = 0 end
		p.cluster_lengths[i] = length
		p.total_length = p.total_length + length
	end

	
	if p.total_length <= 0 then p.total_length = 1 end

	p.completed_length = 0           
	p.current_cluster_start_time = nil 
	p.render_speed = 1.0             
	p.last_cluster_render_time = nil 
end

local function UpdateRenderProgress(index, cluster, cluster_type)
	local p = project_data.render_progress

	
	if p.current_index > 0 and p.current_index < index then
		
		if not p.completed_times then p.completed_times = {} end
		p.completed_times[p.current_index] = reaper.time_precise()

		
		local prev_length = p.cluster_lengths[p.current_index] or 0
		p.completed_length = p.completed_length + prev_length

		
		if p.current_cluster_start_time and prev_length > 0 then
			local actual_time = reaper.time_precise() - p.current_cluster_start_time
			p.last_cluster_render_time = actual_time
			
			
			local new_speed = actual_time / prev_length
			if p.current_index == 1 then
				
				p.render_speed = new_speed
			else
				
				p.render_speed = new_speed * 0.7 + p.render_speed * 0.3
			end
		end
	end

	p.current_index = index
	p.current_cluster = cluster
	p.cluster_type = cluster_type
	p.current_cluster_start_time = reaper.time_precise()
end


local render_overlay_ctx = nil
local render_overlay_hwnd = nil  

local function ClearRenderProgress()
	local p = project_data.render_progress
	p.active = false
	p.current_index = 0
	p.total_count = 0
	p.current_cluster = nil
	p.cluster_type = nil
	p.start_time = nil
	
	p.cluster_lengths = nil
	p.total_length = 0
	p.completed_length = 0
	p.current_cluster_start_time = nil
	p.render_speed = 1.0
	p.last_cluster_render_time = nil
	p.completed_times = {}
	p.render_complete = false
	project_data.render_progress.overlay_pos = nil
	
	render_overlay_ctx = nil
	render_overlay_hwnd = nil
end


local async_render = {
	active = false,
	queue = {},           
	batches = {},         
	current_batch_index = 0,
	current_index = 0,    
	current_batch_size = 0, 
	tcp_state_cache = {}, 
	focus_and_solo = false,
	focused_clusters = {},
	aborted = false,
	results = {},         
}


local ProcessNextClusterAsync

local function FinishAsyncRender()
	
	local export_options = render_session.export_options
	local project_render_folder_path = render_session.project_render_folder_path
	local render_start_time = render_session.start_time

	
	CleanupRenderSession(async_render.focused_clusters, async_render.focus_and_solo)

	
	for track, props in pairs(async_render.tcp_state_cache) do
		if props.hidden then reaper.SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0) end
		if props.collapsed_state then reaper.SetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT", props.collapsed_state) end
		if props.solo_state then reaper.SetMediaTrackInfo_Value(track, "I_SOLO", props.solo_state) end
	end

	
	if #async_render.results > 0 and export_options and project_render_folder_path then
		async_render.results = VerifyRenderedFiles(
			async_render.results,
			export_options,
			project_render_folder_path,
			render_start_time
		)
	end

	
	local success_count = 0
	local fail_count = 0
	for _, result in ipairs(async_render.results) do
		if result.success then
			success_count = success_count + 1
		else
			fail_count = fail_count + 1
		end
	end

	
	if #async_render.results > 0 then
		gui.render_summary_data = {
			results = async_render.results,
			total_time = project_data.render_progress.start_time and
				(reaper.time_precise() - project_data.render_progress.start_time) or 0,
			success_count = success_count,
			fail_count = fail_count,
			aborted = async_render.aborted
		}
		gui.show_render_summary = true
		
		project_data.render_progress.render_complete = true

		
		gui.waveform_selected_result = nil
		gui.waveform_peaks_cache = nil
		for _, r in ipairs(async_render.results) do
			if r.output_path and reaper.file_exists(r.output_path) then
				
				r.cluster_color = r.cluster_color or (project_data.render_cluster_table and project_data.render_cluster_table[r.cluster_guid] and project_data.render_cluster_table[r.cluster_guid].cluster_color)
				gui.waveform_selected_result = r
				break
			end
		end
	else
		
		ClearRenderProgress()
		project_data.render_in_progress = false
	end
	reaper.UpdateArrange()
	
	async_render.active = false
	async_render.queue = {}
	async_render.batches = {}
	async_render.current_batch_index = 0
	async_render.current_index = 0
	async_render.current_batch_size = 0
	async_render.tcp_state_cache = {}
	async_render.aborted = false
	async_render.results = {}
end

ProcessNextClusterAsync = function()
	if not async_render.active then return end
	if async_render.aborted then
		FinishAsyncRender()
		return
	end

	async_render.current_batch_index = async_render.current_batch_index + 1
	local batch_idx = async_render.current_batch_index

	if batch_idx > #async_render.batches then
		
		FinishAsyncRender()
		return
	end

	local batch = async_render.batches[batch_idx]
	local batch_items = batch.items
	local batch_type = batch.type

	
	
	local queue_idx = 0
	for i = 1, batch_idx - 1 do
		queue_idx = queue_idx + #async_render.batches[i].items
	end
	queue_idx = queue_idx + 1
	async_render.current_index = queue_idx
	async_render.current_batch_size = #batch_items  

	local first_cluster = batch_items[1].cluster
	UpdateRenderProgress(queue_idx, first_cluster, batch_type)

	
	reaper.defer(function()
		if async_render.aborted or not async_render.active then
			FinishAsyncRender()
			return
		end

		
		local batch_results = RenderBatch(batch_items, batch_type)

		
		
		if batch_results and #batch_results > 0 then
			
			local files_exist_count = 0
			local verified_results = {}
			for _, result in ipairs(batch_results) do
				local file_exists = result.output_path and reaper.file_exists(result.output_path)
				if file_exists then
					files_exist_count = files_exist_count + 1
					table.insert(verified_results, result)
				end
			end

			
			if files_exist_count < #batch_results then
				
				for _, result in ipairs(verified_results) do
					table.insert(async_render.results, result)
				end
				async_render.aborted = true
				FinishAsyncRender()
				return
			end

			
			for _, result in ipairs(batch_results) do
				table.insert(async_render.results, result)
			end
		end

		
		local p = project_data.render_progress
		if not p.completed_times then p.completed_times = {} end
		local completion_time = reaper.time_precise()
		for i = 1, #batch_items do
			local cluster_queue_idx = queue_idx + i - 1
			p.completed_times[cluster_queue_idx] = completion_time
		end

		
		reaper.defer(function()
			reaper.defer(ProcessNextClusterAsync)
		end)
	end)
end

local function StartAsyncRender(clusters_to_render, focus_and_solo, focused_clusters)
	if async_render.active then return false end

	
	if not InitRenderSession() then
		return false
	end

	
	
	
	local non_loops = {}  
	local loops = {}
	for _, cluster in pairs(clusters_to_render) do
		
		if cluster.children then goto continue_cluster end
		
		if cluster.c_start >= cluster.c_end then
			goto continue_cluster
		end
		if cluster.is_loop and cluster.c_entry and cluster.c_exit and
		   (cluster.c_start < cluster.c_entry or cluster.c_end > cluster.c_exit) then
			
			table.insert(non_loops, {cluster = cluster, type = "oneshot"})
		elseif cluster.is_loop then
			table.insert(loops, {cluster = cluster, type = "loop"})
		else
			table.insert(non_loops, {cluster = cluster, type = "oneshot"})
		end
		::continue_cluster::
	end

	
	
	local batches = {}
	if #non_loops > 0 then
		local non_loop_batches = GroupClustersIntoBatches(non_loops)
		for _, batch in ipairs(non_loop_batches) do
			table.insert(batches, {items = batch, type = "oneshot"})
		end
	end
	if #loops > 0 then
		local loop_batches = GroupClustersIntoBatches(loops)
		for _, batch in ipairs(loop_batches) do
			table.insert(batches, {items = batch, type = "loop"})
		end
	end

	
	local queue = {}
	for _, batch in ipairs(batches) do
		for _, item in ipairs(batch.items) do
			table.insert(queue, item)
		end
	end

	if #queue == 0 then
		CleanupRenderSession(focused_clusters, focus_and_solo)
		return false
	end

	
	local tcp_state_list = {}
	local total_tracks = reaper.CountTracks(0)
	for id = 0, total_tracks - 1 do
		local track = reaper.GetTrack(0, id)
		tcp_state_list[track] = { track = track }
		if not reaper.IsTrackVisible(track, false) then
			tcp_state_list[track].hidden = true
			reaper.SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 1)
		end
		if reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
			tcp_state_list[track].collapsed_state = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT")
			reaper.SetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT", 0)
		end
		if reaper.GetMediaTrackInfo_Value(track, "I_SOLO") > 0 then
			tcp_state_list[track].solo_state = reaper.GetMediaTrackInfo_Value(track, "I_SOLO")
			reaper.SetMediaTrackInfo_Value(track, "I_SOLO", 0)
		end
	end

	
	async_render.active = true
	async_render.queue = queue
	async_render.batches = batches  
	async_render.current_batch_index = 0
	async_render.current_index = 0
	async_render.tcp_state_cache = tcp_state_list
	async_render.focus_and_solo = focus_and_solo or false
	async_render.focused_clusters = focused_clusters or {}
	async_render.aborted = false
	async_render.results = {}

	
	InitRenderProgress(queue)

	
	reaper.defer(ProcessNextClusterAsync)

	return true
end

local function SetRecordedClusterBoundaries(cluster, item_table)
	local new_start, new_end
	for key, item in pairs(item_table) do
		local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
		local item_end = item_start + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
		if new_start == nil or new_start > item_start then new_start = item_start end
		if new_end == nil or new_end < item_end then new_end = item_end end
	end
	if new_start < new_end then
		cluster.c_start = reaper.SnapToGrid(0, new_start)
		cluster.c_end = reaper.SnapToGrid(0, new_end)
		local sel_start, sel_end = reaper.GetSet_LoopTimeRange2(0, false, true, 0,0,false)
		local time_selection = sel_start ~= sel_end
		if new_end > cluster.c_end and not time_selection then
			local ret, grid_div = reaper.GetSetProjectGrid(0, false)
			local sig_numerator, sig_denom = reaper.TimeMap_GetTimeSigAtTime(0, cluster.c_end)
			local beat_offset = grid_div * sig_denom
			local time_offset = reaper.TimeMap2_beatsToTime(0, beat_offset)
			local qn_time_offset = reaper.TimeMap2_timeToQN(0, cluster.c_end + time_offset)
			local qn_cluster_end = reaper.TimeMap2_timeToQN(0, cluster.c_end)
			local time_offset_measure = reaper.TimeMap_QNToMeasures(0, qn_time_offset)
			local cluster_end_measure = reaper.TimeMap_QNToMeasures(0, qn_cluster_end)
			if time_offset_measure > cluster_end_measure then
				local measure_start_time = reaper.TimeMap_GetMeasureInfo(0, time_offset_measure-1)
				cluster.c_end = measure_start_time
			else
				cluster.c_end = cluster.c_end + time_offset
			end
		elseif reaper.GetSetRepeat(-1) == 1 and time_selection then
			cluster.c_start = sel_start
			cluster.c_end = sel_end
		end
		cluster.c_qn_start = reaper.TimeMap2_timeToQN(0, cluster.c_start)
		cluster.c_qn_end = reaper.TimeMap2_timeToQN(0, cluster.c_end)
		if cluster.is_loop then
			cluster.c_entry, cluster.c_exit = cluster.c_start, cluster.c_end
			cluster.c_qn_entry = reaper.TimeMap2_timeToQN(0, cluster.c_entry)
			cluster.c_qn_exit = reaper.TimeMap2_timeToQN(0, cluster.c_exit)
		end
		Set_Cluster_Boundaries(cluster)
		UpdateRenderClusterTable()
	end
end

local function DuplicateClusterFunc()
	
	local clusters_to_duplicate = {}
	for k, c in pairs(project_data.render_cluster_list) do
		if c.is_selected then
			table.insert(clusters_to_duplicate, {key = k, cluster = c})
		end
	end
	
	for _, item in ipairs(clusters_to_duplicate) do
		local new_cluster_id = item.cluster.cluster_id .. "_dup"
		Duplicate_cluster(item.cluster, new_cluster_id)
		item.cluster.is_selected = false
	end
	
	UpdateRenderClusterTable()
	
	for _, item in ipairs(clusters_to_duplicate) do
		local new_idx = item.key + 1
		if project_data.render_cluster_list[new_idx] then
			project_data.render_cluster_list[new_idx].is_selected = true
		end
	end
end

local function _renderAllClusters()
	local selected_clusters = {}
	for k, v in pairs(project_data.render_cluster_list) do
		if v.is_selected then
			table.insert(selected_clusters, v)
		end
	end
	reaper.PreventUIRefresh(1)
	local total_tracks = reaper.CountTracks(0)
	local tcp_state_list = {}
	for id = 0, total_tracks-1, 1 do
		local track = reaper.GetTrack(0, id)
		tcp_state_list[track] = {
			track = track
		}
		if not reaper.IsTrackVisible(track, false) then
			tcp_state_list[track].hidden = true
			reaper.SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 1)
		end
		if reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
			local collapsed_state = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT")
			tcp_state_list[track].collapsed_state = collapsed_state
			reaper.SetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT", 0)
		end
		if reaper.GetMediaTrackInfo_Value(track, "I_SOLO") > 0 then
			local solo_state = reaper.GetMediaTrackInfo_Value(track, "I_SOLO")
			tcp_state_list[track].solo_state = solo_state
			reaper.SetMediaTrackInfo_Value(track, "I_SOLO", 0)
		end
	end
	
	local render_queue = {}
	for _, cluster in ipairs(project_data.render_cluster_table) do
		if not cluster.children then
			table.insert(render_queue, {cluster = cluster, type = "oneshot"})
		end
	end
	InitRenderProgress(render_queue)
	local function progress_callback(index, cluster, cluster_type)
		UpdateRenderProgress(index, cluster, cluster_type)
	end
	RenderClusters(project_data.render_cluster_table, gui.focus_activated and gui.solo_clusters_on_focus, selected_clusters, progress_callback)
	ClearRenderProgress()
	for track, props in pairs(tcp_state_list) do
		if props.hidden then reaper.SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0) end
		if props.collapsed_state ~= nil then reaper.SetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT", props.collapsed_state) end
		if props.solo_state ~= nil then reaper.SetMediaTrackInfo_Value(track, "I_SOLO", props.solo_state) end
	end
	reaper.PreventUIRefresh(-1)
end

local function _renderSelectedClusters()
	local selected_clusters = {}
	for k, v in pairs(project_data.render_cluster_list) do
		if v.is_selected then
			table.insert(selected_clusters, v)
		end
	end
	reaper.PreventUIRefresh(1)
	local total_tracks = reaper.CountTracks(0)
	local tcp_state_list = {}
	for id = 0, total_tracks-1, 1 do
		local track = reaper.GetTrack(0, id)
		tcp_state_list[track] = {
			track = track
		}
		if not reaper.IsTrackVisible(track, false) then
			tcp_state_list[track].hidden = true
			reaper.SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 1)
		end
		if reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
			local collapsed_state = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT")
			tcp_state_list[track].collapsed_state = collapsed_state
			reaper.SetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT", 0)
		end
		if reaper.GetMediaTrackInfo_Value(track, "I_SOLO") > 0 then
			local solo_state = reaper.GetMediaTrackInfo_Value(track, "I_SOLO")
			tcp_state_list[track].solo_state = solo_state
			reaper.SetMediaTrackInfo_Value(track, "I_SOLO", 0)
		end
	end
	
	local render_queue = {}
	for _, cluster in ipairs(selected_clusters) do
		if not cluster.children then
			table.insert(render_queue, {cluster = cluster, type = "oneshot"})
		end
	end
	InitRenderProgress(render_queue)
	local function progress_callback(index, cluster, cluster_type)
		UpdateRenderProgress(index, cluster, cluster_type)
	end
	RenderClusters(selected_clusters, gui.focus_activated and gui.solo_clusters_on_focus, selected_clusters, progress_callback)
	ClearRenderProgress()

	for track, props in pairs(tcp_state_list) do
		if props.hidden then reaper.SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0) end
		if props.collapsed_state ~= nil then reaper.SetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT", props.collapsed_state) end
		if props.solo_state ~= nil then reaper.SetMediaTrackInfo_Value(track, "I_SOLO", props.solo_state) end
	end
	reaper.PreventUIRefresh(-1)
end

local function DetectItemGroups()
	local count = reaper.CountSelectedMediaItems(0)
	if count == 0 then return nil end

	local items = {}
	for i = 0, count - 1 do
		local item = reaper.GetSelectedMediaItem(0, i)
		local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
		local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
		table.insert(items, {
			item = item,
			start_pos = pos,
			end_pos = pos + len
		})
	end

	table.sort(items, function(a, b) return a.start_pos < b.start_pos end)

	local groups = {}
	local current_group = {items[1]}
	local group_end = items[1].end_pos

	for i = 2, #items do
		local item = items[i]
		if item.start_pos <= group_end + 0.001 then
			table.insert(current_group, item)
			group_end = math.max(group_end, item.end_pos)
		else
			table.insert(groups, current_group)
			current_group = {item}
			group_end = item.end_pos
		end
	end
	table.insert(groups, current_group)

	local group_info = {}
	for i, group in ipairs(groups) do
		local g_start = group[1].start_pos
		local g_end = group[1].end_pos
		for _, item in ipairs(group) do
			g_start = math.min(g_start, item.start_pos)
			g_end = math.max(g_end, item.end_pos)
		end
		table.insert(group_info, {
			items = group,
			group_start = g_start,
			group_end = g_end,
			item_count = #group
		})
	end

	return group_info
end






local function ExpandTemplateName(template, index)
	local n_pattern = template:match("%$n+")
	if n_pattern then
		local padding = #n_pattern - 1  
		local num = index
		local formatted = string.format("%0" .. padding .. "d", num)
		return template:gsub("%$n+", formatted, 1)
	end

	local num_pattern = template:match("%$(%d+)")
	if num_pattern then
		local start_num = tonumber(num_pattern)
		local padding = #num_pattern
		local num = start_num + index - 1
		local formatted = string.format("%0" .. padding .. "d", num)
		return template:gsub("%$%d+", formatted, 1)
	end

	return template
end

local function CreateNewCluster(new_cluster_id, isLoop, isRegion, last_selected_cluster_idx, parent_guid)
	if UndoManager then UndoManager:push("AMAPP: Create New Render Cluster") end
	if last_selected_cluster_idx ~= nil then last_selected_cluster_idx = last_selected_cluster_idx + 1 end
	CreateNewRenderCluster(new_cluster_id, isLoop, isRegion, last_selected_cluster_idx, parent_guid)
	UpdateRenderClusterTable()
	for key, value in pairs(project_data.render_cluster_list) do
		value.is_selected = false
	end
	if last_selected_cluster_idx ~= nil then
		project_data.render_cluster_list[last_selected_cluster_idx].is_selected = true
	elseif #project_data.render_cluster_list > 0 then
		project_data.render_cluster_list[#project_data.render_cluster_list].is_selected = true
	end
	reaper.Undo_OnStateChange("AMAPP: Create New Render Cluster")
	gui.triggerFunction = false
end


local function CreateMultipleClusters(groups, template, isLoop, isRegion, createGroup)
	if UndoManager then UndoManager:push("AMAPP: Create Render Cluster Variations") end
	reaper.PreventUIRefresh(1)

	
	local last_selected_cluster_idx, parent_guid
	for guid, c in pairs(project_data.render_cluster_list) do
		if c.is_selected then
			last_selected_cluster_idx = c.idx
			parent_guid = c.parent_guid
		end
	end
	if last_selected_cluster_idx ~= nil then
		last_selected_cluster_idx = last_selected_cluster_idx + 1
	end

	
	local group_parent_guid = nil
	if createGroup then
		
		local group_name = template:gsub("%$n+", ""):gsub("%$%d+", "")
		group_name = group_name:gsub("_+$", ""):gsub("%-+$", "")  
		if group_name == "" then group_name = "Variations" end

		
		reaper.Main_OnCommand(40289, 0)  
		reaper.GetSet_LoopTimeRange(true, false, 0, 0, false)  

		
		group_parent_guid = CreateNewRenderCluster(group_name, false, false, last_selected_cluster_idx, parent_guid)
		UpdateRenderClusterTable()

		
		if last_selected_cluster_idx then
			last_selected_cluster_idx = last_selected_cluster_idx + 1
		end
	end

	local created_count = 0
	local num_groups = #groups

	
	for i, group in ipairs(groups) do
		local cluster_name = ExpandTemplateName(template, i)

		
		reaper.Main_OnCommand(40289, 0)  
		for _, item_info in ipairs(group.items) do
			reaper.SetMediaItemSelected(item_info.item, true)
		end

		
		reaper.GetSet_LoopTimeRange(true, false, group.group_start, group.group_end, false)

		
		local child_parent = createGroup and group_parent_guid or parent_guid
		CreateNewRenderCluster(cluster_name, isLoop, isRegion, last_selected_cluster_idx, child_parent)

		created_count = created_count + 1
		if last_selected_cluster_idx then
			last_selected_cluster_idx = last_selected_cluster_idx + 1
		end
	end

	
	UpdateRenderClusterTable()
	for key, value in pairs(project_data.render_cluster_list) do
		value.is_selected = false
	end

	
	if createGroup and group_parent_guid then
		for key, cluster in pairs(project_data.render_cluster_list) do
			if cluster.cluster_guid == group_parent_guid then
				cluster.is_selected = true
				break
			end
		end
	end

	reaper.PreventUIRefresh(-1)
	reaper.Undo_OnStateChange("AMAPP: Create " .. created_count .. " Render Cluster Variations")
	gui.triggerFunction = false
end

local function EditSelectedCluster(edit_buffer)
	
	local selected_cluster_index = nil
	for k, v in pairs(project_data.render_cluster_list) do
		if v.cluster_guid == edit_buffer.c.cluster_guid then
			Edit_Selected_Cluster(v, edit_buffer)
			selected_cluster_index = k
			break
		end
	end
	UpdateRenderClusterTable()
	project_data.render_cluster_list[selected_cluster_index].is_selected = true
	gui.triggerFunction = false
end

local function DeleteCluster(cluster, cluster_guid)
	if UndoManager then UndoManager:push("AMAPP: Render Cluster Deleted") end
	Delete_Selected_Cluster(cluster, cluster_guid)
	UpdateRenderClusterTable()
	reaper.Undo_OnStateChange("AMAPP: Render Cluster Deleted")
	if gui.focus_activated then
		Unfocus_view_clusters()
		gui.focus_activated = false
	end
	gui.triggerFunction = false
end

local function CreateNewSet(set_id)
	if UndoManager then UndoManager:push("AMAPP: Create New Set") end
	Create_New_Set(set_id)
	reaper.Undo_OnStateChange("AMAPP: Create New Set")
end

local function UpdateSetConfig(graph)
	if project_data.set_table == nil then return end
	if UndoManager then UndoManager:push("AMAPP: Update Set Configuration") end
	for i, s in pairs(project_data.set_table) do
		local clusters = {}
		for k, cs in pairs(graph) do
			if cs.set_guid ~= s.set_guid then goto next end
			if cs.value == false then goto next end
			table.insert(clusters, cs.cluster_guid)
			::next::
		end
		if #clusters == 0 then
			s.connected_clusters = nil
		else
			s.connected_clusters = clusters
		end
	end
	local set_sTable = table.serialize(project_data.set_table)
	reaper.SetProjExtState(0, "AMAPP", "SET_TABLE", set_sTable)
	reaper.Undo_OnStateChange("AMAPP: Update Set Configuration")
end

local function ClearAllSets()
	if UndoManager then UndoManager:push("AMAPP: Clear All Sets") end
	reaper.SetProjExtState(0, "AMAPP", "SET_TABLE", "{}")
	reaper.Undo_OnStateChange("AMAPP: Clear All Sets")
end

local function OpenRenderFolder()
	local function File_path_is_absolute(path)
		if package.config:sub(1, 1) == "\\" then
			
			return path:match("^%a:[\\/]")
				or path:match("^\\\\")
		else
			
			return path:sub(1, 1) == "/"
		end
	end

	local proj_dir = select(2,reaper.EnumProjects(-1)):match("^(.+[\\/])")
	local retval, export_options_string = reaper.GetProjExtState(0, "AMAPP", "EXPORT_OPTIONS")
	local export_options = table.deserialize(export_options_string) or {}
	if retval == 0 then
		local export_options_table = Init_export_options()
		export_options = export_options_table
		reaper.SetProjExtState(0, "AMAPP", "EXPORT_OPTIONS", table.serialize(export_options_table))
	end
	if export_options == nil then
		return reaper.MB("No export options have been set. Please set export options inside AMAPP.", "Error!", 0)
	end
	
	local file_path = Find_and_replace_wildcards("", nil, export_options.file_path or "AMAPP Exports")
    local project_render_folder_path = ""
	if File_path_is_absolute(file_path) then
		project_render_folder_path = file_path:match("^(.+[\\/])")
	else
		local proj_dir = select(2,reaper.EnumProjects(-1)):match("^(.+[\\/])")
		project_render_folder_path = proj_dir .. file_path .. string.char(92)
	end
    project_render_folder_path = string.gsub(project_render_folder_path, string.char(92), string.char(47))
	local open_path_cmd = "open '" .. project_render_folder_path .. "'"
	local win_open_path_cmd = "start %windir%\\explorer.exe " .. string.char(34) .. project_render_folder_path .. string.char(34)
	if reaper.GetOS() == "Win32" or reaper.GetOS() == "Win64" then
		open_path_cmd = win_open_path_cmd
	end
	os.execute(open_path_cmd)
end

local function ReorderItems(last_hovered_item, add_index, item_index, target_parent_guid)
	if UndoManager then UndoManager:push("AMAPP: Reorder Clusters") end
	
	local target_index = 0
	for k, v in pairs(project_data.render_cluster_list) do
		if v.cluster_guid == last_hovered_item then
			target_index = k + add_index
			break
		end
	end

	
	local directly_selected_guids = {}
	local all_selected_guids = {}

	local function mark_children_selected(cluster)
		if cluster.children then
			for _, child_guid in ipairs(cluster.children) do
				all_selected_guids[child_guid] = true
				local child_cluster = project_data.render_cluster_table[child_guid]
				if child_cluster then
					mark_children_selected(child_cluster)
				end
			end
		end
	end

	
	for k, v in pairs(project_data.render_cluster_list) do
		if v.is_selected then
			directly_selected_guids[v.cluster_guid] = true
			all_selected_guids[v.cluster_guid] = true
			mark_children_selected(v)
		end
	end

	
	local selected_items = {}
	local non_selected_items = {}
	for i = 1, #project_data.render_cluster_list do
		local cluster = project_data.render_cluster_list[i]
		if cluster then
			if all_selected_guids[cluster.cluster_guid] then
				table.insert(selected_items, cluster)
			else
				table.insert(non_selected_items, cluster)
			end
		end
	end

	
	local adjusted_target = target_index
	for i = 1, #project_data.render_cluster_list do
		if i < target_index then
			local cluster = project_data.render_cluster_list[i]
			if cluster and all_selected_guids[cluster.cluster_guid] then
				adjusted_target = adjusted_target - 1
			end
		end
	end

	
	local temp_render_cluster_table = {}
	local insert_position = math.max(1, math.min(adjusted_target, #non_selected_items + 1))

	
	for i = 1, insert_position - 1 do
		if non_selected_items[i] then
			table.insert(temp_render_cluster_table, non_selected_items[i])
		end
	end

	
	
	for _, cluster in ipairs(selected_items) do
		table.insert(temp_render_cluster_table, cluster)

		
		if directly_selected_guids[cluster.cluster_guid] then
			
			if cluster.parent_guid and project_data.render_cluster_table[cluster.parent_guid] then
				local old_parent = project_data.render_cluster_table[cluster.parent_guid]
				if old_parent.children then
					for i = #old_parent.children, 1, -1 do
						if old_parent.children[i] == cluster.cluster_guid then
							table.remove(old_parent.children, i)
						end
					end
				end
			end

			
			if target_parent_guid and project_data.render_cluster_table[target_parent_guid] then
				local new_parent = project_data.render_cluster_table[target_parent_guid]
				if not new_parent.children then
					new_parent.children = {}
				end
				
				local already_child = false
				for _, child_guid in ipairs(new_parent.children) do
					if child_guid == cluster.cluster_guid then
						already_child = true
						break
					end
				end
				if not already_child then
					table.insert(new_parent.children, cluster.cluster_guid)
				end
				project_data.render_cluster_table[cluster.cluster_guid].parent_guid = target_parent_guid
			else
				
				project_data.render_cluster_table[cluster.cluster_guid].parent_guid = nil
			end
		end
		
	end

	
	for i = insert_position, #non_selected_items do
		if non_selected_items[i] then
			table.insert(temp_render_cluster_table, non_selected_items[i])
		end
	end

	
	for idx, cluster in ipairs(temp_render_cluster_table) do
		if cluster.cluster_guid and project_data.render_cluster_table[cluster.cluster_guid] then
			project_data.render_cluster_table[cluster.cluster_guid].idx = idx
		end
	end

	UpdateRenderClusterExtProjState(project_data.render_cluster_table)
	UpdateRenderClusterTable()
	reaper.Undo_OnStateChange("AMAPP: Reorder Clusters")
end

local function AddItemsToGroup(target_group_guid)
	if not target_group_guid then return end

	local target_group = project_data.render_cluster_table[target_group_guid]
	if not target_group then return end

	if UndoManager then UndoManager:push("AMAPP: Add Clusters to Group") end

	
	if not target_group.children then
		target_group.children = {}
	end

	
	local items_to_add = {}
	for k, cluster in pairs(project_data.render_cluster_list) do
		if cluster.is_selected and cluster.cluster_guid ~= target_group_guid then
			
			local already_child = false
			for _, child_guid in ipairs(target_group.children) do
				if child_guid == cluster.cluster_guid then
					already_child = true
					break
				end
			end
			if not already_child then
				table.insert(items_to_add, cluster)
			end
		end
	end

	
	for _, cluster in ipairs(items_to_add) do
		if cluster.parent_guid and project_data.render_cluster_table[cluster.parent_guid] then
			local old_parent = project_data.render_cluster_table[cluster.parent_guid]
			if old_parent.children then
				for i = #old_parent.children, 1, -1 do
					if old_parent.children[i] == cluster.cluster_guid then
						table.remove(old_parent.children, i)
					end
				end
			end
		end
	end

	
	for _, cluster in ipairs(items_to_add) do
		table.insert(target_group.children, cluster.cluster_guid)
		project_data.render_cluster_table[cluster.cluster_guid].parent_guid = target_group_guid
	end

	UpdateRenderClusterExtProjState(project_data.render_cluster_table)
	UpdateRenderClusterTable()
	reaper.Undo_OnStateChange("AMAPP: Add Clusters to Group")
end

local function RemoveItemsFromGroup()
	if UndoManager then UndoManager:push("AMAPP: Remove Clusters from Group") end
	
	for k, cluster in pairs(project_data.render_cluster_list) do
		if cluster.is_selected and cluster.parent_guid then
			local parent = project_data.render_cluster_table[cluster.parent_guid]
			if parent and parent.children then
				for i = #parent.children, 1, -1 do
					if parent.children[i] == cluster.cluster_guid then
						table.remove(parent.children, i)
					end
				end
			end
			project_data.render_cluster_table[cluster.cluster_guid].parent_guid = nil
		end
	end

	UpdateRenderClusterExtProjState(project_data.render_cluster_table)
	UpdateRenderClusterTable()
	reaper.Undo_OnStateChange("AMAPP: Remove Clusters from Group")
end


local function GetSortedClusterIndices()
	local indices = {}
	for k, v in pairs(project_data.render_cluster_list) do
		if type(v) == "table" then
			table.insert(indices, k)
		end
	end
	table.sort(indices)
	return indices
end

local function SelectPreviousCluster(add_to_selection)
	local sorted_indices = GetSortedClusterIndices()
	if #sorted_indices == 0 then return end

	
	local selection_exists = false
	local selection_pos = 0  
	for i, idx in ipairs(sorted_indices) do
		local cluster = project_data.render_cluster_list[idx]
		if cluster and cluster.is_selected then
			selection_exists = true
			selection_pos = i
			break
		end
	end

	
	if not add_to_selection then
		for _, idx in ipairs(sorted_indices) do
			project_data.render_cluster_list[idx].is_selected = false
		end
	end

	
	local target_idx
	if not selection_exists then
		
		if gui.last_selected_item_idx and project_data.render_cluster_list[gui.last_selected_item_idx] then
			target_idx = gui.last_selected_item_idx
		else
			target_idx = sorted_indices[#sorted_indices]
		end
	elseif selection_pos == 1 then
		
		target_idx = sorted_indices[1]
	else
		
		target_idx = sorted_indices[selection_pos - 1]
	end

	if target_idx and project_data.render_cluster_list[target_idx] then
		project_data.render_cluster_list[target_idx].is_selected = true
		gui.toggleLoop = project_data.render_cluster_list[target_idx].is_loop
		gui.last_selected_item_idx = target_idx
	end
end

local function SelectNextCluster(add_to_selection)
	local sorted_indices = GetSortedClusterIndices()
	if #sorted_indices == 0 then return end

	
	local selection_exists = false
	local selection_pos = 0  
	for i, idx in ipairs(sorted_indices) do
		local cluster = project_data.render_cluster_list[idx]
		if cluster and cluster.is_selected then
			selection_exists = true
			selection_pos = i  
		end
	end

	
	if not add_to_selection then
		for _, idx in ipairs(sorted_indices) do
			project_data.render_cluster_list[idx].is_selected = false
		end
	end

	
	local target_idx
	if not selection_exists then
		
		if gui.last_selected_item_idx and project_data.render_cluster_list[gui.last_selected_item_idx] then
			target_idx = gui.last_selected_item_idx
		else
			target_idx = sorted_indices[1]
		end
	elseif selection_pos == #sorted_indices then
		
		target_idx = sorted_indices[#sorted_indices]
	else
		
		target_idx = sorted_indices[selection_pos + 1]
	end

	if target_idx and project_data.render_cluster_list[target_idx] then
		project_data.render_cluster_list[target_idx].is_selected = true
		gui.toggleLoop = project_data.render_cluster_list[target_idx].is_loop
		gui.last_selected_item_idx = target_idx
	end
end

local function MoveEditCursorToCluster()
	for k, v in pairs(project_data.render_cluster_list) do
		if v.is_selected then
			local region_pos, region_end = v.c_start, v.c_end
			if v.is_loop then
				region_pos = v.c_entry or v.c_start
				region_end = v.c_exit or v.c_end
				if region_pos == region_end then region_end = v.c_end end
			end
			if region_pos == nil or region_end == nil then return end
			if v.is_loop then
				reaper.PreventUIRefresh(1)
				reaper.GetSet_LoopTimeRange(true, true, region_pos, region_end, true)
				reaper.SetEditCurPos(region_pos, true, true)
				reaper.PreventUIRefresh(-1)
				reaper.GetSetRepeat(1)
			else
				local _, loop_end = reaper.GetSet_LoopTimeRange(false, true, region_pos, region_end, false)
				if loop_end == region_pos then reaper.GetSetRepeat(0) end
				reaper.SetEditCurPos(v.c_start, true, true)
			end
			return
		end
	end
end

local function FocusSelectedClusters()
	if project_data.render_cluster_list == nil or #project_data.render_cluster_list == 0 then	return end
	reaper.PreventUIRefresh(1)
	local selected_clusters = {}
	for k, v in pairs(project_data.render_cluster_list) do
		if v.is_selected then
			table.insert(selected_clusters, v)
		end
	end
	local project_length = reaper.GetProjectLength(0)
	local start_time = project_length
	local end_time = 0
	if #selected_clusters > 0 then
		Focus_view_selected_clusters(selected_clusters, gui.solo_clusters_on_focus)
		for k, v in pairs(selected_clusters) do
			local region_pos, region_end = v.c_start, v.c_end
			if region_pos == nil or region_end == nil then goto skip end
			if region_pos < start_time then start_time = region_pos end
			if region_end > end_time then end_time = region_end end
			::skip::
		end
		
		
	else
		Unfocus_view_clusters()
	end
	if start_time == project_length then start_time = 0 end
	if end_time == 0 then end_time = project_length end
	reaper.GetSet_ArrangeView2(0, true,  0, 0, start_time-4, end_time+4)
	reaper.PreventUIRefresh(-1)
end

local function UnfocusClusters()
	Unfocus_view_clusters()
	gui.cluster_armed = false
	reaper.SelectAllMediaItems(0, false)
end

local function SelectLastSelectedCluster()
	local selection_exists = false
	for k, v in pairs(project_data.render_cluster_list) do
		if v.is_selected then
			selection_exists = true
			break
		end
	end
	if selection_exists then return end
	project_data.render_cluster_list[gui.last_selected_item_idx].is_selected = true
	if gui.focus_activated then FocusSelectedClusters() end
end

local function ClearClusterSelection()
	for k, v in pairs(project_data.render_cluster_list) do
		v.is_selected = false
	end
end

local function CreateClusterGroup()
	gui.open_create_group = true
end

local function AddItemFunc()
	if UndoManager then UndoManager:push("AMAPP: Add Items to Cluster") end
	for k, c in pairs(project_data.render_cluster_list) do
		if c == nil or not c.is_selected then goto continue end
		ClusterAPI.set_items_in_cluster(c)
		::continue::
	end
	UpdateRenderClusterTable()  
	UpdateActiveItems()
	reaper.Undo_OnStateChange("AMAPP: Add Items to Cluster")
end

local function RemoveItemFunc()
	if UndoManager then UndoManager:push("AMAPP: Remove Items from Cluster") end
	for k, c in pairs(project_data.render_cluster_list) do
		if not c.is_selected then goto continue end
		ClusterAPI.remove_items_in_cluster(c)
		::continue::
	end
	UpdateRenderClusterTable()  
	UpdateActiveItems()
	if gui.focus_activated then
		FocusSelectedClusters()
	end
	reaper.Undo_OnStateChange("AMAPP: Remove Items from Cluster")
end


local function Migrate_export_options(export_options)
	if export_options == nil then return nil end
	
	if export_options.primary_output_format.format_code == nil then
		
		export_options.primary_output_format.format_code = 0
		export_options.primary_output_format.format = "WAV"
		
		export_options.primary_output_format.bit_depth = 2           
		export_options.primary_output_format.bit_depth_code = 2
		
		export_options.primary_output_format.flac_bit_depth = 1      
		export_options.primary_output_format.flac_bit_depth_code = 1
		export_options.primary_output_format.flac_compression = 5    
	end
	
	if export_options.overwrite_existing == nil then
		export_options.overwrite_existing = false
	end
	return export_options
end

local function LoadExportOptions()
	local _, export_table_string = reaper.GetProjExtState(0, "AMAPP", "EXPORT_OPTIONS")
	local export_options = table.deserialize(export_table_string)
	return Migrate_export_options(export_options)
end

local function Save_Cluster_Export_Options(buffer)
	local sTable = table.serialize(buffer)
	reaper.SetProjExtState(0, "AMAPP", "EXPORT_OPTIONS", sTable)
	reaper.MarkProjectDirty(0)
end

local function Save_Default_Export_Options(buffer)
	local sTable = table.serialize(buffer)
	reaper.SetExtState("AMAPP", "DEFAULT_EXPORT_OPTIONS", sTable, true)
end

local function UpdateStoredClusterItems()
	local tr_num = reaper.CountTracks()
	for i = 0, tr_num do
		local track = reaper.GetTrack(0, i)
		if track == nil then goto skip end
		local item_num = reaper.GetTrackNumMediaItems(track)
		local _, guid = reaper.GetSetMediaTrackInfo_String(track, "GUID", "", false)
		items_per_track[i] = {guid = guid, items = item_num}
		::skip::
	end
end

gui.cluster_recording = false
gui.cluster_rec_buffer = {}
gui.items_before_rec = 0
local function ClusterRecording_INIT()
	if gui.cluster_recording then return end
	for _, cluster in pairs(project_data.render_cluster_list) do
		if cluster.is_selected then
			table.insert(gui.cluster_rec_buffer, cluster)
		end
	end
	gui.cluster_recording = true
end

local function ClusterImporting_INIT()
	if gui.cluster_recording then return end
	for _, cluster in pairs(project_data.render_cluster_list) do
		if cluster.is_selected then
			table.insert(gui.cluster_rec_buffer, cluster)
		end
	end
end

local function AttachNewItemToCluster(cluster, item)
	local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
	local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

	local _, cluster_items_string = reaper.GetProjExtState(0, "AMAPP", "CLUSTER_ITEMS")
	local cluster_items = table.deserialize(cluster_items_string)
	if cluster_items == nil then cluster_items = {} end
	local existing_items = cluster_items[cluster.cluster_guid]
	if existing_items == nil then existing_items = {} end
	local item_table = {}
	if not (item_pos < cluster.c_start and (item_pos + item_len) <= cluster.c_start) and not (cluster.c_end <= item_pos) then
		local _curTake = reaper.GetMediaItemInfo_Value(item, "I_CURTAKE")
		local _take = reaper.GetTake( item, _curTake )
		local _, item_curTake
		if _take ~= nil then
			_, item_curTake = reaper.GetSetMediaItemTakeInfo_String(_take, "GUID", "", false)
		end
		local _item_cluster_table = {}
		local _, stringTable = reaper.GetSetMediaItemInfo_String(item, "P_EXT:AMAPP", "", false)
		local exists = false
		if stringTable == nil then
			goto continue
		elseif stringTable ~= "" then
			_item_cluster_table = parse_item_ext(stringTable)
		end
		if _item_cluster_table == nil then goto continue end
		for k, obj in pairs(_item_cluster_table) do
			if type(obj) == "table" and obj.cluster_guid == cluster.cluster_guid then
				_item_cluster_table[k].take = item_curTake
				stringTable = table.serialize(_item_cluster_table)
				reaper.GetSetMediaItemInfo_String(item, "P_EXT:AMAPP", stringTable, true)
				exists = true
				break
			end
		end
		::continue::
		if not exists then
			table.insert(_item_cluster_table, {cluster_guid = cluster.cluster_guid, cluster_id = cluster.cluster_id, take = item_curTake})
			stringTable = table.serialize(_item_cluster_table)
			reaper.GetSetMediaItemInfo_String(item, "P_EXT:AMAPP", stringTable, true)
		end
		local _, item_guid = reaper.GetSetMediaItemInfo_String(item, "GUID", "", false)
		item_table[item_guid] = {
			item_modified = os.time(),
			item_take_guid = item_curTake
		}
	end
	for item_guid, item_props_table in pairs(item_table) do
		existing_items[item_guid] = item_props_table
	end
	cluster_items[cluster.cluster_guid] = existing_items
	local c_string = table.serialize(cluster_items)
	reaper.SetProjExtState(0, "AMAPP", "CLUSTER_ITEMS", c_string)
end

local function ClusterRecording_DONE()
	local new_item_total = reaper.CountMediaItems()
	if new_item_total > gui.items_before_rec then
		local sel_items = reaper.CountSelectedMediaItems(0)
		local item_table = {}
		local i = 0
		while i < sel_items do
			local item = reaper.GetSelectedMediaItem(0, i)
			table.insert(item_table, item)
			i = i + 1
		end
		for _, cluster in pairs(gui.cluster_rec_buffer) do
			if cluster.c_start >= cluster.c_end then
				SetRecordedClusterBoundaries(cluster, item_table)
			end
			for _, item in pairs(item_table) do
				AttachNewItemToCluster(cluster, item)
			end
		end
	end
	if gui.focus_activated then FocusSelectedClusters() end
	gui.cluster_recording = false
	gui.cluster_rec_buffer = {}
end

local function ImportItemsIntoClusters()
	local new_item_total = reaper.CountMediaItems()
	if new_item_total > gui.items_before_rec then
		ClusterImporting_INIT()
		local sel_items = reaper.CountSelectedMediaItems(0)
		local item_table = {}
		local i = 0
		while i < sel_items do
			local item = reaper.GetSelectedMediaItem(0, i)
			table.insert(item_table, item)
			i = i + 1
		end
		for _, cluster in pairs(gui.cluster_rec_buffer) do
			if cluster.c_qn_start >= cluster.c_qn_end then
				SetRecordedClusterBoundaries(cluster, item_table)
			end
			for _, item in pairs(item_table) do
				AttachNewItemToCluster(cluster, item)
			end
		end
	end
	gui.cluster_rec_buffer = {}
end

local function NewItems()
	if gui.all_items ~= tonumber(reaper.CountMediaItems()) then
		gui.all_items = reaper.CountMediaItems()
		return true
	else
		return false
	end
end

local function ChangedItems()
	local undo_states = {
		"Move media items",
		"Resize media items",
		"Trim media items",
		"Trim items left of cursor",
		"Trim items right of cursor",
		"Trim selected portions of selected items",
		"Slip media items",
		"Snap media items",
		"Reorder adjacent items",
		"Nudge items",
		"Stretch items to fit time selection",
		"Stretch and loop items to fit time selection"
	}
	for _, value in pairs(undo_states) do
		if value == reaper.Undo_CanUndo2(0) then
			
			return true
		end
	end
	return false
end

local function UpdateGroupCollapseState(c_guid, state)
	if UndoManager then UndoManager:push("AMAPP: Toggle Group Collapse") end
	project_data.render_cluster_table[c_guid].group_visible = state
	local sTable = table.serialize(project_data.render_cluster_table)
	reaper.SetProjExtState(0, "AMAPP", "CLUSTER_TABLE", sTable)
	UpdateRenderClusterTable()
	reaper.Undo_OnStateChange("AMAPP: Toggle Group Collapse")
end


local function RefreshProjectData()
	local _, cluster_table_str = reaper.GetProjExtState(0, "AMAPP", "CLUSTER_TABLE")
	project_data.render_cluster_table = table.deserialize(cluster_table_str) or {}

	local _, set_table_str = reaper.GetProjExtState(0, "AMAPP", "SET_TABLE")
	project_data.set_table = table.deserialize(set_table_str) or {}

	local _, cluster_items_str = reaper.GetProjExtState(0, "AMAPP", "CLUSTER_ITEMS")
	project_data.cluster_items_table = table.deserialize(cluster_items_str) or {}

	
	UpdateRenderClusterTable()
end


local function CheckUndoRedoChanges()
	if UndoManager then
		UndoManager:check_reaper_undo(RefreshProjectData)
	end
end


gui.fonts = {}
gui.images = {}
gui.needs_context_recreation = false

local ctx  

local function CreateImGuiContext()
	
	ctx = ImGui.CreateContext("AMAPP Cluster Manager")

	
	
	gui.fonts.serif = ImGui.CreateFont("serif", ImGui.FontFlags_Bold)
	gui.fonts.sans_serif = ImGui.CreateFont("sans_serif", ImGui.FontFlags_Bold)
	gui.fonts.sans_serif_bold = ImGui.CreateFont("sans_serif", ImGui.FontFlags_Bold)
	gui.fonts.sans_serif_sm = ImGui.CreateFont("sans_serif", ImGui.FontFlags_Bold)
	gui.fonts.sans_serif_sm_thin = ImGui.CreateFont("sans_serif")  
	gui.fonts.mono_md_thin = ImGui.CreateFont("monospace")  
	gui.fonts.mono_bold = ImGui.CreateFont("monospace", ImGui.FontFlags_Bold)
	gui.fonts.mono_sm = ImGui.CreateFont("monospace", ImGui.FontFlags_Bold)
	ImGui.Attach(ctx, gui.fonts.serif)
	ImGui.Attach(ctx, gui.fonts.sans_serif)
	ImGui.Attach(ctx, gui.fonts.sans_serif_bold)
	ImGui.Attach(ctx, gui.fonts.sans_serif_sm)
	ImGui.Attach(ctx, gui.fonts.sans_serif_sm_thin)
	ImGui.Attach(ctx, gui.fonts.mono_md_thin)
	ImGui.Attach(ctx, gui.fonts.mono_bold)
	ImGui.Attach(ctx, gui.fonts.mono_sm)

	
	gui.font_sizes = {
		serif = 16,
		sans_serif = 14,
		sans_serif_bold = 18,
		sans_serif_sm = 12,
		sans_serif_sm_thin = 12,
		mono_md_thin = 15,
		mono_bold = 18,
		mono_sm = 10,
	}

	
	gui.images.mwm_logo = ImGui.CreateImage(amapp.lib_path .. "img/mwm logo mini.png")
	ImGui.Attach(ctx, gui.images.mwm_logo)
	gui.images.logo = ImGui.CreateImage(amapp.lib_path .. "img/AMAPP logo 7 micro.png")
	ImGui.Attach(ctx, gui.images.logo)
	gui.images.logo_w_text = ImGui.CreateImage(amapp.lib_path .. "img/AMAPP Logo 7 w text micro.png")
	ImGui.Attach(ctx, gui.images.logo_w_text)
	gui.images.logo_w_text_lg = ImGui.CreateImage(amapp.lib_path .. "img/AMAPP Logo 7 text lg.png")
	ImGui.Attach(ctx, gui.images.logo_w_text_lg)
	gui.images.mwm_avatar = ImGui.CreateImage(amapp.lib_path .. "img/mwm-avatar.png")
	ImGui.Attach(ctx, gui.images.mwm_avatar)
	gui.images.render_logo = ImGui.CreateImage(amapp.lib_path .. "img/AMAPP render in progress.png")
	ImGui.Attach(ctx, gui.images.render_logo)

	
	gui.font_stack_depth = 0

	
	gui.splitter = nil
	gui.splitter_overlay = nil

	
	gui.needs_context_recreation = false

	return ctx
end


ctx = CreateImGuiContext()
gui.ctx = ctx  
gui.lb_min_x, gui.lb_min_y, gui.lb_max_x, gui.lb_max_y = 0, 0, 0, 0
gui.listbox_width, gui.listbox_height = 400, 150
gui.lb_should_scroll = false
gui.reorder_engaged = false
gui.prevent_reorder = false
gui.pers_rect_min_x, gui.pers_rect_min_y, gui.pers_rect_max_x, gui.pers_rect_max_y = 0, 0, 0, 0
gui.reorder_item_clicked_index = 0
gui.reorder_prevent_clear_items = false
gui.splitter = nil
gui.splitter_overlay = nil
gui.win_flags = ImGui.WindowFlags_None|ImGui.WindowFlags_NoCollapse|ImGui.WindowFlags_TopMost
gui.toggle_menu_visible = true
gui.menu_bar_auto_visible = false  
gui.main_window_pos = {x = 0, y = 0}  
gui.main_window_size = {w = 0, h = 0}  
gui.menu_bar_height = 28  
gui.exit_btn_hovered = false  
gui.exit_btn_hovered_prev = false  
gui.exit_btn_active = false  
gui.exit_btn_active_prev = false  
project_data.project_name = ""
project_data.project_path = ""
project_data.render_mode_all = true
project_data.render_in_progress = false
project_data.render_pending = nil  
project_data.render_anim_start_frame = nil  

project_data.render_progress = {
	active = false,
	current_index = 0,
	total_count = 0,
	current_cluster = nil,
	cluster_type = nil,  
	start_time = 0,
	completed_times = {},  
}
gui.was_project_dirty = false
gui.silent_verification = false
gui.verifying_membership = false
gui.verification_successful = false
gui.verification_failed = false
gui.authorizing = false
gui.quit = false

gui.styles = {}
gui.styles.exit_btn = {
	{idx = ImGui.Col_Button, color = 0x11191c00},
	{idx = ImGui.Col_ButtonActive, color = 0x921925ff},
	{idx = ImGui.Col_ButtonHovered, color = 0xf9f9f9ff},
}
gui.styles.x_li_btn = {
	{idx = ImGui.Col_Button, color = 0x11191c00},
	{idx = ImGui.Col_ButtonActive, color = 0x333333ff},
	{idx = ImGui.Col_ButtonHovered, color = 0x333333ff},
}
gui.styles.tooltip_btn = {
	{idx = ImGui.Col_Button, color = 0x11191c00},
	{idx = ImGui.Col_ButtonActive, color = 0x0099ccff},
	{idx = ImGui.Col_ButtonHovered, color = 0x0099ccff},
}
gui.styles.accept_btn = {
	{idx = ImGui.Col_Button, color = 0x202f34ff},
	{idx = ImGui.Col_ButtonActive, color = 0x5cb85cff},
	{idx = ImGui.Col_ButtonHovered, color = 0x4c707eff},
}
gui.styles.error_btn = {
	{idx = ImGui.Col_Button, color = 0x921925ff},
	{idx = ImGui.Col_ButtonActive, color = 0x921925ff},
	{idx = ImGui.Col_ButtonHovered, color = 0x921925ff},
}

local function SetFrameCount(frame)
	if frame ~= gui.cached_frame_count then
		gui.cached_frame_count = frame
		gui.ctx_validated_this_frame = false  
	end
end

local function GetCachedFrameCount()
	return gui.cached_frame_count
end

local function ValidateCtxOnce()
	if not gui.ctx_validated_this_frame then
		gui.ctx_valid_this_frame = ImGui.ValidatePtr(ctx, "ImGui_Context*")
		gui.ctx_validated_this_frame = true
	end
	return gui.ctx_valid_this_frame
end


local function SafePushFont(ctx, font, size)
	if not ValidateCtxOnce() then return false end
	if font == nil or not ImGui.ValidatePtr(font, "ImGui_Font*") then return false end
	
	if not size then
		for name, f in pairs(gui.fonts) do
			if f == font then
				size = gui.font_sizes[name]
				break
			end
		end
	end
	size = size or 14  
	ImGui.PushFont(ctx, font, size)
	gui.font_stack_depth = (gui.font_stack_depth or 0) + 1
	return true
end

local function SafePopFont(ctx)
	if not ValidateCtxOnce() then return false end
	ImGui.PopFont(ctx)
	gui.font_stack_depth = gui.font_stack_depth - 1
	return true
end

local function GetFontStackDepth()
	return gui.font_stack_depth or 0
end

local function ResetFontStackTracking()
	gui.font_stack_depth = 0
end

local function CheckIfShiftIsPressed()
	if ImGui.IsKeyDown(ctx, ImGui.Key_LeftShift) or ImGui.IsKeyDown(ctx, ImGui.Key_RightShift) then
		return true
	else
		return false
	end
end

local function CheckIfCtrlIsPressed()
	if ImGui.IsKeyDown(ctx, ImGui.Key_LeftCtrl) or ImGui.IsKeyDown(ctx, ImGui.Key_RightCtrl) then
		return true
	else
		return false
	end
end

local function CheckIfAltIsPressed()
	if ImGui.IsKeyDown(ctx, ImGui.Key_LeftAlt) or ImGui.IsKeyDown(ctx, ImGui.Key_RightAlt) then
		return true
	else
		return false
	end
end

local function TriggerFunctionBool()
	local retval = ImGui.IsMouseReleased(ctx, 0)
	local mouse_x, mouse_y = ImGui.GetMousePos(ctx)
	local w_x, w_y = ImGui.GetWindowSize(ctx)
	if w_x < (600 + 20) then
		gui.lb_max_x = gui.lb_min_x + (w_x / 2) - 12
	end
	if w_y < 170 then
		gui.lb_max_y = gui.lb_min_y + w_y
	end
	local hovers_list = ImGui.IsMouseHoveringRect(ctx, gui.lb_min_x, gui.lb_min_y, gui.lb_max_x, gui.lb_max_y, true)
	if retval and hovers_list then
		gui.triggerFunction = true
	else
		gui.triggerFunction = false
	end
end

local function VerticalScrollToFirstItem(cluster)
	local m_tr
	if project_data.cluster_items_table[cluster.cluster_guid] == nil then return end
	for item_guid, props in pairs(project_data.cluster_items_table[cluster.cluster_guid]) do
		local item = reaper.BR_GetMediaItemByGUID(0, item_guid)
		if item == nil then goto skip end
		local tr = reaper.GetMediaItemInfo_Value(item, "P_TRACK")
		if type(tr) ~= number then goto skip end
		
		local idx = reaper.GetMediaTrackInfo_Value(tr, "IP_TRACKNUMBER")
		if m_tr == nil or idx < m_tr.idx then
			m_tr = {
				idx = idx,
			}
		end
		::skip::
	end
	if m_tr ~= nil then
		local tr = reaper.GetTrack(0, m_tr.idx-1)
		reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_SAVESEL"), 0)
		reaper.Main_OnCommand(40297, 0) 
		reaper.SetMediaTrackInfo_Value(tr, "I_SELECTED", 1)
		reaper.Main_OnCommand(40913, 0) 
		reaper.UpdateArrange()
		reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_RESTORESEL"), 0)
	end
end


local textColorCache = {}

local function TextColorBasedOnBgColor(bgColor)
	if bgColor == 0 or bgColor < 0x1000000 then return 0xffffffff end

	
	local cached = textColorCache[bgColor]
	if cached then return cached end

	
	local r = (bgColor >> 16) & 0xFF
	local g = (bgColor >> 8) & 0xFF
	local b = bgColor & 0xFF

	
	local result
	if (r * 0.299 + g * 0.587 + b * 0.114) >= 128 then
		result = 0x000000ff  
	else
		result = 0xffffffff  
	end

	textColorCache[bgColor] = result
	return result
end


local function decimalToHex(num)
	if num == 0 then return '0' end
	if num < 0 then return '-' .. decimalToHex(-num) end
	return string.format("%X", num)
end


local outlineColorCache = {}


local function OutlineColorBasedOnBgColor(bgColor, alpha)
	alpha = alpha or 0x60
	if bgColor == 0 or bgColor < 0x1000000 then return 0xffffff00 | alpha end

	
	local cacheKey = bgColor + (alpha << 24)
	local cached = outlineColorCache[cacheKey]
	if cached then return cached end

	
	local r = (bgColor >> 16) & 0xFF
	local g = (bgColor >> 8) & 0xFF
	local b = bgColor & 0xFF

	
	local result
	if (r * 0.299 + g * 0.587 + b * 0.114) >= 128 then
		result = 0x00000000 | alpha  
	else
		result = 0xffffff00 | alpha  
	end

	outlineColorCache[cacheKey] = result
	return result
end










local function DrawClusterMenuButton(draw_list, x, y, size, cluster_color, cluster, id, label_y1)
	local mx, my = ImGui.GetMousePos(ctx)
	local rounding = math.floor(size * 0.25)
	local x1, y1 = x, y
	local x2, y2 = x + size, y + size

	
	local is_hovered_raw = mx >= x1 and mx <= x2 and my >= y1 and my <= y2

	
	gui.cluster_menu_btn_was_hovered = gui.cluster_menu_btn_was_hovered or {}
	local was_hovered = gui.cluster_menu_btn_was_hovered[id] == true
	local is_new_hover = is_hovered_raw and not was_hovered
	gui.cluster_menu_btn_was_hovered[id] = is_hovered_raw

	local mouse_down = ImGui.IsMouseDown(ctx, ImGui.MouseButton_Left)

	gui.cluster_menu_btn_mouse_down_on_entry = gui.cluster_menu_btn_mouse_down_on_entry or {}
	if is_new_hover and mouse_down then
		gui.cluster_menu_btn_mouse_down_on_entry[id] = true
	elseif not is_hovered_raw then
		gui.cluster_menu_btn_mouse_down_on_entry[id] = nil
	elseif not mouse_down then
		gui.cluster_menu_btn_mouse_down_on_entry[id] = nil
	end

	local suppress_interaction = gui.cluster_menu_btn_mouse_down_on_entry[id] == true

	local is_hovered = is_hovered_raw and not suppress_interaction
	local is_pressed = is_hovered and mouse_down
	local is_clicked = is_hovered and ImGui.IsMouseReleased(ctx, ImGui.MouseButton_Left)

	
	local cc = cluster_color or 0x505050
	local cc_r = (cc >> 16) & 0xFF
	local cc_g = (cc >> 8) & 0xFF
	local cc_b = cc & 0xFF

	
	local luminance = cc_r * 0.299 + cc_g * 0.587 + cc_b * 0.114

	
	local bg_normal = (cc_r << 24) | (cc_g << 16) | (cc_b << 8) | 0xD0
	local bg_hovered, bg_pressed
	if luminance < 128 then
		
		local br = math.min(255, math.floor(cc_r * 1.3 + 30))
		local bg = math.min(255, math.floor(cc_g * 1.3 + 30))
		local bb = math.min(255, math.floor(cc_b * 1.3 + 30))
		bg_hovered = (br << 24) | (bg << 16) | (bb << 8) | 0xFF
		bg_pressed = (math.floor(cc_r * 0.7) << 24) | (math.floor(cc_g * 0.7) << 16) | (math.floor(cc_b * 0.7) << 8) | 0xFF
	else
		
		local dr = math.floor(cc_r * 0.8)
		local dg = math.floor(cc_g * 0.8)
		local db = math.floor(cc_b * 0.8)
		bg_hovered = (dr << 24) | (dg << 16) | (db << 8) | 0xFF
		bg_pressed = (math.floor(cc_r * 0.6) << 24) | (math.floor(cc_g * 0.6) << 16) | (math.floor(cc_b * 0.6) << 8) | 0xFF
	end

	
	local cluster_is_selected = false
	if project_data and project_data.render_cluster_list then
		for _, cc in pairs(project_data.render_cluster_list) do
			if cc.cluster_guid == cluster.cluster_guid then
				cluster_is_selected = cc.is_selected
				break
			end
		end
	end
	local is_focused = gui.focus_activated and cluster_is_selected
	local bg_color = bg_normal
	if is_pressed or is_focused then
		bg_color = bg_pressed
	elseif is_hovered then
		bg_color = bg_hovered
	end

	
	local looks_pressed = is_pressed or is_focused
	local highlight_alpha = looks_pressed and 0x10 or (is_hovered and 0x90 or 0x50)
	local shadow_alpha = looks_pressed and 0x60 or (is_hovered and 0x40 or 0x30)
	local highlight_col = 0xFFFFFF00 | highlight_alpha
	local shadow_col = 0x00000000 | shadow_alpha

	
	if not looks_pressed then
		ImGui.DrawList_AddRectFilled(draw_list, x1+1, y1+1, x2+1, y2+1, 0x00000030, rounding)
	end

	
	ImGui.DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, bg_color, rounding)

	
	ImGui.DrawList_AddLine(draw_list, x1+rounding, y1+0.5, x2-rounding, y1+0.5, highlight_col, 1)
	ImGui.DrawList_AddLine(draw_list, x1+0.5, y1+rounding, x1+0.5, y2-rounding, highlight_col, 1)
	ImGui.DrawList_AddLine(draw_list, x1+rounding, y2-0.5, x2-rounding, y2-0.5, shadow_col, 1)
	ImGui.DrawList_AddLine(draw_list, x2-0.5, y1+rounding, x2-0.5, y2-rounding, shadow_col, 1)

	
	local outline_alpha = is_hovered and 0x80 or 0x40
	ImGui.DrawList_AddRect(draw_list, x1, y1, x2, y2, 0x00000000 | outline_alpha, rounding, ImGui.DrawFlags_None, 1)

	
	if looks_pressed then
		ImGui.DrawList_AddLine(draw_list, x1+rounding, y1+1.5, x2-rounding, y1+1.5, 0x00000060, 1)
		ImGui.DrawList_AddLine(draw_list, x1+1.5, y1+rounding, x1+1.5, y2-rounding, 0x00000060, 1)
	end

	
	local show_modifier_indicator = is_hovered and (ImGui.IsKeyDown(ctx, ImGui.Mod_Ctrl) or ImGui.IsKeyDown(ctx, ImGui.Mod_Alt))
	local indicator_color = luminance < 128 and 0xFFFFFFFF or 0x000000FF

	if show_modifier_indicator then
		local cx, cy = x1 + size * 0.5, y1 + size * 0.5
		local half_h = size * 0.18
		local half_w = size * 0.15
		if ImGui.IsKeyDown(ctx, ImGui.Mod_Alt) then
			
			ImGui.DrawList_AddLine(draw_list, cx - half_w, cy - half_h, cx - half_w, cy + half_h, indicator_color, 1.5)
			ImGui.DrawList_AddLine(draw_list, cx - half_w, cy - half_h, cx + half_w - 1, cy - half_h, indicator_color, 1.5)
			ImGui.DrawList_AddLine(draw_list, cx + half_w - 1, cy - half_h, cx + half_w, cy, indicator_color, 1.5)
			ImGui.DrawList_AddLine(draw_list, cx + half_w, cy, cx + half_w - 1, cy + half_h, indicator_color, 1.5)
			ImGui.DrawList_AddLine(draw_list, cx + half_w - 1, cy + half_h, cx - half_w, cy + half_h, indicator_color, 1.5)
		else
			
			ImGui.DrawList_AddLine(draw_list, cx - half_w, cy + half_h, cx, cy - half_h, indicator_color, 1.5)
			ImGui.DrawList_AddLine(draw_list, cx, cy - half_h, cx + half_w, cy + half_h, indicator_color, 1.5)
			ImGui.DrawList_AddLine(draw_list, cx - half_w + 1, cy + 0.5, cx + half_w - 1, cy + 0.5, indicator_color, 1.5)
		end
	elseif gui.images.logo then
		local icon_padding = math.max(2, math.floor(size * 0.15))
		local icon_x1, icon_y1 = x1 + icon_padding, y1 + icon_padding
		local icon_x2, icon_y2 = x2 - icon_padding, y2 - icon_padding

		local tint_r, tint_g, tint_b
		if is_focused then
			tint_r, tint_g, tint_b = 255, 255, 255
		elseif is_hovered then
			if luminance < 128 then
				tint_r, tint_g, tint_b = 255, 255, 255
			else
				tint_r, tint_g, tint_b = 0, 0, 0
			end
		else
			if luminance < 128 then
				tint_r = math.min(255, math.floor(cc_r * 1.8 + 60))
				tint_g = math.min(255, math.floor(cc_g * 1.8 + 60))
				tint_b = math.min(255, math.floor(cc_b * 1.8 + 60))
			else
				tint_r = math.floor(cc_r * 0.4)
				tint_g = math.floor(cc_g * 0.4)
				tint_b = math.floor(cc_b * 0.4)
			end
		end
		local tint_color = (tint_r << 24) | (tint_g << 16) | (tint_b << 8) | 0xFF
		ImGui.DrawList_AddImage(draw_list, gui.images.logo, icon_x1, icon_y1, icon_x2, icon_y2, 0.0, 0.0, 1.0, 1.0, tint_color)
	end

	
	gui.cluster_menu_btn_hovered = is_hovered

	
	if is_hovered and gui.help_tooltips_enabled then
		ImGui.SetTooltip(ctx, gui.HELP_TOOLTIPS.cluster_menu_button)
	end

	
	gui.timeline_icon_pressed = gui.timeline_icon_pressed or {}
	if is_hovered and ImGui.IsMouseClicked(ctx, ImGui.MouseButton_Left) then
		gui.timeline_icon_pressed[id] = {
			alt = ImGui.IsKeyDown(ctx, ImGui.Mod_Alt),
			cmd = ImGui.IsKeyDown(ctx, ImGui.Mod_Ctrl),
			shift = ImGui.IsKeyDown(ctx, ImGui.Mod_Shift),
			cluster = cluster,
		}
	end

	local pressed_data = gui.timeline_icon_pressed[id]
	if is_clicked and pressed_data then
		
		local list_cluster = nil
		for _, cc in pairs(project_data.render_cluster_list) do
			if cc.cluster_guid == pressed_data.cluster.cluster_guid then
				list_cluster = cc
				break
			end
		end
		if list_cluster then
			if pressed_data.alt then
				
				reaper.PreventUIRefresh(1)
				Deactivate_items_in_cluster(list_cluster)
				reaper.PreventUIRefresh(-1)
			elseif pressed_data.cmd then
				
				reaper.PreventUIRefresh(1)
				Get_items_in_cluster(list_cluster, true)
				reaper.PreventUIRefresh(-1)
			elseif pressed_data.shift then
				
				list_cluster.is_selected = not list_cluster.is_selected
				gui.focus_activated = true
				FocusSelectedClusters()
			elseif gui.focus_activated and list_cluster.is_selected then
				
				UnfocusClusters()
				gui.focus_activated = false
			else
				
				for _, cc in pairs(project_data.render_cluster_list) do
					cc.is_selected = false
				end
				list_cluster.is_selected = true
				gui.focus_activated = true
				FocusSelectedClusters()
			end
		end
		gui.timeline_icon_pressed[id] = nil
	elseif not is_hovered and pressed_data then
		
		gui.timeline_icon_pressed[id] = nil
	end

	return is_hovered, is_pressed, is_clicked
end













local function DrawOffscreenClusterIndicator(draw_list, direction, y, height, cluster, cluster_color, viewport_left, viewport_right, i_pad_y)
	local margin = 8
	local btn_width = 48  
	local btn_height = height
	local x
	if direction == "left" then
		x = viewport_left + margin
	else
		x = viewport_right - btn_width - margin
	end

	
	local mx, my = reaper.GetMousePosition()

	local rounding = math.floor(btn_height * 0.25)
	local x1, y1 = x, y - btn_height
	local x2, y2 = x + btn_width, y

	
	local hover_x1, hover_x2 = x1, x2
	local hover_y1, hover_y2
	local _os = gui.overlay_os or reaper.GetOS()
	if _os == "OSX32" or _os == "OSX64" or _os == "macOS-arm64" then
		local sy = gui.overlay_sy or 0
		local pad_y = i_pad_y or gui.overlay_i_pad_y or 0
		hover_y1 = sy + pad_y - y2
		hover_y2 = sy + pad_y - y1
	else
		hover_y1, hover_y2 = y1, y2
	end

	local is_hovered = mx >= hover_x1 and mx <= hover_x2 and my >= hover_y1 and my <= hover_y2

	
	local mouse_down = reaper.JS_Mouse_GetState(1) == 1
	local is_pressed = is_hovered and mouse_down
	local is_clicked = is_hovered and gui.offscreen_btn_was_pressed and not mouse_down
	gui.offscreen_btn_was_pressed = is_pressed

	
	local cc = cluster_color or 0x505050
	local cc_r = (cc >> 16) & 0xFF
	local cc_g = (cc >> 8) & 0xFF
	local cc_b = cc & 0xFF
	local luminance = cc_r * 0.299 + cc_g * 0.587 + cc_b * 0.114

	
	local bg_normal = (cc_r << 24) | (cc_g << 16) | (cc_b << 8) | 0xD0
	local bg_hovered, bg_pressed
	if luminance < 128 then
		local br = math.min(255, math.floor(cc_r * 1.3 + 30))
		local bg = math.min(255, math.floor(cc_g * 1.3 + 30))
		local bb = math.min(255, math.floor(cc_b * 1.3 + 30))
		bg_hovered = (br << 24) | (bg << 16) | (bb << 8) | 0xFF
		bg_pressed = (math.floor(cc_r * 0.7) << 24) | (math.floor(cc_g * 0.7) << 16) | (math.floor(cc_b * 0.7) << 8) | 0xFF
	else
		local dr = math.floor(cc_r * 0.8)
		local dg = math.floor(cc_g * 0.8)
		local db = math.floor(cc_b * 0.8)
		bg_hovered = (dr << 24) | (dg << 16) | (db << 8) | 0xFF
		bg_pressed = (math.floor(cc_r * 0.6) << 24) | (math.floor(cc_g * 0.6) << 16) | (math.floor(cc_b * 0.6) << 8) | 0xFF
	end

	local bg_color = bg_normal
	if is_pressed then
		bg_color = bg_pressed
	elseif is_hovered then
		bg_color = bg_hovered
	end

	
	if not is_pressed then
		ImGui.DrawList_AddRectFilled(draw_list, x1+1, y1+1, x2+1, y2+1, 0x00000030, rounding)
	end

	
	ImGui.DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, bg_color, rounding)

	
	local highlight_alpha = is_pressed and 0x10 or (is_hovered and 0x90 or 0x50)
	local shadow_alpha = is_pressed and 0x60 or (is_hovered and 0x40 or 0x30)
	local highlight_col = 0xFFFFFF00 | highlight_alpha
	local shadow_col = 0x00000000 | shadow_alpha
	ImGui.DrawList_AddLine(draw_list, x1+rounding, y1+0.5, x2-rounding, y1+0.5, highlight_col, 1)
	ImGui.DrawList_AddLine(draw_list, x1+0.5, y1+rounding, x1+0.5, y2-rounding, highlight_col, 1)
	ImGui.DrawList_AddLine(draw_list, x1+rounding, y2-0.5, x2-rounding, y2-0.5, shadow_col, 1)
	ImGui.DrawList_AddLine(draw_list, x2-0.5, y1+rounding, x2-0.5, y2-rounding, shadow_col, 1)

	
	local icon_padding = 4
	local arrow_size = math.floor(btn_height * 0.35)
	local icon_size = btn_height - icon_padding * 2
	local center_y = y1 + btn_height / 2

	
	local arrow_color = luminance < 128 and 0xFFFFFFFF or 0x000000FF
	local arrow_cx
	if direction == "left" then
		arrow_cx = x1 + icon_padding + arrow_size / 2
		ImGui.DrawList_AddTriangleFilled(draw_list,
			arrow_cx + arrow_size / 2, center_y - arrow_size / 2,
			arrow_cx - arrow_size / 2, center_y,
			arrow_cx + arrow_size / 2, center_y + arrow_size / 2,
			arrow_color)
	else
		arrow_cx = x2 - icon_padding - arrow_size / 2
		ImGui.DrawList_AddTriangleFilled(draw_list,
			arrow_cx - arrow_size / 2, center_y - arrow_size / 2,
			arrow_cx + arrow_size / 2, center_y,
			arrow_cx - arrow_size / 2, center_y + arrow_size / 2,
			arrow_color)
	end

	
	if gui.images and gui.images.logo then
		local icon_x1, icon_y1, icon_x2, icon_y2
		if direction == "left" then
			icon_x1 = x1 + icon_padding + arrow_size + 4
			icon_x2 = icon_x1 + icon_size
		else
			icon_x2 = x2 - icon_padding - arrow_size - 4
			icon_x1 = icon_x2 - icon_size
		end
		icon_y1 = y1 + icon_padding
		icon_y2 = icon_y1 + icon_size

		local tint_r, tint_g, tint_b
		if luminance < 128 then
			tint_r, tint_g, tint_b = 255, 255, 255
		else
			tint_r = math.floor(cc_r * 0.4)
			tint_g = math.floor(cc_g * 0.4)
			tint_b = math.floor(cc_b * 0.4)
		end
		local tint_color = (tint_r << 24) | (tint_g << 16) | (tint_b << 8) | 0xFF
		ImGui.DrawList_AddImage(draw_list, gui.images.logo, icon_x1, icon_y1, icon_x2, icon_y2, 0.0, 0.0, 1.0, 1.0, tint_color)
	end

	
	if is_hovered then
		gui.hovering_item_button = true
	end

	return is_clicked
end



local function DrawClusterContextMenu()
	if not gui.cluster_menu_open then return end

	local cluster = gui.cluster_menu_cluster
	local cluster_color = gui.cluster_menu_color
	local label_y1 = gui.cluster_menu_label_y1

	if not cluster then
		gui.cluster_menu_open = false
		return
	end

	
	local cc = cluster_color or 0x505050
	local cc_r = (cc >> 16) & 0xFF
	local cc_g = (cc >> 8) & 0xFF
	local cc_b = cc & 0xFF
	local luminance = cc_r * 0.299 + cc_g * 0.587 + cc_b * 0.114

	
	local popup_bg = (cc_r << 24) | (cc_g << 16) | (cc_b << 8) | 0xF0
	local text_color = luminance < 128 and 0xFFFFFFFF or 0x000000FF
	local border_col = luminance < 128 and 0xFFFFFF40 or 0x00000040

	ImGui.PushStyleColor(ctx, ImGui.Col_WindowBg, popup_bg)
	ImGui.PushStyleColor(ctx, ImGui.Col_Text, text_color)
	ImGui.PushStyleColor(ctx, ImGui.Col_Border, border_col)
	ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowRounding, 4)
	ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowBorderSize, 1)
	ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, 8, 6)

	
	if label_y1 then
		local popup_height = 180
		ImGui.SetNextWindowPos(ctx, gui.cluster_menu_btn_x or 0, label_y1 - popup_height + 20, ImGui.Cond_Appearing)
	end

	SafePushFont(ctx, gui.fonts.sans_serif_sm)

	
	local window_flags = ImGui.WindowFlags_NoTitleBar |
	                     ImGui.WindowFlags_NoResize |
	                     ImGui.WindowFlags_NoMove |
	                     ImGui.WindowFlags_AlwaysAutoResize |
	                     ImGui.WindowFlags_NoSavedSettings |
	                     ImGui.WindowFlags_NoFocusOnAppearing

	local visible, open = ImGui.Begin(ctx, "cluster_context_menu_window", true, window_flags)

	if visible then
		
		local wx, wy = ImGui.GetWindowPos(ctx)
		local ww, wh = ImGui.GetWindowSize(ctx)
		gui.cluster_menu_bounds = {x = wx, y = wy, w = ww, h = wh}

		
		local popup_hovered = ImGui.IsWindowHovered(ctx,
			ImGui.HoveredFlags_RootAndChildWindows |
			ImGui.HoveredFlags_AllowWhenBlockedByActiveItem)

		
		local btn_hovered = gui.cluster_menu_btn_hovered

		
		if popup_hovered or btn_hovered then
			
			gui.cluster_menu_leave_time = nil
		else
			
			if not gui.cluster_menu_leave_time then
				gui.cluster_menu_leave_time = reaper.time_precise()
			else
				local elapsed = reaper.time_precise() - gui.cluster_menu_leave_time
				if elapsed >= 0.3 then
					
					gui.cluster_menu_open = false
					gui.cluster_menu_leave_time = nil
				end
			end
		end

		
		local hover_bg = luminance < 128 and 0xFFFFFF20 or 0x00000020
		ImGui.PushStyleColor(ctx, ImGui.Col_HeaderHovered, hover_bg)

		if ImGui.MenuItem(ctx, "Edit Cluster...") then
			for _, c in pairs(project_data.render_cluster_list) do
				c.is_selected = c.cluster_guid == cluster.cluster_guid
			end
			gui.timeline_gui_edit_clicked = true
			gui.cluster_menu_open = false
		end

		if ImGui.MenuItem(ctx, "Audition...") then
			for _, c in pairs(project_data.render_cluster_list) do
				c.is_selected = c.cluster_guid == cluster.cluster_guid
			end
			gui.audition_cluster = cluster
			gui.show_audition_popup = true
			gui.cluster_menu_open = false
		end

		ImGui.Separator(ctx)

		if ImGui.MenuItem(ctx, "Create group") then
			for _, c in pairs(project_data.render_cluster_list) do
				c.is_selected = c.cluster_guid == cluster.cluster_guid
			end
			CreateClusterGroup()
			gui.cluster_menu_open = false
		end

		if ImGui.MenuItem(ctx, "Duplicate") then
			for _, c in pairs(project_data.render_cluster_list) do
				c.is_selected = c.cluster_guid == cluster.cluster_guid
			end
			DuplicateClusterFunc()
			gui.cluster_menu_open = false
		end

		ImGui.Separator(ctx)

		if ImGui.MenuItem(ctx, "Select items in cluster") then
			for _, c in pairs(project_data.render_cluster_list) do
				c.is_selected = c.cluster_guid == cluster.cluster_guid
			end
			SelectItemsInSelectedClusters()
			gui.cluster_menu_open = false
		end

		if ImGui.MenuItem(ctx, "Activate Cluster") then
			reaper.PreventUIRefresh(1)
			Get_items_in_cluster(cluster, true)  
			reaper.PreventUIRefresh(-1)
			gui.cluster_menu_open = false
		end

		if ImGui.MenuItem(ctx, "Deactivate Cluster") then
			reaper.PreventUIRefresh(1)
			Deactivate_items_in_cluster(cluster)
			reaper.PreventUIRefresh(-1)
			gui.cluster_menu_open = false
		end

		ImGui.Separator(ctx)

		if ImGui.MenuItem(ctx, "Render Selected") then
			for _, c in pairs(project_data.render_cluster_list) do
				c.is_selected = c.cluster_guid == cluster.cluster_guid
			end
			local clusters_to_render = {cluster}
			local focus_and_solo = gui.focus_activated and gui.solo_clusters_on_focus
			project_data.render_pending = {
				clusters = clusters_to_render,
				focus_and_solo = focus_and_solo,
				focused_clusters = clusters_to_render
			}
			project_data.render_in_progress = true
			project_data.render_anim_start_frame = GetCachedFrameCount()
			gui.cluster_menu_open = false
		end

		if ImGui.MenuItem(ctx, "Render Options...") then
			for _, c in pairs(project_data.render_cluster_list) do
				c.is_selected = c.cluster_guid == cluster.cluster_guid
			end
			gui.open_export_options = true
			gui.cluster_menu_open = false
		end

		ImGui.Separator(ctx)

		if ImGui.MenuItem(ctx, "Delete") then
			for _, c in pairs(project_data.render_cluster_list) do
				c.is_selected = c.cluster_guid == cluster.cluster_guid
			end
			gui.delete_cluster_clicked = true
			gui.cluster_menu_open = false
		end

		ImGui.PopStyleColor(ctx)  
		ImGui.End(ctx)
	end

	
	if not open then
		gui.cluster_menu_open = false
		gui.cluster_menu_id = nil
		gui.cluster_menu_cluster = nil
		gui.cluster_menu_color = nil
		gui.cluster_menu_btn_x = nil
		gui.cluster_menu_leave_time = nil
		gui.cluster_menu_btn_hovered = nil
		gui.cluster_menu_bounds = nil
		gui.cluster_menu_label_y1 = nil
	end

	SafePopFont(ctx)
	ImGui.PopStyleVar(ctx, 3)
	ImGui.PopStyleColor(ctx, 3)
end


local ITEM_BTN_MIN_SIZE = 12
local ITEM_BTN_MAX_SIZE = 20
local ITEM_BTN_TRACK_RATIO = 0.38
local ITEM_BTN_PADDING = 8


local function GetItemButtonSize(track_h)
	local size = math.floor(track_h * ITEM_BTN_TRACK_RATIO)
	return math.max(ITEM_BTN_MIN_SIZE, math.min(ITEM_BTN_MAX_SIZE, size))
end

local function CanShowItemButton(item_w, item_h, btn_size)
	local min_w = btn_size + ITEM_BTN_PADDING * 2
	return item_w >= min_w
end

local ITEM_BTN_LEFT_PADDING = 10

local function GetItemButtonPos(x1, y1, x2, y2, btn_size, bounds)
	
	local btn_x = x1 + ITEM_BTN_LEFT_PADDING
	local btn_y = y2 - btn_size - ITEM_BTN_PADDING
	
	local item_h = y2 - y1
	if item_h < btn_size + ITEM_BTN_PADDING * 2 then
		btn_y = y1 + (item_h - btn_size) * 0.5
	end

	
	local item_left = x1 + ITEM_BTN_LEFT_PADDING
	local item_right = x2 - ITEM_BTN_PADDING

	
	local min_x = item_left
	local max_right = item_right

	
	if bounds and bounds.cluster_left then
		min_x = math.max(min_x, bounds.cluster_left + ITEM_BTN_LEFT_PADDING)
	end
	if bounds and bounds.cluster_right then
		max_right = math.min(max_right, bounds.cluster_right - ITEM_BTN_PADDING)
	end

	
	if bounds and bounds.viewport_left then
		min_x = math.max(min_x, bounds.viewport_left + ITEM_BTN_LEFT_PADDING)
	end
	if bounds and bounds.viewport_right then
		max_right = math.min(max_right, bounds.viewport_right - ITEM_BTN_PADDING)
	end

	
	local max_x = max_right - btn_size

	
	if max_x < min_x then
		max_x = min_x
	end

	
	btn_x = math.max(min_x, math.min(max_x, btn_x))

	
	local btn_right = btn_x + btn_size
	if btn_right > max_right then
		btn_x = max_right - btn_size
	end

	return btn_x, btn_y
end










local function DrawItemActionButton(draw_list, x, y, btn_size, cluster_color, is_in_cluster, id, is_item_selected, is_focused)
	local rounding = math.floor(btn_size * 0.2)
	local x1, y1 = x, y
	local x2, y2 = x + btn_size, y + btn_size

	
	
	local mx, my = reaper.GetMousePosition()

	
	local hover_x1, hover_x2 = x1, x2
	local hover_y1, hover_y2
	local _os = gui.overlay_os or reaper.GetOS()
	if _os == "OSX32" or _os == "OSX64" or _os == "macOS-arm64" then
		
		local sy = gui.overlay_sy or 0
		local i_pad_y = gui.overlay_i_pad_y or 0
		
		hover_y1 = sy + i_pad_y - y2
		hover_y2 = sy + i_pad_y - y1
	else
		
		hover_y1, hover_y2 = y1, y2
	end

	local is_hovered_manual = mx >= hover_x1 and mx <= hover_x2 and my >= hover_y1 and my <= hover_y2

	
	gui.item_btn_rects_next[id] = {x1 = hover_x1, y1 = hover_y1, x2 = hover_x2, y2 = hover_y2}
	gui.item_btn_was_hovered_next[id] = is_hovered_manual

	
	local was_hovered = gui.item_btn_was_hovered[id] == true
	local is_new_hover = is_hovered_manual and not was_hovered

	
	local mouse_down = reaper.JS_Mouse_GetState(1) == 1  

	
	if is_new_hover and mouse_down then
		gui.item_btn_mouse_down_on_entry[id] = true
	elseif not is_hovered_manual then
		
		gui.item_btn_mouse_down_on_entry[id] = nil
	elseif not mouse_down then
		
		gui.item_btn_mouse_down_on_entry[id] = nil
	end

	
	local suppress_interaction = gui.item_btn_mouse_down_on_entry[id] == true

	
	if is_hovered_manual and not suppress_interaction then
		gui.hovering_item_button = true
	end

	
	ImGui.SetCursorScreenPos(ctx, x1, y1)
	local is_clicked_raw = ImGui.InvisibleButton(ctx, "item_btn_" .. id, btn_size, btn_size)
	local is_hovered_raw = ImGui.IsItemHovered(ctx) or is_hovered_manual
	local is_pressed_raw = ImGui.IsItemActive(ctx)

	
	local is_clicked = is_clicked_raw and not suppress_interaction
	local is_hovered = is_hovered_raw and not suppress_interaction
	local is_pressed = is_pressed_raw and not suppress_interaction

	
	if is_hovered then
		gui.item_btn_any_hovered = true
		gui.item_btn_hovered_is_in_cluster = is_in_cluster
	end

	
	local show_hover_visual = is_hovered or (gui.item_btn_any_hovered_prev and is_item_selected and gui.item_btn_hovered_is_in_cluster_prev == is_in_cluster)

	
	local bg_normal = 0x505050FF
	local bg_hovered = 0x707070FF
	local bg_pressed = 0x383838FF

	local bg_color
	if is_pressed or (is_focused and is_in_cluster) then
		
		bg_color = bg_pressed
	elseif show_hover_visual then
		
		bg_color = bg_hovered
	elseif is_in_cluster then
		
		local cc = cluster_color or 0x505050
		local cc_r = (cc >> 16) & 0xFF
		local cc_g = (cc >> 8) & 0xFF
		local cc_b = cc & 0xFF
		bg_color = (cc_r << 24) | (cc_g << 16) | (cc_b << 8) | 0xFF
	else
		
		bg_color = bg_normal
	end

	
	local looks_pressed = is_pressed or (is_focused and is_in_cluster)
	if not looks_pressed then
		ImGui.DrawList_AddRectFilled(draw_list, x1+1, y1+1, x2+1, y2+1, 0x00000060, rounding)
	end

	
	ImGui.DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, bg_color, rounding)

	
	local highlight_alpha = looks_pressed and 0x20 or (show_hover_visual and 0xA0 or 0x60)
	local shadow_alpha = looks_pressed and 0x80 or (show_hover_visual and 0x60 or 0x40)
	local highlight_col = 0xFFFFFF00 | highlight_alpha
	local shadow_col = 0x00000000 | shadow_alpha

	ImGui.DrawList_AddLine(draw_list, x1+rounding, y1+0.5, x2-rounding, y1+0.5, highlight_col, 1)
	ImGui.DrawList_AddLine(draw_list, x1+0.5, y1+rounding, x1+0.5, y2-rounding, highlight_col, 1)
	ImGui.DrawList_AddLine(draw_list, x1+rounding, y2-0.5, x2-rounding, y2-0.5, shadow_col, 1)
	ImGui.DrawList_AddLine(draw_list, x2-0.5, y1+rounding, x2-0.5, y2-rounding, shadow_col, 1)

	
	local outline_alpha = show_hover_visual and 0x90 or 0x50
	ImGui.DrawList_AddRect(draw_list, x1, y1, x2, y2, 0x00000000 | outline_alpha, rounding, ImGui.DrawFlags_None, 1)

	
	local icon_padding = math.max(2, math.floor(btn_size * 0.15))
	local icon_x1, icon_y1 = x1 + icon_padding, y1 + icon_padding
	local icon_x2, icon_y2 = x2 - icon_padding, y2 - icon_padding
	local line_thickness = math.max(2, math.floor(btn_size * 0.12))

	if show_hover_visual then
		
		local sign_color
		local cx = (icon_x1 + icon_x2) / 2
		local cy = (icon_y1 + icon_y2) / 2
		if is_in_cluster then
			
			sign_color = 0xFF4444FF
			ImGui.DrawList_AddLine(draw_list, icon_x1+1, cy, icon_x2-1, cy, sign_color, line_thickness)
		else
			
			sign_color = 0x44FF44FF
			ImGui.DrawList_AddLine(draw_list, icon_x1+1, cy, icon_x2-1, cy, sign_color, line_thickness)
			ImGui.DrawList_AddLine(draw_list, cx, icon_y1+1, cx, icon_y2-1, sign_color, line_thickness)
		end

		
		if is_hovered then
			local sel_count = reaper.CountSelectedMediaItems(0)
			
			if not is_item_selected then
				sel_count = sel_count + 1
			end
			if sel_count < 1 then sel_count = 1 end
			if is_in_cluster then
				ImGui.SetTooltip(ctx, "Remove " .. sel_count .. " item" .. (sel_count > 1 and "s" or "") .. " from cluster")
			else
				ImGui.SetTooltip(ctx, "Add " .. sel_count .. " item" .. (sel_count > 1 and "s" or "") .. " to cluster")
			end
		end
	else
		
		if gui.images.logo then
			local tint_r, tint_g, tint_b
			local tint_alpha = 0xFF

			if is_focused and is_in_cluster then
				
				tint_r, tint_g, tint_b = 255, 255, 255
			else
				
				local bg_rgb = (bg_color >> 8) & 0xFFFFFF
				local bg_r = (bg_rgb >> 16) & 0xFF
				local bg_g = (bg_rgb >> 8) & 0xFF
				local bg_b = bg_rgb & 0xFF
				local bg_luminance = bg_r * 0.299 + bg_g * 0.587 + bg_b * 0.114

				if bg_luminance < 128 then
					local brighten = 1.8
					tint_r = math.min(255, math.floor(bg_r * brighten + 60))
					tint_g = math.min(255, math.floor(bg_g * brighten + 60))
					tint_b = math.min(255, math.floor(bg_b * brighten + 60))
				else
					local darken = 0.4
					tint_r = math.floor(bg_r * darken)
					tint_g = math.floor(bg_g * darken)
					tint_b = math.floor(bg_b * darken)
				end

				if not is_in_cluster then
					tint_alpha = 0x80
				end
			end

			local tint_color = (tint_r << 24) | (tint_g << 16) | (tint_b << 8) | tint_alpha
			ImGui.DrawList_AddImage(draw_list, gui.images.logo, icon_x1, icon_y1, icon_x2, icon_y2, 0.0, 0.0, 1.0, 1.0, tint_color)
		end
	end

	
	if is_pressed then
		ImGui.DrawList_AddLine(draw_list, x1+rounding, y1+1.5, x2-rounding, y1+1.5, 0x00000050, 1)
		ImGui.DrawList_AddLine(draw_list, x1+1.5, y1+rounding, x1+1.5, y2-rounding, 0x00000050, 1)
	end

	return is_hovered, is_pressed, is_clicked
end

gui.hovering_cluster_edit = false
gui.hovering_item_button = false  
gui.offscreen_btn_was_pressed = false  
gui.item_btn_rects = {}  
gui.item_btn_rects_next = {}  
gui.item_btn_mouse_down_on_entry = {}  
gui.item_btn_was_hovered = {}  
gui.item_btn_was_hovered_next = {}  
gui.item_btn_any_hovered = false  
gui.item_btn_any_hovered_prev = false  
gui.item_btn_hovered_is_in_cluster = false  
gui.item_btn_hovered_is_in_cluster_prev = false  
gui.cluster_menu_open = false  
gui.cluster_menu_id = nil
gui.cluster_menu_cluster = nil
gui.cluster_menu_color = nil
gui.cluster_menu_bounds = nil  
gui.cluster_menu_label_y1 = nil  
gui.mouse_drag_offset = 0	
gui.c_drag_area = -1 
gui.buf_cluster_items = {}
gui.buf_cluster_data = {}
gui.main_dpi_scale = ImGui.GetWindowDpiScale(ctx)
gui.dpi_scale = ImGui.GetWindowDpiScale(ctx)
gui.inv_dpi_scale = 1/gui.dpi_scale
gui.rec_arm_alpha = 255
gui.fade_direction = -1
gui.fade_speed = 5

local function scale(_in)
	return _in * gui.inv_dpi_scale
end

local function Timeline_GUI()
	if not project_data or not project_data.render_cluster_table or not project_data.render_cluster_list then return false end
	local main_wnd = reaper.GetMainHwnd()
	if not main_wnd then return false end
	local track_window = reaper.JS_Window_FindChildByID(main_wnd, 0x3E8)
	if not track_window then return false end

	local selected_clusters = {}
	for guid, cluster in pairs(project_data.render_cluster_list) do
		if cluster.is_selected then
			table.insert(selected_clusters, cluster)
		else
			if cluster.cluster_guid == nil then goto skip end
			gui.buf_cluster_items[cluster.cluster_guid] = nil
			gui.buf_cluster_data[cluster.cluster_guid] = nil
		end
		::skip::
	end

	local retval, main_left, main_top, main_right, main_bot = reaper.BR_Win32_GetWindowRect(main_wnd)
	local sx, sy = reaper.JS_Window_ClientToScreen(track_window, 0, 0)
	gui.overlay_sy = sy  
	local function Round(n)
		return n % 1 >= 0.5 and (n+1 - n%1) or n//1
	end

	local function Get_zoom_and_arrange_start()
		local zoom_lvl = reaper.GetHZoomLevel() 
		local Arr_start_time = reaper.GetSet_ArrangeView2(0, false, 0, 0) 
		return zoom_lvl, Arr_start_time
	end

	
	local function Convert_time_to_pixel(t_start, t_end)
		local zoom_lvl, Arr_start_time = Get_zoom_and_arrange_start()
		local x = Round((t_start - Arr_start_time) * zoom_lvl)
		local w = Round(t_end * zoom_lvl)
		return x, w
	end

	local function Convert_pixel_to_time(x, arr_viewport_start, arr_viewport_width)
		local zoom_lvl, Arr_start_time = Get_zoom_and_arrange_start()
		local width_px = arr_viewport_width / zoom_lvl
		local time = (x - arr_viewport_start) / zoom_lvl + Arr_start_time
		local time_end =  Arr_start_time + width_px
		return time, time_end
	end

	local window_flags = 	ImGui.WindowFlags_NoDecoration	     	|
							ImGui.WindowFlags_AlwaysAutoResize   	|
							ImGui.WindowFlags_NoNav					|
							ImGui.WindowFlags_NoBackground			|
							ImGui.WindowFlags_NoMove				|
							ImGui.WindowFlags_NoFocusOnAppearing	|
							ImGui.WindowFlags_NoScrollWithMouse

	
	
	
	
	local minimap_hover_now = false
	if gui.minimap_bar_rects then
		local pmx, pmy = reaper.GetMousePosition()
		for _, rect in ipairs(gui.minimap_bar_rects) do
			if pmx >= rect.x1 and pmx <= rect.x2 and pmy >= rect.y1 and pmy <= rect.y2 then
				minimap_hover_now = true
				break
			end
		end
	end
	
	
	
	local mouse_down_now = reaper.JS_Mouse_GetState(1) == 1
	
	
	
	if mouse_down_now and gui.minimap_prev_mouse_down == false then
		gui.minimap_press_was_on_bar = minimap_hover_now
	end
	if not mouse_down_now then
		gui.minimap_press_was_on_bar = nil
	end
	gui.minimap_prev_mouse_down = mouse_down_now
	if mouse_down_now and not gui.minimap_press_was_on_bar then
		minimap_hover_now = false
	end
	gui.hovering_minimap = minimap_hover_now

	local enable_input = gui.hovering_cluster_edit or gui.hovering_item_button or gui.hovering_minimap

	if not enable_input then
		window_flags = 		window_flags | ImGui.WindowFlags_NoInputs
	end
	
	gui.hovering_item_button = false

	local mx, my = reaper.GetMousePosition()
	local viewport = ImGui.GetMainViewport(ctx)
	local work_pos_x, work_pos_y = ImGui.Viewport_GetWorkPos(viewport)
	local work_size_w, work_size_h = ImGui.Viewport_GetWorkSize(viewport)
	local _, width, height = reaper.JS_Window_GetClientSize(track_window)
	local _, left, top, right, bottom = reaper.JS_Window_GetClientRect(track_window)
	local full_width, full_height = reaper.JS_Window_ScreenToClient(main_wnd, 0, 0)
	local pad_y = 0
	local _os = reaper.GetOS()
	if _os == "OSX32" or _os == "OSX64" or _os == "macOS-arm64" then
		pad_y = full_height - top
	end
	if _os == "Win32" or _os == "Win64" then
		left, top = ImGui.PointConvertNative(ctx, left, top, false)
		bottom, right = ImGui.PointConvertNative(ctx, bottom, right, false)
		width, height = ImGui.PointConvertNative(ctx, width, height, false)
		width = width + (4*scale(gui.dpi_scale - 1))   
		height = height + (6*scale(gui.dpi_scale - 1)) 
		sy = scale(sy)
		work_pos_y = sy
	end
	work_pos_y = work_pos_y + pad_y
	local i_pad_y = work_pos_y
	gui.overlay_i_pad_y = i_pad_y  
	gui.overlay_os = _os  
	ImGui.SetNextWindowPos(ctx, left - 1, work_pos_y - 1, ImGui.Cond_Always, 0, 0)
	ImGui.SetNextWindowSize(ctx, width + 2, height + 2, ImGui.Cond_Always)
	ImGui.SetNextWindowBgAlpha(ctx, 0.0)
	local rv, open = ImGui.Begin(ctx, "AMAPP GUI overlay", nil, window_flags)
	if not rv then return open end

	
	if enable_input then
		local wheel_v = ImGui.GetMouseWheel(ctx)
		if wheel_v ~= 0 then
			local scroll_dir = wheel_v > 0 and -1 or 1
			
			local shift_held = ImGui.IsKeyDown(ctx, ImGui.Mod_Shift)
			if shift_held then
				reaper.CSurf_OnScroll(scroll_dir, 0)
			else
				reaper.CSurf_OnScroll(0, scroll_dir)
			end
		end
	end

	gui.dpi_scale = ImGui.GetWindowDpiScale(ctx)
	gui.inv_dpi_scale = 1/gui.dpi_scale
	work_size_h = work_size_h * (gui.main_dpi_scale/gui.dpi_scale)

	
	local offscreen_left_clusters = {}
	local offscreen_right_clusters = {}
	local viewport_right = left + width

	
	
	if gui.focus_activated then
		local focus_draw_list = ImGui.GetWindowDrawList(ctx)
		local dark_fill = 0x000000A0
		
		local cluster_regions = {}
		for _, c in pairs(selected_clusters) do
			local cl
			for _, v in pairs(project_data.render_cluster_table) do
				if v.cluster_guid == c.cluster_guid then cl = v; break end
			end
			if cl and cl.c_qn_start and cl.c_qn_end then
				local cs = reaper.TimeMap2_QNToTime(0, cl.c_qn_start)
				local ce = reaper.TimeMap2_QNToTime(0, cl.c_qn_end)
				local px_s, w_s = Convert_time_to_pixel(cs, 0)
				local px_e, w_e = Convert_time_to_pixel(ce, 0)
				if px_s then
					local x1 = px_s + left
					local x2 = px_e + left
					table.insert(cluster_regions, {x1 = x1, x2 = x2})
				end
			end
		end
		
		table.sort(cluster_regions, function(a, b) return a.x1 < b.x1 end)
		
		local y_top = i_pad_y
		local y_bot = i_pad_y + work_pos_y + work_size_h
		local cur_x = work_pos_x
		for _, region in ipairs(cluster_regions) do
			if region.x1 > cur_x then
				ImGui.DrawList_AddRectFilled(focus_draw_list, cur_x, y_top, region.x1, y_bot, dark_fill)
			end
			if region.x2 > cur_x then cur_x = region.x2 end
		end
		
		if cur_x < work_pos_x + work_size_w then
			ImGui.DrawList_AddRectFilled(focus_draw_list, cur_x, y_top, work_pos_x + work_size_w, y_bot, dark_fill)
		end
	end

	
	gui.hovering_cluster_edit = false

	
	
	if gui.minimap_visible then
		local draw_list = ImGui.GetWindowDrawList(ctx)
		local bar_height = 8
		local minimap_padding = 4
		local label_bar_offset = 5
		local minimap_y_base = i_pad_y + height - minimap_padding - bar_height

		local selected_guids = {}
		for _, c in pairs(project_data.render_cluster_list) do
			if c.is_selected then selected_guids[c.cluster_guid] = true end
		end

		local minimap_items = {}
		for guid, cl in pairs(project_data.render_cluster_table) do
			if cl.c_qn_start and cl.c_qn_end and not cl.children then
				local pos = reaper.TimeMap2_QNToTime(0, cl.c_qn_start)
				local rgnend = reaper.TimeMap2_QNToTime(0, cl.c_qn_end)
				if pos and rgnend and rgnend > pos then
					local px_start, px_width = Convert_time_to_pixel(pos, rgnend - pos)
					if px_start then
						if _os == "Win32" or _os == "Win64" then
							px_start = scale(px_start)
							if gui.dpi_scale ~= 1 then px_width = scale(px_width) end
						end
						local x1 = px_start + left
						local x2 = x1 + px_width
						table.insert(minimap_items, {
							cluster = cl,
							x1 = x1, x2 = x2,
							is_selected = selected_guids[cl.cluster_guid] == true,
						})
					end
				end
			end
		end

		table.sort(minimap_items, function(a, b) return a.x1 < b.x1 end)

		
		
		local visible_items = {}
		for _, item in ipairs(minimap_items) do
			if not (item.is_selected and gui.timeline_gui_visible) then
				table.insert(visible_items, item)
			end
		end

		
		local selected_ranges = {}
		if gui.timeline_gui_visible then
			for _, sc in ipairs(selected_clusters) do
				if not sc.children and sc.c_qn_start and sc.c_qn_end then
					local sc_pos = reaper.TimeMap2_QNToTime(0, sc.c_qn_start)
					local sc_end = reaper.TimeMap2_QNToTime(0, sc.c_qn_end)
					local sc_px, sc_w = Convert_time_to_pixel(sc_pos, sc_end - sc_pos)
					if sc_px then
						if _os == "Win32" or _os == "Win64" then
							sc_px = scale(sc_px)
							if gui.dpi_scale ~= 1 then sc_w = scale(sc_w) end
						end
						table.insert(selected_ranges, {x1 = sc_px + left, x2 = sc_px + left + sc_w})
					end
				end
			end
		end

		
		for _, item in ipairs(visible_items) do
			item.overlaps_selected = false
			for _, sr in ipairs(selected_ranges) do
				if item.x1 < sr.x2 and item.x2 > sr.x1 then
					item.overlaps_selected = true; break
				end
			end
		end

		
		
		local function pack_rows(items)
			local rows = {}
			for _, item in ipairs(items) do
				local assigned_row = nil
				for row_idx, row in ipairs(rows) do
					local fits = true
					for _, occupied in ipairs(row) do
						if item.x1 < occupied.x2 and item.x2 > occupied.x1 then
							fits = false; break
						end
					end
					if fits then assigned_row = row_idx; break end
				end
				if not assigned_row then
					assigned_row = #rows + 1
					rows[assigned_row] = {}
				end
				table.insert(rows[assigned_row], {x1 = item.x1, x2 = item.x2})
				item.row = assigned_row
			end
		end

		local overlapping = {}
		local non_overlapping = {}
		for _, item in ipairs(visible_items) do
			if item.overlaps_selected then
				table.insert(overlapping, item)
			else
				table.insert(non_overlapping, item)
			end
		end
		pack_rows(overlapping)
		pack_rows(non_overlapping)

		local row_height = bar_height + 2
		
		local mx, my = reaper.GetMousePosition()
		local hover_mx, hover_my = mx, my
		
		local use_mac_invert = _os == "OSX32" or _os == "OSX64" or _os == "macOS-arm64"

		gui.minimap_bar_rects = {} 
		
		local mouse_down = reaper.JS_Mouse_GetState(1) == 1
		local minimap_clicked = mouse_down and not gui.minimap_mouse_was_down
		gui.minimap_mouse_was_down = mouse_down

		
		
		
		
		
		
		
		local EXPAND_SPEED = 0.25
		local COLLAPSE_DELAY = 0.5
		local MAX_STACK_ROWS = 8
		
		local trigger_top_imgui = minimap_y_base
		local trigger_bottom_imgui = minimap_y_base + bar_height
		local stay_top_imgui = minimap_y_base - (MAX_STACK_ROWS - 1) * row_height - bar_height - label_bar_offset
		local stay_bottom_imgui = minimap_y_base + bar_height
		local trigger_top_y, trigger_bottom_y, stay_top_y, stay_bottom_y
		if use_mac_invert then
			local sy_val = gui.overlay_sy or 0
			local ipy = gui.overlay_i_pad_y or 0
			trigger_top_y = sy_val + ipy - trigger_bottom_imgui
			trigger_bottom_y = sy_val + ipy - trigger_top_imgui
			stay_top_y = sy_val + ipy - stay_bottom_imgui
			stay_bottom_y = sy_val + ipy - stay_top_imgui
		else
			trigger_top_y, trigger_bottom_y = trigger_top_imgui, trigger_bottom_imgui
			stay_top_y, stay_bottom_y = stay_top_imgui, stay_bottom_imgui
		end
		local mouse_in_x_band = mx >= left and mx <= left + width
		local mouse_in_trigger = mouse_in_x_band and my >= trigger_top_y and my <= trigger_bottom_y
		local mouse_in_stay = mouse_in_x_band and my >= stay_top_y and my <= stay_bottom_y

		
		
		gui.minimap_expand_progress = gui.minimap_expand_progress or 1
		gui.minimap_expand_target = gui.minimap_expand_target or 1
		local now_t = reaper.time_precise()
		
		
		local keep_expanded = mouse_in_trigger or (gui.minimap_expand_target == 1 and mouse_in_stay)
		if keep_expanded then
			gui.minimap_expand_target = 1
			gui.minimap_collapse_at = nil
		else
			if gui.minimap_expand_target == 1 and not gui.minimap_collapse_at then
				gui.minimap_collapse_at = now_t + COLLAPSE_DELAY
			end
			if gui.minimap_collapse_at and now_t >= gui.minimap_collapse_at then
				gui.minimap_expand_target = 0
				gui.minimap_collapse_at = nil
			end
		end
		gui.minimap_expand_progress = gui.minimap_expand_progress +
			(gui.minimap_expand_target - gui.minimap_expand_progress) * EXPAND_SPEED
		local expand = gui.minimap_expand_progress
		local interaction_enabled = expand > 0.7

		for _, item in ipairs(visible_items) do
			local cl = item.cluster
			local bar_x1 = math.max(item.x1, left)
			local bar_x2 = math.min(item.x2, left + width)
			if bar_x2 - bar_x1 < 3 then bar_x2 = bar_x1 + 3 end
			
			
			local base_y_expanded = minimap_y_base
			if item.overlaps_selected then
				base_y_expanded = base_y_expanded - bar_height - label_bar_offset - bar_height
			end
			local expanded_y = base_y_expanded - (item.row - 1) * row_height
			
			local collapsed_y = minimap_y_base
			
			local bar_y = collapsed_y + (expanded_y - collapsed_y) * expand
			local bar_y2 = bar_y + bar_height

			
			bar_x1 = bar_x1 + 0.5
			bar_x2 = bar_x2 - 0.5

			local cc = cl.cluster_color or 0x888888
			local r = (cc >> 16) & 0xFF
			local g = (cc >> 8) & 0xFF
			local b = cc & 0xFF
			local rounding = 2

			local fill = (math.floor(r * 0.5) << 24) | (math.floor(g * 0.5) << 16) | (math.floor(b * 0.5) << 8) | 0xA0
			ImGui.DrawList_AddRectFilled(draw_list, bar_x1, bar_y, bar_x2, bar_y2, fill, rounding)
			
			ImGui.DrawList_AddLine(draw_list, bar_x1 + rounding, bar_y + 0.5, bar_x2 - rounding, bar_y + 0.5, 0xFFFFFF25, 1)
			ImGui.DrawList_AddLine(draw_list, bar_x1 + 0.5, bar_y + rounding, bar_x1 + 0.5, bar_y2 - rounding, 0xFFFFFF25, 1)
			ImGui.DrawList_AddLine(draw_list, bar_x1 + rounding, bar_y2 - 0.5, bar_x2 - rounding, bar_y2 - 0.5, 0x00000030, 1)
			ImGui.DrawList_AddLine(draw_list, bar_x2 - 0.5, bar_y + rounding, bar_x2 - 0.5, bar_y2 - rounding, 0x00000030, 1)

			
			local hover_y1, hover_y2
			if use_mac_invert then
				local sy_val = gui.overlay_sy or 0
				local ipy = gui.overlay_i_pad_y or 0
				hover_y1 = sy_val + ipy - bar_y2
				hover_y2 = sy_val + ipy - bar_y
			else
				hover_y1, hover_y2 = bar_y, bar_y2
			end

			
			
			
			if interaction_enabled then
				table.insert(gui.minimap_bar_rects, {x1 = bar_x1, x2 = bar_x2, y1 = hover_y1, y2 = hover_y2})
			end

			
			
			local minimap_interact = interaction_enabled and not gui.cluster_dragging
			if minimap_interact and hover_mx >= bar_x1 and hover_mx <= bar_x2 and hover_my >= hover_y1 and hover_my <= hover_y2 then
				ImGui.DrawList_AddRect(draw_list, bar_x1, bar_y, bar_x2, bar_y2, 0xFFFFFF80, rounding, 0, 1)
				ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand)

				
				
				local tip_r = (cc & 0xFF0000) >> 16
				local tip_g = (cc & 0x00FF00) >> 8
				local tip_b = cc & 0x0000FF
				local tip_lum = tip_r * 0.299 + tip_g * 0.587 + tip_b * 0.114
				local tip_bg = (tip_r << 24) | (tip_g << 16) | (tip_b << 8) | 0xF0
				local tip_text = tip_lum < 128 and 0xFFFFFFFF or 0x000000FF
				local tip_border = tip_lum < 128 and 0xFFFFFF40 or 0x00000040
				
				ImGui.SetNextWindowPos(ctx, (bar_x1 + bar_x2) * 0.5, bar_y - 6, ImGui.Cond_Always, 0.5, 1.0)
				ImGui.PushStyleColor(ctx, ImGui.Col_PopupBg, tip_bg)
				ImGui.PushStyleColor(ctx, ImGui.Col_Text, tip_text)
				ImGui.PushStyleColor(ctx, ImGui.Col_Border, tip_border)
				ImGui.PushStyleVar(ctx, ImGui.StyleVar_PopupRounding, 4)
				ImGui.PushStyleVar(ctx, ImGui.StyleVar_PopupBorderSize, 1)
				ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, 8, 6)
				SafePushFont(ctx, gui.fonts.sans_serif_sm)
				if ImGui.BeginTooltip(ctx) then
					ImGui.Text(ctx, cl.cluster_id or "Unnamed")
					ImGui.EndTooltip(ctx)
				end
				SafePopFont(ctx)
				ImGui.PopStyleVar(ctx, 3)
				ImGui.PopStyleColor(ctx, 3)
				if minimap_clicked then
					local shift_held = reaper.JS_Mouse_GetState(8) == 8
					if shift_held then
						
						for _, lc in pairs(project_data.render_cluster_list) do
							if lc.cluster_guid == cl.cluster_guid then
								lc.is_selected = true
								break
							end
						end
					else
						
						for _, lc in pairs(project_data.render_cluster_list) do
							lc.is_selected = lc.cluster_guid == cl.cluster_guid
						end
					end
					
					if gui.focus_activated then
						FocusSelectedClusters()
					end
				end
			end
		end
	end

	
	if not gui.timeline_gui_visible or #selected_clusters == 0 then
		gui.cluster_dragging = false
		if rv then ImGui.End(ctx) end
		return false
	end

	for key, c in pairs(selected_clusters) do
		local cluster
		for _, v in pairs(project_data.render_cluster_table) do
			if v.cluster_guid == c.cluster_guid then
				cluster = v
				break
			end
		end
		if cluster == nil then
			goto next_cluster
		end
		
		if cluster.children then goto next_cluster end
		if cluster.c_qn_start == nil then goto next_cluster end
		local pos = reaper.TimeMap2_QNToTime(0, cluster.c_qn_start)
		local rgnend = reaper.TimeMap2_QNToTime(0, cluster.c_qn_end)
		if pos == nil or rgnend == nil then goto next_cluster end
		local rgn_start, rgn_length = Convert_time_to_pixel(pos, rgnend - pos)
		if _os == "Win32" or _os == "Win64" then
			rgn_start, rgn_length = scale(rgn_start), rgn_length
		end
		local border_start = rgn_start + left
		if gui.dpi_scale ~= 1 and (_os == "Win32" or _os == "Win64") then rgn_length = scale(rgn_length) end
		local border_end = rgn_length + border_start

		
		local cluster_offscreen = nil
		if border_end < left then
			
			table.insert(offscreen_left_clusters, {cluster = cluster, border_start = border_start, border_end = border_end})
			cluster_offscreen = "left"
		elseif border_start > viewport_right then
			
			table.insert(offscreen_right_clusters, {cluster = cluster, border_start = border_start, border_end = border_end})
			cluster_offscreen = "right"
		end

		local label = cluster.cluster_id
		local label_size_w, label_size_h = ImGui.CalcTextSize(ctx, label)
		if gui.dpi_scale ~= 1 and _os == "Win32" or _os == "Win64" then label_size_w, label_size_h = scale(label_size_w), scale(label_size_h) end
		local label_pad = 4
		local label_x = rgn_start + (rgn_length / 2) - (label_size_w / 2) + label_pad
		local label_y = top - bottom - label_size_h - label_pad
		if _os == "Win32" or _os == "Win64" then
			label_y = sy + height - label_size_h
			label_y = label_y - (15*scale(gui.dpi_scale-1))
		end

		
		if label_x < label_pad then label_x = label_pad end
		if rgn_start < 0 then label_x = (border_end - left) / 2 - (label_size_w / 2) end
		if rgn_start > 0 and border_end > right then label_x =  rgn_start + ((width - rgn_start) / 2) - (label_size_w / 2) end
		if label_x + label_size_w > border_end - left - label_pad then label_x = border_end - left - label_size_w - label_pad end
		if label_x + label_size_w > width then label_x = width - label_size_w - label_pad end
		if rgn_start > width - label_size_w - label_pad then label_x = rgn_start + label_pad end
		local label_expanded = false
		if label_size_w > rgn_length - (label_pad * 2) then
			label_x = rgn_start + label_pad
			label_expanded = true
		end
		if label_size_w > rgn_length and label_x < label_pad and rgn_start > 0 then
			label_x = label_pad
			label_expanded = true
		end
		if border_start < left and border_end > right then label_x = (width / 2) - (label_size_w / 2) end

		local label_bg_start, label_bg_end = border_start, border_end
		local label_bg_h = label_size_h + label_pad
		label_bg_h = label_bg_h * (gui.main_dpi_scale/gui.dpi_scale)
		if label_size_w > rgn_length then
			label_bg_end = label_bg_start + label_size_w
		end
		local label_bg_y = top - bottom + work_pos_y - (label_bg_h*scale(gui.dpi_scale))
		if _os == "Win32" or _os == "Win64" then
			label_size_h = label_size_h + (10*scale(gui.dpi_scale - 1))
			label_bg_y = sy + height - label_size_h
		end

		
		if not cluster_offscreen then

			local hovered_x = false
			local cluster_edit_margin = 5
			local hover_x_start = label_bg_start - cluster_edit_margin
			local hover_x_end = label_bg_end + cluster_edit_margin
			if _os == "Win32" or _os == "Win64" then
				hover_x_start, hover_x_end = border_start - cluster_edit_margin, border_end + cluster_edit_margin
				hover_x_start, hover_x_end = ImGui.PointConvertNative(ctx, hover_x_start, hover_x_end, true)
			end
			if mx > hover_x_start and mx < hover_x_end then
				hovered_x = true
			end
			local hovered_y = false
			local hover_y_start = sy + i_pad_y - label_bg_y - label_pad - 18
			local hover_y_end = sy + i_pad_y - label_bg_y + label_bg_h - 19
			if _os == "Win32" or _os == "Win64" then
				hover_y_start, hover_y_end = label_bg_y - label_pad, label_bg_y + label_bg_h
				hover_y_start, hover_y_end = ImGui.PointConvertNative(ctx, hover_y_start, hover_y_end, true)
			end
			if my > hover_y_start and my < hover_y_end then
				hovered_y = true
			end

			local mx_rel = mx
			local rel_left, rel_right = left, right
			if _os == "Win32" or _os == "Win64" then
				mx_rel = ImGui.PointConvertNative(ctx, mx, 0, false)
				mx_rel = scale(mx_rel)
				local _, l, _, r = reaper.JS_Window_GetClientRect(track_window)
				rel_left, rel_right = ImGui.PointConvertNative(ctx, l, r, false)
				rel_left = scale(rel_left)
				rel_right = scale(rel_right)
			end
			if mx_rel > rel_left and mx_rel < rel_right and hovered_x and hovered_y then
				
				gui.hovering_cluster_edit = true
			else
				
				gui.hovering_cluster_edit = false
			end
			local cluster_area_hovered = -1
			if gui.hovering_cluster_edit then
				ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand)
				cluster_area_hovered = 0
				if hover_x_start < mx and mx < hover_x_start+2*cluster_edit_margin then
					ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_ResizeEW)
					cluster_area_hovered = 1
				elseif hover_x_end-2*cluster_edit_margin < mx and mx < hover_x_end then
					ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_ResizeEW)
					cluster_area_hovered = 2
				end
			end
			local mx_conv = mx
			if _os == "Win32" or _os == "Win64" then
				mx_conv = ImGui.PointConvertNative(ctx, mx, 0, false)
			end
			if gui.hovering_cluster_edit and ImGui.IsMouseClicked(ctx, 1, false) then
				gui.timeline_context_menu_clicked = true
				gui.timeline_context_menu_color = cluster.cluster_color or 0x505050
			end
			if gui.hovering_cluster_edit and ImGui.IsMouseClicked(ctx, 0, false) and not gui.cluster_menu_btn_hovered then
				gui.cluster_dragging = true
				gui.region_index_cache = RegionManager.CacheAllRegionIndices()
				gui.mouse_drag_offset = mx_conv - label_bg_start
				if _os == "Win32" or _os == "Win64" then
					gui.mouse_drag_offset = ImGui.PointConvertNative(ctx, gui.mouse_drag_offset, 0 , true)
				end
				gui.c_drag_area = cluster_area_hovered
				if cluster_area_hovered == 0 then
					ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand)
				elseif cluster_area_hovered == 1 or cluster_area_hovered == 2 then
					ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_ResizeEW)
				end
				_, gui.buf_cluster_items = Get_items_in_cluster(cluster, not gui.toggleDeactivate)
				
				gui.buf_drag_items = {}
				local _, ci_str = reaper.GetProjExtState(0, "AMAPP", "CLUSTER_ITEMS")
				local ci_table = table.deserialize(ci_str)
				local ci_items = ci_table and ci_table[cluster.cluster_guid] or {}
				for item_guid, _ in pairs(ci_items) do
					local drag_item = reaper.BR_GetMediaItemByGUID(0, item_guid)
					if drag_item then
						local item_pos = reaper.GetMediaItemInfo_Value(drag_item, "D_POSITION")
						local rel_start = item_pos - reaper.TimeMap2_QNToTime(0, cluster.c_qn_start)
						table.insert(gui.buf_drag_items, {item = drag_item, rel_start = rel_start})
					end
				end
				for _, item_info in pairs(gui.buf_cluster_items) do
					if item_info.item_pos == nil then goto skip end
					local rel_start = item_info.item_pos - reaper.TimeMap2_QNToTime(0, cluster.c_qn_start)
					item_info.rel_start = rel_start
					::skip::
				end
				if cluster.region_guid then
					
					if RegionManager.ValidateRegionGUID(cluster.region_guid) then
						gui.buf_cluster_data = {
							c_start = cluster.c_start,
							c_end = cluster.c_end,
							c_qn_start = cluster.c_qn_start,
							c_qn_end = cluster.c_qn_end
						}
					end
				end
			end
			if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) and gui.cluster_dragging then
				gui.cluster_dragging = false
				cluster.c_start, cluster.c_end = gui.buf_cluster_data.c_start, gui.buf_cluster_data.c_end
				cluster.c_qn_start, cluster.c_qn_end = gui.buf_cluster_data.c_qn_start, gui.buf_cluster_data.c_qn_end
				for _, item_info in pairs(gui.buf_cluster_items) do
					local media_item_take = reaper.GetMediaItemTakeByGUID(0, item_info.take_guid)
					local item = reaper.GetMediaItemTakeInfo_Value(media_item_take, "P_ITEM")
					if type(item) == "number" then goto skip end
					reaper.SetMediaItemPosition(item, item_info.item_pos, true)
					::skip::
				end
				gui.buf_cluster_items = {}
				if cluster.region_guid then
					
					RegionManager.UpdateRegionBoundaries(cluster.region_guid, gui.buf_cluster_data.c_start, gui.buf_cluster_data.c_end)
					gui.buf_cluster_data = {}
				end
				gui.region_index_cache = nil
				reaper.UpdateTimeline()
			end
			if ImGui.IsMouseDragging(ctx, 0) and gui.cluster_dragging then
				local _start_time = Convert_pixel_to_time(mx - gui.mouse_drag_offset, left, width)
				local mouse_time = Convert_pixel_to_time(mx, left, width)
				local cluster_start = reaper.TimeMap2_QNToTime(0, cluster.c_qn_start)
				local cluster_end = reaper.TimeMap2_QNToTime(0, cluster.c_qn_end)
				local cluster_exit, cluster_entry
				if cluster.c_qn_entry then
					cluster_entry = reaper.TimeMap2_QNToTime(0, cluster.c_qn_entry)
				end
				if cluster.c_qn_exit then
					cluster_exit = reaper.TimeMap2_QNToTime(0, cluster.c_qn_exit)
				end
				local snap = reaper.GetToggleCommandStateEx(0, 1157) 
				if not ImGui.IsKeyDown(ctx, ImGui.Key_LeftAlt) and snap == 1 then
					_start_time = reaper.SnapToGrid(0, _start_time)
					mouse_time = reaper.SnapToGrid(0, mouse_time)
				end
				if _start_time < 0 then _start_time = 0 end
				if gui.c_drag_area == 0 then
					if cluster.c_qn_entry then
						cluster.c_qn_entry = reaper.TimeMap2_timeToQN(0, _start_time - cluster_start + cluster_entry)
						cluster.c_entry = reaper.TimeMap2_QNToTime(0,cluster.c_qn_entry)
					end
					if cluster.c_qn_exit then
						cluster.c_qn_exit = reaper.TimeMap2_timeToQN(0, _start_time + cluster_exit - cluster_start)
						cluster.c_exit = _start_time + cluster_exit - cluster_start
					end
					cluster.c_qn_end = reaper.TimeMap2_timeToQN(0, _start_time) + cluster.c_qn_end - cluster.c_qn_start
					cluster.c_end = _start_time + cluster.c_end - cluster.c_start
					cluster.c_qn_start = reaper.TimeMap2_timeToQN(0, _start_time)
					cluster.c_start = _start_time
					ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand)
					
					if gui.buf_drag_items then
						for _, drag_info in ipairs(gui.buf_drag_items) do
							local item_start = reaper.TimeMap2_QNToTime(0, cluster.c_qn_start) + drag_info.rel_start
							reaper.SetMediaItemPosition(drag_info.item, item_start, true)
						end
					end
				elseif gui.c_drag_area == 1 then
					cluster.c_start = _start_time
					cluster.c_qn_start = reaper.TimeMap2_timeToQN(0, _start_time)
					if cluster.c_qn_start > cluster.c_qn_end then
						cluster.c_start = cluster.c_end
						cluster.c_qn_start = cluster.c_qn_end
					end
					if cluster.c_qn_entry and cluster.c_qn_entry < cluster.c_qn_start then
						cluster.c_entry = cluster.c_start
						cluster.c_qn_entry = cluster.c_qn_start
					end
					if cluster.c_qn_exit and cluster.c_qn_exit < cluster.c_qn_start then
						cluster.c_exit = cluster.c_start
						cluster.c_qn_exit = cluster.c_qn_start
					end
					ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_ResizeEW)
				elseif gui.c_drag_area == 2 then
					cluster.c_end = mouse_time
					cluster.c_qn_end = reaper.TimeMap2_timeToQN(0, mouse_time)
					if cluster.c_qn_end < cluster.c_qn_start then
						cluster.c_end = cluster.c_start
						cluster.c_qn_end = cluster.c_qn_start
					end
					if cluster.c_qn_exit and cluster.c_qn_exit > cluster.c_qn_end then
						cluster.c_exit = cluster.c_end
						cluster.c_qn_exit = cluster.c_qn_end
					end
					if cluster.c_qn_entry and cluster.c_qn_entry > cluster.c_qn_end then
						cluster.c_entry = cluster.c_end
						cluster.c_qn_entry = cluster.c_qn_end
					end
					ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_ResizeEW)
				end

				
				if cluster.region_guid then
					local new_pos = reaper.TimeMap2_QNToTime(0, cluster.c_qn_start)
					local new_end = reaper.TimeMap2_QNToTime(0, cluster.c_qn_end)
					RegionManager.UpdateRegionBoundaries(cluster.region_guid, new_pos, new_end)
				end
			end
			if ImGui.IsMouseReleased(ctx, 0) and gui.cluster_dragging then
				local entry_exit = cluster.c_qn_entry and cluster.c_qn_exit
				if entry_exit and (cluster.c_qn_entry <= cluster.c_qn_start or cluster.c_qn_entry >= cluster.c_qn_end) then
					cluster.c_qn_entry = nil
					cluster.c_qn_exit = nil
				end
				gui.cluster_dragging = false
				gui.mouse_drag_offset = 0
				Set_Cluster_Boundaries(cluster)
				reaper.UpdateTimeline()
				reaper.Main_OnCommand(40898, 0) 
				if gui.region_index_cache then
					RegionManager.RestoreRegionIndices(gui.region_index_cache)
					gui.region_index_cache = nil
				end
				UpdateRenderClusterTable()
				gui.buf_cluster_items = {}
			end

		end 

		
		local draw_list = ImGui.GetWindowDrawList(ctx)
		local color = ImGui.ColorConvertNative(cluster.cluster_color or 0xffffffff)
		local bkg_alpha = 0xff
		local border_col = (color << 8) | bkg_alpha
		local overlay_inverse = gui.gui_settings_overlay_inverse
		local splitter_was_split = false
		if overlay_inverse then
			if not ImGui.ValidatePtr(gui.splitter_overlay, 'ImGui_DrawListSplitter*') then
				gui.splitter_overlay = ImGui.CreateDrawListSplitter(draw_list)
			end
			ImGui.DrawListSplitter_Split(gui.splitter_overlay, 2)
			ImGui.DrawListSplitter_SetCurrentChannel(gui.splitter_overlay, 1)
			splitter_was_split = true
		end
		ImGui.DrawList_AddLine(draw_list, border_start, i_pad_y, border_start, i_pad_y+work_pos_y+work_size_h, border_col, 0.5)
		ImGui.DrawList_AddLine(draw_list, border_end, i_pad_y, border_end, i_pad_y+work_pos_y+work_size_h, border_col, 0.5)
		
		-- if cluster.c_qn_entry ~= nil then
		-- 	local c_entry = reaper.TimeMap2_QNToTime(0, cluster.c_qn_entry)
		-- 	c_entry = Convert_time_to_pixel(c_entry, 0)
		-- 	if gui.dpi_scale ~= 1 and _os == "Win32" or _os == "Win64" then c_entry = scale(c_entry) end
		-- 	local entry = c_entry + left
		-- 	ImGui.DrawList_AddLine(draw_list, entry, i_pad_y, entry, i_pad_y+work_pos_y+work_size_h, border_col, 2)
		-- end
		-- if cluster.c_qn_exit ~= nil then
		-- 	local c_exit = reaper.TimeMap2_QNToTime(0, cluster.c_qn_exit)
		-- 	c_exit = Convert_time_to_pixel(c_exit, 0)
		-- 	if gui.dpi_scale ~= 1 and _os == "Win32" or _os == "Win64" then c_exit = scale(c_exit) end
		-- 	local exit = c_exit + left
		-- 	ImGui.DrawList_AddLine(draw_list, exit, i_pad_y, exit, i_pad_y+work_pos_y+work_size_h, border_col, 2)
		-- end
		local label_w_added = 0
		if label_expanded then
			label_w_added = label_pad
		end
		
		if not gui.focus_activated then
			local overlay_alpha = 0x28
			local border_fill = (color << 8) | math.floor(overlay_alpha)
			if #selected_clusters > 1 then overlay_inverse = false end
			if overlay_inverse then
				ImGui.DrawList_AddRectFilled(draw_list, work_pos_x, i_pad_y, border_start, i_pad_y+work_pos_y+work_size_h, border_fill)
				ImGui.DrawList_AddRectFilled(draw_list, border_end, i_pad_y, work_pos_x+work_size_w, i_pad_y+work_pos_y+work_size_h, border_fill)
			else
				ImGui.DrawList_AddRectFilled(draw_list, border_start, i_pad_y, border_end, i_pad_y+work_pos_y+work_size_h, border_fill)
			end
		end
		
		local outline_col = OutlineColorBasedOnBgColor(cluster.cluster_color or 0xffffffff, 0x50)
		local rounding = 3
		ImGui.DrawList_AddRect(draw_list, border_start, i_pad_y, border_end, i_pad_y+work_pos_y+work_size_h, outline_col, rounding, ImGui.DrawFlags_None, 1)

		
		if cluster_offscreen then
			
			if splitter_was_split then
				ImGui.DrawListSplitter_Merge(gui.splitter_overlay)
			end
			goto next_cluster
		end

		bkg_alpha = 0xff
		local label_bg_col = (color << 8) | bkg_alpha
		if gui.cluster_armed then
			label_bg_col = 0xFFFFFFFF
		end
		
		local label_rounding = 4
		local label_x1 = label_bg_start-3
		local label_y1 = label_bg_y-label_pad
		local label_x2 = label_bg_end+label_w_added+3
		local label_y2 = label_bg_y + label_bg_h

		
		
		local minus_total_w = 6 + 5 + 3
		local minus_btn_gap = 3
		local btn_size = 14
		local btn_spacing = 7
		local min_label_w = minus_total_w + minus_btn_gap + btn_size + btn_spacing + label_size_w + 6
		if label_x2 - label_x1 < min_label_w then
			label_x2 = label_x1 + min_label_w
		end

		
		local shadow_col = OutlineColorBasedOnBgColor(cluster.cluster_color or 0xffffffff, 0x18)
		local shadow_offset = 2
		
		for i = 3, 1, -1 do
			local offset = shadow_offset * i * 0.5
			local alpha = math.floor(0x10 / i)
			local layer_col = (shadow_col & 0xFFFFFF00) | alpha
			ImGui.DrawList_AddRectFilled(draw_list, label_x1+offset, label_y1+offset, label_x2+offset, label_y2+offset, layer_col, label_rounding + i)
		end

		ImGui.DrawList_AddRectFilled(draw_list, label_x1, label_y1, label_x2, label_y2, label_bg_col, label_rounding)
		
		local label_outline_col = OutlineColorBasedOnBgColor(cluster.cluster_color or 0xffffffff, 0x40)
		ImGui.DrawList_AddRect(draw_list, label_x1, label_y1, label_x2, label_y2, label_outline_col, label_rounding, ImGui.DrawFlags_None, 1)

		
		
		local minus_size = 6
		local minus_indent = 5
		local minus_cy = label_y1 + 4 + minus_size / 2
		if gui.cluster_armed then
			gui.rec_arm_alpha = gui.rec_arm_alpha + gui.fade_direction * gui.fade_speed
			local arm_color = 0xFF000000 | gui.rec_arm_alpha
			if gui.rec_arm_alpha <= 60 then
				gui.rec_arm_alpha = 60
				gui.fade_direction = 1
			elseif gui.rec_arm_alpha >= 255 then
				gui.rec_arm_alpha = 255
				gui.fade_direction = -1
			end
			arm_color = ImGui.ColorConvertNative(arm_color)
			ImGui.DrawList_AddRectFilled(draw_list, label_x1, label_y1, label_x2, label_y2, arm_color, label_rounding)
		end
		
		
		
		
		

		local bar_pad = 3
		local abs_left = label_x1 + bar_pad
		local abs_right = label_x2 - bar_pad
		local vp_left = left
		local vp_right = left + width

		
		local all_content_w = minus_size + minus_btn_gap + btn_size + btn_spacing + label_size_w

		
		local vis_left = math.max(abs_left, vp_left + bar_pad)
		local vis_right = math.min(abs_right, vp_right - bar_pad)
		local vis_w = vis_right - vis_left

		
		local group_x
		if all_content_w < vis_w then
			group_x = vis_left + (vis_w - all_content_w) / 2
		else
			group_x = vis_left
		end

		
		group_x = math.max(group_x, abs_left)
		
		if group_x + all_content_w > abs_right then
			group_x = abs_right - all_content_w
		end
		
		group_x = math.max(group_x, abs_left)

		
		minus_cx = group_x + minus_size / 2
		local btn_x = group_x + minus_size + minus_btn_gap
		local text_screen_x = btn_x + btn_size + btn_spacing

		
		local btn_y = label_y1 + (label_y2 - label_y1) / 2 - btn_size / 2 - 1
		local text_y = label_y1 + 5

		
		DrawClusterMenuButton(draw_list, btn_x, btn_y, btn_size, cluster.cluster_color or 0x505050, cluster, cluster.cluster_guid, label_y1)

		
		SafePushFont(ctx, gui.fonts.sans_serif_sm)
		local tmp_col = color
		if gui.cluster_armed then
			tmp_col = 0xFFFFFFFF
		end
		local text_color = TextColorBasedOnBgColor(tmp_col + 0x1000000)
		ImGui.PushStyleColor(ctx, ImGui.Col_Text, text_color)
		ImGui.SetCursorScreenPos(ctx, text_screen_x, text_y)
		ImGui.Text(ctx, label)
		ImGui.PopStyleColor(ctx)
		SafePopFont(ctx)

		
		do
			local minus_x1 = minus_cx - minus_size / 2
			local minus_x2 = minus_cx + minus_size / 2
			local minus_color = OutlineColorBasedOnBgColor(cluster.cluster_color or 0xffffffff, 0x50)

			local minus_hit_pad = 3
			local minus_hx1 = minus_x1 - minus_hit_pad
			local minus_hy1 = minus_cy - minus_size / 2 - minus_hit_pad
			local minus_hx2 = minus_x2 + minus_hit_pad
			local minus_hy2 = minus_cy + minus_size / 2 + minus_hit_pad
			local mmx, mmy = ImGui.GetMousePos(ctx)
			local minus_hovered = mmx >= minus_hx1 and mmx <= minus_hx2 and mmy >= minus_hy1 and mmy <= minus_hy2

			if minus_hovered then
				minus_color = OutlineColorBasedOnBgColor(cluster.cluster_color or 0xffffffff, 0xCC)
				ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand)
				if ImGui.IsMouseClicked(ctx, 0) then
					for _, lc in pairs(project_data.render_cluster_list) do
						if lc.cluster_guid == cluster.cluster_guid then
							lc.is_selected = false
							break
						end
					end
					if gui.focus_activated then
						UnfocusClusters()
						gui.focus_activated = false
					end
				end
			end

			
			if minus_x1 >= label_x1 and minus_x2 <= label_x2 then
				ImGui.DrawList_AddLine(draw_list, minus_x1, minus_cy, minus_x2, minus_cy, minus_color, 1.5)
			end
		end

		reaper.UpdateTimeline()

		local items_table = project_data.cluster_items_table
		if items_table == nil then items_table = {} end
		local cluster_items = items_table[c.cluster_guid]
		if not gui.item_overlay then goto no_item_overlay end
		
		
		if not cluster_items then cluster_items = {} end
		if next(cluster_items) then  
		table.sort(cluster_items, function(_a, _b)
			local mi_a, mi_b = reaper.BR_GetMediaItemByGUID(0, _a.item_guid), reaper.BR_GetMediaItemByGUID(0, _b.item_guid)
			local track = reaper.GetMediaItem_Track(mi_a)
			local has_lanes = reaper.GetMediaTrackInfo_Value(track, "I_FREEMODE" ) ~= 0
			local y = reaper.GetMediaTrackInfo_Value(track, "I_TCPY")
			local h = reaper.GetMediaTrackInfo_Value(track, "I_TCPH")
			_a.y1 = y
			_a.y2 = _a.y1 + h
			local item_start = reaper.GetMediaItemInfo_Value(mi_a, "D_POSITION")
			local item_len = reaper.GetMediaItemInfo_Value(mi_a, "D_LENGTH")
			local x, w = Convert_time_to_pixel(item_start, item_len)
			_a.x1 = x
			_a.x2 = x + w

			track = reaper.GetMediaItem_Track(mi_b)
			has_lanes = reaper.GetMediaTrackInfo_Value(track, "I_FREEMODE" ) ~= 0
			y = reaper.GetMediaTrackInfo_Value(track, "I_TCPY")
			h = reaper.GetMediaTrackInfo_Value(track, "I_TCPH")
			_b.y1 = y
			_b.y2 = _b.y1 + h
			item_start = reaper.GetMediaItemInfo_Value(mi_b, "D_POSITION")
			item_len = reaper.GetMediaItemInfo_Value(mi_b, "D_LENGTH")
			x, w = Convert_time_to_pixel(item_start, item_len)
			_b.x1 = x
			_b.x2 = x + w
			return _a.y1 < _b.y1
		end)
		end  
		if overlay_inverse then
			ImGui.DrawListSplitter_SetCurrentChannel(gui.splitter_overlay, 0)

			
			if #selected_clusters == 1 then
				for item_guid, item_props_table in pairs(cluster_items) do
					local item = reaper.BR_GetMediaItemByGUID(0, item_guid)
					if item == nil then goto item_btn_next end
					local track = reaper.GetMediaItem_Track(item)
					if not reaper.IsTrackVisible(track, false) then goto item_btn_next end
					local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
					local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
					local x, w = Convert_time_to_pixel(item_start, item_len)
					if x == nil or w == nil then goto item_btn_next end

					local track_h = reaper.GetMediaTrackInfo_Value(track, "I_TCPH")
					local track_y = reaper.GetMediaTrackInfo_Value(track, "I_TCPY")
					local h, y
					if reaper.GetMediaTrackInfo_Value(track, "I_FREEMODE") == 2 then
						local num_lanes = reaper.GetMediaTrackInfo_Value(track, "I_NUMFIXEDLANES")
						local item_lane = reaper.GetMediaItemInfo_Value(item, "I_FIXEDLANE")
						local lane_h = (track_h - 18) / num_lanes
						y = track_y + 0.5 + item_lane * lane_h
						h = lane_h
					else
						y = track_y
						h = track_h
					end

					local x_l = x + left
					local x_r = x + w + left
					if (x_l < border_start and x_r < border_start) or (x_l > border_end and x_r > border_end) then goto item_btn_next end
					if x_l < border_start then x_l = border_start end
					if x_r > border_end then x_r = border_end end

					local item_w = x_r - x_l
					local item_h = h
					local btn_size = GetItemButtonSize(h)
					if CanShowItemButton(item_w, item_h, btn_size) then
						local bounds = {
							cluster_left = border_start,
							cluster_right = border_end,
							viewport_left = left,
							viewport_right = left + width,
							viewport_top = i_pad_y,
							viewport_bottom = i_pad_y + work_size_h
						}
						local btn_x, btn_y = GetItemButtonPos(x_l, i_pad_y+y, x_r, i_pad_y+y+h, btn_size, bounds)
						local is_item_selected = reaper.IsMediaItemSelected(item)
						local _, _, btn_clicked = DrawItemActionButton(
							draw_list, btn_x, btn_y, btn_size, cluster.cluster_color or 0xFFFFFF, true, item_guid, is_item_selected, gui.focus_activated
						)
						if btn_clicked then
							
							if not reaper.IsMediaItemSelected(item) then
								reaper.SelectAllMediaItems(0, false)
								reaper.SetMediaItemSelected(item, true)
							end
							ClusterAPI.remove_items_in_cluster(cluster)
							UpdateRenderClusterTable()
						end
					end
					::item_btn_next::
				end
			end
		-- else
		-- 	local last_y = i_pad_y
		-- 	Msg()
		-- 	for i, hole in pairs(cluster_items) do
		-- 		local mi_a = reaper.BR_GetMediaItemByGUID(0, hole.item_guid)
		-- 		local track = reaper.GetMediaItem_Track(mi_a)
		-- 		local has_lanes = reaper.GetMediaTrackInfo_Value(track, "I_FREEMODE" ) ~= 0

		-- 		local y = reaper.GetMediaTrackInfo_Value(track, "I_TCPY")
		-- 		local h = reaper.GetMediaTrackInfo_Value(track, "I_TCPH")

		-- 		hole.y1 = y
		-- 		hole.y2 = hole.y1 + h
		-- 		local item_start = reaper.GetMediaItemInfo_Value(mi_a, "D_POSITION")
		-- 		local item_len = reaper.GetMediaItemInfo_Value(mi_a, "D_LENGTH")
		-- 		local x, w = Convert_time_to_pixel(item_start, item_len)
		-- 		hole.x1 = x
		-- 		hole.x2 = x + w
		-- 		Msg(table.serialize(hole))

		-- 		if hole.y1 > last_y then
		-- 			ImGui.DrawList_AddRectFilled(list.draw_list, border_start, i_pad_y, border_end, hole.y1, border_fill)
		-- 		end

		-- 		if hole.x1 > border_start then
		-- 			ImGui.DrawList_AddRectFilled(list.draw_list, border_start, hole.y1, hole.x1, hole.y2, border_fill)
		-- 		end

		-- 		if hole.x2 < border_end then
		-- 			ImGui.DrawList_AddRectFilled(list.draw_list, hole.x2, hole.y1, border_end, hole.y2, border_fill)
		-- 		end

		-- 		last_y = hole.y2
		-- 	end

		-- 	if last_y < i_pad_y then
		-- 		ImGui.DrawList_AddRectFilled(list.draw_list, border_start, last_y, border_end, i_pad_y+work_pos_y+work_size_h, border_fill)
		-- 	end
		end

		
		if #selected_clusters == 1 and gui.item_overlay then
			local num_selected = reaper.CountSelectedMediaItems(0)
			for i = 0, num_selected - 1 do
				local item = reaper.GetSelectedMediaItem(0, i)
				if item then
					local item_guid = reaper.BR_GetMediaItemGUID(item)
					
					if cluster_items and cluster_items[item_guid] then goto skip_add_btn end

					local track = reaper.GetMediaItem_Track(item)
					if not reaper.IsTrackVisible(track, false) then goto skip_add_btn end

					local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
					local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
					local item_end = item_start + item_len

					
					local c_start = cluster.c_start or 0
					local c_end = cluster.c_end or 0
					local item_overlaps = not ((item_end <= c_start) or (item_start >= c_end))
					if not item_overlaps then goto skip_add_btn end

					local x, w = Convert_time_to_pixel(item_start, item_len)
					if x == nil or w == nil then goto skip_add_btn end

					local track_h = reaper.GetMediaTrackInfo_Value(track, "I_TCPH")
					local track_y = reaper.GetMediaTrackInfo_Value(track, "I_TCPY")
					local h, y
					if reaper.GetMediaTrackInfo_Value(track, "I_FREEMODE") == 2 then
						local num_lanes = reaper.GetMediaTrackInfo_Value(track, "I_NUMFIXEDLANES")
						local item_lane = reaper.GetMediaItemInfo_Value(item, "I_FIXEDLANE")
						local lane_h = (track_h - 18) / num_lanes
						y = track_y + 0.5 + item_lane * lane_h
						h = lane_h
					else
						y = track_y
						h = track_h
					end

					
					local x_l = x + left
					local x_r = x + w + left
					if (x_l < border_start and x_r < border_start) or (x_l > border_end and x_r > border_end) then goto skip_add_btn end
					if x_l < border_start then x_l = border_start end
					if x_r > border_end then x_r = border_end end

					local item_w = x_r - x_l
					local item_h = h
					local btn_size = GetItemButtonSize(h)
					if CanShowItemButton(item_w, item_h, btn_size) then
						local bounds = {
							cluster_left = border_start,
							cluster_right = border_end,
							viewport_left = left,
							viewport_right = left + width,
							viewport_top = i_pad_y,
							viewport_bottom = i_pad_y + work_size_h
						}
						local btn_x, btn_y = GetItemButtonPos(x_l, i_pad_y+y, x_r, i_pad_y+y+h, btn_size, bounds)
						local _, _, btn_clicked = DrawItemActionButton(
							draw_list, btn_x, btn_y, btn_size, cluster.cluster_color or 0xFFFFFF, false, "add_" .. item_guid, true, gui.focus_activated  
						)
						if btn_clicked then
							
							ClusterAPI.set_items_in_cluster(cluster)
							UpdateRenderClusterTable()
						end
					end
				end
				::skip_add_btn::
			end
		end
		::no_item_overlay::
		if splitter_was_split then
			ImGui.DrawListSplitter_Merge(gui.splitter_overlay)
		end
		-- ImGui.DrawList_PopClipRect(draw_list)
		-- if overlay_inverse then
		-- 	ImGui.DrawListSplitter_Merge(gui.splitter_overlay)
		-- 	ImGui.DrawList_PopClipRect(list.draw_list)
		-- end
		::next_cluster::
	end

	
	local draw_list = ImGui.GetWindowDrawList(ctx)
	local indicator_height = 24
	local indicator_bottom = i_pad_y + height - 20  
	local indicator_spacing = indicator_height + 4

	
	for i, data in ipairs(offscreen_left_clusters) do
		local y_offset = (i - 1) * indicator_spacing
		local clicked = DrawOffscreenClusterIndicator(
			draw_list, "left", indicator_bottom - y_offset, indicator_height,
			data.cluster, data.cluster.cluster_color or 0x505050,
			left, viewport_right, i_pad_y
		)
		if clicked then
			
			for _, c in pairs(project_data.render_cluster_list) do
				c.is_selected = c.cluster_guid == data.cluster.cluster_guid
			end
			MoveEditCursorToCluster()
			VerticalScrollToFirstItem(data.cluster)
		end
	end

	
	for i, data in ipairs(offscreen_right_clusters) do
		local y_offset = (i - 1) * indicator_spacing
		local clicked = DrawOffscreenClusterIndicator(
			draw_list, "right", indicator_bottom - y_offset, indicator_height,
			data.cluster, data.cluster.cluster_color or 0x505050,
			left, viewport_right, i_pad_y
		)
		if clicked then
			
			for _, c in pairs(project_data.render_cluster_list) do
				c.is_selected = c.cluster_guid == data.cluster.cluster_guid
			end
			MoveEditCursorToCluster()
			VerticalScrollToFirstItem(data.cluster)
		end
	end

	
	if rv then ImGui.End(ctx) end

	
	DrawClusterContextMenu()

	
	gui.item_btn_rects = gui.item_btn_rects_next
	gui.item_btn_rects_next = {}
	gui.item_btn_was_hovered = gui.item_btn_was_hovered_next
	gui.item_btn_was_hovered_next = {}
	
	gui.item_btn_any_hovered_prev = gui.item_btn_any_hovered
	gui.item_btn_hovered_is_in_cluster_prev = gui.item_btn_hovered_is_in_cluster
	gui.item_btn_any_hovered = false
	gui.item_btn_hovered_is_in_cluster = false
	
end


gui.cluster_modal_names = {
	"Edit Cluster",
	"Delete Cluster",
	"Create Group",
	"Multiple Groups Detected",
	"Create New Cluster",
	"Create Multiple Clusters",
	"Render Options"
}


function gui.DrawClusterModalOverlay()
	local any_open = false
	for _, name in ipairs(gui.cluster_modal_names) do
		if ImGui.IsPopupOpen(ctx, name) then
			any_open = true
			break
		end
	end

	if any_open then
		local draw_list = ImGui.GetForegroundDrawList(ctx)
		local win_x, win_y = ImGui.GetWindowPos(ctx)
		local win_w, win_h = ImGui.GetWindowSize(ctx)
		local overlay_color = 0xFFFFFF40 

		
		local padding = 10
		local modal_x = gui.lb_min_x and (gui.lb_min_x + padding) or win_x
		local modal_y = gui.lb_min_y and (gui.lb_min_y + padding) or win_y
		local modal_x2 = gui.lb_max_x and (gui.lb_max_x - padding) or (win_x + win_w)
		local modal_y2 = gui.lb_max_y and (gui.lb_max_y - padding) or (win_y + win_h)

		
		
		ImGui.DrawList_AddRectFilled(draw_list, win_x, win_y, win_x + win_w, modal_y, overlay_color)
		
		ImGui.DrawList_AddRectFilled(draw_list, win_x, modal_y2, win_x + win_w, win_y + win_h, overlay_color)
		
		ImGui.DrawList_AddRectFilled(draw_list, win_x, modal_y, modal_x, modal_y2, overlay_color)
		
		ImGui.DrawList_AddRectFilled(draw_list, modal_x2, modal_y, win_x + win_w, modal_y2, overlay_color)
	end
end


function gui.SetClusterModalPosSize(padding)
	padding = padding or 10

	if gui.lb_min_x and gui.lb_min_y and gui.lb_max_x and gui.lb_max_y then
		local modal_x = gui.lb_min_x + padding
		local modal_y = gui.lb_min_y + padding
		local modal_w = (gui.lb_max_x - gui.lb_min_x) - (padding * 2)
		local modal_h = (gui.lb_max_y - gui.lb_min_y) - (padding * 2)
		ImGui.SetNextWindowPos(ctx, modal_x, modal_y, ImGui.Cond_Always)
		ImGui.SetNextWindowSize(ctx, modal_w, modal_h, ImGui.Cond_Always)
	else
		local center = {ImGui.Viewport_GetCenter(ImGui.GetMainViewport(ctx))}
		ImGui.SetNextWindowPos(ctx, center[1], center[2], ImGui.Cond_Always, 0.5, 0.5)
	end
end

local function Modal_VariationPrompt()
	if not gui.show_variation_prompt or gui.detected_item_groups == nil then return end

	gui.SetClusterModalPosSize()

	if ImGui.BeginPopupModal(ctx, "Multiple Groups Detected", nil, ImGui.WindowFlags_NoResize | ImGui.WindowFlags_NoMove) then
		local num_groups = #gui.detected_item_groups

		SafePushFont(ctx, gui.fonts.sans_serif)
		ImGui.Text(ctx, "Detected " .. num_groups .. " distinct item groups.")
		ImGui.Spacing(ctx)
		ImGui.Text(ctx, "Create as variations of the same asset?")
		SafePopFont(ctx)

		ImGui.Spacing(ctx)
		ImGui.Separator(ctx)
		ImGui.Spacing(ctx)

		if ImGui.Button(ctx, "Yes, Create Variations", 140, 0) then
			ImGui.CloseCurrentPopup(ctx)
			gui.show_variation_prompt = false
			gui.open_multi_cluster_modal = true
		end
		ImGui.SameLine(ctx)
		if ImGui.Button(ctx, "No, Single Cluster", 120, 0) then
			ImGui.CloseCurrentPopup(ctx)
			gui.show_variation_prompt = false
			gui.detected_item_groups = nil
			gui.open_single_cluster_modal = true
		end
		ImGui.SameLine(ctx)
		if ImGui.Button(ctx, "Cancel", 70, 0) or ImGui.IsKeyPressed(ctx, ImGui.Key_Escape, false) then
			ImGui.CloseCurrentPopup(ctx)
			gui.show_variation_prompt = false
			gui.detected_item_groups = nil
		end

		ImGui.EndPopup(ctx)
	end
end

local function Modal_CreateNewCluster()
	gui.SetClusterModalPosSize()
	if ImGui.BeginPopupModal(ctx, "Create New Cluster", nil, ImGui.WindowFlags_NoResize | ImGui.WindowFlags_NoMove) then
		if not ImGui.IsMouseDown(ctx, 0) then ImGui.SetKeyboardFocusHere(ctx) end
		gui.modal_rv, gui.modal_buf = ImGui.InputTextWithHint(ctx, "##", "Type name here...", gui.modal_buf)
		gui.modal_rv, gui.modal_new_loop_toggle = ImGui.Checkbox(ctx, "Is loop", gui.modal_new_loop_toggle)
		ImGui.SameLine(ctx)
		gui.modal_rv, gui.modal_new_region_toggle = ImGui.Checkbox(ctx, "Create region", gui.modal_new_region_toggle)
		if ImGui.Button(ctx, "Create", 70, 0) or ImGui.IsKeyPressed(ctx, ImGui.Key_Enter) then
			local last_selected_cluster_idx, parent_guid
			for guid, c in pairs(project_data.render_cluster_list) do
				if c.is_selected then
					last_selected_cluster_idx = c.idx
					parent_guid = c.parent_guid
				end
			end
			if #gui.modal_buf > 0 then CreateNewCluster(gui.modal_buf, gui.modal_new_loop_toggle, gui.modal_new_region_toggle, last_selected_cluster_idx, parent_guid) end
			ImGui.CloseCurrentPopup(ctx)
			gui.modal_new_loop_toggle = false
			gui.modal_new_region_toggle = false
			gui.modal_buf = ""
		end
		ImGui.SameLine(ctx)
		if ImGui.Button(ctx, "Cancel", 70, 0) then
			ImGui.CloseCurrentPopup(ctx)
			gui.modal_new_loop_toggle = false
			gui.modal_new_region_toggle = false
			gui.modal_buf = ""
		end
		if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape, false) then
			ImGui.CloseCurrentPopup(ctx)
			gui.modal_new_loop_toggle = false
			gui.modal_new_region_toggle = false
			gui.modal_buf = ""
		end
		ImGui.EndPopup(ctx)
	end
end

local function Modal_CreateMultipleClusters()
	if gui.detected_item_groups == nil then return end

	gui.SetClusterModalPosSize()

	if ImGui.BeginPopupModal(ctx, "Create Multiple Clusters", nil, ImGui.WindowFlags_NoResize | ImGui.WindowFlags_NoMove) then
		local num_groups = #gui.detected_item_groups

		
		SafePushFont(ctx, gui.fonts.sans_serif)
		ImGui.Text(ctx, "Detected " .. num_groups .. " distinct item groups.")
		SafePopFont(ctx)
		ImGui.Spacing(ctx)
		ImGui.Separator(ctx)
		ImGui.Spacing(ctx)

		
		if not ImGui.IsMouseDown(ctx, 0) then ImGui.SetKeyboardFocusHere(ctx) end
		gui.modal_rv, gui.multi_cluster_buf = ImGui.InputTextWithHint(ctx, "Template", "e.g. Impact_$nn", gui.multi_cluster_buf)

		
		if #gui.multi_cluster_buf > 0 and gui.multi_cluster_buf:match("%$") then
			ImGui.Spacing(ctx)
			ImGui.Text(ctx, "Preview:")
			ImGui.Indent(ctx, 14)
			for i = 1, math.min(num_groups, 3) do
				local preview_name = ExpandTemplateName(gui.multi_cluster_buf, i)
				ImGui.BulletText(ctx, preview_name)
			end
			if num_groups > 3 then
				ImGui.BulletText(ctx, "... (" .. (num_groups - 3) .. " more)")
			end
			ImGui.Unindent(ctx, 14)
		end

		ImGui.Spacing(ctx)
		ImGui.Separator(ctx)
		ImGui.Spacing(ctx)

		
		gui.modal_rv, gui.multi_loop_toggle = ImGui.Checkbox(ctx, "Is loop", gui.multi_loop_toggle)
		ImGui.SameLine(ctx)
		gui.modal_rv, gui.multi_region_toggle = ImGui.Checkbox(ctx, "Create regions", gui.multi_region_toggle)
		gui.modal_rv, gui.multi_create_group_toggle = ImGui.Checkbox(ctx, "Group variations", gui.multi_create_group_toggle)
		if ImGui.IsItemHovered(ctx) then
			ImGui.SetTooltip(ctx, "Create a parent cluster group containing all variations")
		end

		ImGui.Spacing(ctx)

		
		local can_create = #gui.multi_cluster_buf > 0
		if not can_create then
			ImGui.BeginDisabled(ctx)
		end
		if ImGui.Button(ctx, "Create " .. num_groups .. " Clusters", 150, 0) or (can_create and ImGui.IsKeyPressed(ctx, ImGui.Key_Enter)) then
			CreateMultipleClusters(
				gui.detected_item_groups,
				gui.multi_cluster_buf,
				gui.multi_loop_toggle,
				gui.multi_region_toggle,
				gui.multi_create_group_toggle
			)
			ImGui.CloseCurrentPopup(ctx)
			
			gui.multi_cluster_buf = ""
			gui.multi_loop_toggle = false
			gui.multi_region_toggle = false
			gui.multi_create_group_toggle = true
			gui.detected_item_groups = nil
		end
		if not can_create then
			ImGui.EndDisabled(ctx)
		end

		ImGui.SameLine(ctx)
		if ImGui.Button(ctx, "Cancel", 70, 0) or ImGui.IsKeyPressed(ctx, ImGui.Key_Escape, false) then
			ImGui.CloseCurrentPopup(ctx)
			gui.multi_cluster_buf = ""
			gui.multi_loop_toggle = false
			gui.multi_region_toggle = false
			gui.multi_create_group_toggle = true
			gui.detected_item_groups = nil
		end

		ImGui.EndPopup(ctx)
	end
end

local function AttachRegion(edit_buf)
	local pos, rgnend, name, color = edit_buf.c.c_start, edit_buf.c.c_end, edit_buf.c.cluster_id, edit_buf.old_color
	
	local region_guid = RegionManager.CreateRegionWithGUID(pos, rgnend, name, color|0x1000000)
	if region_guid and region_guid ~= "" then
		edit_buf.c.region_guid = region_guid
	end
	EditSelectedCluster(edit_buf)
end

local function DeleteRegion(edit_buf)
	
	if edit_buf.c.region_guid then
		RegionManager.DeleteRegionByGUID(edit_buf.c.region_guid)
	end
	edit_buf.c.region_guid = nil
	EditSelectedCluster(edit_buf)
end

local edit_buf = {}
local cluster_buffered = false
local col_edit_flags = 	ImGui.ColorEditFlags_NoBorder 			|
						ImGui.ColorEditFlags_NoOptions			|
						ImGui.ColorEditFlags_DisplayHex			|
						ImGui.ColorEditFlags_NoSmallPreview		|
						ImGui.ColorEditFlags_NoTooltip


local group_modal = {}

local function Modal_CreateGroup()
	gui.SetClusterModalPosSize()
	if ImGui.BeginPopupModal(ctx, "Create Group", nil, ImGui.WindowFlags_NoResize | ImGui.WindowFlags_NoMove) then
		
		if not group_modal.initialized then
			group_modal.buf = ""
			group_modal.region_toggle = false
			group_modal.color = reaper.ColorToNative(math.random(50, 255), math.random(50, 255), math.random(50, 255))
			group_modal.color_picker = group_modal.color
			group_modal.initialized = true
		end

		
		local rv
		rv, group_modal.buf = ImGui.InputTextWithHint(ctx, "##group_name", "Type group name here...", group_modal.buf)

		ImGui.Spacing(ctx)
		ImGui.Spacing(ctx)

		
		rv, group_modal.region_toggle = ImGui.Checkbox(ctx, "Create region", group_modal.region_toggle)

		ImGui.Spacing(ctx)
		ImGui.Spacing(ctx)
		ImGui.Separator(ctx)
		ImGui.Spacing(ctx)
		ImGui.Spacing(ctx)

		
		local col_picker = group_modal.color_picker
		if reaper.GetOS() == "Win32" or reaper.GetOS() == "Win64" then
			col_picker = ImGui.ColorConvertNative(col_picker)
		end
		local color_rv, new_color = ImGui.ColorPicker3(ctx, "##group_color", col_picker or 0, col_edit_flags)
		new_color = ImGui.ColorConvertNative(new_color)
		if group_modal.color_picker < 0 then new_color = new_color + 0x1000000 end
		if color_rv then
			group_modal.color_picker = new_color
		end
		if reaper.GetOS() == "OSX32" or reaper.GetOS() == "OSX64" or reaper.GetOS() == "macOS-arm64" then
			new_color = ImGui.ColorConvertNative(new_color)
		end
		group_modal.color = new_color|0x1000000

		
		if ImGui.Button(ctx, "Create", 70, 0) or ImGui.IsKeyPressed(ctx, ImGui.Key_Enter) then
			
			local selected_clusters = {}
			for idx, cluster in pairs(project_data.render_cluster_list) do
				if cluster.is_selected then
					table.insert(selected_clusters, cluster.cluster_guid)
				end
			end

			
			local name = group_modal.buf
			if name == "" then name = "Group" end

			Create_Cluster_Group(selected_clusters, gui.last_hovered_item_index, name, group_modal.region_toggle, group_modal.color)
			UpdateRenderClusterTable()

			
			ImGui.CloseCurrentPopup(ctx)
			group_modal = {}
		end

		
		local _x, _y = ImGui.GetContentRegionAvail(ctx)
		ImGui.SameLine(ctx)
		ImGui.SetCursorPosX(ctx, _x - 70)
		if ImGui.Button(ctx, "Cancel", 70, 0) or ImGui.IsKeyPressed(ctx, ImGui.Key_Escape, false) then
			ImGui.CloseCurrentPopup(ctx)
			group_modal = {}
		end

		ImGui.EndPopup(ctx)
	end
end

local function Modal_EditCluster()
	gui.SetClusterModalPosSize()
	if ImGui.BeginPopupModal(ctx, "Edit Cluster", nil, ImGui.WindowFlags_NoResize | ImGui.WindowFlags_NoMove) then
		if cluster_buffered then goto continue end
		for k, v in pairs(project_data.render_cluster_list) do
			if v.is_selected then
				edit_buf = {
					c = v,
					old_name_buf = v.cluster_id,
					new_loop_toggle = v.is_loop,
					old_color = v.cluster_color,
					has_region = v.region_guid ~= nil,
					region_buffered = v.region_guid ~= nil
				}
				if edit_buf.buffered_color == nil then edit_buf.buffered_color = 0 end
				cluster_buffered = true
				break
			end
		end
		::continue::
		rv, edit_buf.c.cluster_id = ImGui.InputTextWithHint(ctx, "##", "Type name here...", edit_buf.c.cluster_id)

		rv, edit_buf.new_loop_toggle = ImGui.Checkbox(ctx, "Render cluster as loop", edit_buf.new_loop_toggle)
		if rv then
			gui.toggleLoop = edit_buf.new_loop_toggle
			
		end
		ImGui.Spacing(ctx)
		ImGui.Spacing(ctx)

		rv, edit_buf.has_region = ImGui.Checkbox(ctx, "Attach REAPER region", edit_buf.has_region)
		if edit_buf.has_region and edit_buf.c.region_guid == nil then
			AttachRegion(edit_buf)
		elseif edit_buf.has_region == false and edit_buf.c.region_guid ~= nil then
			DeleteRegion(edit_buf)
		end

		ImGui.Spacing(ctx)
		ImGui.Spacing(ctx)
		ImGui.Separator(ctx)
		ImGui.Spacing(ctx)
		ImGui.Spacing(ctx)
		local col_picker = edit_buf.c.cluster_color
		if reaper.GetOS() == "Win32" or reaper.GetOS() == "Win64" then
			col_picker = edit_buf.c.cluster_color
			col_picker = ImGui.ColorConvertNative(col_picker)
		end
		local rv, new_color = ImGui.ColorPicker3(ctx, "", col_picker or 0, col_edit_flags)
		new_color = ImGui.ColorConvertNative(new_color)
		if edit_buf.c.cluster_color < 0 then new_color = new_color + 0x1000000 end
		if rv then
			
			if project_data.render_cluster_table[edit_buf.c.cluster_guid] then
				project_data.render_cluster_table[edit_buf.c.cluster_guid].cluster_color = new_color|0x1000000
			end
		end
		if rv and edit_buf.c.region_guid ~= nil then
			
			RegionManager.UpdateRegionColor(edit_buf.c.region_guid, new_color|0x1000000 or 0)
		end
		if reaper.GetOS() == "OSX32" or reaper.GetOS() == "OSX64" or reaper.GetOS() == "macOS-arm64" then
			new_color = ImGui.ColorConvertNative(new_color)
		end
		::skip_region::
		edit_buf.c.cluster_color = new_color|0x1000000
		if ImGui.Button(ctx, "Save", 70, 0) or ImGui.IsKeyPressed(ctx, ImGui.Key_Enter) then
			
			if UndoManager then UndoManager:push("AMAPP: Edit Cluster") end
			edit_buf.c.is_loop = edit_buf.new_loop_toggle
			EditSelectedCluster(edit_buf)
			if edit_buf.c.region_guid ~= nil then
				
				local region_info = RegionManager.GetRegionByGUID(edit_buf.c.region_guid)
				if region_info then
					reaper.SetProjectMarker3(0, region_info.displayIndex, true, region_info.position, region_info.regionEnd, edit_buf.c.cluster_id, edit_buf.c.cluster_color or 0)
				end
			end
			
			reaper.Undo_OnStateChange("AMAPP: Edit Cluster")
			ImGui.CloseCurrentPopup(ctx)
			gui.toggleLoop = edit_buf.new_loop_toggle
			new_loop_toggle = false
			edit_buf = {}
			cluster_buffered = false
			UpdateRenderClusterTable()
		end
		local _x, _y = ImGui.GetContentRegionAvail(ctx)
		ImGui.SameLine(ctx)
		ImGui.SetCursorPosX(ctx, _x - 70)
		if ImGui.Button(ctx, "Cancel", 70, 0) or ImGui.IsKeyPressed(ctx, ImGui.Key_Escape, false) then
			ImGui.CloseCurrentPopup(ctx)
			gui.toggleLoop = edit_buf.c.is_loop
			cluster_buffered = false
			
			if edit_buf.c.region_guid ~= nil then
				RegionManager.UpdateRegionColor(edit_buf.c.region_guid, edit_buf.old_color or 0)
			end
			
			if project_data.render_cluster_table[edit_buf.c.cluster_guid] then
				project_data.render_cluster_table[edit_buf.c.cluster_guid].cluster_color = edit_buf.old_color
			end
			if edit_buf.region_buffered and edit_buf.c.region_guid == nil then
				AttachRegion(edit_buf)
			elseif not edit_buf.region_buffered and edit_buf.c.region_guid ~= nil then
				DeleteRegion(edit_buf)
			end
			edit_buf = {}
			
			UpdateRenderClusterTable()
		end
		ImGui.EndPopup(ctx)
	end
end

local buf_cluster_table = {}
local function Modal_DeleteCluster()
	gui.SetClusterModalPosSize()
	if ImGui.BeginPopupModal(ctx, 'Delete Cluster', nil, ImGui.WindowFlags_NoResize | ImGui.WindowFlags_NoMove) then
		if cluster_buffered then goto continue end
		for k, v in pairs(project_data.render_cluster_list) do
			if v.is_selected then
				buf = v.cluster_id
				buf_cluster_table[v.cluster_guid] = v
				table.insert(buf_cluster_table, v)
				cluster_buffered = true
			end
		end
		if #buf_cluster_table == 0 then
			ImGui.CloseCurrentPopup(ctx)
			ImGui.EndPopup(ctx)
			return
		end
		::continue::
		if #buf_cluster_table == 1 then
			local indent = 14
			ImGui.Text(ctx, "Are you sure you want to delete cluster: ")
			ImGui.Indent(ctx, indent)
			ImGui.Text(ctx, buf)
			ImGui.Unindent(ctx, indent)
			ImGui.Text(ctx, "")
			ImGui.Text(ctx, "This action can not be undone. Are you sure?")
			ImGui.Text(ctx, "")
		elseif #buf_cluster_table > 1 then
			ImGui.Text(ctx, "You are about to delete ".. #buf_cluster_table .." clusters!")
			ImGui.Text(ctx, "")
			ImGui.Text(ctx, "This action can not be undone. Are you sure?")
			ImGui.Text(ctx, "")
		end
		if ImGui.Button(ctx, "Delete", 70, 0) or ImGui.IsKeyPressed(ctx, ImGui.Key_Delete) then
			for cluster_guid, cluster in pairs(buf_cluster_table) do
				DeleteCluster(cluster, cluster_guid)
			end
			ImGui.CloseCurrentPopup(ctx)
			buf_cluster_table = {}
			buf = ""
			cluster_buffered = false
		end
		ImGui.SameLine(ctx)
		if ImGui.Button(ctx, "Cancel", 70, 0) or ImGui.IsKeyPressed(ctx, ImGui.Key_Escape, false) then
			ImGui.CloseCurrentPopup(ctx)
			buf = ""
			buf_cluster_table = {}
			cluster_buffered = false
		end
		ImGui.EndPopup(ctx)
	end
end









local function DrawClusterMinimap(draw_list, map_x, map_y, map_width, rendered_guids, completed_guids, current_batch_guids, selected_guid)
	rendered_guids = rendered_guids or {}
	completed_guids = completed_guids or {}
	current_batch_guids = current_batch_guids or {}

	local clusters_to_draw = {}

	
	if project_data.render_cluster_table then
		for guid, cluster in pairs(project_data.render_cluster_table) do
			
			if cluster.c_start and cluster.c_end and cluster.c_start < cluster.c_end then
				local is_being_rendered = rendered_guids[guid] == true
				local is_completed = completed_guids[guid] == true
				local is_current = current_batch_guids[guid] == true
				table.insert(clusters_to_draw, {
					cluster = cluster,
					completed = is_completed,
					current = is_current,
					is_rendered = is_being_rendered
				})
			end
		end
	end

	if #clusters_to_draw == 0 then
		return 20  
	end

	
	table.sort(clusters_to_draw, function(a, b)
		return (a.cluster.c_start or 0) < (b.cluster.c_start or 0)
	end)

	
	local min_gap = 2
	local segments = {}
	local current_x = 0

	for _, item in ipairs(clusters_to_draw) do
		local c = item.cluster
		local duration = (c.c_end or 0) - (c.c_start or 0)
		if duration <= 0 then duration = 1 end

		
		local overlaps_with = nil
		local max_overlap_end = 0
		for _, seg in ipairs(segments) do
			local seg_c = seg.item.cluster
			if c.c_start < seg_c.c_end and c.c_end > seg_c.c_start then
				if seg.x_end > max_overlap_end then
					max_overlap_end = seg.x_end
					overlaps_with = seg
				end
			end
		end

		local x_start
		if overlaps_with then
			local overlap_c = overlaps_with.item.cluster
			local overlap_duration = overlap_c.c_end - overlap_c.c_start
			local relative_offset = (c.c_start - overlap_c.c_start) / overlap_duration
			local overlap_width = overlaps_with.x_end - overlaps_with.x_start
			x_start = overlaps_with.x_start + relative_offset * overlap_width
		else
			if #segments > 0 then
				local last_seg = segments[#segments]
				x_start = last_seg.x_end + min_gap
			else
				x_start = 0
			end
		end

		table.insert(segments, {
			x_start = x_start,
			x_end = x_start + duration,
			item = item
		})
		if x_start + duration > current_x then
			current_x = x_start + duration
		end
	end

	
	local bar_height = 10

	
	local total_width = current_x
	if total_width <= 0 then total_width = 1 end
	local scale = map_width / total_width

	
	
	table.sort(segments, function(a, b)
		local dur_a = a.x_end - a.x_start
		local dur_b = b.x_end - b.x_start
		return dur_a > dur_b
	end)

	
	local rows = {}
	for _, seg in ipairs(segments) do
		local scaled_start = seg.x_start * scale
		local scaled_end = seg.x_end * scale
		local assigned_row = nil
		for row_idx, row in ipairs(rows) do
			local fits = true
			for _, occupied in ipairs(row) do
				if scaled_start < occupied.x_end and scaled_end > occupied.x_start then
					fits = false
					break
				end
			end
			if fits then
				assigned_row = row_idx
				break
			end
		end
		if not assigned_row then
			assigned_row = #rows + 1
			rows[assigned_row] = {}
		end
		table.insert(rows[assigned_row], {x_start = scaled_start, x_end = scaled_end})
		seg.row = assigned_row
	end

	local num_rows = #rows
	local row_height = bar_height + 2
	local total_map_height = num_rows * row_height

	
	local clicked_guid = nil
	for _, seg in ipairs(segments) do
		local item = seg.item
		local cluster = item.cluster
		local scaled_start = seg.x_start * scale
		local scaled_width = (seg.x_end - seg.x_start) * scale
		scaled_width = math.max(4, scaled_width)

		local bar_x = map_x + scaled_start
		
		local bar_y = map_y + (num_rows - seg.row) * row_height

		
		local cluster_color = cluster.cluster_color or 0x888888
		local r = (cluster_color >> 16) & 0xFF
		local g = (cluster_color >> 8) & 0xFF
		local b = cluster_color & 0xFF

		local rounding = math.min(3, bar_height / 3)

		if not item.is_rendered then
			
			local bg_alpha = 0x20
			local outline_color = (r << 24) | (g << 16) | (b << 8) | bg_alpha
			ImGui.DrawList_AddRect(draw_list, bar_x, bar_y, bar_x + scaled_width, bar_y + bar_height, outline_color, rounding, 0, 1)
		elseif item.completed then
			
			local fill_color = (r << 24) | (g << 16) | (b << 8) | 0xFF
			ImGui.DrawList_AddRectFilled(draw_list, bar_x, bar_y, bar_x + scaled_width, bar_y + bar_height, fill_color, rounding)
			
			local highlight = 0xFFFFFF40
			ImGui.DrawList_AddLine(draw_list, bar_x + rounding, bar_y + 1, bar_x + scaled_width - rounding, bar_y + 1, highlight)
		elseif item.current then
			
			local fill_alpha = 0x40  
			local fill_color = (r << 24) | (g << 16) | (b << 8) | fill_alpha
			ImGui.DrawList_AddRectFilled(draw_list, bar_x, bar_y, bar_x + scaled_width, bar_y + bar_height, fill_color, rounding)
			
			local outline_alpha = 0xE0  
			local outline_color = (r << 24) | (g << 16) | (b << 8) | outline_alpha
			ImGui.DrawList_AddRect(draw_list, bar_x, bar_y, bar_x + scaled_width, bar_y + bar_height, outline_color, rounding, 0, 1)
		else
			
			local dim_alpha = 0x60
			local outline_color = (r << 24) | (g << 16) | (b << 8) | dim_alpha
			ImGui.DrawList_AddRect(draw_list, bar_x, bar_y, bar_x + scaled_width, bar_y + bar_height, outline_color, rounding, 0, 1)
		end

		
		if selected_guid and cluster.cluster_guid == selected_guid then
			
			ImGui.DrawList_AddRect(draw_list, bar_x - 1, bar_y - 1, bar_x + scaled_width + 1, bar_y + bar_height + 1, 0xFFFFFFCC, rounding, 0, 1.5)
			
			ImGui.DrawList_AddLine(draw_list, bar_x + rounding, bar_y + 0.5, bar_x + scaled_width - rounding, bar_y + 0.5, 0xFFFFFF90, 1)
			
			ImGui.DrawList_AddLine(draw_list, bar_x + rounding, bar_y + bar_height - 0.5, bar_x + scaled_width - rounding, bar_y + bar_height - 0.5, 0x00000060, 1)
		end

		
		if not clicked_guid and item.is_rendered then
			local mx, my = ImGui.GetMousePos(ctx)
			if mx >= bar_x and mx <= bar_x + scaled_width and my >= bar_y and my <= bar_y + bar_height then
				
				ImGui.DrawList_AddRect(draw_list, bar_x, bar_y, bar_x + scaled_width, bar_y + bar_height, 0xFFFFFF60, rounding, 0, 1)
				ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand)
				if ImGui.IsMouseClicked(ctx, 0) then
					clicked_guid = cluster.cluster_guid
				end
			end
		end
	end

	return total_map_height, clicked_guid
end



local function DrawClusterWaveform(draw_list, x, y, width, height, result, playback_pos)
	if not result or not result.output_path then
		return nil 
	end

	local output_path = result.output_path

	
	if not reaper.file_exists(output_path) then
		
		ImGui.DrawList_AddRectFilled(draw_list, x, y, x + width, y + height, 0x1A1A1AFF, 4)
		ImGui.DrawList_AddRect(draw_list, x, y, x + width, y + height, 0x333333FF, 4, 0, 1)
		
		return nil
	end

	
	local cache = gui.waveform_peaks_cache
	local cache_valid = cache and cache.path == output_path and cache.width == math.floor(width)

	if not cache_valid then
		
		
		os.remove(output_path .. ".reapeaks")
		local tmp_name = output_path .. ".amapp_" .. tostring(math.floor(reaper.time_precise() * 10000))
		os.rename(output_path, tmp_name)
		local src = reaper.PCM_Source_CreateFromFile(tmp_name)
		os.rename(tmp_name, output_path)
		if not src then
			ImGui.DrawList_AddRectFilled(draw_list, x, y, x + width, y + height, 0x1A1A1AFF, 4)
			return nil
		end

		local length = reaper.GetMediaSourceLength(src)
		local num_channels = reaper.GetMediaSourceNumChannels(src)

		if length <= 0 then
			reaper.PCM_Source_Destroy(src)
			ImGui.DrawList_AddRectFilled(draw_list, x, y, x + width, y + height, 0x1A1A1AFF, 4)
			return nil
		end

		
		
		local num_pixels = math.floor(width)
		local peaks = {}
		local max_peak = 0
		local sample_rate = reaper.GetMediaSourceSampleRate(src)
		local samples_per_pixel = math.max(1, math.floor(length * sample_rate / num_pixels))

		
		reaper.PreventUIRefresh(1)
		local temp_track_idx = reaper.CountTracks(0)
		reaper.InsertTrackAtIndex(temp_track_idx, false)
		local temp_track = reaper.GetTrack(0, temp_track_idx)
		local temp_item = reaper.AddMediaItemToTrack(temp_track)
		reaper.SetMediaItemInfo_Value(temp_item, "D_POSITION", 0)
		reaper.SetMediaItemInfo_Value(temp_item, "D_LENGTH", length)
		local temp_take = reaper.AddTakeToMediaItem(temp_item)
		reaper.SetMediaItemTake_Source(temp_take, src)

		local accessor = reaper.CreateTakeAudioAccessor(temp_take)
		if accessor then
			local buf = reaper.new_array(samples_per_pixel * num_channels)
			for px = 1, num_pixels do
				local time_start = (px - 1) / num_pixels * length
				local spp = samples_per_pixel
				buf.clear()
				reaper.GetAudioAccessorSamples(accessor, sample_rate, num_channels, time_start, spp, buf)
				local samples = buf.table()
				local peak_val = 0
				for i = 1, #samples do
					local v = samples[i]
					if v then
						local abs_v = v < 0 and -v or v
						if abs_v > peak_val then peak_val = abs_v end
					end
				end
				peaks[px] = peak_val
				if peak_val > max_peak then max_peak = peak_val end
			end
			reaper.DestroyAudioAccessor(accessor)
		else
			for px = 1, num_pixels do peaks[px] = 0 end
		end

		
		
		reaper.DeleteTrack(temp_track)
		reaper.PreventUIRefresh(-1)
		src = nil 

		gui.waveform_peaks_cache = {
			path = output_path,
			peaks = peaks,
			length = length,
			channels = num_channels,
			width = math.floor(width),
			max_peak = max_peak,
		}

		if src then reaper.PCM_Source_Destroy(src) end
		cache = gui.waveform_peaks_cache
	end

	
	local bg_r, bg_g, bg_b = 0x1A, 0x1A, 0x1A
	if result.cluster_color then
		bg_r = (result.cluster_color >> 16) & 0xFF
		bg_g = (result.cluster_color >> 8) & 0xFF
		bg_b = result.cluster_color & 0xFF
	end

	
	
	local luminance = (0.299 * bg_r + 0.587 * bg_g + 0.114 * bg_b) / 255
	local is_light_bg = luminance > 0.5

	
	local bg_color = (bg_r << 24) | (bg_g << 16) | (bg_b << 8) | 0xFF
	ImGui.DrawList_AddRectFilled(draw_list, x, y, x + width, y + height, bg_color, 4)

	
	if not cache or not cache.peaks or #cache.peaks == 0 then
		local border_color = is_light_bg and 0x00000044 or 0xFFFFFF44
		ImGui.DrawList_AddRect(draw_list, x, y, x + width, y + height, border_color, 4, 0, 1)
		return nil
	end

	
	local max_peak = cache and cache.max_peak or 0
	if cache and cache.peaks and #cache.peaks > 0 and max_peak > 0.001 then
		local peaks = cache.peaks
		local center_y = y + height / 2
		local half_height = (height / 2) - 3 

		
		local wave_fill = is_light_bg and 0x000000CC or 0xFFFFFFCC

		
		local smooth_radius = 2  
		local smoothed = {}
		for i = 1, #peaks do
			local sum = 0
			local count = 0
			for j = math.max(1, i - smooth_radius), math.min(#peaks, i + smooth_radius) do
				sum = sum + peaks[j]
				count = count + 1
			end
			smoothed[i] = sum / count
		end

		
		
		for i = 1, #smoothed do
			local px = x + i - 1
			local peak = smoothed[i]

			
			local scaled_height = peak * half_height

			
			if scaled_height < 1 and peak > 0.001 then
				scaled_height = 1
			end

			if scaled_height > 0.5 then
				
				local y1 = center_y - scaled_height
				local y2 = center_y + scaled_height

				
				ImGui.DrawList_AddRectFilled(draw_list, px, y1, px + 1, y2, wave_fill)
			end
		end

		
		local center_line_color = is_light_bg and 0x00000020 or 0xFFFFFF20
		ImGui.DrawList_AddLine(draw_list, x, center_y, x + width, center_y, center_line_color, 1)
	else
		
		local center_y = y + height / 2
		local text_color = is_light_bg and 0x00000060 or 0xFFFFFF60

		
		ImGui.DrawList_AddLine(draw_list, x + 10, center_y, x + width - 10, center_y, text_color, 1)

		
		for i = 0, 4 do
			local marker_x = x + 20 + i * ((width - 40) / 4)
			ImGui.DrawList_AddLine(draw_list, marker_x, center_y - 3, marker_x, center_y + 3, text_color, 1)
		end
	end

	
	local border_color = is_light_bg and 0x00000044 or 0xFFFFFF44
	ImGui.DrawList_AddRect(draw_list, x, y, x + width, y + height, border_color, 4, 0, 1)

	
	local playhead_color = is_light_bg and 0x000000AA or 0xFFFFFFAA
	local hover_color = is_light_bg and 0x00000040 or 0xFFFFFF40

	
	if playback_pos and playback_pos >= 0 and playback_pos <= 1 then
		local playhead_x = x + playback_pos * width
		
		ImGui.DrawList_AddLine(draw_list, playhead_x, y + 2, playhead_x, y + height - 2, playhead_color, 1)
	end

	
	local mouse_x, mouse_y = ImGui.GetMousePos(ctx)
	local is_hovered = mouse_x >= x and mouse_x <= x + width and mouse_y >= y and mouse_y <= y + height

	if is_hovered then
		
		ImGui.DrawList_AddLine(draw_list, mouse_x, y + 2, mouse_x, y + height - 2, hover_color, 1)

		
		if ImGui.IsMouseClicked(ctx, 0) then
			local click_pos = (mouse_x - x) / width
			click_pos = math.max(0, math.min(1, click_pos))
			return click_pos 
		end
	end

	return nil 
end



local audition_window_open = false
local function Modal_Audition()
	
	if gui.show_audition_popup or gui.show_render_summary then
		audition_window_open = true
		gui.show_audition_popup = false  
		gui.show_render_summary = false
	end

	
	if not audition_window_open then
		return
	end

	local center = {ImGui.Viewport_GetCenter(ImGui.GetMainViewport(ctx))}
	ImGui.SetNextWindowPos(ctx, center[1], center[2], ImGui.Cond_Appearing, 0.5, 0.5)
	ImGui.SetNextWindowSize(ctx, 650, 620, ImGui.Cond_Appearing)

	local window_flags = ImGui.WindowFlags_NoScrollbar | ImGui.WindowFlags_NoCollapse
	local visible, open = ImGui.Begin(ctx, "Audition & Implementation", true, window_flags)
	if not open then
		
		audition_window_open = false
		gui.render_summary_data = nil
		gui.audition_cluster = nil
		
		gui.waveform_selected_result = nil
		gui.waveform_peaks_cache = nil
		gui.preview_playing = false
		if gui.current_preview then
			reaper.CF_Preview_Stop(gui.current_preview)
			gui.current_preview = nil
		end
		if gui.current_preview_src then
			reaper.PCM_Source_Destroy(gui.current_preview_src)
			gui.current_preview_src = nil
		end
		ClearRenderProgress()
		project_data.render_in_progress = false
		ImGui.End(ctx)
		return
	end
	if visible then
		local modal_w, modal_h = ImGui.GetWindowSize(ctx)
		local render_data = gui.render_summary_data
		local has_render_results = render_data ~= nil and render_data.results ~= nil

		
		SafePushFont(ctx, gui.fonts.sans_serif_bold)
		if gui.audition_cluster then
			ImGui.Text(ctx, gui.audition_cluster.cluster_id or "Unknown Cluster")
		elseif has_render_results and #render_data.results > 0 then
			ImGui.Text(ctx, "Render Results")
		else
			ImGui.Text(ctx, "Audition & Implementation")
		end
		SafePopFont(ctx)

		ImGui.Spacing(ctx)
		ImGui.Separator(ctx)
		ImGui.Spacing(ctx)

		
		local content_height = modal_h - 110
		if ImGui.BeginChild(ctx, "AuditionContent", modal_w - 20, content_height, ImGui.ChildFlags_Borders) then

			
			if has_render_results then
				
				if render_data.aborted then
					ImGui.TextColored(ctx, 0xFFAA66FF, "Rendering Aborted")
				else
					ImGui.TextColored(ctx, 0x66FF66FF, "Rendering Complete")
				end

				ImGui.SameLine(ctx, 200)
				ImGui.TextDisabled(ctx, string.format("Time: %s", FormatDuration(render_data.total_time or 0)))

				ImGui.Spacing(ctx)
				ImGui.Separator(ctx)
				ImGui.Spacing(ctx)

				
				local rendered_guids = {}
				local completed_guids = {}
				for _, result in ipairs(render_data.results) do
					if result.cluster_guid then
						rendered_guids[result.cluster_guid] = true
						if result.success then
							completed_guids[result.cluster_guid] = true
						end
					end
				end

				local content_w = ImGui.GetContentRegionAvail(ctx)
				local map_width = math.min(content_w - 20, 500)
				local cursor_x, cursor_y = ImGui.GetCursorScreenPos(ctx)
				local draw_list = ImGui.GetWindowDrawList(ctx)
				local map_x = cursor_x + (content_w - map_width) / 2
				local audition_selected_guid = gui.waveform_selected_result and gui.waveform_selected_result.cluster_guid
				local map_height, minimap_clicked_guid = DrawClusterMinimap(draw_list, map_x, cursor_y, map_width, rendered_guids, completed_guids, nil, audition_selected_guid)

				
				if minimap_clicked_guid then
					for _, r in ipairs(render_data.results) do
						if r.cluster_guid == minimap_clicked_guid then
							
							if gui.current_preview then
								reaper.CF_Preview_Stop(gui.current_preview)
								if gui.current_preview_src then
									reaper.PCM_Source_Destroy(gui.current_preview_src)
									gui.current_preview_src = nil
								end
								gui.current_preview = nil
								gui.preview_playing = false
							end
							r.cluster_color = r.cluster_color or (project_data.render_cluster_table and project_data.render_cluster_table[r.cluster_guid] and project_data.render_cluster_table[r.cluster_guid].cluster_color)
							gui.waveform_selected_result = r
							gui.waveform_peaks_cache = nil
							break
						end
					end
				end
				ImGui.Dummy(ctx, content_w, map_height + 10)

				ImGui.Spacing(ctx)

				
				local waveform_height = 80
				local selected_result = gui.waveform_selected_result

				
				local playback_pos = nil
				if gui.current_preview and selected_result and gui.preview_playing then
					local _, pos = reaper.CF_Preview_GetValue(gui.current_preview, "D_POSITION")
					local _, len = reaper.CF_Preview_GetValue(gui.current_preview, "D_LENGTH")
					if type(pos) == "number" and type(len) == "number" and len > 0 then
						playback_pos = math.min(pos / len, 1.0)
						
						if pos >= len then
							gui.preview_playing = false
						end
					end
				end

				
				if selected_result and selected_result.output_path then
					local wave_x = cursor_x + (content_w - map_width) / 2
					local wave_cursor_y = select(2, ImGui.GetCursorScreenPos(ctx))

					
					ImGui.TextDisabled(ctx, "Preview: " .. (selected_result.cluster_id or "Unknown"))

					wave_cursor_y = select(2, ImGui.GetCursorScreenPos(ctx))
					local wave_draw_list = ImGui.GetWindowDrawList(ctx)

					
					local seek_pos = DrawClusterWaveform(wave_draw_list, wave_x, wave_cursor_y, map_width, waveform_height, selected_result, playback_pos)

					if seek_pos then
						
						
						if reaper.CF_Preview_StopAll then
							reaper.CF_Preview_StopAll()
						end
						
						if gui.current_preview_src then
							reaper.PCM_Source_Destroy(gui.current_preview_src)
							gui.current_preview_src = nil
						end
						gui.current_preview = nil

						
						if selected_result.output_path and reaper.file_exists(selected_result.output_path) and reaper.CF_CreatePreview then
							os.remove(selected_result.output_path .. ".reapeaks")
							local tmp_name = selected_result.output_path .. ".amapp_" .. tostring(math.floor(reaper.time_precise() * 10000))
							os.rename(selected_result.output_path, tmp_name)
							local src = reaper.PCM_Source_CreateFromFile(tmp_name)
							os.rename(tmp_name, selected_result.output_path)
							if src then
								gui.current_preview_src = src
								gui.current_preview = reaper.CF_CreatePreview(src)
								if gui.current_preview then
									reaper.CF_Preview_SetValue(gui.current_preview, "D_VOLUME", 1.0)
									local _, len = reaper.CF_Preview_GetValue(gui.current_preview, "D_LENGTH")
									if type(len) == "number" and len > 0 then
										reaper.CF_Preview_SetValue(gui.current_preview, "D_POSITION", seek_pos * len)
									end
									reaper.CF_Preview_Play(gui.current_preview)
									gui.preview_playing = true
								end
							end
						end
					end

					ImGui.Dummy(ctx, content_w, waveform_height + 5)
					ImGui.Spacing(ctx)
				else
					
					ImGui.TextDisabled(ctx, "Click Play on a cluster to see its waveform")
					ImGui.Spacing(ctx)
				end

				
				local table_height = content_height - 260
				if ImGui.BeginTable(ctx, "RenderResults", 3, ImGui.TableFlags_BordersInnerH | ImGui.TableFlags_RowBg | ImGui.TableFlags_ScrollY, 0, table_height) then
					ImGui.TableSetupColumn(ctx, "Cluster", ImGui.TableColumnFlags_WidthFixed, modal_w * 0.5)
					ImGui.TableSetupColumn(ctx, "Status", ImGui.TableColumnFlags_WidthFixed, 40)
					ImGui.TableSetupColumn(ctx, "Actions", ImGui.TableColumnFlags_WidthFixed, 120)
					ImGui.TableHeadersRow(ctx)

					for _, r in ipairs(render_data.results) do
						ImGui.TableNextRow(ctx)

						
						local is_row_selected = gui.waveform_selected_result and gui.waveform_selected_result.output_path == r.output_path

						
						ImGui.TableNextColumn(ctx)
						ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + 6)
						local file_exists_for_select = r.output_path and reaper.file_exists(r.output_path)
						if file_exists_for_select then
							
							if ImGui.Selectable(ctx, "  " .. (r.cluster_id or "Unknown"), is_row_selected) then
								
								if not is_row_selected and gui.current_preview then
									reaper.CF_Preview_Stop(gui.current_preview)
									if gui.current_preview_src then
										reaper.PCM_Source_Destroy(gui.current_preview_src)
										gui.current_preview_src = nil
									end
									gui.current_preview = nil
									gui.preview_playing = false
								end
								
								r.cluster_color = r.cluster_color or (project_data.render_cluster_table and project_data.render_cluster_table[r.cluster_guid] and project_data.render_cluster_table[r.cluster_guid].cluster_color)
								
								gui.waveform_selected_result = r
								
								gui.waveform_peaks_cache = nil
							end
						else
							ImGui.Text(ctx, "  " .. (r.cluster_id or "Unknown"))
						end

						
						ImGui.TableNextColumn(ctx)
						ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + 4)
						if r.success and r.output_path and reaper.file_exists(r.output_path) then
							ImGui.TextColored(ctx, 0x66FF66FF, "OK")
						elseif r.file_exists == false then
							ImGui.TextColored(ctx, 0xFFAA66FF, "No File")
						else
							ImGui.TextColored(ctx, 0xFF6666FF, "FAILED")
						end

						
						ImGui.TableNextColumn(ctx)
						ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + 4)
						ImGui.PushID(ctx, r.cluster_id or "unknown")

						
						local file_exists = r.output_path and reaper.file_exists(r.output_path)

						
						local is_selected = gui.waveform_selected_result and gui.waveform_selected_result.output_path == r.output_path
						
						local is_playing = is_selected and gui.preview_playing == true

						if not file_exists then
							
							ImGui.BeginDisabled(ctx)
						end

						
						local play_label = is_playing and "\u{25A0} Stop" or "\u{25B6} Play"
						local btn_w = ImGui.CalcTextSize(ctx, "\u{25A0} Stop  ") + ImGui.GetStyleVar(ctx, ImGui.StyleVar_FramePadding) * 2
						if ImGui.Button(ctx, play_label, btn_w, 0) then
							
							if file_exists and reaper.CF_CreatePreview then
								if is_playing then
									
									if gui.current_preview then
										reaper.CF_Preview_Stop(gui.current_preview)
									end
									if gui.current_preview_src then
										reaper.PCM_Source_Destroy(gui.current_preview_src)
										gui.current_preview_src = nil
									end
									gui.current_preview = nil
									gui.preview_playing = false
								else
									
									
									
									if gui.current_preview then
										reaper.CF_Preview_Stop(gui.current_preview)
									end
									if gui.current_preview_src then
										reaper.PCM_Source_Destroy(gui.current_preview_src)
										gui.current_preview_src = nil
									end
									gui.current_preview = nil
									gui.preview_playing = false

									
									os.remove(r.output_path .. ".reapeaks")
									local tmp_name = r.output_path .. ".amapp_" .. tostring(math.floor(reaper.time_precise() * 10000))
									os.rename(r.output_path, tmp_name)
									local src = reaper.PCM_Source_CreateFromFile(tmp_name)
									os.rename(tmp_name, r.output_path)
									if src then
										gui.current_preview_src = src
										gui.current_preview = reaper.CF_CreatePreview(src)
										if gui.current_preview then
											reaper.CF_Preview_SetValue(gui.current_preview, "D_VOLUME", 1.0)
											reaper.CF_Preview_SetValue(gui.current_preview, "D_POSITION", 0)
											r.cluster_color = r.cluster_color or (project_data.render_cluster_table and project_data.render_cluster_table[r.cluster_guid] and project_data.render_cluster_table[r.cluster_guid].cluster_color)
											
											if not gui.waveform_selected_result or gui.waveform_selected_result.output_path ~= r.output_path then
												gui.waveform_peaks_cache = nil
											end
											gui.waveform_selected_result = r
											reaper.CF_Preview_Play(gui.current_preview)
											gui.preview_playing = true
										end
									end
								end
							end
						end
						if not file_exists then
							ImGui.EndDisabled(ctx)
						end

						ImGui.SameLine(ctx)
						if ImGui.SmallButton(ctx, "Locate") then
							
							if r.output_path then
								local _os = reaper.GetOS()
								if reaper.file_exists(r.output_path) then
									if _os == "OSX32" or _os == "OSX64" or _os == "macOS-arm64" then
										os.execute('open -R "' .. r.output_path .. '"')
									elseif _os == "Win32" or _os == "Win64" then
										os.execute('explorer /select,"' .. r.output_path .. '"')
									else
										local folder = r.output_path:match("^(.+[\\/])")
										if folder and reaper.CF_ShellExecute then
											reaper.CF_ShellExecute(folder)
										end
									end
								else
									
									local folder = r.output_path:match("^(.+[\\/])")
									if folder and reaper.CF_ShellExecute then
										reaper.CF_ShellExecute(folder)
									end
								end
							end
						end
						ImGui.PopID(ctx)
					end

					ImGui.EndTable(ctx)
				end

				ImGui.Spacing(ctx)

				
				local actual_success = 0
				local missing_files = 0
				for _, r in ipairs(render_data.results) do
					if r.output_path and reaper.file_exists(r.output_path) then
						actual_success = actual_success + 1
					else
						missing_files = missing_files + 1
					end
				end
				ImGui.TextDisabled(ctx, string.format("Rendered: %d / %d clusters", actual_success, #render_data.results))
				if missing_files > 0 then
					ImGui.SameLine(ctx)
					ImGui.TextColored(ctx, 0xFFAA66FF, string.format("  |  Missing: %d", missing_files))
				end

			else
				
				ImGui.TextDisabled(ctx, "Select clusters and render to see results here.")
				ImGui.Spacing(ctx)
				ImGui.Spacing(ctx)

				
				if gui.audition_cluster then
					ImGui.Text(ctx, "Quick Actions:")
					ImGui.Spacing(ctx)

					if ImGui.Button(ctx, "Render This Cluster", 150, 0) then
						
						project_data.render_pending = {
							clusters = {gui.audition_cluster},
							focus_and_solo = gui.focus_activated and gui.solo_clusters_on_focus,
							focused_clusters = {gui.audition_cluster}
						}
						project_data.render_in_progress = true
						project_data.render_anim_start_frame = GetCachedFrameCount()
						audition_window_open = false
						gui.audition_cluster = nil
					end

					ImGui.SameLine(ctx)
					if ImGui.Button(ctx, "Focus Cluster", 120, 0) then
						ClearClusterSelection()
						gui.audition_cluster.is_selected = true
						if gui.focus_activated then
							FocusSelectedClusters()
						end
					end
				end
			end

			ImGui.EndChild(ctx)
		end

		ImGui.Spacing(ctx)

		
		local btn_width = 100
		local btn_spacing = 10

		if ImGui.Button(ctx, "Close", btn_width, 0) or ImGui.IsKeyPressed(ctx, ImGui.Key_Escape, false) then
			audition_window_open = false
			gui.render_summary_data = nil
			gui.audition_cluster = nil
			
			gui.waveform_selected_result = nil
			gui.waveform_peaks_cache = nil
			if gui.current_preview then
				reaper.CF_Preview_Stop(gui.current_preview)
				gui.current_preview = nil
			end
			if gui.current_preview_src then
				reaper.PCM_Source_Destroy(gui.current_preview_src)
				gui.current_preview_src = nil
			end
			
			ClearRenderProgress()
			project_data.render_in_progress = false
		end

		ImGui.SameLine(ctx)
		if ImGui.Button(ctx, "Open Folder", btn_width, 0) then
			OpenRenderFolder()
		end

		
		if gui.current_preview then
			local _, playing_val = reaper.CF_Preview_GetValue(gui.current_preview, "B_PLAYING")
			if playing_val == true or playing_val == 1 then
				ImGui.SameLine(ctx)
				if ImGui.Button(ctx, "Stop", 60, 0) then
					reaper.CF_Preview_Stop(gui.current_preview)
					gui.current_preview = nil
					if gui.current_preview_src then
						reaper.PCM_Source_Destroy(gui.current_preview_src)
						gui.current_preview_src = nil
					end
				end
			end
		end

		if has_render_results then
			ImGui.SameLine(ctx)
			if ImGui.Button(ctx, "Clear Results", btn_width, 0) then
				gui.render_summary_data = nil
				
				gui.waveform_selected_result = nil
				gui.waveform_peaks_cache = nil
				if gui.current_preview then
					reaper.CF_Preview_Stop(gui.current_preview)
					gui.current_preview = nil
				end
				if gui.current_preview_src then
					reaper.PCM_Source_Destroy(gui.current_preview_src)
					gui.current_preview_src = nil
				end
				
				ClearRenderProgress()
				project_data.render_in_progress = false
			end
		end
	end
	ImGui.End(ctx)
end


local export_config = {
	buf = {},
	buf_old = {},
	table_buffered = false,
	sample_rates = {"44100", "48000", "88200", "96000", "176400", "192000"},
	sample_rates_combo = " 44100\0 48000\0 88200\0 96000\0 176400\0 192000\0",
	channels = {1, 2, 4, 6, 8},
	channels_combo = " Mono\0 Stereo\0 4\0 6\0 8\0",
	primary_formats = {"WAV", "FLAC", "OGG"},
	primary_formats_combo = " WAV\0 FLAC\0 OGG\0",
	wav_bit_depths = {"8-bit PCM", "16-bit PCM", "24-bit PCM", "32-bit FP", "64-bit FP", "4-bit IMA ADPCM", "2-bit cADPCM", "32-bit PCM", "8-bit u-Law"},
	wav_bit_depths_combo = " 8-bit PCM\0 16-bit PCM\0 24-bit PCM\0 32-bit FP\0 64-bit FP\0 4-bit IMA ADPCM\0 2-bit cADPCM\0 32-bit PCM\0 8-bit u-Law\0",
	flac_bit_depths = {"16-bit", "24-bit"},
	flac_bit_depths_combo = " 16-bit\0 24-bit\0"
}
local function Modal_ClusterExportOptions()
	gui.SetClusterModalPosSize()
	if ImGui.BeginPopupModal(ctx, "Render Options", nil, ImGui.WindowFlags_NoResize | ImGui.WindowFlags_NoMove) then
		if not export_config.table_buffered then
			export_config.buf = LoadExportOptions() or Init_export_options()
			export_config.buf_old = {}
			for k, v in pairs(export_config.buf) do export_config.buf_old[k] = v end
			buf = export_config.buf.export_file_name or ""
			export_config.table_buffered = true
		end
		SafePushFont(ctx, gui.fonts.mono_bold)
		ImGui.LabelText(ctx, "", "Output")
		SafePopFont(ctx)
		local _, c_y = ImGui.GetCursorPos(ctx)
		ImGui.SetCursorPosY(ctx, c_y + 10)
		rv, export_config.buf.file_path = ImGui.InputTextWithHint(ctx, "File path", export_config.buf_old.file_path or "AMAPP Exports", export_config.buf.file_path)
		ImGui.SameLine(ctx, 0.0, -1.0)
		ImGui.Text(ctx, "[?]")
		if ImGui.IsItemHovered(ctx) then
			ImGui.SetTooltip(ctx, "Supports wildcards: $project, $projectdir, etc.\nCan be absolute or relative to project folder.")
		end
		rv, buf = ImGui.InputTextWithHint(ctx, "##", export_config.buf.export_file_name or "$cluster", buf)
		ImGui.SameLine(ctx, 0.0, -1.0)
		ImGui.Text(ctx, "[?]")
		if ImGui.IsItemHovered(ctx) then
			local tooltip_text = "Supported wildcards:\n\n$project\n$projectdir\n$title\n$author\n$notes\n$date (YYYY-MM-DD)\n$tempo\n$timesignature\n$regionnumber\n$region\n$cluster\n\nNOTE: Currently $regions\nand $cluster will default\nto cluster name."
			ImGui.SetTooltip(ctx, tooltip_text)
		end
		ImGui.Spacing(ctx)
		rv, export_config.buf.primary_output_format.sample_rate_code = ImGui.Combo(ctx, "Sample Rate", export_config.buf.primary_output_format.sample_rate_code, export_config.sample_rates_combo)
		if rv then
			export_config.buf.primary_output_format.sample_rate = export_config.sample_rates[export_config.buf.primary_output_format.sample_rate_code+1]
		end
		rv, export_config.buf.channels_code = ImGui.Combo(ctx, "Channels", export_config.buf.channels_code, export_config.channels_combo)
		if rv then
			export_config.buf.channels = export_config.channels[export_config.buf.channels_code+1]
		end
		
		rv, export_config.buf.primary_output_format.format_code = ImGui.Combo(ctx, "Format", export_config.buf.primary_output_format.format_code or 0, export_config.primary_formats_combo)
		if rv then
			export_config.buf.primary_output_format.format = export_config.primary_formats[export_config.buf.primary_output_format.format_code + 1]
		end
		
		if export_config.buf.primary_output_format.format == "WAV" then
			rv, export_config.buf.primary_output_format.bit_depth_code = ImGui.Combo(ctx, "Bit Depth", export_config.buf.primary_output_format.bit_depth_code or 2, export_config.wav_bit_depths_combo)
			if rv then
				export_config.buf.primary_output_format.bit_depth = export_config.buf.primary_output_format.bit_depth_code
			end
		elseif export_config.buf.primary_output_format.format == "FLAC" then
			rv, export_config.buf.primary_output_format.flac_bit_depth_code = ImGui.Combo(ctx, "Bit Depth", export_config.buf.primary_output_format.flac_bit_depth_code or 1, export_config.flac_bit_depths_combo)
			if rv then
				export_config.buf.primary_output_format.flac_bit_depth = export_config.buf.primary_output_format.flac_bit_depth_code
			end
			rv, export_config.buf.primary_output_format.flac_compression = ImGui.SliderInt(ctx, "Compression", export_config.buf.primary_output_format.flac_compression or 5, 0, 8)
			if ImGui.IsItemHovered(ctx) then
				ImGui.SetTooltip(ctx, "0 = Fastest encoding, larger file\n8 = Slowest encoding, smallest file\n5 = Default/recommended")
			end
		elseif export_config.buf.primary_output_format.format == "OGG" then
			rv, export_config.buf.primary_output_format.ogg_quality = ImGui.SliderDouble(ctx, "Quality", export_config.buf.primary_output_format.ogg_quality or 1.0, 0.0, 1.0, "%.2f")
			if ImGui.IsItemHovered(ctx) then
				ImGui.SetTooltip(ctx, "0.0 = Lowest quality, smallest file\n1.0 = Highest quality, largest file")
			end
		end
		rv, export_config.buf.tail_enabled = ImGui.Checkbox(ctx, "Tail", export_config.buf.tail_enabled)
		ImGui.SameLine(ctx)
		ImGui.BeginDisabled(ctx, not export_config.buf.tail_enabled)
		rv, export_config.buf.tail_ms = ImGui.InputInt(ctx, "Tail MS", export_config.buf.tail_ms, 1, 100)
		if export_config.buf.tail_ms < 0 then export_config.buf.tail_ms = 0 end
		ImGui.EndDisabled(ctx)

		rv, export_config.buf.export_secondary = ImGui.Checkbox(ctx, "Render compressed duplicate (OGG)", export_config.buf.export_secondary)
		rv, export_config.buf.overwrite_existing = ImGui.Checkbox(ctx, "Overwrite existing files", export_config.buf.overwrite_existing)
		rv, export_config.buf.close_after_render = ImGui.Checkbox(ctx, "Skip Render Stats", export_config.buf.close_after_render)

		ImGui.Spacing(ctx)
		_, c_y = ImGui.GetCursorPos(ctx)
		ImGui.SetCursorPosY(ctx, c_y + 10)

		
		ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + 20)
		if ImGui.Button(ctx, "Save as default Render Options") then
			if buf == "" and export_config.buf.export_file_name == "" then
				export_config.buf.export_file_name = "$cluster"
			elseif buf == "" then
				export_config.buf.export_file_name = export_config.buf.export_file_name
			else
				export_config.buf.export_file_name = buf
			end
			Save_Cluster_Export_Options(export_config.buf)
			Save_Default_Export_Options(export_config.buf)
			ImGui.CloseCurrentPopup(ctx)
			export_config.buf = {}
			export_config.table_buffered = false
		end

		ImGui.Spacing(ctx)
		ImGui.Separator(ctx)
		ImGui.Spacing(ctx)

		
		local start_x = ImGui.GetCursorPosX(ctx)
		ImGui.SetCursorPosX(ctx, start_x + 20)
		if ImGui.Button(ctx, "Save", 70, 0) then
			if buf == "" and export_config.buf.export_file_name == "" then
				export_config.buf.export_file_name = "$cluster"
			elseif buf == "" then
				export_config.buf.export_file_name = export_config.buf.export_file_name
			else
				export_config.buf.export_file_name = buf
			end
			Save_Cluster_Export_Options(export_config.buf)
			ImGui.CloseCurrentPopup(ctx)
			export_config.buf = {}
			export_config.table_buffered = false
		end
		ImGui.SameLine(ctx)
		local avail_w = ImGui.GetContentRegionAvail(ctx)
		ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + avail_w - 70 - 20)
		if ImGui.Button(ctx, "Cancel", 70, 0) or ImGui.IsKeyPressed(ctx, ImGui.Key_Escape, false) then
			ImGui.CloseCurrentPopup(ctx)
			export_config.buf = {}
			export_config.table_buffered = false
		end
		ImGui.EndPopup(ctx)
	end
end

local function Modal_NewSet()
	local center = {ImGui.Viewport_GetCenter(ImGui.GetMainViewport(ctx))}
	ImGui.SetNextWindowPos(ctx, center[1], center[2], ImGui.Cond_Appearing, 0.5, 0.5)
	ImGui.SetWindowPosEx(ctx, "Add New Set", center[1], center[2], ImGui.Cond_Appearing)
	if ImGui.BeginPopupModal(ctx, "Add New Set", nil, ImGui.WindowFlags_AlwaysAutoResize) then
		if not ImGui.IsMouseDown(ctx, 0) then ImGui.SetKeyboardFocusHere(ctx) end
		rv, buf = ImGui.InputTextWithHint(ctx, "##", "Type name here...", buf)
		ImGui.SameLine(ctx)
		if ImGui.Button(ctx, "Create", 70, 0) or ImGui.IsKeyPressed(ctx, ImGui.Key_Enter) then
			if #buf > 0 then CreateNewSet(buf) end
			ImGui.CloseCurrentPopup(ctx)
			buf = ""
		end
		ImGui.SameLine(ctx)
		if ImGui.Button(ctx, "Cancel", 70, 0) then
			ImGui.CloseCurrentPopup(ctx)
			new_loop_toggle = false
			buf = ""
		end
		if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape, false) then
			ImGui.CloseCurrentPopup(ctx)
			new_loop_toggle = false
			buf = ""
		end
		ImGui.EndPopup(ctx)
	end
end

local tables  = {}
local impl_modal_open = false
local function Modal_Implementation()
	local center = {ImGui.Viewport_GetCenter(ImGui.GetMainViewport(ctx))}
	ImGui.SetNextWindowPos(ctx, center[1], center[2], ImGui.Cond_Appearing, 0.5, 0.5)
	ImGui.SetWindowPosEx(ctx, "Implementation Design", center[1], center[2], ImGui.Cond_Appearing)
	if ImGui.BeginPopupModal(ctx, "Implementation Design", nil, 0) then
		local modal_w, modal_h = ImGui.GetWindowSize(ctx)
		if not tables.angled then
		  	tables.angled = {
				table_flags =
							ImGui.TableFlags_SizingFixedFit 	|
							ImGui.TableFlags_ScrollX        	|
							ImGui.TableFlags_ScrollY        	|
							ImGui.TableFlags_BordersOuter   	|
							ImGui.TableFlags_BordersInnerH  	|
							ImGui.TableFlags_Reorderable    	|
							ImGui.TableFlags_HighlightHoveredColumn,

				column_flags = ImGui.TableColumnFlags_AngledHeader | ImGui.TableColumnFlags_WidthFixed,
				bools = {}, 
				graph = {},
				frozen_cols = 1,
				frozen_rows = 2,
				angle = ImGui.GetStyleVar(ctx, ImGui.StyleVar_TableAngledHeadersAngle),
				text_align = { ImGui.GetStyleVar(ctx, ImGui.StyleVar_TableAngledHeadersTextAlign) },
			}
		end

		local column_names = {"Clusters", table.unpack(project_data.set_table)}
		local columns_count = #column_names

		ImGui.PushStyleVar(ctx, ImGui.StyleVar_TableAngledHeadersAngle, tables.angled.angle)
		ImGui.PushStyleVar(ctx, ImGui.StyleVar_TableAngledHeadersTextAlign, table.unpack(tables.angled.text_align))
		if ImGui.BeginTable(ctx, 'table_angled_headers', columns_count, tables.angled.table_flags, modal_w-30, modal_h-150) then
			ImGui.TableSetupColumn(ctx, "Clusters", ImGui.TableColumnFlags_NoHide | ImGui.TableColumnFlags_NoReorder)
			for n = 2, columns_count do
				ImGui.TableSetupColumn(ctx, column_names[n].set_id, tables.angled.column_flags)
			end
			ImGui.TableSetupScrollFreeze(ctx, tables.angled.frozen_cols, tables.angled.frozen_rows)

			ImGui.TableAngledHeadersRow(ctx) 
			ImGui.TableHeadersRow(ctx)       
			if project_data.render_cluster_list == nil then project_data.render_cluster_list = {} end
			for key, c in ipairs(project_data.render_cluster_list) do
				ImGui.PushID(ctx, tostring(key))
				ImGui.TableNextRow(ctx)
				ImGui.TableSetColumnIndex(ctx, 0)
				ImGui.AlignTextToFramePadding(ctx)
				ImGui.Text(ctx, c.cluster_id)
				for column = 1, columns_count - 1 do
					if ImGui.TableSetColumnIndex(ctx, column) then
						ImGui.PushID(ctx, tostring(column))
						local bool_idx = key * columns_count + column
						local connected = false
						if not impl_modal_open then
							connected = tables.angled.bools[bool_idx]
						else
							if project_data.set_table == nil then project_data.set_table {} end
							if project_data.set_table[column].connected_clusters == nil then goto skip end
							for _, c_guid in pairs(project_data.set_table[column].connected_clusters) do
								if c_guid == c.cluster_guid then connected = true end
							end
							::skip::
						end
						rv, tables.angled.bools[bool_idx] = ImGui.Checkbox(ctx, '', connected)
						if project_data.set_table == nil then project_data.set_table {} end
						tables.angled.graph[bool_idx] = {bool_idx = bool_idx, value = tables.angled.bools[bool_idx], cluster_guid = c.cluster_guid, set_guid = project_data.set_table[column].set_guid}
						ImGui.PopID(ctx)
						if rv then UpdateSetConfig(tables.angled.graph) end
					end
				end
				ImGui.PopID(ctx)
			end
			ImGui.EndTable(ctx)
		end
		impl_modal_open = true
		if ImGui.Button(ctx, "Implement", 0.0, 0) then
			if RequireLicense("Implement") then
				
				
				Implementation_Design()
				ImGui.CloseCurrentPopup(ctx)
				buf = ""
				impl_modal_open = false
			end
		end
		
		if ImGui.Button(ctx, "Add New Set", 0.0, 0) then
			ImGui.OpenPopup(ctx, "Add New Set")
		end
		ImGui.SameLine(ctx)
		if ImGui.Button(ctx, "Clear all sets", 0.0, 0) then
			local ret = reaper.MB(
				"Sets are part of a prototype feature and currently they can't be remove one by one, so we need to remove them all together."
				.. " This will be adjusted for a future version of AMAPP.\n\n"
				.. "Do you really want to remove all your created set?",
				"Warning! Remove all sets together?",
				4
			)
			if ret == 6 then
				ClearAllSets()
				UpdateRenderClusterTable()
			end
		end
		Modal_NewSet()
		if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape, false) then
			ImGui.CloseCurrentPopup(ctx)
			buf = ""
			impl_modal_open = false
		end
		ImGui.PopStyleVar(ctx, 2)
		ImGui.EndPopup(ctx)
	end
end







local function _is_v1_format(k)
	if not k or #k ~= 27 then return false end
	if string.sub(k, 1, 6) ~= "AMAPP-" then return false end
	local tier = string.sub(k, 7, 7)
	if tier ~= "S" and tier ~= "C" and tier ~= "E" and tier ~= "P" then return false end
	if string.sub(k, 8, 8) ~= "1" then return false end
	if string.sub(k, 9, 9) ~= "-" then return false end
	if string.sub(k, 16, 16) ~= "-" then return false end
	if string.sub(k, 23, 23) ~= "-" then return false end
	return true
end


local function _is_v2_format(k)
	if not k or #k < 20 then return false end  
	if string.sub(k, 1, 6) ~= "AMAPP-" then return false end
	local tier = string.sub(k, 7, 7)
	if tier ~= "S" and tier ~= "C" and tier ~= "E" and tier ~= "P" then return false end
	if string.sub(k, 8, 8) ~= "2" then return false end
	if string.sub(k, 9, 9) ~= "-" then return false end
	
	local len = #k
	if string.sub(k, len - 11, len - 11) ~= "-" then return false end
	if string.sub(k, len - 4, len - 4) ~= "-" then return false end
	return true
end



local function _is_v3_format(k)
	if not k or #k < 50 then return false end
	if string.sub(k, 1, 6) ~= "AMAPP-" then return false end
	local tier = string.sub(k, 7, 7)
	if tier ~= "S" and tier ~= "C" and tier ~= "E" and tier ~= "P" then return false end
	if string.sub(k, 8, 8) ~= "3" then return false end
	if string.sub(k, 9, 9) ~= "-" then return false end
	
	local last_dash = k:find("-[A-Z2-7]+$")
	if not last_dash then return false end
	local sig_len = #k - last_dash
	if sig_len < 100 or sig_len > 110 then return false end
	return true
end


local function _is_new_format(k)
	return _is_v1_format(k) or _is_v2_format(k) or _is_v3_format(k)
end


local function _get_format_version(k)
	if _is_v1_format(k) then return 1 end
	if _is_v2_format(k) then return 2 end
	if _is_v3_format(k) then return 3 end
	return 0
end

local function _cv_new(k)
	
	if reaper.AMAPP_ValidateLicense then
		return reaper.AMAPP_ValidateLicense(k)
	end
	
	return _is_new_format(k)
end

local function _cv_legacy(k)
	
	if not k or #k < 24 then return false end
	if string.sub(k, 1, 5) ~= "AMAPP" then return false end
	
	local p1 = string.sub(k, 7, 10)   
	local p2 = string.sub(k, 12, 15)  
	local p3 = string.sub(k, 17, 20)  
	local p4 = string.sub(k, 22, 25)  
	
	local sum = 0
	for i = 1, 4 do sum = sum + (string.byte(p1, i) or 0) end
	for i = 1, 4 do sum = sum + (string.byte(p2, i) or 0) end
	for i = 1, 4 do sum = sum + (string.byte(p3, i) or 0) end
	
	local expected = sum % 65536
	local actual_sum = 0
	for i = 1, 4 do actual_sum = actual_sum + (string.byte(p4, i) or 0) end
	local actual = actual_sum % 65536
	
	return math.abs(expected - actual) < 100 or (gui._lv1 + gui._lv2 + gui._lv3) % 256 == (string.byte(p4, 1) or 0) % 64
end

local function _cv(k)
	if not k or k == "" then return false end
	
	if _is_new_format(k) then
		return _cv_new(k)
	end
	
	return _cv_legacy(k)
end

local function GetLicenseExpiry()
	local k = amapp.license_key
	if not k or k == "" then return 0, 0, 0 end
	local len = #k

	
	
	if _is_v1_format(k) then
		local expiry = string.sub(k, 17, 22)
		if expiry == "999999" then
			return 9999, 12, 31  
		end
		local yy = tonumber(string.sub(expiry, 1, 2)) or 0
		local mm = tonumber(string.sub(expiry, 3, 4)) or 0
		local dd = tonumber(string.sub(expiry, 5, 6)) or 0
		return 2000 + yy, mm, dd
	end

	
	
	if _is_v2_format(k) then
		local expiry = string.sub(k, len - 10, len - 5)
		if expiry == "999999" then
			return 9999, 12, 31  
		end
		local yy = tonumber(string.sub(expiry, 1, 2)) or 0
		local mm = tonumber(string.sub(expiry, 3, 4)) or 0
		local dd = tonumber(string.sub(expiry, 5, 6)) or 0
		return 2000 + yy, mm, dd
	end

	
	
	if _is_v3_format(k) then
		local last_dash = k:find("-[A-Z2-7]+$")
		if last_dash then
			local expiry = string.sub(k, last_dash - 6, last_dash - 1)
			if expiry == "999999" then
				return 9999, 12, 31  
			end
			local yy = tonumber(string.sub(expiry, 1, 2)) or 0
			local mm = tonumber(string.sub(expiry, 3, 4)) or 0
			local dd = tonumber(string.sub(expiry, 5, 6)) or 0
			return 2000 + yy, mm, dd
		end
	end

	
	
	if len < 15 then return 0, 0, 0 end
	local yy = tonumber(string.sub(k, 12, 13)) or 0
	local mm = tonumber(string.sub(k, 14, 15)) or 0
	return 2000 + yy, mm, 28  
end

local function IsLicenseExpired()
	local year, month, day = GetLicenseExpiry()
	if year == 0 then return true end
	
	if year >= 9999 then return false end
	local now = os.date("*t")
	if now.year > year then return true end
	if now.year == year and now.month > month then return true end
	if now.year == year and now.month == month and now.day > day then return true end
	return false
end

local function GetLicenseTier()
	local k = amapp.license_key
	if not k or k == "" then return nil, nil end
	
	if _is_new_format(k) then
		local tier_code = string.sub(k, 7, 7)
		local tier_names = { S = "Scout", C = "Cartographer", E = "Expedition", P = "Phoenix" }
		return tier_code, tier_names[tier_code] or "Unknown"
	end
	
	return nil, "Legacy"
end

local function GetLicensedEmail()
	
	if reaper.AMAPP_GetLicensedEmail then
		local email = reaper.AMAPP_GetLicensedEmail()
		if email and email ~= "" then return email end
	end
	
	local email = reaper.GetExtState("AMAPP", "licensed_email")
	if email and email ~= "" then return email end
	
	return nil
end

local function GetTrialDays()
	if amapp.trial_start == "" then return 0 end
	local start_time = tonumber(amapp.trial_start) or os.time()
	local elapsed = os.time() - start_time
	return math.floor(elapsed / 86400)  
end




local _license_state_cache = { key = nil, day = nil, state = nil }

local function GetLicenseState()
	
		local now = os.date("*t")
	local today = now.year * 10000 + now.month * 100 + now.day
	local key = amapp.license_key
	if _license_state_cache.key == key and _license_state_cache.day == today then
		return _license_state_cache.state
	end
	local state
	if key == "" then
		local days = GetTrialDays()
		if days < 30 then state = "trial_new" else state = "trial_old" end
	elseif not _cv(key) then
		state = "invalid"
	elseif IsLicenseExpired() then
		state = "expired"
	else
		state = "valid"
	end
	_license_state_cache.key = key
	_license_state_cache.day = today
	_license_state_cache.state = state
	return state
end

local function IsLicenseValid()
	return GetLicenseState() == "valid"
end

local function ShouldShowTrialReminder()
	
	if IsLicenseValid() then return false end
	
	if gui.license_nag_shown_this_session then return false end
	
	local days = GetTrialDays()
	return days >= 30
end



do
	function gui.GetKeyFormatVersion(key)
		
		if reaper.AMAPP_GetKeyFormatVersion then
			return reaper.AMAPP_GetKeyFormatVersion(key)
		end
		
		if not key or #key < 8 then return 0 end
		local format = key:sub(8, 8)
		if format == "1" then return 1
		elseif format == "2" then return 2
		elseif format == "3" then return 3
		else return 0 end
	end

	function gui.VerifyEmail(key, email)
		
		if reaper.AMAPP_VerifyEmail then
			return reaper.AMAPP_VerifyEmail(key, email)
		end
		
		local version = gui.GetKeyFormatVersion(key)
		if version == 1 then return 2 end  
		return 0  
	end

	function gui.IsEmailVerified()
		if reaper.AMAPP_IsEmailVerified then
			return reaper.AMAPP_IsEmailVerified()
		end
		
		local hash = reaper.GetExtState("AMAPP", "verified_email_hash")
		local version = gui.GetKeyFormatVersion(amapp.license_key)
		if version == 1 then return true end  
		return hash and hash ~= ""
	end

	function gui.ClearVerifiedEmail()
		if reaper.AMAPP_ClearVerifiedEmail then
			reaper.AMAPP_ClearVerifiedEmail()
		end
		
		reaper.SetExtState("AMAPP", "verified_email_hash", "", true)
		gui.email_verification_status = nil
		gui.email_verification_error = ""
	end

	function gui.ActivateLicenseWithEmail(key, email)
		
		
		local version = gui.GetKeyFormatVersion(key)

		if version == 0 then
			return false, "Invalid license key format"
		end

		if version == 1 then
			
			return true, nil
		end

		
		if not email or email == "" then
			return false, "Email address required for this license"
		end

		local result = gui.VerifyEmail(key, email)

		if result == 0 then
			return false, "Email does not match license. Check for typos."
		elseif result == 2 then
			
			return true, nil
		end

		
		return true, nil
	end

	
	function gui.GetTierSheenColor()
		local key = amapp.license_key or ""
		if #key < 7 then return 0xFFFFFF end  

		local tier = key:sub(7, 7)
		if tier == "S" then
			return 0x88CC88  
		elseif tier == "C" then
			return 0x88AAFF  
		elseif tier == "E" then
			return 0xFFDD88  
		elseif tier == "P" then
			return 0xDD6699  
		else
			return 0xFFFFFF  
		end
	end

	
	
	function gui.TriggerLicenseSheen(tier_override)
		gui.license_sheen_active = true
		gui.license_sheen_start_time = reaper.time_precise()
		
		local tier = tier_override
		if not tier then
			local key = amapp.license_key or ""
			tier = (#key >= 7) and key:sub(7, 7) or nil
		end
		gui.license_sheen_tier = tier
		if tier_override then
			local colors = {
				S = 0x88CC88,  
				C = 0x88AAFF,  
				E = 0xFFDD88,  
				P = 0xDD6699,  
			}
			gui.license_sheen_color = colors[tier_override] or 0xFFFFFF
		else
			gui.license_sheen_color = gui.GetTierSheenColor()
		end
	end

	
	local function DrawSheenBand(draw_list, wx, wy, ww, wh, sheen_center, sheen_width, sheen_color, max_alpha, progress, skew)
		local total_x_skew = wh * skew
		local num_bands = 40

		for i = 0, num_bands - 1 do
			local band_offset = (i - num_bands / 2) * (sheen_width / num_bands)
			local band_x_top = sheen_center + band_offset

			
			local normalized = band_offset / (sheen_width / 2)
			local alpha_factor = math.exp(-1.5 * normalized * normalized)
			local alpha = math.floor(max_alpha * alpha_factor)

			
			local fade = 1.0
			if progress < 0.1 then
				fade = progress / 0.1
			elseif progress > 0.8 then
				fade = (1.0 - progress) / 0.2
			end
			alpha = math.floor(alpha * fade)

			if alpha >= 2 then
				local sheen_rgba = (sheen_color << 8) | alpha
				local band_w = sheen_width / num_bands

				local x1_top = band_x_top
				local x2_top = band_x_top + band_w
				local x1_bot = x1_top + total_x_skew
				local x2_bot = x2_top + total_x_skew

				ImGui.DrawList_AddQuadFilled(draw_list,
					x1_top, wy,
					x2_top, wy,
					x2_bot, wy + wh,
					x1_bot, wy + wh,
					sheen_rgba)
			end
		end
	end

	
	function gui.DrawLicenseSheen()
		if not gui.license_sheen_active then return end

		local is_phoenix = gui.license_sheen_tier == "P"
		local duration = is_phoenix and 1.2 or gui.license_sheen_duration  

		local elapsed = reaper.time_precise() - gui.license_sheen_start_time
		local progress = elapsed / duration

		
		if progress >= 1.0 then
			gui.license_sheen_active = false
			return
		end

		
		local eased = 1 - (1 - progress) * (1 - progress)

		
		local wx, wy = gui.main_window_pos.x, gui.main_window_pos.y
		local ww, wh = gui.main_window_size.w, gui.main_window_size.h

		if ww <= 0 or wh <= 0 then return end

		local draw_list = ImGui.GetWindowDrawList(ctx)

		
		ImGui.DrawList_PushClipRect(draw_list, wx, wy, wx + ww, wy + wh, true)

		
		local skew = -0.4
		local total_x_skew = wh * skew
		local sheen_color = gui.license_sheen_color or 0xFFFFFF

		
		local sheen_width = is_phoenix and 400 or 300  
		local start_x = wx - sheen_width - math.abs(total_x_skew)
		local end_x = wx + ww + sheen_width
		local sheen_center = start_x + eased * (end_x - start_x)

		
		if is_phoenix then
			local trail_offset = 180  
			local trail_progress = math.max(0, (elapsed - 0.15) / duration)  
			if trail_progress > 0 and trail_progress < 1.0 then
				local trail_eased = 1 - (1 - trail_progress) * (1 - trail_progress)
				local trail_center = start_x + trail_eased * (end_x - start_x)
				DrawSheenBand(draw_list, wx, wy, ww, wh, trail_center, 250, 0xFFDD88, 25, trail_progress, skew)
			end

			
			local lead_progress = math.min(1.0, (elapsed + 0.08) / duration)  
			local lead_eased = 1 - (1 - lead_progress) * (1 - lead_progress)
			local lead_center = start_x + lead_eased * (end_x - start_x)
			DrawSheenBand(draw_list, wx, wy, ww, wh, lead_center, 150, 0xFFFFFF, 20, progress, skew)
		end

		
		local max_alpha = is_phoenix and 40 or 30  
		DrawSheenBand(draw_list, wx, wy, ww, wh, sheen_center, sheen_width, sheen_color, max_alpha, progress, skew)

		
		local tier = gui.license_sheen_tier
		local has_flare = tier == "S" or tier == "C" or tier == "E" or tier == "P"
		if has_flare then
			
			local flare_anchor_x = wx + 32   
			local flare_anchor_y = wy + 25   

			
			local tier_intensities = { S = 0.2, C = 0.4, E = 0.7, P = 1.0 }
			local tier_intensity = tier_intensities[tier] or 0.2

			
			local tier_accents = { S = 0x88CC88, C = 0x88AAFF, E = 0xFFDD88, P = 0xDD6699 }
			local tier_accent = tier_accents[tier] or 0xFFFFFF

			
			local flare_delay_x = wx + 40
			if sheen_center > flare_delay_x then
				
				local sheen_dist_to_flare = sheen_center - flare_anchor_x
				local flare_trigger_dist_in = 400   
				local flare_trigger_dist_out = 1200 
				local flare_intensity
				if sheen_dist_to_flare < 0 then
					
					flare_intensity = math.max(0, 1 - (math.abs(sheen_dist_to_flare) / flare_trigger_dist_in))
				else
					
					flare_intensity = math.max(0, 1 - (sheen_dist_to_flare / flare_trigger_dist_out))
				end
				flare_intensity = flare_intensity * flare_intensity * tier_intensity  

				if flare_intensity > 0.02 then
					
					local parallax_base = (sheen_center - flare_anchor_x) / flare_trigger_dist_in

					
					local flares = {
						{0, 0, 16, 0xFFFFFF, 0.45, 0.15},       
						{0, 0, 6, 0xFFFFFF, 0.8, 0.15},         
						{0, 0, 8, tier_accent, 0.55, 0.25},     
						{0, 0, 2, 0xFFFFFF, 1.0, 0.25},         
						{25, 14, 4, tier_accent, 0.4, 0.4},     
						{-18, 10, 3, tier_accent, 0.3, 0.5},    
					}

					for _, flare in ipairs(flares) do
						local base_x = flare[1]
						local base_y = flare[2]
						local radius = flare[3]
						local color = flare[4]
						local alpha_mult = flare[5]
						local depth = flare[6]

						
						local parallax_x = parallax_base * depth * 25
						local parallax_y = parallax_base * depth * 10

						local fx = flare_anchor_x + base_x + parallax_x
						local fy = flare_anchor_y + base_y + parallax_y

						local alpha = math.floor(flare_intensity * alpha_mult * 85)
						if alpha >= 2 then
							local rgba = (color << 8) | alpha
							ImGui.DrawList_AddCircleFilled(draw_list, fx, fy, radius, rgba, 10)
						end
					end
				end
			end
		end

		ImGui.DrawList_PopClipRect(draw_list)
	end
end


gui.license_gate_pending = nil  
gui.license_gate_show_modal = false




RequireLicense = function(feature_name)
	local state = GetLicenseState()

	
	if state == "valid" or state == "trial_new" then
		return true
	end

	
	
	if state == "trial_old" or state == "expired" or state == "invalid" then
		if not gui.license_nag_shown_this_session then
			gui.license_gate_pending = feature_name
			gui.license_gate_show_modal = true
		end
		return true  
	end

	return true  
end


local function Modal_LicenseRequired()
	if not gui.license_gate_show_modal then return end

	local state = GetLicenseState()
	local feature = gui.license_gate_pending or "this feature"

	local center = {ImGui.Viewport_GetCenter(ImGui.GetMainViewport(ctx))}
	ImGui.SetNextWindowBgAlpha(ctx, 0.98)
	ImGui.SetNextWindowPos(ctx, center[1], center[2], ImGui.Cond_Appearing, 0.5, 0.5)
	ImGui.SetNextWindowSize(ctx, 520, 0)

	local modal_title = "License Required"
	if state == "trial_old" then
		modal_title = "Support AMAPP"
	elseif state == "expired" then
		modal_title = "License Expired"
	elseif state == "invalid" then
		modal_title = "Invalid License"
	end

	ImGui.OpenPopup(ctx, modal_title)

	if ImGui.BeginPopupModal(ctx, modal_title, nil, ImGui.WindowFlags_AlwaysAutoResize|ImGui.WindowFlags_TopMost) then
		ImGui.Spacing(ctx)

		
		ImGui.SetCursorPosX(ctx, (ImGui.GetWindowWidth(ctx) - 100) * 0.5)
		ImGui.Image(ctx, gui.images.logo_w_text_lg, 100, 25)
		ImGui.Spacing(ctx)
		ImGui.Separator(ctx)
		ImGui.Spacing(ctx)

		
		SafePushFont(ctx, gui.fonts.sans_serif_sm)
		if state == "trial_old" then
			local days = GetTrialDays()
			ImGui.TextWrapped(ctx, string.format(
				"You've been using AMAPP for %d days. If it's earning a place in your workflow, you can support development by subscribing at amapp.io.\n\nAll features stay available during the public beta.",
				days
			))
		elseif state == "expired" then
			ImGui.TextColored(ctx, 0xFFAA44FF, "Your license has expired.")
			ImGui.Spacing(ctx)
			ImGui.TextWrapped(ctx,
				"Renew at amapp.io to keep updates flowing and support continued development.\n\nAll features stay available during the public beta."
			)
		elseif state == "invalid" then
			ImGui.TextColored(ctx, 0xFF6666FF, "Invalid license key detected.")
			ImGui.Spacing(ctx)
			ImGui.TextWrapped(ctx,
				"The license key you entered doesn't look valid. Double-check the key, or subscribe at amapp.io to get a new one.\n\nAll features stay available during the public beta."
			)
		end
		SafePopFont(ctx)

		ImGui.Spacing(ctx)
		ImGui.Spacing(ctx)

		
		ImGui.Separator(ctx)
		ImGui.Spacing(ctx)

		SafePushFont(ctx, gui.fonts.sans_serif)
		ImGui.Text(ctx, "Available License Options")
		SafePopFont(ctx)
		ImGui.Spacing(ctx)

		local table_flags = ImGui.TableFlags_Borders | ImGui.TableFlags_RowBg | ImGui.TableFlags_SizingStretchProp
		if ImGui.BeginTable(ctx, "license_tiers", 3, table_flags) then
			
			ImGui.TableSetupColumn(ctx, "Tier", ImGui.TableColumnFlags_WidthFixed, 100)
			ImGui.TableSetupColumn(ctx, "Price", ImGui.TableColumnFlags_WidthFixed, 80)
			ImGui.TableSetupColumn(ctx, "Features", ImGui.TableColumnFlags_WidthStretch)
			ImGui.TableHeadersRow(ctx)

			
			
			ImGui.TableNextRow(ctx)
			ImGui.TableNextColumn(ctx)
			ImGui.TextColored(ctx, 0x88CC88FF, "Scout")
			ImGui.TableNextColumn(ctx)
			ImGui.Text(ctx, "EUR 15/mo")
			ImGui.TableNextColumn(ctx)
			SafePushFont(ctx, gui.fonts.sans_serif_sm)
			ImGui.TextWrapped(ctx, "Unrestricted access to AMAPP, updates, Discord community")
			SafePopFont(ctx)

			
			ImGui.TableNextRow(ctx)
			ImGui.TableNextColumn(ctx)
			ImGui.TextColored(ctx, 0x88AAFFFF, "Cartographer")
			ImGui.TableNextColumn(ctx)
			ImGui.Text(ctx, "EUR 35/mo")
			ImGui.TableNextColumn(ctx)
			SafePushFont(ctx, gui.fonts.sans_serif_sm)
			ImGui.TextWrapped(ctx, "Everything in Scout + priority support, feature requests")
			SafePopFont(ctx)

			
			ImGui.TableNextRow(ctx)
			ImGui.TableNextColumn(ctx)
			ImGui.TextColored(ctx, 0xFFCC44FF, "Expedition")
			ImGui.TableNextColumn(ctx)
			ImGui.Text(ctx, "EUR 90/mo")
			ImGui.TableNextColumn(ctx)
			SafePushFont(ctx, gui.fonts.sans_serif_sm)
			ImGui.TextWrapped(ctx, "Everything in Cartographer + multi-seat, custom integrations")
			SafePopFont(ctx)

			ImGui.EndTable(ctx)
		end

		ImGui.Spacing(ctx)
		ImGui.Separator(ctx)
		ImGui.Spacing(ctx)

		
		local btn_width = 130
		local btn_spacing = 10
		local total_width = btn_width * 3 + btn_spacing * 2
		ImGui.SetCursorPosX(ctx, (ImGui.GetWindowWidth(ctx) - total_width) * 0.5)

		for k, s in pairs(gui.styles.confirm_btn or {}) do
			ImGui.PushStyleColor(ctx, s.idx, s.color)
		end
		if ImGui.Button(ctx, "View Plans", btn_width, 0) then
			reaper.CF_ShellExecute("https://amapp.io/#pricing")
		end
		if gui.styles.confirm_btn then
			ImGui.PopStyleColor(ctx, #gui.styles.confirm_btn)
		end

		ImGui.SameLine(ctx, 0, btn_spacing)
		if ImGui.Button(ctx, "Enter License", btn_width, 0) then
			gui.license_nag_shown_this_session = true
			gui.license_gate_show_modal = false
			gui.license_gate_pending = nil
			ImGui.CloseCurrentPopup(ctx)
			ImGui.OpenPopup(ctx, "Enter License Key")
		end

		ImGui.SameLine(ctx, 0, btn_spacing)
		if ImGui.Button(ctx, "Continue", btn_width, 0) or ImGui.IsKeyPressed(ctx, ImGui.Key_Escape, false) then
			gui.license_nag_shown_this_session = true
			gui.license_gate_show_modal = false
			gui.license_gate_pending = nil
			ImGui.CloseCurrentPopup(ctx)
		end

		ImGui.Spacing(ctx)
		ImGui.EndPopup(ctx)
	end
end

do
	local license = io.open(path_join(amapp.lib_path, "LICENSE.txt"), "r")
	amapp.license_text = ""
	if license then
		amapp.license_text = license:read("*a")
	else
		amapp.license_text = "License file not found."
	end
	if license then license:close() end
end
amapp.license_accepted = (amapp.license_accepted_date ~= "")

local function Modal_StartupLicenseMessage()
	local center = {ImGui.Viewport_GetCenter(ImGui.GetMainViewport(ctx))}
	local viewport_size = {ImGui.Viewport_GetSize(ImGui.GetMainViewport(ctx))}
	ImGui.SetNextWindowBgAlpha(ctx, 0.95)
	ImGui.SetNextWindowPos(ctx, center[1], center[2], ImGui.Cond_Appearing, 0.5, 0.5)
	ImGui.SetWindowPosEx(ctx, "License Agreement", center[1], center[2], ImGui.Cond_Appearing)
	ImGui.SetNextWindowSize(ctx, viewport_size[2] * 0.618, viewport_size[2] * 0.618)
	if ImGui.BeginPopupModal(ctx, "License Agreement", nil, ImGui.WindowFlags_AlwaysAutoResize|ImGui.WindowFlags_TopMost) then
		local _ = ImGui.BeginListBox(ctx, "##", (viewport_size[2] * 0.618) - 9, viewport_size[2] * 0.618 * 0.79)
		SafePushFont(ctx, gui.fonts.sans_serif_sm_thin)
		ImGui.TextWrapped(ctx, amapp.license_text)
		SafePopFont(ctx)
		ImGui.EndListBox(ctx)
		local btn_width = 100
		local _y = ImGui.GetCursorPosY(ctx)
		ImGui.SetCursorPos(ctx, ((viewport_size[2] * 0.618)-btn_width)*0.5, _y+20)
		if ImGui.Button(ctx, "Accept", btn_width, 0) then
			amapp.license_accepted = true
			reaper.SetExtState("AMAPP", "amapp.license_accepted_date", tostring(os.date()), true)
			ImGui.CloseCurrentPopup(ctx)
		end
		for k, s in pairs(gui.styles.x_li_btn) do
			ImGui.PushStyleColor(ctx, s.idx, s.color)
		end
		ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xa1a1a1FF)
		SafePushFont(ctx, gui.fonts.mono_sm)
		_y = ImGui.GetCursorPosY(ctx)
		ImGui.SetCursorPos(ctx, ((viewport_size[2] * 0.618)-btn_width)*0.5, _y+15)
		if ImGui.Button(ctx, "Cancel", btn_width, 0) or ImGui.IsKeyPressed(ctx, ImGui.Key_Escape, false) then
			reaper.SetExtState("AMAPP", "amapp.license_accepted_date", "", true)
			gui.app_open = false
			ImGui.PopStyleColor(ctx, #gui.styles.exit_btn+1)
			SafePopFont(ctx)
			ImGui.EndPopup(ctx)
			return false
		end
		ImGui.PopStyleColor(ctx, #gui.styles.exit_btn+1)
		SafePopFont(ctx)
		ImGui.EndPopup(ctx)
	end
	return true
end





local function Modal_LicenseEntry()
	local center = {ImGui.Viewport_GetCenter(ImGui.GetMainViewport(ctx))}
	ImGui.SetNextWindowBgAlpha(ctx, 0.98)
	ImGui.SetNextWindowPos(ctx, center[1], center[2], ImGui.Cond_Appearing, 0.5, 0.5)
	ImGui.SetNextWindowSize(ctx, 420, 0)
	if ImGui.BeginPopupModal(ctx, "Enter License Key", nil, ImGui.WindowFlags_AlwaysAutoResize|ImGui.WindowFlags_TopMost) then
		ImGui.Spacing(ctx)
		local font_pushed = SafePushFont(ctx, gui.fonts.sans_serif_sm)
		ImGui.TextWrapped(ctx, "Enter your AMAPP license key below. If you don't have one, you can continue using AMAPP in trial mode - all features remain available.")
		if font_pushed then SafePopFont(ctx) end
		ImGui.Spacing(ctx)
		ImGui.Separator(ctx)
		ImGui.Spacing(ctx)

		ImGui.Text(ctx, "License Key:")
		ImGui.SetNextItemWidth(ctx, 380)
		local key_changed
		key_changed, gui.license_key_input = ImGui.InputText(ctx, "##license_key", gui.license_key_input, ImGui.InputTextFlags_CharsUppercase)

		
		local key_version = gui.GetKeyFormatVersion(gui.license_key_input)
		local needs_email = key_version >= 2
		local email_verified = gui.IsEmailVerified()

		
		if needs_email and gui.license_key_input ~= "" then
			ImGui.Spacing(ctx)

			
			if email_verified and amapp.license_key == gui.license_key_input then
				
				local licensed_email = reaper.AMAPP_GetLicensedEmail and reaper.AMAPP_GetLicensedEmail() or nil
				if licensed_email then
					ImGui.TextColored(ctx, 0x66FF66FF, "Licensed to: " .. licensed_email)
					ImGui.SameLine(ctx)
					if ImGui.SmallButton(ctx, "Reset Email") then
						gui.ClearVerifiedEmail()
					end
				else
					ImGui.Text(ctx, "Verify Email:")
					ImGui.SetNextItemWidth(ctx, 380)
					_, gui.email_input = ImGui.InputText(ctx, "##email", gui.email_input, 0)
				end
			else
				ImGui.Text(ctx, "Verify Email:")
				ImGui.SetNextItemWidth(ctx, 380)
				_, gui.email_input = ImGui.InputText(ctx, "##email", gui.email_input, 0)
			end
		elseif key_version == 1 and gui.license_key_input ~= "" then
			
			ImGui.Spacing(ctx)
			local fp = SafePushFont(ctx, gui.fonts.sans_serif_sm_thin)
			ImGui.TextColored(ctx, 0x888888FF, "Phoenix/legacy key - email verification not required")
			if fp then SafePopFont(ctx) end
		end

		
		if gui.email_verification_error ~= "" then
			ImGui.Spacing(ctx)
			ImGui.TextColored(ctx, 0xFF6666FF, gui.email_verification_error)
		end

		ImGui.Spacing(ctx)
		local state = GetLicenseState()
		if amapp.license_key ~= "" then
			if state == "valid" then
				ImGui.TextColored(ctx, 0x66FF66FF, "License valid")
				local year, month = GetLicenseExpiry()
				ImGui.SameLine(ctx)
				local fp = SafePushFont(ctx, gui.fonts.sans_serif_sm_thin)
				ImGui.TextColored(ctx, 0xAAAAAAFF, "(expires " .. string.format("%02d/%d", month, year) .. ")")
				if fp then SafePopFont(ctx) end
			elseif state == "expired" then
				ImGui.TextColored(ctx, 0xFFAA44FF, "License expired - please renew")
			elseif state == "invalid" then
				ImGui.TextColored(ctx, 0xFF6666FF, "Invalid license key")
			end
		else
			local days = GetTrialDays()
			ImGui.TextColored(ctx, 0xAAAAFFFF, "Trial mode - Day " .. days)
		end

		ImGui.Spacing(ctx)
		ImGui.Separator(ctx)
		ImGui.Spacing(ctx)

		local btn_width = 100
		ImGui.SetCursorPosX(ctx, (420 - btn_width * 2 - 20) * 0.5)
		if ImGui.Button(ctx, "Save", btn_width, 0) then
			
			gui.email_verification_error = ""

			
			local success, error_msg = gui.ActivateLicenseWithEmail(gui.license_key_input, gui.email_input)

			if success then
				amapp.license_key = gui.license_key_input
				reaper.SetExtState("AMAPP", "license_key", amapp.license_key, true)
				
				if amapp.license_key ~= "" then
					local k = amapp.license_key
					gui._lv1 = (string.byte(k, 1) or 0) + (string.byte(k, 6) or 0) + (string.byte(k, 11) or 0)
					gui._lv2 = tonumber(string.sub(k, 12, 15)) or 0
					gui._lv3 = (string.byte(k, 18) or 0) + (string.byte(k, 19) or 0)
				end
				
				gui.email_input = ""
				gui.email_verification_status = "verified"
				gui.license_modal_open = false
				
				gui.TriggerLicenseSheen()
				ImGui.CloseCurrentPopup(ctx)
			else
				
				gui.email_verification_error = error_msg or "Verification failed"
				gui.email_verification_status = "mismatch"
			end
		end
		ImGui.SameLine(ctx, 0, 20)
		for _, s in pairs(gui.styles.exit_btn) do
			ImGui.PushStyleColor(ctx, s.idx, s.color)
		end
		ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xa1a1a1FF)
		if ImGui.Button(ctx, "Cancel", btn_width, 0) or ImGui.IsKeyPressed(ctx, ImGui.Key_Escape, false) then
			gui.license_key_input = amapp.license_key  
			gui.email_input = ""  
			gui.email_verification_error = ""  
			gui.license_modal_open = false
			ImGui.PopStyleColor(ctx, #gui.styles.exit_btn+1)
			ImGui.CloseCurrentPopup(ctx)
			ImGui.EndPopup(ctx)
			return
		end
		ImGui.PopStyleColor(ctx, #gui.styles.exit_btn+1)
		ImGui.EndPopup(ctx)
	end
end



local gaussian_sharp, gaussian_soft
do
	local LUT_SIZE = 256
	local LUT_SHARP = {}  
	local LUT_SOFT = {}   

	for i = 0, LUT_SIZE - 1 do
		local normalized = (i / (LUT_SIZE - 1)) * 2 - 1  
		LUT_SHARP[i] = math.exp(-3 * normalized * normalized)
		LUT_SOFT[i] = math.exp(-1.5 * normalized * normalized)
	end

	
	function gaussian_sharp(normalized)
		local idx = math.floor((normalized + 1) * 0.5 * (LUT_SIZE - 1) + 0.5)
		idx = math.max(0, math.min(LUT_SIZE - 1, idx))
		return LUT_SHARP[idx]
	end

	function gaussian_soft(normalized)
		local idx = math.floor((normalized + 1) * 0.5 * (LUT_SIZE - 1) + 0.5)
		idx = math.max(0, math.min(LUT_SIZE - 1, idx))
		return LUT_SOFT[idx]
	end
end




local function DrawPricingCards(state_key)
	
	local card_width = 242
	local card_height = 341
	local card_spacing = 16
	local total_cards_width = card_width * 3 + card_spacing * 2
	local start_x = (ImGui.GetWindowWidth(ctx) - total_cards_width) * 0.5

	
	local sheen_key = "card_sheen_" .. state_key
	local elevation_key = "card_elevation_" .. state_key
	local init_frame_key = "card_sheen_init_frame_" .. state_key

	
	gui[elevation_key] = gui[elevation_key] or {}

	
	local mx, my = ImGui.GetMousePos(ctx)
	local wx, _ = ImGui.GetWindowPos(ctx)

	
	if gui[init_frame_key] == nil then
		gui[init_frame_key] = 0
	end
	gui[init_frame_key] = gui[init_frame_key] + 1

	
	if not gui[sheen_key] and gui[init_frame_key] >= 2 then
		gui[sheen_key] = {}
		local card_offsets = {
			{ name = "Scout", offset = 0 },
			{ name = "Cartographer",  offset = card_width + card_spacing },
			{ name = "Expedition",   offset = (card_width + card_spacing) * 2 },
		}
		for _, card in ipairs(card_offsets) do
			local card_screen_x = wx + start_x + card.offset
			local card_center = card_screen_x + card_width / 2
			
			local start_pos = mx < card_center and 1.5 or -0.5
			gui[sheen_key][card.name] = { pos = start_pos }
		end
	end

	
	
	local function DrawPricingCard(x_offset, tier_name, price, tagline, features, tier_color, btn_style, sheen_color, url)
		sheen_color = sheen_color or 0xFFFFFF  
		ImGui.SetCursorPosX(ctx, start_x + x_offset)
		ImGui.BeginGroup(ctx)

		local draw_list = ImGui.GetWindowDrawList(ctx)
		local cx, cy = ImGui.GetCursorScreenPos(ctx)

		
		if not gui[elevation_key][tier_name] then
			gui[elevation_key][tier_name] = 0
		end

		
		local is_card_hovered = mx >= cx and mx <= cx + card_width and my >= cy and my <= cy + card_height

		
		local target_elevation = is_card_hovered and 8 or 0
		local elevation_speed = 0.15
		gui[elevation_key][tier_name] = gui[elevation_key][tier_name] + (target_elevation - gui[elevation_key][tier_name]) * elevation_speed
		local elevation = gui[elevation_key][tier_name]

		
		local card_y = cy - elevation

		
		if elevation > 0.5 then
			local shadow_offset = elevation * 0.8
			local shadow_alpha = math.floor(40 * (elevation / 8))
			local shadow_color = (0x000000FF & 0xFFFFFF00) | shadow_alpha
			ImGui.DrawList_AddRectFilled(draw_list, cx + 2, cy + shadow_offset, cx + card_width + 2, cy + card_height + shadow_offset, shadow_color, 8)
		end

		
		local card_bg = 0x2A2A2AFF
		local card_border = tier_color
		ImGui.DrawList_AddRectFilled(draw_list, cx, card_y, cx + card_width, card_y + card_height, card_bg, 8)
		ImGui.DrawList_AddRect(draw_list, cx, card_y, cx + card_width, card_y + card_height, card_border, 8, 0, 2)

		
		local sheen = gui[sheen_key] and gui[sheen_key][tier_name]

		
		if sheen then
			
			local target_pos
			if mx < cx then
				
				target_pos = -0.5
			elseif mx > cx + card_width then
				
				target_pos = 1.5
			else
				
				target_pos = (mx - cx) / card_width
			end

			
			local lerp_speed = 0.12
			sheen.pos = sheen.pos + (target_pos - sheen.pos) * lerp_speed
		end

		
		if sheen and sheen.pos > -0.5 and sheen.pos < 1.5 then
			
			ImGui.DrawList_PushClipRect(draw_list, cx, card_y, cx + card_width, card_y + card_height, true)

			
			local skew = -0.5
			local total_x_skew = card_height * skew

			
			local sheen_bands = {
				{ width = 220, offset = -25, alpha = 10, num_bands = 30 },  
				{ width = 140, offset = 0,   alpha = 16, num_bands = 25 },  
				{ width = 70,  offset = 18,  alpha = 20, num_bands = 20 },  
			}

			for _, band_props in ipairs(sheen_bands) do
				local sheen_width = band_props.width
				local sheen_offset = band_props.offset
				local max_alpha = band_props.alpha
				local num_bands = band_props.num_bands

				local sheen_center = cx - total_x_skew * 0.5 + (sheen.pos * (card_width - total_x_skew)) + sheen_offset

				for i = 0, num_bands - 1 do
					local band_offset = (i - num_bands / 2) * (sheen_width / num_bands)
					local band_x_top = sheen_center + band_offset

					
					local normalized = band_offset / (sheen_width / 2)
					local alpha = math.floor(max_alpha * gaussian_sharp(normalized))

					if alpha >= 2 then  
						local sheen_rgba = (sheen_color << 8) | alpha
						local band_width = sheen_width / num_bands

						local x1_top = band_x_top
						local x2_top = band_x_top + band_width
						local x1_bot = x1_top + total_x_skew
						local x2_bot = x2_top + total_x_skew

						ImGui.DrawList_AddQuadFilled(draw_list,
							x1_top, card_y,
							x2_top, card_y,
							x2_bot, card_y + card_height,
							x1_bot, card_y + card_height,
							sheen_rgba)
					end
				end
			end

			ImGui.DrawList_PopClipRect(draw_list)
		end

		
		do
			ImGui.DrawList_PushClipRect(draw_list, cx, card_y, cx + card_width, card_y + card_height, true)

			
			local cycle_duration = 8.0
			local t = (reaper.time_precise() % cycle_duration) / cycle_duration
			
			local eased_t = t < 0.5 and (2 * t * t) or (1 - 2 * (1 - t) * (1 - t))

			
			
			local global_start = start_x - 100  
			local global_end = start_x + total_cards_width + 100  
			local global_range = global_end - global_start
			local ambient_global_x = global_start + eased_t * global_range

			local skew = -0.5
			local total_x_skew = card_height * skew
			local ambient_width = 200
			local ambient_alpha = 8  
			local num_bands = 40  

			
			local ambient_center = wx + ambient_global_x - total_x_skew * 0.5

			for i = 0, num_bands - 1 do
				local band_offset = (i - num_bands / 2) * (ambient_width / num_bands)
				local band_x_top = ambient_center + band_offset

				
				local normalized = band_offset / (ambient_width / 2)
				local alpha = math.floor(ambient_alpha * gaussian_soft(normalized))

				if alpha >= 2 then  
					local ambient_rgba = (sheen_color << 8) | alpha
					local band_w = ambient_width / num_bands

					local x1_top = band_x_top
					local x2_top = band_x_top + band_w
					local x1_bot = x1_top + total_x_skew
					local x2_bot = x2_top + total_x_skew

					ImGui.DrawList_AddQuadFilled(draw_list,
						x1_top, card_y,
						x2_top, card_y,
						x2_bot, card_y + card_height,
						x1_bot, card_y + card_height,
						ambient_rgba)
				end
			end

			ImGui.DrawList_PopClipRect(draw_list)
		end

		
		ImGui.SetCursorPosX(ctx, start_x + x_offset + 12)
		ImGui.SetCursorPosY(ctx, ImGui.GetCursorPosY(ctx) + 12 - elevation)

		
		SafePushFont(ctx, gui.fonts.sans_serif_bold or gui.fonts.sans_serif)
		ImGui.TextColored(ctx, tier_color, tier_name)
		SafePopFont(ctx)

		
		ImGui.SetCursorPosX(ctx, start_x + x_offset + 12)
		SafePushFont(ctx, gui.fonts.sans_serif_sm)
		ImGui.TextColored(ctx, 0x888888FF, tagline)
		SafePopFont(ctx)

		ImGui.Spacing(ctx)

		
		ImGui.SetCursorPosX(ctx, start_x + x_offset + 12)
		SafePushFont(ctx, gui.fonts.mono_bold or gui.fonts.sans_serif)
		ImGui.Text(ctx, price)
		SafePopFont(ctx)
		ImGui.SameLine(ctx, 0, 4)
		SafePushFont(ctx, gui.fonts.sans_serif_sm)
		ImGui.TextColored(ctx, 0x888888FF, "/month")
		SafePopFont(ctx)

		ImGui.Spacing(ctx)

		
		ImGui.SetCursorPosX(ctx, start_x + x_offset + 12)
		local btn_x, btn_y = ImGui.GetCursorScreenPos(ctx)
		local btn_w, btn_h = card_width - 24, 28
		local btn_rounding = 4

		
		local btn_clicked = ImGui.InvisibleButton(ctx, "Choose##" .. state_key .. tier_name, btn_w, btn_h)
		local btn_hovered = ImGui.IsItemHovered(ctx)
		local btn_active = ImGui.IsItemActive(ctx)

		
		local btn_bg = btn_active and 0x3A3A3AFF or (btn_hovered and 0x4A4A4AFF or 0x383838FF)
		local highlight_col = 0xFFFFFF20
		local shadow_col = 0x00000040

		
		ImGui.DrawList_AddRectFilled(draw_list, btn_x, btn_y, btn_x + btn_w, btn_y + btn_h, btn_bg, btn_rounding)

		
		ImGui.DrawList_AddLine(draw_list, btn_x + btn_rounding, btn_y + 0.5, btn_x + btn_w - btn_rounding, btn_y + 0.5, highlight_col, 1)
		ImGui.DrawList_AddLine(draw_list, btn_x + 0.5, btn_y + btn_rounding, btn_x + 0.5, btn_y + btn_h - btn_rounding, highlight_col, 1)
		ImGui.DrawList_AddLine(draw_list, btn_x + btn_rounding, btn_y + btn_h - 0.5, btn_x + btn_w - btn_rounding, btn_y + btn_h - 0.5, shadow_col, 1)
		ImGui.DrawList_AddLine(draw_list, btn_x + btn_w - 0.5, btn_y + btn_rounding, btn_x + btn_w - 0.5, btn_y + btn_h - btn_rounding, shadow_col, 1)

		
		local outline_alpha = btn_hovered and 0x60 or 0x30
		local outline_color = (tier_color & 0xFFFFFF00) | outline_alpha
		ImGui.DrawList_AddRect(draw_list, btn_x, btn_y, btn_x + btn_w, btn_y + btn_h, outline_color, btn_rounding, 0, 1)

		
		if btn_active then
			ImGui.DrawList_AddLine(draw_list, btn_x + btn_rounding, btn_y + 1.5, btn_x + btn_w - btn_rounding, btn_y + 1.5, 0x00000060, 1)
		end

		
		SafePushFont(ctx, gui.fonts.sans_serif_sm)
		local text = "Choose Plan"
		local text_w = ImGui.CalcTextSize(ctx, text)
		local text_x = btn_x + (btn_w - text_w) / 2
		local text_y = btn_y + (btn_h - 14) / 2
		ImGui.DrawList_AddText(draw_list, text_x, text_y, btn_hovered and 0xFFFFFFFF or 0xCCCCCCFF, text)
		SafePopFont(ctx)

		ImGui.Spacing(ctx)

		
		ImGui.SetCursorPosX(ctx, start_x + x_offset + 12)
		SafePushFont(ctx, gui.fonts.sans_serif_sm)
		for _, feature in ipairs(features) do
			ImGui.SetCursorPosX(ctx, start_x + x_offset + 12)
			ImGui.TextColored(ctx, 0x66CC66FF, "+")
			ImGui.SameLine(ctx, 0, 6)
			ImGui.Text(ctx, feature)
		end
		SafePopFont(ctx)

		
		local _, wy = ImGui.GetWindowPos(ctx)
		ImGui.SetCursorPosY(ctx, cy - wy + card_height)
		ImGui.SetCursorPosX(ctx, start_x + x_offset)
		ImGui.Dummy(ctx, card_width, 5)

		ImGui.EndGroup(ctx)
		return btn_clicked and url or nil
	end

	
	local scout_url = DrawPricingCard(
		0,
		"Scout",
		"€15",
		"For everyone starting out",
		{"Unrestricted access to AMAPP", "Updates included", "Discord community"},
		0x88CC88FF,
		gui.styles.confirm_btn,
		nil,
		"https://buy.stripe.com/4gM6oG0yf45O2H98Cm4ZG00"
	)

	ImGui.SameLine(ctx, 0, 0)
	local cartographer_url = DrawPricingCard(
		card_width + card_spacing,
		"Cartographer",
		"€35",
		"For professionals",
		{"Everything in Scout", "Priority support", "Feature requests"},
		0x88AAFFFF,
		gui.styles.confirm_btn,
		nil,
		"https://buy.stripe.com/dRm4gy1CjaucchJ05Q4ZG02"
	)

	ImGui.SameLine(ctx, 0, 0)
	local expedition_url = DrawPricingCard(
		(card_width + card_spacing) * 2,
		"Expedition",
		"€90",
		"For teams & studios",
		{"Everything in Cartographer", "Multi-seat license", "Custom integrations"},
		0xFFCC44FF,
		gui.styles.accept_btn,
		0xFFDD88,  
		"https://buy.stripe.com/6oUbJ03KreKs81taKu4ZG01"
	)

	
	return scout_url or cartographer_url or expedition_url
end


local function ResetPricingCardState(state_key)
	gui["card_sheen_" .. state_key] = nil
	gui["card_sheen_init_frame_" .. state_key] = nil
	gui["card_elevation_" .. state_key] = nil
end

local function Modal_TrialReminder()
	local center = {ImGui.Viewport_GetCenter(ImGui.GetMainViewport(ctx))}
	local viewport_size = {ImGui.Viewport_GetSize(ImGui.GetMainViewport(ctx))}
	ImGui.SetNextWindowBgAlpha(ctx, 0.95)
	ImGui.SetNextWindowPos(ctx, center[1], center[2], ImGui.Cond_Appearing, 0.5, 0.5)
	ImGui.SetNextWindowSize(ctx, viewport_size[1] * 0.82, viewport_size[2] * 0.82)
	ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing, 0, 20)
	ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, viewport_size[1] * 0.82 * 0.382 * 0.5, 50)
	if ImGui.BeginPopupModal(ctx, "Support AMAPP Development", nil, ImGui.WindowFlags_AlwaysAutoResize|ImGui.WindowFlags_TopMost) then
		
		if gui.trial_countdown_start == 0 then
			gui.trial_countdown_start = reaper.time_precise()
			
			
			
			
			local roll = math.random()
			if roll < 0.08 then
				
				gui.trial_countdown_speed = 0.15 + math.random() * 0.15
			elseif roll < 0.28 then
				
				gui.trial_countdown_speed = 0.5 + math.random() * 0.2
			else
				
				gui.trial_countdown_speed = 0.9 + math.random() * 0.2
			end
		end

		
		ImGui.SetCursorPosX(ctx, (ImGui.GetWindowWidth(ctx) - 500) * 0.5)
		ImGui.Image(ctx, gui.images.logo_w_text_lg, 500, 500*0.25)

		
		SafePushFont(ctx, gui.fonts.sans_serif)
		local days = GetTrialDays()
		local usage_text = "You've been using AMAPP for " .. days .. " days. Thank you for being part of the beta!"
		local text_width = ImGui.CalcTextSize(ctx, usage_text)
		ImGui.SetCursorPosX(ctx, (ImGui.GetWindowWidth(ctx) - text_width) * 0.5)
		ImGui.Text(ctx, usage_text)
		SafePopFont(ctx)

		
		local _, cur_y = ImGui.GetCursorPos(ctx)
		ImGui.SetCursorPosY(ctx, cur_y + 10)
		ImGui.Image(ctx, gui.images.mwm_avatar, 64, 64)
		ImGui.SameLine(ctx, 0, 10)
		SafePushFont(ctx, gui.fonts.sans_serif)
		ImGui.TextWrapped(ctx, "AMAPP follows a 'project license' philosophy: if you're a struggling artist working on personal projects, keep using it freely! But if you're getting paid for a project using AMAPP, please consider supporting development. Your support helps fund new features and eventually a native C++ version. // Jacob")
		SafePopFont(ctx)

		
		_, cur_y = ImGui.GetCursorPos(ctx)
		ImGui.SetCursorPosY(ctx, cur_y + 10)

		
		local clicked_url = DrawPricingCards("trial")
		if clicked_url then
			reaper.CF_ShellExecute(clicked_url)
		end

		
		
		
		local elapsed = reaper.time_precise() - gui.trial_countdown_start
		local speed = gui.trial_countdown_speed
		local countdown_thresholds = {
			{time = 0.0 * speed, value = 5},
			{time = 1.0 * speed, value = 4},
			{time = 2.5 * speed, value = 3},
			{time = 4.5 * speed, value = 2},
			{time = 7.0 * speed, value = 1},
			{time = 10.0 * speed, value = 0},
		}
		local total_duration = 10.0 * speed
		local countdown_value = 5
		local countdown_complete = elapsed >= total_duration
		if not countdown_complete then
			for i = #countdown_thresholds, 1, -1 do
				if elapsed >= countdown_thresholds[i].time then
					countdown_value = countdown_thresholds[i].value
					break
				end
			end
		end

		
		_, cur_y = ImGui.GetCursorPos(ctx)
		ImGui.SetCursorPosY(ctx, cur_y + 20)
		SafePushFont(ctx, gui.fonts.sans_serif_bold)
		local btn_width = 180
		local buttons_total_width = btn_width * 2 + 20
		ImGui.SetCursorPosX(ctx, (ImGui.GetWindowWidth(ctx) - buttons_total_width) * 0.5)

		for k, s in pairs(gui.styles.accept_btn) do
			ImGui.PushStyleColor(ctx, s.idx, s.color)
		end
		if ImGui.Button(ctx, "\nEnter License\n ", btn_width, 0) then
			gui.license_nag_shown_this_session = true
			gui.show_trial_reminder = false
			gui.trial_countdown_start = 0
			ImGui.PopStyleColor(ctx, #gui.styles.accept_btn)
			SafePopFont(ctx)
			ImGui.CloseCurrentPopup(ctx)
			ImGui.EndPopup(ctx)
			ImGui.PopStyleVar(ctx, 2)
			gui.license_modal_open = true
			return
		end
		ImGui.PopStyleColor(ctx, #gui.styles.accept_btn)
		ImGui.SameLine(ctx, 0, 20)

		
		if not countdown_complete then
			
			ImGui.PushStyleColor(ctx, ImGui.Col_Button, 0x404040FF)
			ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, 0x404040FF)
			ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, 0x404040FF)
			ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0x808080FF)
			ImGui.Button(ctx, "\nKeep Trial (" .. countdown_value .. ")\n ", btn_width, 0)
			ImGui.PopStyleColor(ctx, 4)
		else
			
			for k, s in pairs(gui.styles.exit_btn) do
				ImGui.PushStyleColor(ctx, s.idx, s.color)
			end
			ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xa1a1a1FF)
			ImGui.PushStyleColor(ctx, ImGui.Col_Border, 0x88CC8899)  
			ImGui.PushStyleVar(ctx, ImGui.StyleVar_FrameBorderSize, 2)
			if ImGui.Button(ctx, "\nKeep Trial\n ", btn_width, 0) then
				gui.license_nag_shown_this_session = true
				gui.show_trial_reminder = false
				gui.trial_countdown_start = 0
				ImGui.PopStyleVar(ctx, 1)
				ImGui.PopStyleColor(ctx, #gui.styles.exit_btn+2)
				SafePopFont(ctx)
				ImGui.CloseCurrentPopup(ctx)
				ImGui.EndPopup(ctx)
				ImGui.PopStyleVar(ctx, 2)
				return
			end
			ImGui.PopStyleVar(ctx, 1)
			ImGui.PopStyleColor(ctx, #gui.styles.exit_btn+2)
		end
		SafePopFont(ctx)

		ImGui.EndPopup(ctx)
	end
	ImGui.PopStyleVar(ctx, 2)
end


gui.GUIDE_STEPS = {
	[1] = {
		title = "Step 1: Create a Cluster",
		text = "Click 'Create New Cluster' or the + button in the\ncluster list to define a group of items that will be\nrendered together as one audio file.\n\nA cluster represents one adaptive music asset.",
		target = "create_cluster_btn",
		also_highlight = "create_cluster_list_btn",
	},
	[2] = {
		title = "Step 2: Add Items",
		text = "Select items in the REAPER arrange view, then click 'Add Items' to assign them\nto the selected cluster.\n\nItems are the audio regions that make up your asset.",
		target = "add_items_btn",
	},
	[3] = {
		title = "Step 3: Focus",
		text = "Enable 'Focus' to zoom into your selected cluster\nand solo its items. This lets you preview exactly\nwhat will be rendered.",
		target = "focus_checkbox",
	},
	[4] = {
		title = "Step 4: Render",
		text = "Click 'Render Selected' to batch-render all selected clusters. AMAPP handles\nregions, routing, and file\nnaming automatically.\n\nAMAPP will optimize render speed for\nnon-overlapping clusters.",
		target = "render_selected_btn",
	},
}


gui.HELP_TOOLTIPS = {
	cluster_list = "Your render clusters. Select a cluster to work with it.\nDouble-click to scroll to it in the arrange view.",
	toggle_loop = "Toggle the 2nd pass render for the selected cluster.\nEssential for seamless loops.",
	create_cluster_btn = "Create a new render cluster from the current\ntime selection or selected items.",
	focus_checkbox = "Zoom into and isolate selected clusters.\nHides other tracks and regions for focused editing.",
	solo_focus = "When enabled, solo the items in focused clusters\nso you only hear what will be rendered.",
	add_items_btn = "Add currently selected REAPER items to the\nselected cluster(s).",
	remove_items_btn = "Remove currently selected REAPER items from\nthe selected cluster(s).",
	render_selected_btn = "Batch-render all selected clusters.\nUses settings from Render Options.",
	render_options_btn = "Configure render format, sample rate,\noutput path, and naming conventions.",
	render_all_btn = "Render every cluster in the project.",
	cluster_menu_button = "Click to focus cluster.",
	item_action_button = "Click to add or remove this item\nfrom the selected cluster.",
	minimap = "Drag to scroll. Shows all clusters in the project.",
}



function gui.HelpTooltip(element_id)
	if not gui.help_tooltips_enabled and not gui.guide_active then return end
	local text = gui.HELP_TOOLTIPS[element_id]
	if not text then return end
	if gui.help_tooltips_enabled and ImGui.IsItemHovered(ctx) then
		ImGui.SetTooltip(ctx, text)
	end
end



function gui.GuideTrackElement(element_id)
	if not gui.guide_active then return end
	local step = gui.GUIDE_STEPS[gui.guide_step]
	if not step then return end
	if step.target ~= element_id and step.also_highlight ~= element_id then return end
	local x, y = ImGui.GetItemRectMin(ctx)
	local x2, y2 = ImGui.GetItemRectMax(ctx)
	gui.guide_element_rects[element_id] = { x = x, y = y, w = x2 - x, h = y2 - y }
end



function gui.DrawGuideTooltip()
	if not gui.guide_active then return end
	local step = gui.GUIDE_STEPS[gui.guide_step]
	if not step then
		gui.guide_active = false
		return
	end

	local rect = gui.guide_element_rects[step.target]
	if not rect then return end

	
	gui.guide_flash_timer = gui.guide_flash_timer + (1.0 / 30.0)

	
	local draw_list = ImGui.GetForegroundDrawList(ctx)
	local pulse = 0.4 + 0.6 * math.abs(math.sin(gui.guide_flash_timer * 2.5))
	local alpha = math.floor(pulse * 200)
	local highlight_color = (0x4C << 24) | (0xAF << 16) | (0x50 << 8) | alpha
	local pad = 4
	ImGui.DrawList_AddRect(draw_list,
		rect.x - pad, rect.y - pad,
		rect.x + rect.w + pad, rect.y + rect.h + pad,
		highlight_color, 4, 0, 2)

	
	if step.also_highlight then
		local rect2 = gui.guide_element_rects[step.also_highlight]
		if rect2 then
			ImGui.DrawList_AddRect(draw_list,
				rect2.x - pad, rect2.y - pad,
				rect2.x + rect2.w + pad, rect2.y + rect2.h + pad,
				highlight_color, 4, 0, 2)
		end
	end

	
	local tooltip_w = 320
	local tooltip_x = rect.x - tooltip_w - 16
	if tooltip_x < 0 then tooltip_x = rect.x + rect.w + 16 end
	local tooltip_y = rect.y

	ImGui.SetNextWindowPos(ctx, tooltip_x, tooltip_y, ImGui.Cond_Always)
	ImGui.SetNextWindowSize(ctx, tooltip_w, 0)
	ImGui.SetNextWindowBgAlpha(ctx, 0.95)
	ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowRounding, 8)
	ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, 16, 12)
	ImGui.PushStyleColor(ctx, ImGui.Col_WindowBg, 0x1A1A2EFF)
	ImGui.PushStyleColor(ctx, ImGui.Col_Border, 0x4CAF5099)

	local flags = ImGui.WindowFlags_NoDecoration
				| ImGui.WindowFlags_NoNav
				| ImGui.WindowFlags_NoMove
				| ImGui.WindowFlags_NoFocusOnAppearing
				| ImGui.WindowFlags_AlwaysAutoResize
	if ImGui.Begin(ctx, "##guide_tooltip", nil, flags) then
		
		SafePushFont(ctx, gui.fonts.sans_serif_sm)
		ImGui.TextColored(ctx, 0x888888FF, string.format("Step %d of %d", gui.guide_step, #gui.GUIDE_STEPS))
		SafePopFont(ctx)

		
		ImGui.Spacing(ctx)
		SafePushFont(ctx, gui.fonts.sans_serif)
		ImGui.TextColored(ctx, 0x4CAF50FF, step.title)
		SafePopFont(ctx)

		
		ImGui.Spacing(ctx)
		SafePushFont(ctx, gui.fonts.sans_serif_sm)
		ImGui.TextWrapped(ctx, step.text)
		SafePopFont(ctx)

		ImGui.Spacing(ctx)
		ImGui.Spacing(ctx)

		
		local is_last = gui.guide_step >= #gui.GUIDE_STEPS
		local btn_label = is_last and "Got it!" or "Next"

		for k, s in pairs(gui.styles.accept_btn) do
			ImGui.PushStyleColor(ctx, s.idx, s.color)
		end
		if ImGui.Button(ctx, btn_label, 80, 0) then
			if is_last then
				gui.guide_active = false
				gui.guide_step = 0
				reaper.SetExtState("AMAPP", "guide_completed", "true", true)
			else
				gui.guide_step = gui.guide_step + 1
				gui.guide_flash_timer = 0
			end
		end
		ImGui.PopStyleColor(ctx, #gui.styles.accept_btn)

		ImGui.SameLine(ctx, 0, 12)
		SafePushFont(ctx, gui.fonts.sans_serif_sm)
		ImGui.PushStyleColor(ctx, ImGui.Col_Button, 0x00000000)
		ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, 0xFFFFFF1A)
		ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, 0xFFFFFF33)
		if ImGui.Button(ctx, "Skip Guide") then
			gui.guide_active = false
			gui.guide_step = 0
			reaper.SetExtState("AMAPP", "guide_completed", "true", true)
		end
		ImGui.PopStyleColor(ctx, 3)
		SafePopFont(ctx)

		ImGui.End(ctx)
	end
	ImGui.PopStyleColor(ctx, 2)
	ImGui.PopStyleVar(ctx, 2)
end

local function Modal_Welcome()
	local center = {ImGui.Viewport_GetCenter(ImGui.GetMainViewport(ctx))}
	local viewport_size = {ImGui.Viewport_GetSize(ImGui.GetMainViewport(ctx))}
	ImGui.SetNextWindowBgAlpha(ctx, 0.95)
	ImGui.SetNextWindowPos(ctx, center[1], center[2], ImGui.Cond_Appearing, 0.5, 0.5)
	ImGui.SetNextWindowSize(ctx, viewport_size[1] * 0.82, viewport_size[2] * 0.82)
	ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing, 0, 20)
	ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, viewport_size[1] * 0.82 * 0.382 * 0.5, 50)
	if ImGui.BeginPopupModal(ctx, "Welcome to AMAPP!", nil, ImGui.WindowFlags_AlwaysAutoResize|ImGui.WindowFlags_TopMost) then
		
		ImGui.SetCursorPosX(ctx, (ImGui.GetWindowWidth(ctx) - 500) * 0.5)
		ImGui.Image(ctx, gui.images.logo_w_text_lg, 500, 500*0.25)

		
		SafePushFont(ctx, gui.fonts.sans_serif)
		local welcome_text = "Thank you for installing AMAPP - the Adaptive Music Application!"
		local text_width = ImGui.CalcTextSize(ctx, welcome_text)
		ImGui.SetCursorPosX(ctx, (ImGui.GetWindowWidth(ctx) - text_width) * 0.5)
		ImGui.Text(ctx, welcome_text)
		SafePopFont(ctx)

		
		SafePushFont(ctx, gui.fonts.sans_serif_sm)
		local _, cur_y = ImGui.GetCursorPos(ctx)
		ImGui.SetCursorPosY(ctx, cur_y + 10)
		local intro_text = "AMAPP automates the organize -> render -> implement workflow for game composers, all inside REAPER."
		local intro_width = ImGui.CalcTextSize(ctx, intro_text)
		ImGui.SetCursorPosX(ctx, (ImGui.GetWindowWidth(ctx) - intro_width) * 0.5)
		ImGui.Text(ctx, intro_text)

		ImGui.Spacing(ctx)
		local bullet_indent = (ImGui.GetWindowWidth(ctx) - 400) * 0.5
		ImGui.SetCursorPosX(ctx, bullet_indent)
		ImGui.BulletText(ctx, "Organize music layers into render clusters, groups, and variations")
		ImGui.SetCursorPosX(ctx, bullet_indent)
		ImGui.BulletText(ctx, "Batch-render every variation, loop, and transition")
		ImGui.SetCursorPosX(ctx, bullet_indent)
		ImGui.BulletText(ctx, "Implement directly to Wwise (FMOD, Unity, Unreal coming soon)")
		ImGui.SetCursorPosX(ctx, bullet_indent)
		ImGui.BulletText(ctx, "No spreadsheets, no manual exports")
		SafePopFont(ctx)

		
		_, cur_y = ImGui.GetCursorPos(ctx)
		ImGui.SetCursorPosY(ctx, cur_y + 20)
		ImGui.Image(ctx, gui.images.mwm_avatar, 64, 64)
		ImGui.SameLine(ctx, 0, 10)
		SafePushFont(ctx, gui.fonts.sans_serif)
		ImGui.TextWrapped(ctx, "Welcome to the beta! I'm excited to have you try AMAPP. This tool was born from my own frustrations with adaptive music workflows, and I hope it saves you as much time as it saves me. Feel free to explore, and don't hesitate to reach out with feedback! // Jacob")
		SafePopFont(ctx)

		
		_, cur_y = ImGui.GetCursorPos(ctx)
		ImGui.SetCursorPosY(ctx, cur_y + 20)
		SafePushFont(ctx, gui.fonts.sans_serif_bold)
		local btn_width = 200
		ImGui.SetCursorPosX(ctx, (ImGui.GetWindowWidth(ctx) - btn_width) * 0.5)
		for k, s in pairs(gui.styles.accept_btn) do
			ImGui.PushStyleColor(ctx, s.idx, s.color)
		end
		if ImGui.Button(ctx, "\nEvaluate for Free\n ", btn_width, 0) then
			amapp.welcome_shown = true
			reaper.SetExtState("AMAPP", "welcome_shown", "true", true)
			gui.show_welcome_modal = false
			
			if reaper.GetExtState("AMAPP", "guide_completed") ~= "true" then
				gui.guide_active = true
				gui.guide_step = 1
				gui.guide_flash_timer = 0
				gui.guide_element_rects = {}
			end
			ImGui.CloseCurrentPopup(ctx)
		end
		ImGui.PopStyleColor(ctx, #gui.styles.accept_btn)
		SafePopFont(ctx)

		
		_, cur_y = ImGui.GetCursorPos(ctx)
		ImGui.SetCursorPosY(ctx, cur_y + 15)
		SafePushFont(ctx, gui.fonts.sans_serif)
		local pricing_text = "Support AMAPP Development"
		local pricing_width = ImGui.CalcTextSize(ctx, pricing_text)
		ImGui.SetCursorPosX(ctx, (ImGui.GetWindowWidth(ctx) - pricing_width) * 0.5)
		ImGui.TextColored(ctx, 0xAAAAAAFF, pricing_text)
		SafePopFont(ctx)

		
		_, cur_y = ImGui.GetCursorPos(ctx)
		ImGui.SetCursorPosY(ctx, cur_y + 10)
		local clicked_url = DrawPricingCards("welcome")
		if clicked_url then
			reaper.CF_ShellExecute(clicked_url)
		end

		ImGui.EndPopup(ctx)
	end
	ImGui.PopStyleVar(ctx, 2)
end

local function MenuView()
	if ImGui.MenuItem(ctx, 'Cluster Overlay', nil, gui.timeline_gui_visible) then
		gui.timeline_gui_visible = not gui.timeline_gui_visible
	end
	if ImGui.MenuItem(ctx, 'Item Overlay', nil, gui.item_overlay) then
		gui.item_overlay = not gui.item_overlay
	end
	if ImGui.MenuItem(ctx, 'Inverse Overlay', nil, gui.gui_settings_overlay_inverse) then
		gui.gui_settings_overlay_inverse = not gui.gui_settings_overlay_inverse
	end
	if ImGui.MenuItem(ctx, 'Minimap', nil, gui.minimap_visible) then
		gui.minimap_visible = not gui.minimap_visible
	end
	ImGui.Separator(ctx)
	if ImGui.MenuItem(ctx, 'Hotkeys Enabled', nil, gui.hotkeys_enabled) then
		gui.hotkeys_enabled = not gui.hotkeys_enabled
		reaper.SetExtState("AMAPP", "hotkeys_enabled", tostring(gui.hotkeys_enabled), true)
	end
	if ImGui.MenuItem(ctx, 'Help Tooltips', nil, gui.help_tooltips_enabled) then
		gui.help_tooltips_enabled = not gui.help_tooltips_enabled
		reaper.SetExtState("AMAPP", "help_tooltips", tostring(gui.help_tooltips_enabled), true)
	end
	ImGui.Separator(ctx)
	if ImGui.MenuItem(ctx, 'Start Guide') then
		gui.guide_active = true
		gui.guide_step = 1
		gui.guide_flash_timer = 0
		gui.guide_element_rects = {}
	end
end

function gui.MenuOptions()
	if ImGui.MenuItem(ctx, 'Activate cluster on select', nil, gui.toggleActivate) then
		gui.toggleActivate = not gui.toggleActivate
	end
	if ImGui.MenuItem(ctx, 'Deactivate other clusters on select', nil, gui.toggleDeactivate) then
		gui.toggleDeactivate = not gui.toggleDeactivate
	end
	if ImGui.MenuItem(ctx, 'Update cluster on action', nil, gui.update_clusters_is_toggled) then
		gui.update_clusters_is_toggled = not gui.update_clusters_is_toggled
	end
end

local function MenuFile()
	if ImGui.MenuItem(ctx, "Render Selected") then
		if RequireLicense("Render") then
			local clusters_to_render = {}
			for _, v in pairs(project_data.render_cluster_list) do
				if v.is_selected then
					table.insert(clusters_to_render, v)
				end
			end
			Render_Cluster(clusters_to_render)
		end
	end
	if ImGui.MenuItem(ctx, "Render All") then
		if RequireLicense("Render") then
			local clusters_to_render = project_data.render_cluster_table
			Render_Cluster(clusters_to_render)
		end
	end
	if ImGui.MenuItem(ctx, "Render Options...") then
		gui.open_export_options = true
	end
	ImGui.Separator(ctx)
	if ImGui.MenuItem(ctx, "Open Render Folder") then
		OpenRenderFolder()
	end
	ImGui.Separator(ctx)
	
	local license_state = GetLicenseState()
	local license_label = "Enter License Key"
	if license_state == "valid" then
		license_label = "License (Valid)"
	elseif license_state == "expired" then
		license_label = "License (Expired)"
	elseif license_state == "trial_new" or license_state == "trial_old" then
		license_label = "Enter License Key (Trial)"
	end
	if ImGui.MenuItem(ctx, license_label) then
		gui.license_key_input = amapp.license_key
		gui.license_modal_open = true
	end
end



gui.selectable_flag = ImGui.SelectableFlags_AllowOverlap
gui.list_item_rounding = 4
gui.list_item_scrollbar_width = 20
gui.list_item_indent_width = 21 


local function IsMouseInListbox()
	local mx, my = ImGui.GetMousePos(ctx)
	return mx >= gui.lb_min_x and mx <= gui.lb_max_x and my >= gui.lb_min_y and my <= gui.lb_max_y
end

local function RecurClusterList(list, cluster_table, lvl)
	local indentation = lvl or 0
	if cluster_table == nil then cluster_table = project_data.cluster_graph end
	if cluster_table == nil then return end
	local recur_list_idx = 0
	if indentation > 0 then ImGui.Indent(ctx) end
	
	local sorted_keys = {}
	for k, v in pairs(cluster_table) do
		table.insert(sorted_keys, { key = k, idx = v.idx or k })
	end
	table.sort(sorted_keys, function(a, b) return a.idx < b.idx end)
	for _, entry in ipairs(sorted_keys) do
		local idx = entry.key
		local c = cluster_table[idx]
		if list.temp_selected_clusters[c.idx] == nil then goto next end
		local l_item = list.temp_selected_clusters[c.idx]
		recur_list_idx = l_item.idx
		if l_item.cluster_guid == nil then goto next end
		local GUI_element_is_selected = false
		local item_label = l_item.cluster_id
		
		if list.duplicate_names[item_label] == nil then
			list.duplicate_names[item_label] = 1
		else
			list.duplicate_names[item_label] = 1 + list.duplicate_names[item_label]
		end
		if list.lb_visible then
			ImGui.DrawListSplitter_Split(gui.splitter, 2)
			ImGui.DrawListSplitter_SetCurrentChannel(gui.splitter, 1)
		end
		
		ImGui.PushStyleColor(ctx, ImGui.Col_Header, 0x00000000)
		ImGui.PushStyleColor(ctx, ImGui.Col_HeaderHovered, 0x00000000)
		ImGui.PushStyleColor(ctx, ImGui.Col_HeaderActive, 0x00000000)
		if gui.reorder_engaged then ImGui.PushStyleColor(ctx, ImGui.Col_HeaderHovered, 0x00000000) end
		local cluster_color = l_item.cluster_color
		if cluster_color == nil then cluster_color = 1 end
		cluster_color = ImGui.ColorConvertNative(cluster_color + 0x1000000)
		local loop_dot_color = TextColorBasedOnBgColor(cluster_color)
		local bkg_alpha = 0xff
		local text_color
		
		if l_item.is_selected then
			text_color = TextColorBasedOnBgColor(cluster_color)
		else
			text_color = gui.focus_activated and 0xffffff60 or 0xffffffff
		end
		ImGui.PushStyleColor(ctx, ImGui.Col_Text, text_color)
		if cluster_color == 0 then bkg_alpha = 0x30 end
		cluster_color = (cluster_color << 8) | bkg_alpha
		local formatted_item_label = "        " .. (item_label or "")
		
		for i = 0, list.duplicate_names[item_label], 1 do
			formatted_item_label = formatted_item_label .. " "
		end
		local item_width = list.content_width - (indentation * gui.list_item_indent_width) - 4
		GUI_element_is_selected = ImGui.Selectable(ctx, formatted_item_label, l_item.is_selected, gui.selectable_flag, item_width, list.item_height)
		if ImGui.BeginPopupContextItem(ctx) then 
			
			ImGui.PushStyleColor(ctx, ImGui.Col_Header, 0x4296fa66)
			ImGui.PushStyleColor(ctx, ImGui.Col_HeaderHovered, 0x4296faaa)
			ImGui.PushStyleColor(ctx, ImGui.Col_HeaderActive, 0x4296facc)
			ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xffffffff)
			SafePushFont(ctx, gui.fonts.mono_sm)
			if ImGui.MenuItem(ctx, 'Edit Cluster...') then
				ClearClusterSelection()
				l_item.is_selected = true
				gui.timeline_gui_edit_clicked = true
				ImGui.CloseCurrentPopup(ctx)
			end
			if ImGui.MenuItem(ctx, 'Audition...') then
				l_item.is_selected = true
				gui.audition_cluster = l_item
				gui.show_audition_popup = true
				ImGui.CloseCurrentPopup(ctx)
			end
			ImGui.Separator(ctx)
			if ImGui.MenuItem(ctx, 'Create group') then
				l_item.is_selected = true
				CreateClusterGroup()
				ImGui.CloseCurrentPopup(ctx)
			end
			if ImGui.MenuItem(ctx, 'Duplicate') then
				l_item.is_selected = true
				DuplicateClusterFunc()
				ImGui.CloseCurrentPopup(ctx)
			end
			ImGui.Separator(ctx)
			if ImGui.MenuItem(ctx, 'Select items in cluster') then
				l_item.is_selected = true
				SelectItemsInSelectedClusters()
				ImGui.CloseCurrentPopup(ctx)
			end
			if ImGui.MenuItem(ctx, 'Activate Cluster') then
				reaper.PreventUIRefresh(1)
				
				for _, cluster in pairs(project_data.render_cluster_list) do
					if cluster.cluster_guid == l_item.cluster_guid then
						Get_items_in_cluster(cluster, true)
						break
					end
				end
				reaper.PreventUIRefresh(-1)
				ImGui.CloseCurrentPopup(ctx)
			end
			if ImGui.MenuItem(ctx, 'Deactivate Cluster') then
				reaper.PreventUIRefresh(1)
				for _, cluster in pairs(project_data.render_cluster_list) do
					if cluster.cluster_guid == l_item.cluster_guid then
						Deactivate_items_in_cluster(cluster)
						break
					end
				end
				reaper.PreventUIRefresh(-1)
				ImGui.CloseCurrentPopup(ctx)
			end
			if ImGui.MenuItem(ctx, 'Clear Sync Points') then
				l_item.is_selected = true
				ClearClusterBoundaries()
				ImGui.CloseCurrentPopup(ctx)
			end
			ImGui.Separator(ctx)
			if ImGui.MenuItem(ctx, 'Render Selected') then
				l_item.is_selected = true
				local clusters_to_render = {}
				for _, v in pairs(project_data.render_cluster_list) do
					if v.is_selected then
						table.insert(clusters_to_render, v)
					end
				end
				local focus_and_solo = gui.focus_activated and gui.solo_clusters_on_focus
				
				project_data.render_pending = {
					clusters = clusters_to_render,
					focus_and_solo = focus_and_solo,
					focused_clusters = clusters_to_render
				}
				project_data.render_in_progress = true
				project_data.render_anim_start_frame = GetCachedFrameCount()
				ImGui.CloseCurrentPopup(ctx)
			end
			if ImGui.MenuItem(ctx, 'Render Options...') then
				l_item.is_selected = true
				ImGui.CloseCurrentPopup(ctx)
				gui.open_export_options = true
			end
			ImGui.Separator(ctx)
			if ImGui.MenuItem(ctx, 'Delete') then
				l_item.is_selected = true
				gui.delete_cluster_clicked = true
				ImGui.CloseCurrentPopup(ctx)
			end
			SafePopFont(ctx)
			ImGui.PopStyleColor(ctx, 4) 
			ImGui.EndPopup(ctx)
		end
		ImGui.PopStyleColor(ctx) 
		ImGui.PopStyleColor(ctx, 3) 
		if gui.reorder_engaged then ImGui.PopStyleColor(ctx) end
		local item_bg_min_x, item_bg_min_y = ImGui.GetItemRectMin(ctx)
		local item_bg_max_x, item_bg_max_y = ImGui.GetItemRectMax(ctx)
		
		
		local mx, my = ImGui.GetMousePos(ctx)
		local icon_x1, icon_y1 = item_bg_min_x + 9, item_bg_min_y + 4
		local icon_x2, icon_y2 = item_bg_min_x + 22, item_bg_min_y + 17
		local mouse_in_icon = mx >= icon_x1 and mx <= icon_x2 and my >= icon_y1 and my <= icon_y2
		if mouse_in_icon and (GUI_element_is_selected or ImGui.IsMouseDoubleClicked(ctx, 0)) then
			GUI_element_is_selected = false  
		end
		list.sum_height_items = list.sum_height_items + (item_bg_max_y - item_bg_min_y)
		gui.last_rendered_item_max_y = item_bg_max_y
		if list.lb_visible then
			ImGui.DrawListSplitter_SetCurrentChannel(gui.splitter, 0)
		end
		
		local is_item_hovered = ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_AllowWhenBlockedByActiveItem)
		if l_item.is_selected then
			
			ImGui.DrawList_AddRectFilled(list.draw_list, item_bg_min_x, item_bg_min_y, item_bg_max_x, item_bg_max_y, cluster_color, gui.list_item_rounding)
		elseif is_item_hovered and not gui.reorder_engaged then
			
			ImGui.DrawList_AddRectFilled(list.draw_list, item_bg_min_x, item_bg_min_y, item_bg_max_x, item_bg_max_y, 0xffffff20, gui.list_item_rounding)
		end
		if l_item.is_selected and gui.cluster_armed then
			local arm_color = ImGui.ColorConvertNative(0xFF444400 | gui.rec_arm_alpha)
			local bor_color = ImGui.ColorConvertNative(0xDD000000 | gui.rec_arm_alpha)
			local in_color = ImGui.ColorConvertNative(0x44000000 | gui.rec_arm_alpha)
			ImGui.DrawList_AddRectFilled(list.draw_list, item_bg_min_x+4, item_bg_min_y, item_bg_min_x+4+23, item_bg_max_y, bor_color)
			ImGui.DrawList_AddRectFilled(list.draw_list, item_bg_min_x+4+1, item_bg_min_y+1, item_bg_min_x+4+22, item_bg_max_y-1, arm_color)
			ImGui.DrawList_AddRectFilled(list.draw_list, item_bg_min_x+4+4, item_bg_min_y+3, item_bg_min_x+4+19, item_bg_min_y+18, in_color)
		end
		
		local is_group = type(l_item.children) == "table" and #l_item.children > 0
		
		local icon_area_hovered = IsMouseInListbox() and ImGui.IsMouseHoveringRect(ctx, item_bg_min_x+9, item_bg_min_y+4, item_bg_min_x+22, item_bg_min_y+17)
		local group_icon_hovered = is_group and icon_area_hovered
		local cluster_icon_hovered = not is_group and icon_area_hovered
		local icon_hovered = group_icon_hovered or cluster_icon_hovered
		if group_icon_hovered then
			ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand)
			if ImGui.IsMouseClicked(ctx, 0) then
				l_item.group_visible = not l_item.group_visible
				UpdateGroupCollapseState(c.cluster_guid, l_item.group_visible)
			end
		end
		
		gui.cluster_icon_pressed = gui.cluster_icon_pressed or {}
		local icon_id = "cluster_icon_" .. (l_item.cluster_guid or recur_list_idx)

		
		if cluster_icon_hovered and l_item.is_selected then
			gui.cluster_icon_bulk_hover = true
			gui.cluster_icon_bulk_hover_alt = ImGui.IsKeyDown(ctx, ImGui.Mod_Alt)
			gui.cluster_icon_bulk_hover_ctrl = ImGui.IsKeyDown(ctx, ImGui.Mod_Ctrl)
		end

		if cluster_icon_hovered then
			ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand)

			if ImGui.IsMouseClicked(ctx, 0) then
				
				gui.cluster_icon_pressed[icon_id] = {
					alt = ImGui.IsKeyDown(ctx, ImGui.Mod_Alt),
					cmd = ImGui.IsKeyDown(ctx, ImGui.Mod_Ctrl),
					shift = ImGui.IsKeyDown(ctx, ImGui.Mod_Shift),
					cluster = c,
					l_item = l_item,
				}
			end

			if ImGui.IsMouseDoubleClicked(ctx, 0) then
				MoveEditCursorToCluster()
			end

			
			local pressed_data = gui.cluster_icon_pressed[icon_id]
			if ImGui.IsMouseReleased(ctx, 0) and pressed_data then
				gui.icon_action_handled = true  
				
				local clusters_to_process = {}
				if pressed_data.l_item.is_selected then
					
					for _, cl in pairs(project_data.render_cluster_list) do
						if cl.is_selected then
							table.insert(clusters_to_process, cl)
						end
					end
				else
					
					table.insert(clusters_to_process, pressed_data.cluster)
				end

				if pressed_data.alt then
					
					for _, cl in ipairs(clusters_to_process) do
						Deactivate_items_in_cluster(cl)
					end
				elseif pressed_data.cmd then
					
					for _, cl in ipairs(clusters_to_process) do
						Get_items_in_cluster(cl, true)
					end
				else
					
					
					if pressed_data.shift then
						
						pressed_data.l_item.is_selected = not pressed_data.l_item.is_selected
						gui.focus_activated = true
						FocusSelectedClusters()
					elseif gui.focus_activated and pressed_data.l_item.is_selected then
						
						UnfocusClusters()
						gui.focus_activated = false
					else
						
						for _, cc in pairs(project_data.render_cluster_list) do
							cc.is_selected = false
						end
						pressed_data.l_item.is_selected = true
						gui.focus_activated = true
						FocusSelectedClusters()
					end
				end
				gui.cluster_icon_pressed[icon_id] = nil
			end
		else
			
			if gui.cluster_icon_pressed[icon_id] then
				gui.cluster_icon_pressed[icon_id] = nil
			end
		end
		item_bg_min_x = item_bg_min_x+9
		item_bg_min_y = item_bg_min_y+4
		item_bg_max_x = item_bg_min_x+13
		item_bg_max_y = item_bg_min_y+13
		if is_group and l_item.group_visible then
			
			local bar_y1 = item_bg_min_y + 1
			local bar_y2 = item_bg_max_y - 1
			local bar_width = 2
			local spacing = 2
			local total_width = bar_width * 3 + spacing * 2
			local start_x = item_bg_min_x + (item_bg_max_x - item_bg_min_x - total_width) / 2
			local bar_rounding = 1
			
			
			local visual_selected = l_item.is_selected
			if icon_hovered and ImGui.IsMouseDown(ctx, 0) then
				visual_selected = not visual_selected 
			end
			local bar_color = cluster_color
			if visual_selected then
				
				local r = (cluster_color >> 24) & 0xFF
				local g = (cluster_color >> 16) & 0xFF
				local b = (cluster_color >> 8) & 0xFF
				local luma = 0.299 * r + 0.587 * g + 0.114 * b
				if luma > 128 then
					
					r, g, b = math.floor(r * 0.4), math.floor(g * 0.4), math.floor(b * 0.4)
				else
					
					r = math.min(255, math.floor(r + (255 - r) * 0.6))
					g = math.min(255, math.floor(g + (255 - g) * 0.6))
					b = math.min(255, math.floor(b + (255 - b) * 0.6))
				end
				bar_color = (r << 24) | (g << 16) | (b << 8) | 0xFF
			end
			
			for i = 0, 2 do
				local bar_x = start_x + i * (bar_width + spacing)
				
				ImGui.DrawList_AddRectFilled(list.draw_list, bar_x, bar_y1, bar_x + bar_width, bar_y2, bar_color, bar_rounding)
				
				ImGui.DrawList_AddLine(list.draw_list, bar_x + 0.5, bar_y1 + bar_rounding, bar_x + 0.5, bar_y2 - bar_rounding, 0xffffff20, 1)
				
				ImGui.DrawList_AddLine(list.draw_list, bar_x + bar_width - 0.5, bar_y1 + bar_rounding, bar_x + bar_width - 0.5, bar_y2 - bar_rounding, 0x00000030, 1)
			end
		elseif is_group then
			
			local bar_x1 = item_bg_min_x + 1
			local bar_x2 = item_bg_max_x - 1
			local bar_height = 2
			local spacing = 2
			local total_height = bar_height * 3 + spacing * 2
			local start_y = item_bg_min_y + (item_bg_max_y - item_bg_min_y - total_height) / 2
			local bar_rounding = 1
			
			
			local visual_selected = l_item.is_selected
			if icon_hovered and ImGui.IsMouseDown(ctx, 0) then
				visual_selected = not visual_selected 
			end
			local bar_color = cluster_color
			if visual_selected then
				
				local r = (cluster_color >> 24) & 0xFF
				local g = (cluster_color >> 16) & 0xFF
				local b = (cluster_color >> 8) & 0xFF
				local luma = 0.299 * r + 0.587 * g + 0.114 * b
				if luma > 128 then
					
					r, g, b = math.floor(r * 0.4), math.floor(g * 0.4), math.floor(b * 0.4)
				else
					
					r = math.min(255, math.floor(r + (255 - r) * 0.6))
					g = math.min(255, math.floor(g + (255 - g) * 0.6))
					b = math.min(255, math.floor(b + (255 - b) * 0.6))
				end
				bar_color = (r << 24) | (g << 16) | (b << 8) | 0xFF
			end
			
			for i = 0, 2 do
				local bar_y = start_y + i * (bar_height + spacing)
				
				ImGui.DrawList_AddRectFilled(list.draw_list, bar_x1, bar_y, bar_x2, bar_y + bar_height, bar_color, bar_rounding)
				
				ImGui.DrawList_AddLine(list.draw_list, bar_x1 + bar_rounding, bar_y + 0.5, bar_x2 - bar_rounding, bar_y + 0.5, 0xffffff20, 1)
				
				ImGui.DrawList_AddLine(list.draw_list, bar_x1 + bar_rounding, bar_y + bar_height - 0.5, bar_x2 - bar_rounding, bar_y + bar_height - 0.5, 0x00000030, 1)
			end
		else
			
			local ix1, iy1 = item_bg_min_x+1, item_bg_min_y+1
			local ix2, iy2 = item_bg_max_x-1, item_bg_max_y-1
			local icon_rounding = 2

			
			local icon_id = "cluster_icon_" .. (l_item.cluster_guid or recur_list_idx)
			local is_icon_pressed = gui.cluster_icon_pressed and gui.cluster_icon_pressed[icon_id]
			local is_icon_hovered = cluster_icon_hovered
			local is_focused = gui.focus_activated and l_item.is_selected

			
			local fill_color = cluster_color
			local highlight_alpha, shadow_alpha
			local cc_r = (cluster_color >> 24) & 0xFF
			local cc_g = (cluster_color >> 16) & 0xFF
			local cc_b = (cluster_color >> 8) & 0xFF
			local luminance = cc_r * 0.299 + cc_g * 0.587 + cc_b * 0.114

			if (is_icon_pressed and is_icon_hovered) or is_focused then
				
				local r, g, b = math.floor(cc_r * 0.7), math.floor(cc_g * 0.7), math.floor(cc_b * 0.7)
				fill_color = (r << 24) | (g << 16) | (b << 8) | 0xFF
				highlight_alpha = 0x30
				shadow_alpha = 0x80
			elseif is_icon_hovered then
				
				local r = math.min(255, math.floor(cc_r + (255 - cc_r) * 0.2))
				local g = math.min(255, math.floor(cc_g + (255 - cc_g) * 0.2))
				local b = math.min(255, math.floor(cc_b + (255 - cc_b) * 0.2))
				fill_color = (r << 24) | (g << 16) | (b << 8) | 0xFF
				highlight_alpha = 0x90
				shadow_alpha = 0x60
			else
				highlight_alpha = 0x30
				shadow_alpha = 0x50
			end

			
			if not (is_focused or (is_icon_pressed and is_icon_hovered)) then
				ImGui.DrawList_AddRectFilled(list.draw_list, ix1+1, iy1+1, ix2+1, iy2+1, 0x00000060, icon_rounding)
			end

			
			ImGui.DrawList_AddRectFilled(list.draw_list, ix1, iy1, ix2, iy2, fill_color, icon_rounding)

			
			local top_col = 0xFFFFFF00 | highlight_alpha
			local bot_col = 0x00000000 | shadow_alpha

			if is_focused or (is_icon_pressed and is_icon_hovered) then
				top_col, bot_col = bot_col, top_col
			end

			
			ImGui.DrawList_AddLine(list.draw_list, ix1+icon_rounding, iy1+0.5, ix2-icon_rounding, iy1+0.5, top_col, 1)
			ImGui.DrawList_AddLine(list.draw_list, ix1+0.5, iy1+icon_rounding, ix1+0.5, iy2-icon_rounding, top_col, 1)
			
			ImGui.DrawList_AddLine(list.draw_list, ix1+icon_rounding, iy2-0.5, ix2-icon_rounding, iy2-0.5, bot_col, 1)
			ImGui.DrawList_AddLine(list.draw_list, ix2-0.5, iy1+icon_rounding, ix2-0.5, iy2-icon_rounding, bot_col, 1)

			
			if is_icon_hovered then
				ImGui.DrawList_AddRect(list.draw_list, ix1, iy1, ix2, iy2, 0x00000090, icon_rounding, ImGui.DrawFlags_None, 1)
			end

			
			
			
			
			local show_logo = false
			local logo_inverted = false
			local show_modifier_indicator = is_icon_hovered and (ImGui.IsKeyDown(ctx, ImGui.Mod_Ctrl) or ImGui.IsKeyDown(ctx, ImGui.Mod_Alt))
			
			local bulk_modifier = l_item.is_selected and gui.cluster_icon_bulk_hover_active
				and (ImGui.IsKeyDown(ctx, ImGui.Mod_Ctrl) or ImGui.IsKeyDown(ctx, ImGui.Mod_Alt))
			show_modifier_indicator = show_modifier_indicator or bulk_modifier

			if show_modifier_indicator then
				
				local show_deactivate = ImGui.IsKeyDown(ctx, ImGui.Mod_Alt)
				if show_deactivate then
					local d_x = item_bg_min_x + 6.5
					local d_y = item_bg_min_y + 6.5
					local d_color = loop_dot_color
					local half_h = 2.5
					local half_w = 2
					ImGui.DrawList_AddLine(list.draw_list, d_x - half_w, d_y - half_h, d_x - half_w, d_y + half_h, d_color, 1.5)
					ImGui.DrawList_AddLine(list.draw_list, d_x - half_w, d_y - half_h, d_x + half_w - 1, d_y - half_h, d_color, 1.5)
					ImGui.DrawList_AddLine(list.draw_list, d_x + half_w - 1, d_y - half_h, d_x + half_w, d_y, d_color, 1.5)
					ImGui.DrawList_AddLine(list.draw_list, d_x + half_w, d_y, d_x + half_w - 1, d_y + half_h, d_color, 1.5)
					ImGui.DrawList_AddLine(list.draw_list, d_x + half_w - 1, d_y + half_h, d_x - half_w, d_y + half_h, d_color, 1.5)
				else
					local a_x = item_bg_min_x + 6.5
					local a_y = item_bg_min_y + 6.5
					local a_color = loop_dot_color
					local half_h = 2.5
					local half_w = 2
					ImGui.DrawList_AddLine(list.draw_list, a_x - half_w, a_y + half_h, a_x, a_y - half_h, a_color, 1.5)
					ImGui.DrawList_AddLine(list.draw_list, a_x, a_y - half_h, a_x + half_w, a_y + half_h, a_color, 1.5)
					ImGui.DrawList_AddLine(list.draw_list, a_x - half_w + 1, a_y + 0.5, a_x + half_w - 1, a_y + 0.5, a_color, 1.5)
				end
			elseif is_icon_hovered or is_focused then
				
				show_logo = true
				logo_inverted = is_icon_hovered
			elseif l_item.is_loop then
				ImGui.DrawList_AddCircleFilled(list.draw_list, item_bg_min_x+6.2, item_bg_min_y+6.8, 3, loop_dot_color)
			end

			if show_logo and gui.images.logo then
				local icon_padding = 2
				local logo_x1, logo_y1 = ix1 + icon_padding, iy1 + icon_padding
				local logo_x2, logo_y2 = ix2 - icon_padding, iy2 - icon_padding
				local tint_r, tint_g, tint_b
				if is_focused then
					
					tint_r, tint_g, tint_b = 255, 255, 255
				elseif logo_inverted then
					
					if luminance < 128 then
						tint_r, tint_g, tint_b = 255, 255, 255
					else
						tint_r, tint_g, tint_b = 0, 0, 0
					end
				else
					
					if luminance < 128 then
						tint_r = math.min(255, math.floor(cc_r * 1.8 + 60))
						tint_g = math.min(255, math.floor(cc_g * 1.8 + 60))
						tint_b = math.min(255, math.floor(cc_b * 1.8 + 60))
					else
						tint_r = math.floor(cc_r * 0.4)
						tint_g = math.floor(cc_g * 0.4)
						tint_b = math.floor(cc_b * 0.4)
					end
				end
				local tint_color = (tint_r << 24) | (tint_g << 16) | (tint_b << 8) | 0xFF
				ImGui.DrawList_AddImage(list.draw_list, gui.images.logo, logo_x1, logo_y1, logo_x2, logo_y2, 0.0, 0.0, 1.0, 1.0, tint_color)
			end
		end
		if list.lb_visible then
			ImGui.DrawListSplitter_Merge(gui.splitter)
		end
		if l_item.is_selected and gui.lb_should_scroll then
			local center_y_ratio = 0.5
			ImGui.SetScrollHereY(ctx, center_y_ratio)
			gui.lb_should_scroll = false
		end
		if ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_AllowWhenBlockedByActiveItem) and not ImGui.IsPopupOpen(ctx, "", ImGui.PopupFlags_AnyPopupId) then
			gui.last_hovered_item = l_item.cluster_guid
			gui.last_hovered_item_index = l_item.idx
			gui.last_hovered_item_is_group = is_group
			gui.last_hovered_item_parent_guid = l_item.parent_guid
			
			gui.last_hovered_item_is_last_in_group = false
			if l_item.parent_guid then
				local parent = project_data.render_cluster_table[l_item.parent_guid]
				if parent and parent.children and #parent.children > 0 then
					gui.last_hovered_item_is_last_in_group = (parent.children[#parent.children] == l_item.cluster_guid)
				end
			end
			gui.pers_rect_min_x, gui.pers_rect_min_y = ImGui.GetItemRectMin(ctx)
			gui.pers_rect_max_x, gui.pers_rect_max_y = ImGui.GetItemRectMax(ctx)
			if ImGui.IsMouseClicked(ctx, 0, false) and gui.reorder_engaged == false and not icon_hovered then
				gui.reorder_item_clicked_index = l_item.idx
				
				gui.clicked_on_group = is_group
				if project_data.render_cluster_list[recur_list_idx].is_selected then
					gui.reorder_prevent_clear_items = true
				else
					gui.reorder_prevent_clear_items = false
				end
			end
			if ImGui.IsMouseDoubleClicked(ctx, 0) and not icon_hovered and not is_group then
				local negate_deselect = false
				list.double_clicked_cluster = project_data.render_cluster_list[recur_list_idx]
				project_data.render_cluster_list[recur_list_idx].is_selected = negate_deselect
				list.double_click_event = true
				if project_data.render_cluster_list[recur_list_idx].is_loop then
					list.dClick_region_pos = l_item.c_entry or l_item.c_start
					list.dClick_region_end = l_item.c_exit or l_item.c_end
					if list.dClick_region_pos == list.dClick_region_end then list.dClick_region_end = l_item.c_end end
				else
					list.dClick_region_pos, list.dClick_region_end = l_item.c_start, l_item.c_end
				end
				if list.dClick_region_pos == nil or list.dClick_region_end  == nil then goto skip end
				list.dClick_region_isLoop = l_item.is_loop
				local _, loop_end = reaper.GetSet_LoopTimeRange(false, true, list.dClick_region_pos, list.dClick_region_end, false)
				if loop_end == list.dClick_region_pos then reaper.GetSetRepeat(0) end
				::skip::
			end
			
			
			
			
			
		end
		if GUI_element_is_selected and gui.triggerFunction then
			gui.last_selected_item_idx = l_item.idx
			if CheckIfCtrlIsPressed() then
				project_data.render_cluster_list[l_item.idx].is_selected = not project_data.render_cluster_list[l_item.idx].is_selected
			elseif CheckIfShiftIsPressed() then
				project_data.render_cluster_list[l_item.idx].is_selected = not project_data.render_cluster_list[l_item.idx].is_selected
				local _start_index = nil
				local _end_index = nil
				for key, value in pairs(project_data.render_cluster_list) do
					if value.is_selected then
						if _start_index == nil then
							_start_index = key
						else
							_end_index = key
						end
					end
				end
				if _start_index == nil then goto continue end
				if _end_index == nil then goto continue end
				if _start_index > _end_index then
					local _temp = _start_index
					_start_index = _end_index
					_end_index = _temp
				end
				for key, value in pairs(project_data.render_cluster_list) do
					if key >= _start_index and key <= _end_index then
						project_data.render_cluster_list[key].is_selected = true
					end
				end
				::continue::
			else
				project_data.render_cluster_list[recur_list_idx].is_selected = not project_data.render_cluster_list[recur_list_idx].is_selected
				for key, value in pairs(project_data.render_cluster_list) do
					if key ~= recur_list_idx then
						project_data.render_cluster_list[key].is_selected = false
					end
				end
			end
			gui.toggleLoop = l_item.is_loop
		end
		if is_group and l_item.group_visible then
			local children = {}
			for _, _guid in pairs(l_item.children) do
				local child = project_data.render_cluster_table[_guid]
				if child then
					table.insert(children, child)
				end
			end
			
			table.sort(children, function(a, b) return (a.idx or 0) < (b.idx or 0) end)
			indentation = indentation + 1
			RecurClusterList(list, children, indentation)
			if indentation > 0 then indentation = indentation - 1 end
		end
		::next::
	end
	if indentation > 0 then ImGui.Unindent(ctx) end
end

local function RenderClusterListUI()
	local window_width, window_height = ImGui.GetWindowSize(ctx)
	local list = {}
	list.responsive_width = 400
	gui.listbox_height = 219
	if window_width < (800 + 10) and window_height < 800 then
		list.responsive_width = (window_width - 10) * 0.5
	elseif list.responsive_width > window_width then
		list.responsive_width = window_width
	end
	if window_height > 319 and window_height < 800 then
		gui.listbox_height = window_height - gui.listbox_height
	elseif window_height >= 800 then
		gui.listbox_height = (window_height * 0.7) - 150
	end
	if window_width < gui.listbox_width then
		list.responsive_width = window_width - 20
	end
	local c_x, c_y = ImGui.GetCursorPos(ctx)
	SafePushFont(ctx, gui.fonts.sans_serif_sm)
	ImGui.SetCursorPos(ctx, list.responsive_width/2 - 10, c_y+5)
	ImGui.Text(ctx, "Clusters")
	SafePopFont(ctx)
	c_x, c_y = ImGui.GetCursorPos(ctx)
	ImGui.SetCursorPos(ctx, c_x, c_y+5)
	
	local lb_start_x, lb_start_y = ImGui.GetCursorScreenPos(ctx)
	local listbox = ImGui.BeginListBox(ctx, "##render cluster list", list.responsive_width, gui.listbox_height)
	
	gui.lb_min_x, gui.lb_min_y = lb_start_x, lb_start_y
	gui.lb_max_x = lb_start_x + list.responsive_width
	gui.lb_max_y = lb_start_y + gui.listbox_height
	list.lb_visible = ImGui.IsRectVisibleEx(ctx, gui.lb_min_x, gui.lb_min_y, gui.lb_max_x, gui.lb_max_y)
	list.draw_list = ImGui.GetWindowDrawList(ctx)
	if list.lb_visible and not ImGui.ValidatePtr(gui.splitter, 'ImGui_DrawListSplitter*') then
		gui.splitter = ImGui.CreateDrawListSplitter(list.draw_list)
	end
	
	
	if gui.focus_activated and listbox and list.draw_list then
		local focus_color = nil
		for _, c in pairs(project_data.render_cluster_list) do
			if c.is_selected and c.cluster_color then
				focus_color = c.cluster_color
				break
			end
		end
		if focus_color then
			local fc = ImGui.ColorConvertNative(focus_color + 0x1000000)
			local r = math.floor(((fc >> 24) & 0xFF) * 0.15)
			local g = math.floor(((fc >> 16) & 0xFF) * 0.15)
			local b = math.floor(((fc >> 8) & 0xFF) * 0.15)
			local dim_color = (r << 24) | (g << 16) | (b << 8) | 0xFF
			ImGui.DrawList_AddRectFilled(list.draw_list, gui.lb_min_x, gui.lb_min_y, gui.lb_max_x, gui.lb_max_y, dim_color, 8)
		end
	end

	list.temp_selected_clusters = project_data.render_cluster_list
	list.item_height = 17
	list.sum_height_items = 0
	list.double_click_event = false
	list.double_clicked_cluster = {}
	list.dClick_region_pos, list.dClick_region_end, list.dClick_region_isLoop = 0, 0, false
	list.duplicate_names = {}
	
	list.content_width = ImGui.GetContentRegionAvail(ctx)

	
	gui.cluster_icon_bulk_hover_active = gui.cluster_icon_bulk_hover or false
	gui.cluster_icon_bulk_hover_alt_active = gui.cluster_icon_bulk_hover_alt or false
	gui.cluster_icon_bulk_hover_ctrl_active = gui.cluster_icon_bulk_hover_ctrl or false
	gui.cluster_icon_bulk_hover = false
	gui.cluster_icon_bulk_hover_alt = false
	gui.cluster_icon_bulk_hover_ctrl = false

	RecurClusterList(list)

	reaper.PreventUIRefresh(1)
	if gui.focus_activated and gui.triggerFunction then FocusSelectedClusters() end
	
	if gui.toggleActivate and gui.triggerFunction and not gui.icon_action_handled and not gui.clicked_on_group then
		GetItemsFunc()
	end
	gui.icon_action_handled = nil
	gui.clicked_on_group = nil
	if list.double_click_event then
		if list.dClick_region_isLoop then
			reaper.GetSet_LoopTimeRange(true, true, list.dClick_region_pos, list.dClick_region_end, true)
			reaper.SetEditCurPos(list.dClick_region_pos, true, true)
			reaper.GetSetRepeat(1)
		else
			reaper.SetEditCurPos(list.dClick_region_pos, true, true)
		end
		if list.double_clicked_cluster.cluster_guid ~= nil then
			VerticalScrollToFirstItem(list.double_clicked_cluster)
		end
	end
	reaper.PreventUIRefresh(-1)
	
	if gui.timeline_context_menu_clicked then
		ImGui.OpenPopup(ctx, "Timeline Cluster Context Menu")
		gui.timeline_context_menu_clicked = false
	end
	
	local tl_cc = gui.timeline_context_menu_color or 0x505050
	local tl_r = (tl_cc >> 16) & 0xFF
	local tl_g = (tl_cc >> 8) & 0xFF
	local tl_b = tl_cc & 0xFF
	local tl_lum = tl_r * 0.299 + tl_g * 0.587 + tl_b * 0.114
	local tl_popup_bg = (tl_r << 24) | (tl_g << 16) | (tl_b << 8) | 0xF0
	local tl_text_col = tl_lum < 128 and 0xFFFFFFFF or 0x000000FF
	local tl_border_col = tl_lum < 128 and 0xFFFFFF40 or 0x00000040
	local tl_hover_bg = tl_lum < 128 and 0xFFFFFF20 or 0x00000020
	ImGui.PushStyleColor(ctx, ImGui.Col_PopupBg, tl_popup_bg)
	ImGui.PushStyleColor(ctx, ImGui.Col_Text, tl_text_col)
	ImGui.PushStyleColor(ctx, ImGui.Col_Border, tl_border_col)
	ImGui.PushStyleColor(ctx, ImGui.Col_HeaderHovered, tl_hover_bg)
	ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowRounding, 4)
	ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowBorderSize, 1)
	ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, 8, 6)
	if ImGui.BeginPopup(ctx, "Timeline Cluster Context Menu") then
		SafePushFont(ctx, gui.fonts.sans_serif_sm)
		if ImGui.MenuItem(ctx, 'Edit Cluster...') then
			gui.timeline_gui_edit_clicked = true
			ImGui.CloseCurrentPopup(ctx)
		end
		if ImGui.MenuItem(ctx, 'Create group') then
			CreateClusterGroup()
			ImGui.CloseCurrentPopup(ctx)
		end
		if ImGui.MenuItem(ctx, 'Duplicate') then
			DuplicateClusterFunc()
			ImGui.CloseCurrentPopup(ctx)
		end
		ImGui.Separator(ctx)
		if ImGui.MenuItem(ctx, 'Select items in cluster') then
			SelectItemsInSelectedClusters()
			ImGui.CloseCurrentPopup(ctx)
		end
		if ImGui.MenuItem(ctx, 'Activate Cluster') then
			reaper.PreventUIRefresh(1)
			for _, v in pairs(project_data.render_cluster_list) do
				if v.is_selected then
					Get_items_in_cluster(v, true)
				end
			end
			reaper.PreventUIRefresh(-1)
			ImGui.CloseCurrentPopup(ctx)
		end
		if ImGui.MenuItem(ctx, 'Deactivate Cluster') then
			reaper.PreventUIRefresh(1)
			for _, v in pairs(project_data.render_cluster_list) do
				if v.is_selected then
					Deactivate_items_in_cluster(v)
				end
			end
			reaper.PreventUIRefresh(-1)
			ImGui.CloseCurrentPopup(ctx)
		end
		ImGui.Separator(ctx)
		if ImGui.MenuItem(ctx, 'Render Selected') then
			local clusters_to_render = {}
			for _, v in pairs(project_data.render_cluster_list) do
				if v.is_selected then
					table.insert(clusters_to_render, v)
				end
			end
			local focus_and_solo = gui.focus_activated and gui.solo_clusters_on_focus
			
			project_data.render_pending = {
				clusters = clusters_to_render,
				focus_and_solo = focus_and_solo,
				focused_clusters = clusters_to_render
			}
			project_data.render_in_progress = true
			project_data.render_anim_start_frame = GetCachedFrameCount()
			ImGui.CloseCurrentPopup(ctx)
		end
		if ImGui.MenuItem(ctx, 'Render Options...') then
			ImGui.CloseCurrentPopup(ctx)
			gui.open_export_options = true
		end
		ImGui.Separator(ctx)
		if ImGui.MenuItem(ctx, 'Delete') then
			gui.delete_cluster_clicked = true
			ImGui.CloseCurrentPopup(ctx)
		end
		SafePopFont(ctx)
		ImGui.EndPopup(ctx)
	end
	ImGui.PopStyleColor(ctx, 4) 
	ImGui.PopStyleVar(ctx, 3) 

	
	if listbox then
		local btn_height = list.item_height + 4
		local btn_width = list.responsive_width - 16  
		btn_width = math.max(btn_width, 1)
		btn_height = math.max(btn_height, 1)
		local cursor_x, cursor_y = ImGui.GetCursorPos(ctx)
		local draw_list = ImGui.GetWindowDrawList(ctx)
		local screen_x, screen_y = ImGui.GetCursorScreenPos(ctx)
		local mx, my = ImGui.GetMousePos(ctx)
		local in_listbox = IsMouseInListbox()
		local any_popup_open = ImGui.IsPopupOpen(ctx, "", ImGui.PopupFlags_AnyPopupId + ImGui.PopupFlags_AnyPopupLevel)
		local is_enabled = not gui.reorder_engaged and not any_popup_open
		local is_hovered = is_enabled and in_listbox and mx >= screen_x and mx <= screen_x + btn_width and my >= screen_y and my <= screen_y + btn_height
		local is_pressed = is_hovered and ImGui.IsMouseDown(ctx, ImGui.MouseButton_Left)
		local is_clicked = is_hovered and ImGui.IsMouseReleased(ctx, ImGui.MouseButton_Left)
		local rounding = 4
		if is_hovered or is_pressed then
			local bg_color = is_pressed and 0x303030E0 or 0x404040A0
			local highlight_alpha = is_pressed and 0x10 or 0x40
			local shadow_alpha = is_pressed and 0x40 or 0x25
			local highlight_col = 0xFFFFFF00 | highlight_alpha
			local shadow_col = 0x00000000 | shadow_alpha
			if not is_pressed then
				ImGui.DrawList_AddRectFilled(draw_list, screen_x+1, screen_y+1, screen_x+btn_width+1, screen_y+btn_height+1, 0x00000015, rounding)
			end
			ImGui.DrawList_AddRectFilled(draw_list, screen_x, screen_y, screen_x+btn_width, screen_y+btn_height, bg_color, rounding)
			ImGui.DrawList_AddLine(draw_list, screen_x+rounding, screen_y+0.5, screen_x+btn_width-rounding, screen_y+0.5, highlight_col, 1)
			ImGui.DrawList_AddLine(draw_list, screen_x+0.5, screen_y+rounding, screen_x+0.5, screen_y+btn_height-rounding, highlight_col, 1)
			ImGui.DrawList_AddLine(draw_list, screen_x+rounding, screen_y+btn_height-0.5, screen_x+btn_width-rounding, screen_y+btn_height-0.5, shadow_col, 1)
			ImGui.DrawList_AddLine(draw_list, screen_x+btn_width-0.5, screen_y+rounding, screen_x+btn_width-0.5, screen_y+btn_height-rounding, shadow_col, 1)
		end

		local plus_size = 10
		local plus_thickness = 2
		local center_x = math.floor(screen_x + btn_width / 2) + 0.5
		local center_y = math.floor(screen_y + btn_height / 2) + 0.5
		local half_size = math.floor(plus_size / 2)
		local plus_color = is_pressed and 0xFFFFFFFF or (is_hovered and 0xFFFFFFD0 or 0x808080FF)
		local half_thick = plus_thickness / 2

		ImGui.DrawList_AddRectFilled(draw_list,
			center_x - half_size, center_y - half_thick,
			center_x + half_size, center_y + half_thick,
			plus_color, 0)

		ImGui.DrawList_AddRectFilled(draw_list,
			center_x - half_thick, center_y - half_size,
			center_x + half_thick, center_y + half_size,
			plus_color, 0)

		ImGui.SetCursorPos(ctx, cursor_x, cursor_y)
		ImGui.InvisibleButton(ctx, "##create_new_cluster_btn", btn_width, btn_height)
		gui.GuideTrackElement("create_cluster_list_btn")
		if is_hovered then
			ImGui.SetTooltip(ctx, "Create New Cluster")
		end

		if is_pressed then
			gui.new_cluster_btn_clicked = true
		end

		list.sum_height_items = list.sum_height_items + btn_height
	end

	if listbox then ImGui.EndListBox(ctx) end
	gui.HelpTooltip("cluster_list")

	
	if gui.new_cluster_btn_clicked then
		local groups = DetectItemGroups()
		if groups and #groups > 1 then
			gui.detected_item_groups = groups
			gui.show_variation_prompt = true
			ImGui.OpenPopup(ctx, "Multiple Groups Detected")
		else
			gui.detected_item_groups = nil
			ImGui.OpenPopup(ctx, "Create New Cluster")
		end
		gui.new_cluster_btn_clicked = false
	end
	local is_dragging = ImGui.IsMouseDragging(ctx, 0, -1.0)
	local lb_is_overflowing = (list.sum_height_items + 2) > gui.listbox_height
	
	local effective_lb_max_x = gui.lb_max_x
	if lb_is_overflowing then effective_lb_max_x = gui.lb_max_x - 16.5 end
	local hovering_lb = ImGui.IsMouseHoveringRect(ctx, gui.lb_min_x, gui.lb_min_y, effective_lb_max_x, gui.lb_max_y, true)
	if ImGui.IsMouseClicked(ctx, 0) and not hovering_lb then
		gui.prevent_reorder = true
	end
	local popup_visible_flag = ImGui.PopupFlags_AnyPopupId + ImGui.PopupFlags_AnyPopupLevel
	local popup_is_open = ImGui.IsPopupOpen(ctx, "", popup_visible_flag)
	if ImGui.IsMouseReleased(ctx, 0) then gui.prevent_reorder = false end
	if is_dragging and not gui.prevent_reorder
	and project_data.render_cluster_list[gui.reorder_item_clicked_index] ~= nil
	and hovering_lb
	and not popup_is_open then
		list.draw_list = ImGui.GetForegroundDrawList(ctx)
		local w_x = ImGui.GetWindowSize(ctx)
		if w_x < (600 + 20) then
			gui.pers_rect_max_x = gui.pers_rect_min_x + (w_x / 2) - 9
		end

		
		local item_height = gui.pers_rect_max_y - gui.pers_rect_min_y
		local edge_zone = item_height * 0.3  
		local _, my = ImGui.GetMousePos(ctx)
		local in_center_zone = my > (gui.pers_rect_min_y + edge_zone) and my < (gui.pers_rect_max_y - edge_zone)
		local in_bottom_zone = my >= (gui.pers_rect_max_y - edge_zone)

		
		gui.hovering_below_list = my > gui.last_rendered_item_max_y

		
		local dragged_cluster = project_data.render_cluster_list[gui.reorder_item_clicked_index]

		
		local function is_child_of_selected(guid)
			for _, v in pairs(project_data.render_cluster_list) do
				if v.is_selected and v.children then
					local function check_children(children)
						for _, child_guid in ipairs(children) do
							if child_guid == guid then return true end
							local child = project_data.render_cluster_table[child_guid]
							if child and child.children and check_children(child.children) then
								return true
							end
						end
						return false
					end
					if check_children(v.children) then return true end
				end
			end
			return false
		end

		gui.hovering_own_child = is_child_of_selected(gui.last_hovered_item)

		local is_valid_group_target = gui.last_hovered_item_is_group
			and gui.last_hovered_item ~= dragged_cluster.cluster_guid
			and (dragged_cluster.parent_guid ~= gui.last_hovered_item)  
			and not gui.hovering_own_child

		
		gui.drop_into_group = (in_center_zone or in_bottom_zone) and is_valid_group_target

		
		gui.drop_out_of_group = false
		local line_x_offset = 0  
		if gui.last_hovered_item_is_last_in_group and in_bottom_zone and not gui.hovering_own_child then
			
			local bottom_zone_start = gui.pers_rect_max_y - edge_zone
			local bottom_zone_mid = bottom_zone_start + (edge_zone / 2)
			if my >= bottom_zone_mid then
				
				gui.drop_out_of_group = true
			else
				
				line_x_offset = 15  
			end
		end

		local draw_rect_max_x = gui.pers_rect_min_x + list.responsive_width - 16.5
		if not lb_is_overflowing then
			draw_rect_max_x = draw_rect_max_x + 12
		end

		
		if gui.hovering_own_child then
			
		elseif gui.hovering_below_list then
			
			
			local line_y = gui.last_rendered_item_max_y
			ImGui.DrawList_PathRect(list.draw_list, gui.lb_min_x + 2, line_y, draw_rect_max_x, line_y + 1)
			ImGui.DrawList_PathFillConvex(list.draw_list, 0xfffffffff)
		elseif gui.drop_into_group then
			
			ImGui.DrawList_AddRectFilled(list.draw_list,
				gui.pers_rect_min_x + 2, gui.pers_rect_min_y,
				draw_rect_max_x, gui.pers_rect_max_y,
				0xFFFFFF30, 4)
			ImGui.DrawList_AddRect(list.draw_list,
				gui.pers_rect_min_x + 2, gui.pers_rect_min_y,
				draw_rect_max_x, gui.pers_rect_max_y,
				0xFFFFFFAA, 4, 0, 2)
		else
			
			if ImGui.IsMouseHoveringRect(ctx, gui.pers_rect_min_x, (gui.pers_rect_max_y - 5), gui.pers_rect_max_x, gui.lb_max_y, true) then
				gui.pers_rect_min_y = gui.pers_rect_max_y
			end
			local draw_rect_max_y = gui.pers_rect_min_y + 1
			local line_start_x = gui.pers_rect_min_x + 2 + line_x_offset
			if draw_rect_max_y > gui.lb_min_y then
				ImGui.DrawList_PathRect(list.draw_list, line_start_x, gui.pers_rect_min_y, draw_rect_max_x, draw_rect_max_y)
				ImGui.DrawList_PathFillConvex(list.draw_list, 0xfffffffff)
			end
		end

		project_data.render_cluster_list[gui.reorder_item_clicked_index].is_selected = true
		if not gui.reorder_prevent_clear_items and ( CheckIfCtrlIsPressed() == false and CheckIfShiftIsPressed() == false ) then
			for k, v in pairs(project_data.render_cluster_list) do
				if k ~= gui.reorder_item_clicked_index then
					v.is_selected = false
				end
			end
			gui.reorder_prevent_clear_items = false
		end
		gui.reorder_engaged = true
	end
	if ImGui.IsMouseReleased(ctx, 0)
	and gui.reorder_engaged and not gui.prevent_reorder
	and hovering_lb
	and not popup_is_open then
		if gui.hovering_own_child then
			
		elseif gui.hovering_below_list then
			
			local last_cluster_guid = nil
			local last_idx = 0
			for _, v in pairs(project_data.render_cluster_list) do
				if v.idx > last_idx then
					last_idx = v.idx
					last_cluster_guid = v.cluster_guid
				end
			end
			if last_cluster_guid then
				ReorderItems(last_cluster_guid, 1, last_idx, nil)  
			end
		elseif gui.drop_into_group then
			
			AddItemsToGroup(gui.last_hovered_item)
		else
			
			local add_num_to_index = 0
			local draw_rect_max_y = gui.pers_rect_max_y - 5
			if ImGui.IsMouseHoveringRect(ctx, gui.pers_rect_min_x, draw_rect_max_y, gui.pers_rect_max_x, gui.lb_max_y, true) then
				add_num_to_index = 1
			end
			
			
			local target_parent = gui.drop_out_of_group and nil or gui.last_hovered_item_parent_guid
			ReorderItems(gui.last_hovered_item, add_num_to_index, gui.last_hovered_item_index, target_parent)
		end
		gui.reorder_engaged = false
		gui.drop_into_group = false
		gui.drop_out_of_group = false
		gui.hovering_own_child = false
		gui.hovering_below_list = false
	end
end


local color_styling_table = {
	{idx = ImGui.Col_WindowBg, color = 0x11191cff},
	{idx = ImGui.Col_PopupBg, color = 0x11191cff},  
	{idx = ImGui.Col_TitleBg, color = 0x11191cff},
	{idx = ImGui.Col_TitleBgActive, color = 0x202f34ff},
	{idx = ImGui.Col_MenuBarBg, color = 0x11191cff},
	{idx = ImGui.Col_Tab, color = 0x11191cff},
	
	{idx = ImGui.Col_TabHovered, color = 0x11191cff},
	
	
	{idx = ImGui.Col_TableRowBg, color = 0x11191cff},
	
	{idx = ImGui.Col_FrameBg, color = 0x202f3470},
	{idx = ImGui.Col_FrameBgActive, color = 0x202f3400},
	{idx = ImGui.Col_FrameBgHovered, color = 0x4c707eff},
	{idx = ImGui.Col_Button, color = 0x202f34ff},
	{idx = ImGui.Col_ButtonActive, color = 0xb9cdd5ff},
	{idx = ImGui.Col_ButtonHovered, color = 0x4c707eff},
	{idx = ImGui.Col_Header, color = 0xffffff70},
	{idx = ImGui.Col_HeaderActive, color = 0xffffff20},
	{idx = ImGui.Col_HeaderHovered, color = 0xffffff42},
	{idx = ImGui.Col_CheckMark, color = 0xb9cdd5ff},
	{idx = ImGui.Col_ResizeGrip, color = 0x11191cff},
	{idx = ImGui.Col_ResizeGripActive, color = 0xb9cdd5ff},
	{idx = ImGui.Col_ResizeGripHovered, color = 0x4c707eff},
	{idx = ImGui.Col_ModalWindowDimBg, color = 0x00000000}  
}

gui.window_size_initialized = false

local function WindowStyling()
	if not gui.window_size_initialized then
		ImGui.SetNextWindowSize(ctx, 300, 120, ImGui.Cond_FirstUseEver)
		gui.window_size_initialized = true
	end
	for k, v in pairs(color_styling_table) do
		ImGui.PushStyleColor(ctx, v.idx, v.color)
	end
	
	local rounding = 8
	ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowRounding, rounding)
	ImGui.PushStyleVar(ctx, ImGui.StyleVar_PopupRounding, rounding)
	ImGui.PushStyleVar(ctx, ImGui.StyleVar_FrameRounding, rounding * 0.5)
	ImGui.PushStyleVar(ctx, ImGui.StyleVar_ChildRounding, rounding)
	ImGui.PushStyleVar(ctx, ImGui.StyleVar_TabRounding, rounding * 0.5)
	SafePushFont(ctx, gui.fonts.sans_serif)
end


local function RenderProgressPanel()
	local progress = project_data.render_progress
	local is_animating = project_data.render_pending ~= nil
	local is_rendering = progress.active
	local is_complete = progress.render_complete

	
	if not is_animating and not is_rendering and not is_complete then return end

	local w, h = ImGui.GetWindowSize(ctx)
	local x, y = ImGui.GetCursorScreenPos(ctx)
	local fg_draw_list = ImGui.GetForegroundDrawList(ctx)

	
	local anim_start = project_data.render_anim_start_frame or GetCachedFrameCount()

	
	local anim_frame = GetCachedFrameCount() - anim_start
	local anim_progress = math.min(1.0, anim_frame / 10)  

	
	local alpha = math.floor(anim_progress * 255)
	local overlay_color = 0x11191c00 + alpha  
	local img_alpha = 0xFFFFFF00 + alpha  

	
	local x_w = x + w
	local y_h = y + h
	ImGui.DrawList_AddRectFilled(fg_draw_list, 0, 0, x_w, y_h, overlay_color, 0.0)

	
	local image_size = 250
	if h < image_size then
		image_size = h - (h / 30)
	elseif w < image_size then
		image_size = w
	end
	local img_x_offset = x + (w/2) - (image_size/2)
	local img_y_offset = y + (h/2) - (image_size/2) - (h / 30)

	
	if gui.images.render_logo then
		ImGui.DrawList_AddImage(fg_draw_list, gui.images.render_logo, img_x_offset, img_y_offset, img_x_offset + image_size, img_y_offset + image_size, 0.0, 0.0, 1.0, 1.0, img_alpha)
	end

	
	local text_color = 0xFFFFFF00 + alpha  
	local dim_text_color = 0x888888FF  
	if anim_progress >= 1.0 then
		text_color = 0xFFFFFFFF  
	end

	local text_y = img_y_offset + image_size + 20
	local center_x = x + w / 2

	
	SafePushFont(ctx, gui.fonts.sans_serif_bold)
	local header = progress.render_complete and "Complete" or "Rendering"
	local str_w = ImGui.CalcTextSize(ctx, header)
	ImGui.DrawList_AddText(fg_draw_list, center_x - str_w / 2, text_y, text_color, header)
	SafePopFont(ctx)

	text_y = text_y + 25

	
	
	local rendered_guids = {}
	local completed_guids = {}
	local current_batch_guids = {}  

	if async_render.active and async_render.queue then
		
		
		
		
		local batch_start = async_render.current_index
		local batch_end = batch_start + (async_render.current_batch_size or 1) - 1

		
		local finished_guids = {}
		for _, result in ipairs(async_render.results) do
			if result.cluster_guid then
				finished_guids[result.cluster_guid] = true
			end
		end

		for i, item in ipairs(async_render.queue) do
			local guid = item.cluster.cluster_guid
			if guid then
				rendered_guids[guid] = true
				
				if i >= batch_start and i <= batch_end then
					current_batch_guids[guid] = true
				elseif finished_guids[guid] then
					
					completed_guids[guid] = true
				end
			end
		end
	elseif progress.render_complete and gui.render_summary_data and gui.render_summary_data.results then
		
		for _, result in ipairs(gui.render_summary_data.results) do
			if result.cluster_guid then
				rendered_guids[result.cluster_guid] = true
				
				if result.success then
					completed_guids[result.cluster_guid] = true
				end
			end
		end
	elseif project_data.render_pending and project_data.render_pending.clusters then
		for _, cluster in ipairs(project_data.render_pending.clusters) do
			if cluster.cluster_guid then
				rendered_guids[cluster.cluster_guid] = true
			end
		end
	end

	
	local map_width = math.min(w * 0.8, 350)
	local map_x = center_x - map_width / 2
	local map_height = DrawClusterMinimap(fg_draw_list, map_x, text_y, map_width, rendered_guids, completed_guids, current_batch_guids)
	text_y = text_y + map_height + 15


	text_y = text_y + 10

	
	local hint
	if is_complete then
		hint = "Click to close"
	else
		hint = "Cancel from REAPER dialog to abort"
	end
	SafePushFont(ctx, gui.fonts.sans_serif_sm)
	str_w = ImGui.CalcTextSize(ctx, hint)
	ImGui.DrawList_AddText(fg_draw_list, center_x - str_w / 2, text_y, dim_text_color, hint)
	SafePopFont(ctx)
end

local function MainWindow()
	
	TriggerFunctionBool()
	local w_l, w_h = ImGui.GetWindowSize(ctx)
	local responsive_height = false
	if w_l > 400 and w_h < 800 then responsive_height = true end
	local local_x, local_y = ImGui.GetCursorPos(ctx)
	ImGui.SetCursorPosY(ctx, local_y - 2)
	ImGui.Indent(ctx, 3)
	ImGui.Image(ctx, gui.images.logo_w_text, 104.25, 24)
	ImGui.SameLine(ctx, 0.0, 0.0)
	ImGui.SetCursorPosY(ctx, local_y)
	SafePushFont(ctx, gui.fonts.sans_serif_sm)
	ImGui.Text(ctx, "v" .. VERSION)
	SafePopFont(ctx)
	ImGui.SameLine(ctx, 0.0, 5.0)
	
	local _license_state = GetLicenseState()
	if _license_state == "valid" then
		
		local email = GetLicensedEmail()
		if email then
			ImGui.SetCursorPosY(ctx, local_y + 2)
			local font_pushed = SafePushFont(ctx, gui.fonts.sans_serif_sm)
			ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0x88CC88FF)  
			ImGui.Text(ctx, "Licensed to: " .. email)
			ImGui.PopStyleColor(ctx)
			if font_pushed then SafePopFont(ctx) end
		end
	else
		ImGui.SetCursorPosY(ctx, local_y + 2)
		local badge_color, badge_hover, badge_active, badge_text
		if _license_state == "trial_new" or _license_state == "trial_old" then
			badge_color = 0x5588CCFF  
			badge_hover = 0x77AAEEFF
			badge_active = 0x446699FF
			badge_text = "Trial"
		elseif _license_state == "expired" then
			badge_color = 0xCC8844FF  
			badge_hover = 0xEEAA66FF
			badge_active = 0xAA6622FF
			badge_text = "Renew"
		else
			badge_color = 0xAA6666FF  
			badge_hover = 0xCC8888FF
			badge_active = 0x884444FF
			badge_text = "Trial"
		end
		ImGui.PushStyleColor(ctx, ImGui.Col_Button, badge_color)
		ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, badge_hover)
		ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, badge_active)
		ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xFFFFFFFF)
		local font_pushed = SafePushFont(ctx, gui.fonts.sans_serif_sm)
		if ImGui.SmallButton(ctx, badge_text) then
			gui.license_key_input = amapp.license_key
			gui.license_modal_open = true
		end
		if font_pushed then SafePopFont(ctx) end
		ImGui.PopStyleColor(ctx, 4)
		if ImGui.IsItemHovered(ctx) then
			local days = GetTrialDays()
			local tooltip = "Click to enter license key\nTrial day: " .. days
			if _license_state == "expired" then
				tooltip = "Your license has expired\nClick to renew"
			end
			ImGui.SetTooltip(ctx, tooltip)
		end
	end
	ImGui.SameLine(ctx, 0.0, 0.0)
	
	if gui.exit_btn_active_prev then
		ImGui.PushStyleColor(ctx, ImGui.Col_Button, 0x921925ff)  
		ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, 0x921925ff)
		ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, 0x921925ff)
		ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xFFFFFFFF)  
	elseif gui.exit_btn_hovered_prev then
		ImGui.PushStyleColor(ctx, ImGui.Col_Button, 0xf9f9f9ff)  
		ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, 0xf9f9f9ff)
		ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, 0xf9f9f9ff)  
		ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0x111111FF)  
	else
		ImGui.PushStyleColor(ctx, ImGui.Col_Button, 0x11191c00)
		ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, 0xf9f9f9ff)
		ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, 0xf9f9f9ff)  
		ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xa1a1a1FF)
	end
	ImGui.SetCursorPosX(ctx, w_l - 20)
	ImGui.SetCursorPosY(ctx, 4)  
	SafePushFont(ctx, gui.fonts.mono_sm)
	if ImGui.Button(ctx, "X", 0.0, 0.0) then
		gui.app_open = false
		ImGui.PopStyleColor(ctx, #gui.styles.exit_btn+1)
		SafePopFont(ctx)
		return
	end
	if ImGui.IsItemHovered(ctx) then gui.exit_btn_hovered = true end
	if ImGui.IsItemActive(ctx) then gui.exit_btn_active = true end
	ImGui.PopStyleColor(ctx, #gui.styles.exit_btn+1)
	SafePopFont(ctx)
	ImGui.Separator(ctx)
	ImGui.SetCursorPosY(ctx, local_y + 31)
	if responsive_height and ImGui.BeginTable(ctx, "", 2, 0, 0.0, 0.0, 0.0) then
		ImGui.TableNextColumn(ctx)
	end
	if async_render.active or project_data.render_pending or project_data.render_progress.render_complete then
		
		RenderProgressPanel()
		
		if responsive_height then ImGui.EndTable(ctx) end
	else

		RenderClusterListUI()


		if responsive_height then
			ImGui.TableNextColumn(ctx)
			local _, _local_y = ImGui.GetCursorPos(ctx)
			ImGui.SetCursorPosY(ctx, _local_y + 21)
		end

		ImGui.Spacing(ctx)
		ImGui.Spacing(ctx)
		ImGui.Separator(ctx)
		ImGui.Spacing(ctx)
		ImGui.Spacing(ctx)

		_, gui.toggleLoop = ImGui.Checkbox(ctx, "Toggle loop", gui.toggleLoop)
		gui.HelpTooltip("toggle_loop")
		local checkbox_is_hovered = ImGui.IsItemHovered(ctx)
		if checkbox_is_hovered and ImGui.IsMouseReleased(ctx, 0) then ToggleClusterLoop() end
		_, gui.cluster_armed = ImGui.Checkbox(ctx, "Arm Cluster", gui.cluster_armed)
		ImGui.SameLine(ctx)
		for k, s in pairs(gui.styles.tooltip_btn) do
			ImGui.PushStyleColor(ctx, s.idx, s.color)
		end
		SafePushFont(ctx, gui.fonts.mono_md_thin)
		ImGui.Button(ctx, "[?]##arm_cluster_tooltip", 0.0, 0.0)
		ImGui.PopStyleColor(ctx, #gui.styles.tooltip_btn)
		if ImGui.IsItemHovered(ctx) then
			local tooltip_text = 			"Arm Cluster is part of a prototype feature. The feature"
			tooltip_text = tooltip_text .. 	"\nwill add the items and takes you record to the selected"
			tooltip_text = tooltip_text .. 	"\nClusters. This also work with multitrack recordings."
			tooltip_text = tooltip_text .. 	"\n\nWhen Arm Cluster is activated, any files that are imported"
			tooltip_text = tooltip_text .. 	"\nfrom the Media Browser or file explorered and placed inside"
			tooltip_text = tooltip_text .. 	"\nthe Cluster boundaries will be added to the selected"
			tooltip_text = tooltip_text .. 	"\nClusters automatically."
			ImGui.SetTooltip(ctx, tooltip_text)
		end
		SafePopFont(ctx)

		if ImGui.Button(ctx, "Create New Cluster", 0.0, 0.0) then
			local groups = DetectItemGroups()
			if groups and #groups > 1 then
				gui.detected_item_groups = groups
				gui.show_variation_prompt = true
				ImGui.OpenPopup(ctx, "Multiple Groups Detected")
			else
				gui.detected_item_groups = nil
				ImGui.OpenPopup(ctx, "Create New Cluster")
			end
		end
		gui.HelpTooltip("create_cluster_btn")
		gui.GuideTrackElement("create_cluster_btn")
		
		if gui.open_single_cluster_modal then
			ImGui.OpenPopup(ctx, "Create New Cluster")
			gui.open_single_cluster_modal = false
		end
		if gui.open_multi_cluster_modal then
			ImGui.OpenPopup(ctx, "Create Multiple Clusters")
			gui.open_multi_cluster_modal = false
		end

		ImGui.Spacing(ctx)
		ImGui.Separator(ctx)
		ImGui.Spacing(ctx)
		ImGui.Spacing(ctx)

		_, gui.focus_activated = ImGui.Checkbox(ctx, "Focus", gui.focus_activated)
		gui.HelpTooltip("focus_checkbox")
		gui.GuideTrackElement("focus_checkbox")
		local checkbox_is_hovered = ImGui.IsItemHovered(ctx)
		if checkbox_is_hovered and ImGui.IsMouseReleased(ctx, 0) and not gui.focus_activated then
			UnfocusClusters()
		elseif checkbox_is_hovered and ImGui.IsMouseReleased(ctx, 0) and gui.focus_activated then
			FocusSelectedClusters()
			
			local main_wnd = reaper.GetMainHwnd()
			local track_window = reaper.JS_Window_FindChildByID(main_wnd, 0x3E8)
			if track_window then
				reaper.JS_Window_SetScrollPos(track_window, "v", 0)
			end
		end
		ImGui.SameLine(ctx, 0.0, -1.0)
		_, gui.solo_clusters_on_focus = ImGui.Checkbox(ctx, "Solo Focus", gui.solo_clusters_on_focus)
		gui.HelpTooltip("solo_focus")
		checkbox_is_hovered = ImGui.IsItemHovered(ctx)
		if checkbox_is_hovered and ImGui.IsMouseReleased(ctx, 0) and gui.focus_activated then
			UnfocusClusters()
			FocusSelectedClusters()
		elseif checkbox_is_hovered and ImGui.IsMouseReleased(ctx, 0) and gui.focus_activated then
			UnfocusClusters()
			FocusSelectedClusters()
		end
		
		 

		ImGui.Spacing(ctx)
		ImGui.Spacing(ctx)
		ImGui.Separator(ctx)
		ImGui.Spacing(ctx)
		ImGui.Spacing(ctx)

		if ImGui.Button(ctx, "Add Items", 0.0, 0.0) then
			AddItemFunc()
		end
		gui.HelpTooltip("add_items_btn")
		gui.GuideTrackElement("add_items_btn")
		if ImGui.Button(ctx, "Remove Items", 0.0, 0.0) then
			RemoveItemFunc()
		end
		gui.HelpTooltip("remove_items_btn")

		ImGui.Spacing(ctx)
		ImGui.Spacing(ctx)
		ImGui.Separator(ctx)
		ImGui.Spacing(ctx)
		ImGui.Spacing(ctx)

		if ImGui.Button(ctx, "Render Selected", 0.0, 0.0) then
			if RequireLicense("Render") then
				local clusters_to_render = {}
				for _, v in pairs(project_data.render_cluster_list) do
					if v.is_selected then
						table.insert(clusters_to_render, v)
					end
				end
				local focus_and_solo = gui.focus_activated and gui.solo_clusters_on_focus
				
				project_data.render_pending = {
					clusters = clusters_to_render,
					focus_and_solo = focus_and_solo,
					focused_clusters = clusters_to_render
				}
				project_data.render_in_progress = true
				project_data.render_anim_start_frame = GetCachedFrameCount()
			end
		end
		gui.HelpTooltip("render_selected_btn")
		gui.GuideTrackElement("render_selected_btn")

		ImGui.SameLine(ctx)

		if ImGui.Button(ctx, "Render Options", 0.0, 0.0) then
			ImGui.OpenPopup(ctx, "Render Options")
		end
		gui.HelpTooltip("render_options_btn")

		if ImGui.Button(ctx, "Render All", 0.0, 0.0) then
			if RequireLicense("Render") then
				local clusters_to_render = project_data.render_cluster_table
				local focus_and_solo = gui.focus_activated and gui.solo_clusters_on_focus
				local focused_clusters = {}
				for _, v in pairs(project_data.render_cluster_list) do
					if v.is_selected then
						table.insert(focused_clusters, v)
					end
				end
				
				project_data.render_pending = {
					clusters = clusters_to_render,
					focus_and_solo = focus_and_solo,
					focused_clusters = focused_clusters
				}
				project_data.render_in_progress = true
				project_data.render_anim_start_frame = GetCachedFrameCount()
			end
		end
		gui.HelpTooltip("render_all_btn")

		ImGui.SameLine(ctx)

		if ImGui.Button(ctx, "Open Render Folder", 0.0, 0.0) then
			OpenRenderFolder()
		end

		ImGui.Spacing(ctx)
		ImGui.Spacing(ctx)
		ImGui.Separator(ctx)
		ImGui.Spacing(ctx)
		ImGui.Spacing(ctx)

		
		ImGui.BeginDisabled(ctx, true)
		if ImGui.Button(ctx, "Implement", 0.0, 0.0) then
			if RequireLicense("Implement") then
				ImGui.OpenPopup(ctx, "Implementation Design")
			end
		end
		ImGui.EndDisabled(ctx)
		ImGui.SameLine(ctx, 0, -1.0)
		for k, s in pairs(gui.styles.tooltip_btn) do
			ImGui.PushStyleColor(ctx, s.idx, s.color)
		end
		SafePushFont(ctx, gui.fonts.mono_md_thin)
		ImGui.Button(ctx, "[?]##implementation_tooltip", 0.0, 0.0)
		ImGui.PopStyleColor(ctx, #gui.styles.tooltip_btn)
		if ImGui.IsItemHovered(ctx) then
			local tooltip_text = 			"Implementation is in public beta."
			tooltip_text = tooltip_text ..  "\nWwise is supported today."
			tooltip_text = tooltip_text ..  "\nFMOD, Unity, and Unreal are coming soon."
			tooltip_text = tooltip_text ..  "\n\n(Join our Discord to learn more"
			tooltip_text = tooltip_text ..  "\nand get setup help.)"
			ImGui.SetTooltip(ctx, tooltip_text)
		end
		SafePopFont(ctx)
		

		if responsive_height then ImGui.EndTable(ctx) end
	end 

	
	if project_data.render_pending and not async_render.active then
		local anim_frame = GetCachedFrameCount() - (project_data.render_anim_start_frame or 0)
		if anim_frame >= 10 then
			local pending = project_data.render_pending
			project_data.render_pending = nil
			if not StartAsyncRender(pending.clusters, pending.focus_and_solo, pending.focused_clusters) then
				project_data.render_in_progress = false
			end
		end
	end

	
	ImGui.Spacing(ctx)
	ImGui.Spacing(ctx)

	local local_x, local_y = ImGui.GetCursorPos(ctx)
	local _, w_y = ImGui.GetWindowSize(ctx)
	if w_y - 33 - local_y > 0 then
		local_y = w_y - 33
	end

	if not project_data.render_in_progress then local_y = local_y + 5 end
	ImGui.SetCursorPosY(ctx, local_y)
	ImGui.Indent(ctx, 3)
	ImGui.Image(ctx, gui.images.mwm_logo, 18, 18)
	ImGui.SameLine(ctx, 0.0, -1.0)
	ImGui.SetCursorPosY(ctx, local_y + 3)
	SafePushFont(ctx, gui.fonts.sans_serif_sm)
	ImGui.Text(ctx, "© Mount West Music AB, 2026")
	SafePopFont(ctx)

	
end

local function CheckIfHotkeysArePressed()
	if not gui.hotkeys_enabled then
		
		
		if ImGui.IsAnyItemActive(ctx) then return end 
		if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape, false) or
		   ImGui.IsKeyPressed(ctx, ImGui.Key_Space, false) or
		   ImGui.IsKeyPressed(ctx, ImGui.Key_Enter, false) or
		   ImGui.IsKeyPressed(ctx, ImGui.Key_Delete, false) or
		   ImGui.IsKeyPressed(ctx, ImGui.Key_UpArrow, false) or
		   ImGui.IsKeyPressed(ctx, ImGui.Key_DownArrow, false) or
		   ImGui.IsKeyPressed(ctx, ImGui.Key_LeftArrow, false) or
		   ImGui.IsKeyPressed(ctx, ImGui.Key_RightArrow, false) then
			
			ImGui.SetWindowFocusEx(ctx, "")
			reaper.SetCursorContext(1)
		end
		return
	end
	if ImGui.IsPopupOpen(ctx, "", ImGui.PopupFlags_AnyPopupId) then return end
	if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape, false) then
		ImGui.SetWindowFocusEx(ctx, "")
		reaper.SetCursorContext(1)
	end
	if ImGui.IsKeyPressed(ctx, ImGui.Key_UpArrow, true) then
		if ImGui.IsKeyDown(ctx, ImGui.Key_LeftAlt) then
			reaper.Main_OnCommand(40418, 0)
		elseif ImGui.IsKeyDown(ctx, ImGui.Key_LeftShift) then
			gui.lb_should_scroll = true
			reaper.PreventUIRefresh(1)
			SelectPreviousCluster(true)
			if gui.toggleActivate then GetItemsFunc() end
			if gui.focus_activated then FocusSelectedClusters() end
			reaper.PreventUIRefresh(-1)
		else
			gui.lb_should_scroll = true
			reaper.PreventUIRefresh(1)
			SelectPreviousCluster()
			if gui.toggleActivate then GetItemsFunc() end
			if gui.focus_activated then FocusSelectedClusters() end
			reaper.PreventUIRefresh(-1)
		end
	end
	if ImGui.IsKeyPressed(ctx, ImGui.Key_DownArrow, true) then
		if ImGui.IsKeyDown(ctx, ImGui.Key_LeftAlt) then
			reaper.Main_OnCommand(40419, 0)
		elseif ImGui.IsKeyDown(ctx, ImGui.Key_LeftShift) then
			gui.lb_should_scroll = true
			reaper.PreventUIRefresh(1)
			SelectNextCluster(true)
			if gui.toggleActivate then GetItemsFunc() end
			if gui.focus_activated then FocusSelectedClusters() end
			reaper.PreventUIRefresh(-1)
		else
			gui.lb_should_scroll = true
			reaper.PreventUIRefresh(1)
			SelectNextCluster()
			if gui.toggleActivate then GetItemsFunc() end
			if gui.focus_activated then FocusSelectedClusters() end
			reaper.PreventUIRefresh(-1)
		end
	end
	if ImGui.IsKeyPressed(ctx, ImGui.Key_LeftArrow, true) then
		if ImGui.IsKeyDown(ctx, ImGui.Key_LeftAlt) and ImGui.IsKeyDown(ctx, ImGui.Key_LeftShift) then
			local cmd_id = reaper.NamedCommandLookup("_SWS_SELPREVITEM2")
			reaper.Main_OnCommand(cmd_id, 0)
		else
			SelectLastSelectedCluster()
		end
	end
	if ImGui.IsKeyPressed(ctx, ImGui.Key_RightArrow, true) then
		if ImGui.IsKeyDown(ctx, ImGui.Key_LeftAlt) and ImGui.IsKeyDown(ctx, ImGui.Key_LeftShift) then
			local cmd_id = reaper.NamedCommandLookup("_SWS_SELNEXTITEM2")
			reaper.Main_OnCommand(cmd_id, 0)
		else
			SelectLastSelectedCluster()
		end
	end
	if ImGui.IsKeyPressed(ctx, ImGui.Key_Enter, false) then
		if ImGui.IsKeyDown(ctx, ImGui.Key_LeftShift) then
			AddItemFunc()
		else
			
			local has_non_group_selected = false
			for key, cluster in pairs(project_data.render_cluster_list) do
				if cluster.is_selected then
					local is_group = type(cluster.children) == "table" and #cluster.children > 0
					if not is_group then
						has_non_group_selected = true
						break
					end
				end
			end
			
			if has_non_group_selected then
				if gui.toggleActivate then
					GetItemsFunc()
				end
				MoveEditCursorToCluster()
				for key, cluster in pairs(project_data.render_cluster_list) do
					if cluster.is_selected and cluster.cluster_guid ~= nil then
						local is_group = type(cluster.children) == "table" and #cluster.children > 0
						if not is_group then
							VerticalScrollToFirstItem(cluster)
							break
						end
					end
				end
			end
		end
	end
	if ImGui.IsKeyPressed(ctx, ImGui.Key_Delete, false) then
		RemoveItemFunc()
	end
	if ImGui.IsKeyPressed(ctx, ImGui.Key_Space, false) then
		if ImGui.IsKeyDown(ctx, ImGui.Key_LeftShift) then
			reaper.Main_OnCommand(1013, 0) 
		else
			reaper.Main_OnCommand(40044, 0) 
		end
	end
	if ImGui.IsKeyPressed(ctx, ImGui.Key_PageUp, true) then
		if ImGui.IsKeyDown(ctx, ImGui.Key_LeftAlt) then
			reaper.Main_OnCommand(42350, 0)
		end
	end
	if ImGui.IsKeyPressed(ctx, ImGui.Key_PageDown, true) then
		if ImGui.IsKeyDown(ctx, ImGui.Key_LeftAlt) then
			reaper.Main_OnCommand(42349, 0)
		end
	end
	if ImGui.IsKeyPressed(ctx, ImGui.Key_A, false) then
		if CheckIfCtrlIsPressed() and CheckIfShiftIsPressed then
			ActivateAllClusters()
		elseif CheckIfCtrlIsPressed() then
			gui.toggleActivate = not gui.toggleActivate
		else
			GetItemsFunc()
		end
	end
	if ImGui.IsKeyPressed(ctx, ImGui.Key_D, false) then
		if CheckIfCtrlIsPressed() then
			gui.toggleDeactivate = not gui.toggleDeactivate
		else
			DeactivateSelectedClusters()
		end
	end
	if ImGui.IsKeyPressed(ctx, ImGui.Key_U, false) then
		gui.update_clusters_is_toggled = not gui.update_clusters_is_toggled
	end
	if ImGui.IsKeyPressed(ctx, ImGui.Key_K, false) then
		
	end
	if ImGui.IsKeyPressed(ctx, ImGui.Key_R, false) then
		if ImGui.IsKeyDown(ctx, ImGui.Key_LeftShift) then
			gui.toggleLoop = not gui.toggleLoop
			ToggleClusterLoop()
		else
			reaper.Main_OnCommand(1068, 0)
		end
	end
	
	if ImGui.IsKeyPressed(ctx, ImGui.Key_L, false) then
		gui.toggleLoop = not gui.toggleLoop
		ToggleClusterLoop()
	end
	if ImGui.IsKeyPressed(ctx, ImGui.Key_F, false) then
		gui.focus_activated = not gui.focus_activated
		if gui.focus_activated then
			FocusSelectedClusters()
			
			local main_wnd = reaper.GetMainHwnd()
			local track_window = reaper.JS_Window_FindChildByID(main_wnd, 0x3E8)
			if track_window then
				reaper.JS_Window_SetScrollPos(track_window, "v", 0)
			end
		else
			UnfocusClusters()
		end
	end
	if ImGui.IsKeyPressed(ctx, ImGui.Key_Q, false) then
		for k, v in pairs(project_data.render_cluster_list) do
			v.is_selected = false
		end
		if gui.focus_activated then
			reaper.PreventUIRefresh(1)
			UnfocusClusters()
			reaper.GetSet_ArrangeView2(0, true,  0, 0, 0, reaper.GetProjectLength(0)+4)
			reaper.PreventUIRefresh(-1)
		end
	end
	if ImGui.IsKeyPressed(ctx, ImGui.Key_M, false) then
		DeactivateSelectedClusters()
	end
end


local action_handlers = {
	render_selected = function()
		local clusters_to_render = {}
		for _, v in pairs(project_data.render_cluster_list) do
			if v.is_selected then table.insert(clusters_to_render, v) end
		end
		if #clusters_to_render > 0 then
			project_data.render_pending = {
				clusters = clusters_to_render,
				focus_and_solo = gui.focus_activated and gui.solo_clusters_on_focus,
				focused_clusters = clusters_to_render
			}
			project_data.render_in_progress = true
			project_data.render_anim_start_frame = GetCachedFrameCount()
		end
	end,

	render_all = function()
		local focused_clusters = {}
		for _, v in pairs(project_data.render_cluster_list) do
			if v.is_selected then table.insert(focused_clusters, v) end
		end
		project_data.render_pending = {
			clusters = project_data.render_cluster_table,
			focus_and_solo = gui.focus_activated and gui.solo_clusters_on_focus,
			focused_clusters = focused_clusters
		}
		project_data.render_in_progress = true
		project_data.render_anim_start_frame = GetCachedFrameCount()
	end,

	focus_toggle = function()
		if gui.focus_activated then UnfocusClusters() else FocusSelectedClusters() end
	end,

	toggle_overlay = function()
		gui.timeline_gui_visible = not gui.timeline_gui_visible
	end,

	add_item = function() AddItemFunc() end,
	remove_item = function() RemoveItemFunc() end,
	select_items = function() SelectItemsInSelectedClusters() end,

	create_cluster = function()
		local groups = DetectItemGroups()
		if groups and #groups > 1 then
			detected_item_groups = groups
			show_variation_prompt = true
		else
			open_single_cluster_modal = true
		end
	end,

	edit_cluster = function() gui.timeline_gui_edit_clicked = true end,
	group_clusters = function() gui.open_create_group = true end,
	toggle_arm = function() gui.cluster_armed = not gui.cluster_armed end,
}


local function ProcessActionRequests()
	local request = reaper.GetExtState("AMAPP", "action_request")
	if not request or request == "" then return end
	reaper.DeleteExtState("AMAPP", "action_request", false)
	local handler = action_handlers[request]
	if handler then handler() end
end

local function exit()
	if gui.focus_activated then UnfocusClusters() end
	Remove_FX_monitor_mute()
	return
end

local function Main()
	if gui.clear_debug_each_frame then Msg() end

	
	if gui.needs_context_recreation then
		ctx = CreateImGuiContext()
		window_size_initialized = false  
		
		reaper.defer(Main)
		return
	end

	
	CheckUndoRedoChanges()

	
	ProcessActionRequests()

	
	
	SetFrameCount(ImGui.GetFrameCount(ctx))

	WindowStyling()
	
	
	
	
	
	
	
	
	

	
	local mouse_x, mouse_y = ImGui.GetMousePos(ctx)
	local trigger_zone = 8  
	local in_trigger_zone = mouse_x >= gui.main_window_pos.x and
	                        mouse_x <= gui.main_window_pos.x + gui.main_window_size.w and
	                        mouse_y >= gui.main_window_pos.y and
	                        mouse_y <= gui.main_window_pos.y + trigger_zone
	local in_menu_area = mouse_x >= gui.main_window_pos.x and
	                     mouse_x <= gui.main_window_pos.x + gui.main_window_size.w and
	                     mouse_y >= gui.main_window_pos.y and
	                     mouse_y <= gui.main_window_pos.y + gui.menu_bar_height
	local outside_window = mouse_x < gui.main_window_pos.x or
	                       mouse_x > gui.main_window_pos.x + gui.main_window_size.w or
	                       mouse_y < gui.main_window_pos.y or
	                       mouse_y > gui.main_window_pos.y + gui.main_window_size.h

	
	
	local any_popup_open = ImGui.IsPopupOpen(ctx, "", ImGui.PopupFlags_AnyPopupId + ImGui.PopupFlags_AnyPopupLevel)
	if in_trigger_zone then
		gui.menu_bar_auto_visible = true
	elseif gui.menu_bar_auto_visible and not any_popup_open and (not in_menu_area or outside_window) then
		gui.menu_bar_auto_visible = false
	end

	
	if gui.menu_bar_auto_visible then
		gui.win_flags = ImGui.WindowFlags_MenuBar|ImGui.WindowFlags_NoCollapse
	else
		gui.win_flags = ImGui.WindowFlags_None|ImGui.WindowFlags_NoCollapse
	end


	
	local mouse_x, mouse_y = ImGui.GetMousePos(ctx)
	local trigger_zone = 8  
	local in_trigger_zone = mouse_x >= gui.main_window_pos.x and
	                        mouse_x <= gui.main_window_pos.x + gui.main_window_size.w and
	                        mouse_y >= gui.main_window_pos.y and
	                        mouse_y <= gui.main_window_pos.y + trigger_zone
	local in_menu_area = mouse_x >= gui.main_window_pos.x and
	                     mouse_x <= gui.main_window_pos.x + gui.main_window_size.w and
	                     mouse_y >= gui.main_window_pos.y and
	                     mouse_y <= gui.main_window_pos.y + gui.menu_bar_height
	local outside_window = mouse_x < gui.main_window_pos.x or
	                       mouse_x > gui.main_window_pos.x + gui.main_window_size.w or
	                       mouse_y < gui.main_window_pos.y or
	                       mouse_y > gui.main_window_pos.y + gui.main_window_size.h

	
	
	local any_popup_open = ImGui.IsPopupOpen(ctx, "", ImGui.PopupFlags_AnyPopupId + ImGui.PopupFlags_AnyPopupLevel)
	if in_trigger_zone then
		gui.menu_bar_auto_visible = true
	elseif gui.menu_bar_auto_visible and not any_popup_open and (not in_menu_area or outside_window) then
		gui.menu_bar_auto_visible = false
	end

	
	if gui.menu_bar_auto_visible then
		gui.win_flags = ImGui.WindowFlags_MenuBar|ImGui.WindowFlags_NoCollapse
	else
		gui.win_flags = ImGui.WindowFlags_None|ImGui.WindowFlags_NoCollapse
	end

	
	if not gui.first_dock_done then
		gui.first_dock_done = true
		if reaper.GetExtState("AMAPP", "has_docked") == "" then
			reaper.SetExtState("AMAPP", "has_docked", "true", true)
			ImGui.SetNextWindowDockID(ctx, -3) 
		end
	end

	ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowTitleAlign, 0.5, 0.5)
	SafePushFont(ctx, gui.fonts.sans_serif_sm)
	local visible = false
    visible, gui.app_open = ImGui.Begin(ctx, "AMAPP Cluster Manager", true, gui.win_flags)
	SafePopFont(ctx)
	ImGui.PopStyleVar(ctx, 1)

	
	if visible then
		gui.main_window_pos.x, gui.main_window_pos.y = ImGui.GetWindowPos(ctx)
		gui.main_window_size.w, gui.main_window_size.h = ImGui.GetWindowSize(ctx)
	end

	
	if visible then
		gui.main_window_pos.x, gui.main_window_pos.y = ImGui.GetWindowPos(ctx)
		gui.main_window_size.w, gui.main_window_size.h = ImGui.GetWindowSize(ctx)
	end

	
	if visible and not gui.license_sheen_startup_checked then
		gui.license_sheen_startup_checked = true
		local state = GetLicenseState()
		if state == "valid" then
			gui.TriggerLicenseSheen()
		end
	end

	if not amapp.license_accepted then
		ImGui.OpenPopup(ctx, "License Agreement")
		gui.app_open = Modal_StartupLicenseMessage()
	end
	
	if amapp.license_accepted and not amapp.welcome_shown and not gui.show_welcome_modal then
		ResetPricingCardState("welcome")
		gui.show_welcome_modal = true
	end
	if gui.show_welcome_modal then
		ImGui.OpenPopup(ctx, "Welcome to AMAPP!")
	end
	Modal_Welcome()
	
	if gui.license_modal_open then
		ImGui.OpenPopup(ctx, "Enter License Key")
	end
	Modal_LicenseEntry()
	
	if amapp.license_accepted and amapp.welcome_shown and ShouldShowTrialReminder() and not gui.show_trial_reminder then
		ResetPricingCardState("trial")
		gui.show_trial_reminder = true
	end
	if gui.show_trial_reminder then
		ImGui.OpenPopup(ctx, "Support AMAPP Development")
	end
	Modal_TrialReminder()
	Modal_LicenseRequired()
	ImGui.SetConfigVar(ctx, ImGui.ConfigVar_WindowsMoveFromTitleBarOnly, 1)
	if not ImGui.IsWindowFocused(ctx, ImGui.FocusedFlags_AnyWindow) then
		if ImGui.IsKeyPressed(ctx, ImGui.Key_F12, true) then
			ImGui.SetWindowFocusEx(ctx, "AMAPP Cluster Manager")
		end
	end
	if visible then
		local frame_count = GetCachedFrameCount()
		if project_data.render_in_progress == false and math.fmod(frame_count, 60) == 0 and not cluster_buffered then
			UpdateRenderClusterTable()
		end
		
		gui.exit_btn_hovered_prev = gui.exit_btn_hovered
		gui.exit_btn_hovered = false
		gui.exit_btn_active_prev = gui.exit_btn_active
		gui.exit_btn_active = false
		if gui.menu_bar_auto_visible then
			ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding, 4, 6)  
		end
		if gui.menu_bar_auto_visible and ImGui.BeginMenuBar(ctx) then
			local cur_x, cur_y = ImGui.GetCursorPos(ctx)
			ImGui.SetCursorPosX(ctx, cur_x + 3)
			SafePushFont(ctx, gui.fonts.sans_serif_sm)
			if ImGui.BeginMenu(ctx, 'File') then
				MenuFile()
				ImGui.EndMenu(ctx)
			end
			if ImGui.BeginMenu(ctx, 'View') then
				MenuView()
				ImGui.EndMenu(ctx)
			end
			if ImGui.BeginMenu(ctx, 'Options') then
				gui.MenuOptions()
				ImGui.EndMenu(ctx)
			end
						SafePopFont(ctx)
			
			ImGui.PopStyleVar(ctx)  
			local win_w = ImGui.GetWindowWidth(ctx)
			ImGui.SetCursorPosX(ctx, win_w - 20)
			ImGui.SetCursorPosY(ctx, ImGui.GetCursorPosY(ctx) + 4)  
			
			if gui.exit_btn_active_prev then
				ImGui.PushStyleColor(ctx, ImGui.Col_Button, 0x921925ff)  
				ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, 0x921925ff)
				ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, 0x921925ff)
				ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xFFFFFFFF)  
			elseif gui.exit_btn_hovered_prev then
				ImGui.PushStyleColor(ctx, ImGui.Col_Button, 0xf9f9f9ff)  
				ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, 0xf9f9f9ff)
				ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, 0xf9f9f9ff)  
				ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0x111111FF)  
			else
				ImGui.PushStyleColor(ctx, ImGui.Col_Button, 0x11191c00)
				ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, 0xf9f9f9ff)
				ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, 0xf9f9f9ff)  
				ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xa1a1a1FF)
			end
			SafePushFont(ctx, gui.fonts.mono_sm)
			if ImGui.Button(ctx, "X##menubar", 0.0, 0.0) then
				gui.app_open = false
			end
			if ImGui.IsItemHovered(ctx) then gui.exit_btn_hovered = true end
			if ImGui.IsItemActive(ctx) then gui.exit_btn_active = true end
			SafePopFont(ctx)
			ImGui.PopStyleColor(ctx, #gui.styles.exit_btn + 1)
			ImGui.EndMenuBar(ctx)
		elseif gui.menu_bar_auto_visible then
			
			ImGui.PopStyleVar(ctx)
		end
		
		if gui.open_export_options then
			ImGui.OpenPopup(ctx, "Render Options")
			gui.open_export_options = false
		end
		Modal_ClusterExportOptions()
		
		gui.DrawClusterModalOverlay()
		
		if gui.timeline_gui_edit_clicked then
			ImGui.OpenPopup(ctx, "Edit Cluster")
			gui.timeline_gui_edit_clicked = false
		end
		Modal_EditCluster()
		if gui.delete_cluster_clicked then
			ImGui.OpenPopup(ctx, "Delete Cluster")
			gui.delete_cluster_clicked = false
		end
		Modal_DeleteCluster()
		if gui.open_create_group then
			ImGui.OpenPopup(ctx, "Create Group")
			gui.open_create_group = false
		end
		Modal_CreateGroup()
		Modal_VariationPrompt()
		Modal_CreateNewCluster()
		Modal_CreateMultipleClusters()
		Modal_Implementation()
				Timeline_GUI()
		MainWindow()
		
		Modal_Audition()
		
		gui.DrawLicenseSheen()
		
		gui.DrawGuideTooltip()
	end
	if visible then ImGui.End(ctx) end
	if ProjectChanged() then
     	UpdateRenderClusterTable()
		if NewItems() and gui.cluster_armed and not gui.cluster_recording then
			ImportItemsIntoClusters()
		end
		if ChangedItems() and gui.cluster_armed then end
	end
	if project_data.project_name ~= reaper.GetProjectName(0) or project_data.project_path ~= reaper.GetProjectPath() then
	
		
		
		if ProjectVersionCheck() == false then
			reaper.ReaScriptError("This project requires a newer version of AMAPP. Update via Extensions > ReaPack > Synchronize Packages.")
		end
		Startup_sequence()
		UpdateRenderClusterTable()
		project_data.project_name = reaper.GetProjectName(0)
		project_data.project_path = reaper.GetProjectPath()
	end
	if gui.cluster_armed and (reaper.GetPlayState() & 4) ~= 0 then
		ClusterRecording_INIT()
	elseif gui.cluster_armed and gui.cluster_recording and (reaper.GetPlayState() & 4) == 0 then
		ClusterRecording_DONE()
	elseif gui.cluster_armed  and (reaper.GetPlayState() & 4) == 0 then
		gui.items_before_rec = reaper.CountMediaItems()
	end
	
	
	
	
	if(GetFontStackDepth() ~= 0) then
		for i = GetFontStackDepth(), 1, -1 do
			SafePopFont(ctx)
		end
	end
	ImGui.PopStyleColor(ctx, #color_styling_table)
	ImGui.PopStyleVar(ctx, 5) 
    if gui.app_open and not gui.quit then
		if ImGui.IsWindowFocused(ctx, ImGui.FocusedFlags_AnyWindow) then
			CheckIfHotkeysArePressed()
		end
     	reaper.defer(Main)
    else
		exit()
	end
end

function PrintTraceback(err)
    local byLine = "([^\r\n]*)\r?\n?"
    local trimPath = "[\\/]([^\\/]-:%d+:.+)$"
    local stack = {}
    for line in string.gmatch(err, byLine) do
        local str = string.match(line, trimPath) or line
        stack[#stack + 1] = str
    end

	
	local error_msg = stack[1] or "Unknown error"
	local stack_trace = table.concat(stack, "\n", 3)

	
	reaper.ReaScriptError(
		"  !\n\n" .. "===== AMAPP Crash Report =====" .. "\n\n" ..
		"  Error: " .. error_msg .. "\n\n" ..
		"  Stack traceback:\n\t" .. stack_trace:gsub("\n", "\n\t") .. "\n\n" ..
		"  Platform:     \t" .. reaper.GetOS() .. "\n" ..
		"  REAPER:       \t" .. reaper.GetAppVersion() .. "\n" ..
		"  AMAPP:        \t" .. "v" .. VERSION .. "\n"
	)

	
	if ErrorHandling then
		ErrorHandling.show_error_dialog(error_msg, stack_trace, {
			operation = "AMAPP Crash",
			amapp_version = VERSION,
		})
	end
end

function Release()
	exit()
end


do
	local real_defer = reaper.defer

	
	local function IsGpuContextError(err)
		if not err then return false end
		
		if string.find(err, "TexID") or string.find(err, "TextureId") then
			return true
		end
		
		if string.find(err, "DrawList") and string.find(err, "assertion") then
			return true
		end
		
		if string.find(err, "Font") and string.find(err, "assertion") then
			return true
		end
		return false
	end

	function PDefer(func)
		real_defer(function()
			local status, err = xpcall(func, debug.traceback)
			if not status then
				
				if IsGpuContextError(err) then
					
					gui.needs_context_recreation = true
					
					reaper.defer(func)
					return
				end
				Release()
				PrintTraceback(err)
			end
		end)
	end
	reaper.defer = PDefer
end

 -- ========== Profiler ===========
Startup_sequence()
reaper.atexit(Release)
reaper.defer(Main)