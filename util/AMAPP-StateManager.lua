--[[
	Library/Component: AMAPP
	Copyright (c) 2026 Mount West Music AB
	All rights reserved.

	Description:
	Centralized state management for AMAPP.
	Provides a single source of truth for application state with:
	- Validation on state changes
	- Change notification (subscribers)
	- State persistence to REAPER project
	- Undo/redo support preparation

	Usage:
		local State = require_state_manager()
		State:set("clusters.selected", {guid1, guid2})
		local selected = State:get("clusters.selected")
		State:subscribe("clusters", function(path, old, new) ... end)

	(c) 2026 Mount West Music AB. All rights reserved.
--]]

local StateManager = {}
StateManager.__index = StateManager

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------

local EXTSTATE_NAMESPACE = "AMAPP"
local PERSISTENCE_KEYS = {
	CLUSTER_TABLE = "CLUSTER_TABLE",
	CLUSTER_LIST = "CLUSTER_LIST",
	GROUP_TABLE = "GROUP_TABLE",
	CONNECTION_TABLE = "CONNECTION_TABLE",
	GRAPH_META = "GRAPH_META",
	EXPORT_OPTIONS = "EXPORT_OPTIONS",
	CLUSTER_ITEMS = "CLUSTER_ITEMS",
}

--------------------------------------------------------------------------------


--------------------------------------------------------------------------------

local DEFAULT_STATE = {
	
	project = {
		render_cluster_table = {},  
		render_cluster_list = {},   
		group_table = {},           
		connection_table = {},      
		graph_meta = {              
			entry_points = {},
		},
		cluster_items_table = {},   
		cluster_graph = {},         
	},

	
	selection = {
		clusters = {},              
		groups = {},                
		last_selected_idx = 1,
	},

	
	ui = {
		app_open = false,
		timeline_visible = true,
		item_overlay = true,
		overlay_inverse = true,
		focus_activated = false,
		solo_on_focus = true,
		debug_visible = false,
		export_options_open = false,
		render_summary_visible = false,
		render_summary_data = nil,
		audition_popup_visible = false,
		audition_cluster = nil,
	},

	
	drag = {
		active = false,
		source_guid = nil,
		target_guid = nil,
		drop_into_group = false,
		drop_out_of_group = false,
		hovering_own_child = false,
		hovering_below_list = false,
	},

	
	hover = {
		item = "",
		item_index = 0,
		is_group = false,
		parent_guid = nil,
		is_last_in_group = false,
	},

	
	render = {
		active = false,
		queue = {},
		current_batch = 0,
		total_batches = 0,
		aborted = false,
		progress = 0,
	},

	
	recording = {
		armed = false,
		active = false,
		cluster_guid = nil,
	},

	
	flags = {
		trigger_function = false,
		toggle_loop = false,
		toggle_activate = true,
		toggle_deactivate = false,
		update_clusters = true,
		edit_clicked = false,
		context_menu_clicked = false,
		delete_clicked = false,
		new_cluster_clicked = false,
	},

	
	cache = {
		project_state_count = 0,
		all_items_count = 0,
		last_rendered_max_y = 0,
	},
}

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------

function StateManager.new()
	local self = setmetatable({}, StateManager)
	self._state = deep_copy(DEFAULT_STATE)
	self._subscribers = {}
	self._dirty = {}  
	self._initialized = false
	return self
end


function deep_copy(t)
	if type(t) ~= "table" then return t end
	local copy = {}
	for k, v in pairs(t) do
		copy[k] = deep_copy(v)
	end
	return copy
end

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------


local function parse_path(path)
	local parts = {}
	for part in string.gmatch(path, "[^%.]+") do
		table.insert(parts, part)
	end
	return parts
end


local function get_nested(t, parts)
	local current = t
	for _, part in ipairs(parts) do
		if type(current) ~= "table" then return nil end
		current = current[part]
	end
	return current
end


