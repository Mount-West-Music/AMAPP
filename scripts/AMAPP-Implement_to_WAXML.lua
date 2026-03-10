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

local luatoxml = dofile(mwm_lib_path .. "util/luatoxml/src/luatoxml.lua")
dofile(mwm_lib_path .. "util/MWM-Table_serializer.lua")
loadfile(mwm_lib_path .. "scripts/AMAPP-Get_selected_region_name.lua")()
loadfile(mwm_lib_path .. "scripts/AMAPP-Render_clusters.lua")()

local function ValidateProjectHasBeenSaved()
	local proj_dir = select(2,reaper.EnumProjects(-1, '')):match("^(.+[\\/])")
	return proj_dir ~= nil
end


local function File_path_is_absolute(path)
    if package.config:sub(1, 1) == "\\" then
        
        return path:match("^%a:[\\/]")
            or path:match("^\\\\")
    else
        
        return path:sub(1, 1) == "/"
    end
end


local function wildcards_str(user_template_string, cluster_id)
	local table_of_wildcards = {
		{str = "$projectdir", ret_val = function()
			local project_path = select(2,reaper.EnumProjects(-1, '')):match("^(.+[\\/])")
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

local function Project_tempo_and_meter()
    local bpm, bpi_u = reaper.GetProjectTimeSignature2(0)
    local bpi_l = 4 / (reaper.Master_GetTempo()/bpm)
    local bpm_p = bpm * (bpi_u/bpi_l)
    return bpm, bpm_p, bpi_u, bpi_l
end

local function Previous_meter_marker(idx)
    if idx < 0 then
        local upper = reaper.SNM_GetIntConfigVar("projmeaslen", -1)
        local lower = reaper.SNM_GetIntConfigVar("projtsdenom", -1)
        return upper, lower
    end
    local _, _, _, _, _, upper, lower = reaper.GetTempoTimeSigMarker(0, idx)
    if upper == -1 or lower == -1 then
        upper, lower = Previous_meter_marker(idx - 1)
    end
    return upper, lower
end

local  function ClusterSet_Span(cluster_table, guid)
    local _start, _end
    for _, c_obj in pairs(cluster_table) do
        if guid ~=  c_obj.cluster_guid then goto next end
        if _start == nil or c_obj.c_start < _start then
            _start = c_obj.c_start
        end
        if _end == nil or c_obj.c_end > _end then
            _end = c_obj.c_end
        end
        ::next::
    end
    return _start, _end
end

local function Previous_tempo_marker(idx)
    if idx < 0 then
        local tempo = Project_tempo_and_meter()
        return tempo
    end
    local _, _, _, _, tempo = reaper.GetTempoTimeSigMarker(0, idx)
    if tempo == -1 then
        tempo = Previous_tempo_marker(idx - 1)
    end
    return tempo
end

local function Export_requirements()
    if reaper.CountTempoTimeSigMarkers(0) == 0 then
        local bpm, bpm_p, bpi_u, bpi_l = Project_tempo_and_meter()
        if (bpi_l % 2) ~= 0 and bpi_l ~= 1 then return false, "Wwise only supports time signatures that have denominators in multiples of 2." end
    else
        local idx = reaper.CountTempoTimeSigMarkers(0) - 1
        local bpi_u, bpi_l = Previous_meter_marker(idx)
        if (bpi_l % 2) ~= 0 and bpi_l ~= 1 then return false, "Wwise only supports time signatures that have denominators in multiples of 2." end
    end
    return true
end

local function Project_render_path()
	local return_val, export_options_string = reaper.GetProjExtState(0, "AMAPP", "EXPORT_OPTIONS")
	if return_val == 0 then
		return reaper.MB("No export options have been set. Please set export options inside AMAPP.", "Error!", 0)
	end
	local export_options = table.deserialize(export_options_string)
	if export_options == nil then
		return reaper.MB("No export options have been set. Please set export options inside AMAPP.", "Error!", 0)
	end
    local project_render_folder_path = ""
	if File_path_is_absolute(export_options.file_path) then
		project_render_folder_path = export_options.file_path:match("^(.+[\\/])")
	else
		local proj_dir = select(2,reaper.EnumProjects(-1)):match("^(.+[\\/])")
		project_render_folder_path = proj_dir .. export_options.file_path .. string.char(92)
	end
    project_render_folder_path = string.gsub(project_render_folder_path, string.char(92), string.char(47))
    return project_render_folder_path
end

local function _render_clusters_(unrendered_clusters)
	local _, export_table_string = reaper.GetProjExtState(0, "AMAPP", "EXPORT_OPTIONS")
	local export_table = table.deserialize(export_table_string)
	local export_file_name = ""
	if export_table ~= nil then
		export_file_name = export_table[1].export_file_name
	end
	reaper.PreventUIRefresh(1)
	local total_tracks = reaper.CountTracks(0)
	local hidden_tcp_list = {}
	local collapsed_tcp_list = {}
	local soloed_track_list = {}
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
		if reaper.GetMediaTrackInfo_Value(track, "I_SOLO") > 0 then
			local solo_state = reaper.GetMediaTrackInfo_Value(track, "I_SOLO")
			table.insert(soloed_track_list, {track = track, solo_state = solo_state})
			reaper.SetMediaTrackInfo_Value(track, "I_SOLO", 0)
		end
	end
	RenderClusters(unrendered_clusters, export_file_name)
	for key, track in pairs(hidden_tcp_list) do
		reaper.SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
	end
	for key, t in pairs(collapsed_tcp_list) do
		reaper.SetMediaTrackInfo_Value(t.track, "I_FOLDERCOMPACT", t.collapsed_state)
	end
	for key, t in pairs(soloed_track_list) do
		reaper.SetMediaTrackInfo_Value(t.track, "I_SOLO", t.solo_state)
	end
	reaper.PreventUIRefresh(-1)
end

local function File_name_template()
    local _, export_table_string = reaper.GetProjExtState(0, "AMAPP", "EXPORT_OPTIONS")
	local export_table = table.deserialize(export_table_string)
	local export_file_name = "$cluster"
	if export_table ~= nil then
		export_file_name = export_table[1].export_file_name
	end
    return export_file_name
end

local function File_exists(path)
    local f=io.open(path,"r")
    if f~=nil then io.close(f) return true else return false end
end

local function Clusters(cluster_table)
    local clusters = {}
    local unrendered_clusters = {}
    for key, c in pairs(cluster_table) do
        local modified_filename = wildcards_str(File_name_template(), c.cluster_id)
        local file_path = Project_render_path() .. modified_filename .. ".wav"
        if File_exists(file_path) == false then
            table.insert(unrendered_clusters, c)
        end
        local file_length_ms = (c.c_end - c.c_start) * 1000
        local entry, exit = nil, nil
        if c.c_entry ~= nil then entry = (c.c_entry - c.c_start) * 1000 end
        if c.c_exit ~= nil then exit = (c.c_exit - c.c_start) * 1000 end
        local cluster = {
            guid = c.cluster_guid,
            name = c.cluster_id,
            file_path = file_path,
            loop = tostring(c.is_loop),
            loop_style = 0,
            file_length = file_length_ms,
            c_start = c.c_start*1000,
            c_end = c.c_end*1000,
            c_qn_start = c.c_qn_start,
            c_qn_end = c.c_qn_end,
            c_qn_entry = c.c_qn_entry,
            c_qn_exit = c.c_qn_exit,
            entry = entry,
            exit = exit,
        }
        table.insert(clusters, cluster)
    end
    if clusters == {} then
        return nil
    else
        return clusters, unrendered_clusters
    end
end

local function Sets(cluster_table)
	local _, set_table_string = reaper.GetProjExtState(0, "AMAPP", "SET_TABLE")
	local set_table = table.deserialize(set_table_string)
	if set_table == nil then set_table = {} end
    local sets = {}
    local connected_clusters = {}
    for key, s in pairs(set_table) do
        if not s.connected_clusters then goto skip end
        local set = {
            guid = s.set_guid,
            name = s.set_id,
            clusters = s.connected_clusters,
            loop = "true"
        }
        local set_start
        local set_end
        local tempo_sig_markers = reaper.CountTempoTimeSigMarkers(0)
        for _, c in pairs(s.connected_clusters) do
            connected_clusters[c] = "true"
            if tempo_sig_markers > 0 then
                set_start, set_end = ClusterSet_Span(cluster_table, c)
            end
        end

        if tempo_sig_markers > 0 then
            for i = tempo_sig_markers, 0, -1 do
                local ret, timepos, measurepos, beatpos, bpm, timesig_num, timesig_denom, lineartempo = reaper.GetTempoTimeSigMarker(0, i-1)
                if timesig_num == -1 then timesig_num = 4 end
                if timepos < set_end then
                    set.tempo = bpm
                    set.time_signature_upper = timesig_num
                    set.time_signature_lower = timesig_denom
                    break
                elseif ret and timepos <= set_start then
                    set.tempo = bpm
                    set.time_signature_upper = timesig_num
                    set.time_signature_lower = timesig_denom
                    break
                end
            end
        end

        table.insert(sets, set)
        ::skip::
    end

    local pruned_cluster_table = {}
    for key, c in pairs(cluster_table) do
        if connected_clusters[c.cluster_guid] == nil then
            table.insert(pruned_cluster_table, c.cluster_guid)
        end
    end

    local set = {
        guid = reaper.genGuid(),
        name = "General",
        clusters = pruned_cluster_table,
        loop = "false",
        generics = "true"
    }

    table.insert(sets, set)
    return sets
end

local function Project()
    local ret_bpi_u, bpi_u = reaper.get_config_var_string("projmeaslen")
    local ret_bpi_l, bpi_l = reaper.get_config_var_string("projtsdenom")
    if not ret_bpi_u or not ret_bpi_l then
        local u, l = Previous_meter_marker(idx)
        bpi_u = tostring(u)
        bpi_l = tostring(l)
    end
    local ret_bpm, bpm = reaper.get_config_var_string("projbpm")
    if not ret_bpm then
        local idx = reaper.CountTempoTimeSigMarkers(0) - 1
        local _b = Previous_tempo_marker(idx)
        bpm = tostring(bpm)
    end
    local project_info = {
        name = wildcards_str("$projectdir"),
        path = Project_render_path(),
        tempo = bpm,
        time_signature_upper = bpi_u,
        time_signature_lower = bpi_l,
    }
    return project_info
end

local function stringify_timeSig(upper, lower)
    if upper == nil or lower == nil then return nil end
    return tostring(upper) .. "/" .. tostring(lower)
end

local max_channels = 0
local function Audio_XML()
    local xlmns_xsi = "xmlns:xsi"
    local xsi_schemaLocation = "xsi:schemaLocation"
    local luaobj = {
        Audio = {
            xmlns = "https://www.w3schools.com",
            xlmns_xsi = "http://www.w3.org/2001/XMLSchema-instance",
            xsi_schemaLocation = "https://www.w3schools.com https://momdev.se/lindetorp/waxml/scheme_1.10.xsd",

            version="1.0" ,
            timeUnit="ms" ,
            gain="0dB",
            controls="true",
            {
                var = {
                    name = "mix_intensity",
                    default = "0",
                    mapin = "0,1",
                },
            },
            {
                var = {
                    name = "mix_blend",
                    default = "0",
                },
            },
            {
                var = {
                    name = "mix_transition_time",
                    default = "1000",
                },
            },

            Mixer = {
                id = "intensity-mixer",
                controls = "waxml-dynamic-mixer",
                mix = "$mix_intensity",
                selectindex = "$intensity_index",
                crossFadeRange = "$mix_blend",
                transitionTime = "$mix_transition_time",
            },

            {
                Snapshot = {
                    class = "LP",
                    {
                        Command = {
                            type = "set",
                            variable = "v"
                        }
                    }
                }
            }
        }
    }

    for i = 1, max_channels - 1 do
        table.insert(luaobj.Audio.Mixer, {
            GainNode = {
                id = "mix" .. i
            }
        })
    end

    local retval = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" .. luatoxml.toxml(luaobj)
    retval = retval:gsub("xlmns_xsi", xlmns_xsi)
    retval = retval:gsub("xsi_schemaLocation", xsi_schemaLocation)

    local system_path = Project_render_path():gsub("[/\\]$", ""):match("^(.*)[/\\][^/\\]+$") .. string.char(47) .. "audio.xml"
    os.remove(system_path)
    local system_file = assert(io.open(system_path, "w"))
    system_file:write(retval)
    system_file:close()
end

local function GetPreRoll(cluster, TSlower)
    if TSlower == nil then TSlower = 4 end
    if cluster.c_qn_entry == nil or cluster.c_qn_entry == cluster.c_qn_start then return nil end
    local preroll = cluster.c_qn_entry - cluster.c_qn_start
    if preroll == nil then return nil end
    return tostring(preroll) .. "/" .. tostring(TSlower)
end

local function GetLoopLength(cluster, TSlower)
    local loop_length = 0
    local cluster_entry = cluster.c_qn_entry
    if cluster_entry == nil then cluster_entry = cluster.c_qn_start end
    if cluster.c_qn_exit ~= nil then
        loop_length = cluster.c_qn_exit - cluster_entry
    else
        loop_length = cluster.c_qn_end - cluster_entry
    end
    return tostring(loop_length) .. "/" .. tostring(TSlower)
end

local function Include_tracks(set, schema_table)
    local clusters = schema_table.clusters
    local arrangement_table = {
        class = set.name,
    }
    local ch = 0
    local random_group = {}
    for k, c_guid in pairs(set.clusters) do
        for i, cluster in pairs(clusters) do
            if cluster.guid == c_guid then
                local item = {}
                ch = ch + 1
                if cluster.group_type == nil then
                    if cluster.loop == "true" then
                        table.insert(random_group, cluster)
                    else
                        item = {
                            motif = {
                                class = cluster.name,
                                quantize="1",
                                src = "audio/" .. cluster.file_path:match("^.+/(.+)$"),
                                tempo = set.tempo,
                                output = "#mix1",
                                timeSign = stringify_timeSig(set.time_signature_upper, set.time_signature_lower),
                                fadeTime = nil,
                                upbeat = GetPreRoll(cluster, set.time_signature_lower),
                            }
                        }
                    end
                else
                    if cluster.loop == "true" then
                        item = {
                            track = {
                                src = "audio/" .. cluster.file_path:match("^.+/(.+)$"),
                                tempo = set.tempo,
                                output = "#mix" .. tostring(ch),
                                timeSign = stringify_timeSig(set.time_signature_upper, set.time_signature_lower),
                                fadeTime = nil,
                                upbeat = GetPreRoll(cluster, set.time_signature_lower),
                                loopLength = GetLoopLength(cluster, set.time_signature_lower or schema_table.project.time_signature_lower),
                            }
                        }
                    else
                        item = {
                            motif = {
                                class = cluster.name,
                                quantize="1",
                                src = "audio/" .. cluster.file_path:match("^.+/(.+)$"),
                                tempo = set.tempo,
                                output = "#mix1",
                                timeSign = stringify_timeSig(set.time_signature_upper, set.time_signature_lower),
                                fadeTime = nil,
                                upbeat = GetPreRoll(cluster, set.time_signature_lower),
                            }
                        }
                    end
                end
                table.insert(arrangement_table, item)
                break
            end
        end
    end
    local item = {
        track = {
            output = "#mix1",
            fadeTime = nil,
            region = {},
        }
    }
    for key, cluster in pairs(random_group) do
        table.insert(item.track.region, {
            option = {
                upbeat = GetPreRoll(cluster, set.time_signature_lower),
                src = "audio/" .. cluster.file_path:match("^.+/(.+)$"),
            }
        })
        item.track.loopLength = GetLoopLength(cluster, set.time_signature_lower or schema_table.project.time_signature_lower)
    end

    table.insert(arrangement_table, item)
    if ch > max_channels then max_channels = ch end
    return arrangement_table
end

local function Include_oneshots(set, schema_table)
    local clusters = schema_table.clusters
    local arrangement_table = {
        arrangement = {
            class = "motifs",
        }
    }
    local ch = 1
    for k, c_guid in pairs(set.clusters) do
        for i, cluster in pairs(clusters) do
            if cluster.guid == c_guid then
                local motif = {
                    motif = {
                        src = "audio/" .. cluster.file_path:match("^.+/(.+)$"),
                        upbeat = GetPreRoll(cluster, 4),
                        class = cluster.name,
                    }
                }
                ch = ch + 1
                table.insert(arrangement_table.arrangement, motif)
                break
            end
        end
    end
    if ch > max_channels then max_channels = ch end
    return arrangement_table
end

local function Include_sets(schema_table)
    local imusic_table = {
        xmlns = "https://www.w3schools.com",
        xlmns_xsi = "http://www.w3.org/2001/XMLSchema-instance",
        xsi_schemaLocation = "https://www.w3schools.com https://momdev.se/lindetorp/imusic/scheme_1.1.25.xsd",

        version = "1.0" ,
        tempo = tostring(schema_table.project.tempo),
        timeSign = stringify_timeSig(schema_table.project.time_signature_upper, schema_table.project.time_signature_lower),
        loopLength = 8,

        changeOnNext = "bar",
        fadeTime = "10",
        showGUI = "true",
    }
    for key, set in pairs(schema_table.sets) do
        if set.name == "General" then
            
        else
            table.insert(imusic_table, {
                arrangement = Include_tracks(set, schema_table)
            })
        end
    end
    return imusic_table
end

local function Parse_schema_to_imusic(schema_table)
    local imusic_obj = {
        imusic = Include_sets(schema_table),
    }
    return imusic_obj
end

function Implement_WAXML()
    local ready, msg = Export_requirements()
    if not ready then
        reaper.MB("Cannot implement the project for the following reason:\n\n" .. msg, "Implementation error", 0)
        return false
    end
	reaper.PreventUIRefresh(1)
	if ValidateProjectHasBeenSaved() == false then
		return reaper.MB("Project has not been saved!\n\nThe Reaper project needs to be saved before the AMAPP can start export to middleware. Please save your project!", "IMPORTANT!", 0)
	end

	local _, cluster_table_string = reaper.GetProjExtState(0, "AMAPP", "CLUSTER_TABLE")
	local cluster_table = table.deserialize(cluster_table_string)
	if cluster_table == nil then cluster_table = {} end

    local schema_table = {
        project = {},
        sets = {},
        clusters = {},
    }

    local unrendered_clusters
    schema_table.project = Project()
    schema_table.clusters, unrendered_clusters = Clusters(cluster_table)
    schema_table.sets = Sets(cluster_table)

    schema_table = Parse_schema_to_imusic(schema_table)

    if unrendered_clusters ~= nil and #unrendered_clusters > 0 then
        _render_clusters_(unrendered_clusters)
    end

    local xlmns_xsi = "xmlns:xsi"
    local xsi_schemaLocation = "xsi:schemaLocation"
    local retval = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" .. luatoxml.toxml(schema_table)
    retval = retval:gsub("xlmns_xsi", xlmns_xsi)
    retval = retval:gsub("xsi_schemaLocation", xsi_schemaLocation)

    local schema_path =  Project_render_path():gsub("[/\\]$", ""):match("^(.*)[/\\][^/\\]+$") .. string.char(47) .. "music.xml"
    os.remove(schema_path)
    local schema_file = assert(io.open(schema_path, "w"))
    schema_file:write(retval)
    schema_file:close()

    Audio_XML()
end