local function set_nested(t, parts, value)
	local current = t
	for i = 1, #parts - 1 do
		local part = parts[i]
		if current[part] == nil then
			current[part] = {}
		end
		current = current[part]
	end
	current[parts[#parts]] = value
end

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------


function StateManager:get(path)
	if not path then return self._state end
	local parts = parse_path(path)
	return get_nested(self._state, parts)
end


function StateManager:set(path, value, skip_notify)
	local parts = parse_path(path)
	local old_value = get_nested(self._state, parts)

	
	if old_value == value then return end

	
	set_nested(self._state, parts, value)

	
	self._dirty[parts[1]] = true

	
	if not skip_notify then
		self:_notify(path, old_value, value)
	end
end


function StateManager:batch_update(updates, skip_notify)
	for path, value in pairs(updates) do
		self:set(path, value, true)
	end

	if not skip_notify then
		for path, value in pairs(updates) do
			self:_notify(path, nil, value)
		end
	end
end


function StateManager:reset(path)
	if path then
		local parts = parse_path(path)
		local default_value = get_nested(DEFAULT_STATE, parts)
		self:set(path, deep_copy(default_value))
	else
		self._state = deep_copy(DEFAULT_STATE)
		self._dirty = {}
	end
end

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------



function StateManager:subscribe(pattern, callback)
	if not self._subscribers[pattern] then
		self._subscribers[pattern] = {}
	end
	table.insert(self._subscribers[pattern], callback)

	
	return function()
		for i, cb in ipairs(self._subscribers[pattern]) do
			if cb == callback then
				table.remove(self._subscribers[pattern], i)
				break
			end
		end
	end
end


function StateManager:_notify(path, old_value, new_value)
	
	if self._subscribers[path] then
		for _, callback in ipairs(self._subscribers[path]) do
			callback(path, old_value, new_value)
		end
	end

	
	local parts = parse_path(path)
	local prefix = ""
	for i, part in ipairs(parts) do
		prefix = prefix .. (i > 1 and "." or "") .. part
		if prefix ~= path and self._subscribers[prefix] then
			for _, callback in ipairs(self._subscribers[prefix]) do
				callback(path, old_value, new_value)
			end
		end
	end

	
	if self._subscribers["*"] then
		for _, callback in ipairs(self._subscribers["*"]) do
			callback(path, old_value, new_value)
		end
	end
end

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------


function StateManager:load_from_project()
	local function load_key(key)
		local _, str = reaper.GetProjExtState(0, EXTSTATE_NAMESPACE, key)
		if str and str ~= "" then
			return table.deserialize(str)
		end
		return nil
	end

	
	self._state.project.render_cluster_table = load_key(PERSISTENCE_KEYS.CLUSTER_TABLE) or {}
	self._state.project.render_cluster_list = load_key(PERSISTENCE_KEYS.CLUSTER_LIST) or {}
	self._state.project.group_table = load_key(PERSISTENCE_KEYS.GROUP_TABLE) or {}
	self._state.project.connection_table = load_key(PERSISTENCE_KEYS.CONNECTION_TABLE) or {}
	self._state.project.graph_meta = load_key(PERSISTENCE_KEYS.GRAPH_META) or { entry_points = {} }
	self._state.project.cluster_items_table = load_key(PERSISTENCE_KEYS.CLUSTER_ITEMS) or {}

	
	local export_opts = load_key(PERSISTENCE_KEYS.EXPORT_OPTIONS)
	if export_opts then
		self._state.export_options = export_opts
	end

	self._initialized = true
	self._dirty = {}
end


function StateManager:save_to_project()
	local function save_key(key, data)
		local str = table.serialize(data)
		reaper.SetProjExtState(0, EXTSTATE_NAMESPACE, key, str)
	end

	if self._dirty.project then
		save_key(PERSISTENCE_KEYS.CLUSTER_TABLE, self._state.project.render_cluster_table)
		save_key(PERSISTENCE_KEYS.CLUSTER_LIST, self._state.project.render_cluster_list)
		save_key(PERSISTENCE_KEYS.GROUP_TABLE, self._state.project.group_table)
		save_key(PERSISTENCE_KEYS.CONNECTION_TABLE, self._state.project.connection_table)
		save_key(PERSISTENCE_KEYS.GRAPH_META, self._state.project.graph_meta)
		save_key(PERSISTENCE_KEYS.CLUSTER_ITEMS, self._state.project.cluster_items_table)
	end

	self._dirty = {}
end


function StateManager:force_save()
	self._dirty.project = true
	self:save_to_project()
end

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------


function StateManager:get_cluster(guid)
	return self._state.project.render_cluster_table[guid]
end


function StateManager:get_all_clusters()
	return self._state.project.render_cluster_table
end


function StateManager:get_cluster_list()
	return self._state.project.render_cluster_list
end


function StateManager:get_groups()
	return self._state.project.group_table
end


function StateManager:get_connections()
	return self._state.project.connection_table
end


function StateManager:is_cluster_selected(guid)
	for _, selected_guid in ipairs(self._state.selection.clusters) do
		if selected_guid == guid then return true end
	end
	return false
end


function StateManager:select_cluster(guid, add_to_selection)
	if add_to_selection then
		if not self:is_cluster_selected(guid) then
			table.insert(self._state.selection.clusters, guid)
		end
	else
		self._state.selection.clusters = {guid}
	end
	self:_notify("selection.clusters", nil, self._state.selection.clusters)
end


function StateManager:deselect_all_clusters()
	self._state.selection.clusters = {}
	self:_notify("selection.clusters", nil, {})
end


function StateManager:is_rendering()
	return self._state.render.active
end


function StateManager:is_app_open()
	return self._state.ui.app_open
end

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------


function StateManager:validate_cluster(cluster)
	local errors = {}

	if not cluster.cluster_guid then
		table.insert(errors, "Missing cluster_guid")
	end
	if not cluster.cluster_id then
		table.insert(errors, "Missing cluster_id")
	end
	if cluster.c_start and cluster.c_end and cluster.c_start > cluster.c_end then
		table.insert(errors, "c_start > c_end")
	end

	return #errors == 0, errors
end

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------

function StateManager:debug_print()
	local function Msg(str)
		reaper.ShowConsoleMsg(tostring(str) .. "\n")
	end

	Msg("=== AMAPP State Debug ===")
	Msg("Clusters: " .. table_count(self._state.project.render_cluster_table))
	Msg("Groups: " .. table_count(self._state.project.group_table))
	Msg("Connections: " .. table_count(self._state.project.connection_table))
	Msg("Selected: " .. #self._state.selection.clusters)
	Msg("Rendering: " .. tostring(self._state.render.active))
	Msg("Dirty keys: " .. table.concat(table_keys(self._dirty), ", "))
end


function table_count(t)
	local count = 0
	for _ in pairs(t) do count = count + 1 end
	return count
end


function table_keys(t)
	local keys = {}
	for k in pairs(t) do table.insert(keys, k) end
	return keys
end

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------

local _instance = nil

local function get_instance()
	if not _instance then
		_instance = StateManager.new()
	end
	return _instance
end

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------

return {
	StateManager = StateManager,
	get_instance = get_instance,
	new = StateManager.new,
}
