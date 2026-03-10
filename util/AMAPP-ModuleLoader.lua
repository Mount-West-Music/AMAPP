--[[
	Library/Component: AMAPP
	Copyright (c) 2026 Mount West Music AB
	All rights reserved.

	Description:
	Centralized module loader with dependency graph.
	Ensures modules are loaded in correct order and provides clear dependency tracking.

	Usage:
		local ModuleLoader = loadfile(lib_path .. "util/AMAPP-ModuleLoader.lua")(lib_path)
		ModuleLoader:load_all()
		
		ModuleLoader:load("cluster_management")

	(c) 2026 Mount West Music AB. All rights reserved.
--]]

local ModuleLoader = {
	lib_path = nil,
	loaded = {},
	loading = {},  
	errors = {},
}

ModuleLoader.__index = ModuleLoader


local function normalize_path(path)
	if not path then return path end
	
	local sep = package.config:sub(1, 1) 
	if sep == "\\" then
		
		return path:gsub("/", "\\")
	else
		
		return path:gsub("\\", "/")
	end
end

--------------------------------------------------------------------------------


--------------------------------------------------------------------------------

ModuleLoader.MODULES = {
	
	constants = {
		path = "util/AMAPP-Constants.lua",
		deps = {},
		description = "Global constants and configuration values",
	},
	table_serializer = {
		path = "util/MWM-Table_serializer.lua",
		deps = {},
		description = "Table serialization for project state",
	},
	json = {
		path = "util/json/json.lua",
		deps = {},
		description = "JSON encoding/decoding",
		returns = true,  
	},
	async_request = {
		path = "util/AMAPP-Async_request.lua",
		deps = {},
		description = "Async HTTP request handling",
		returns = true,
	},
	logger = {
		path = "util/AMAPP-Logger.lua",
		deps = {},
		description = "Logging framework with levels and formatting",
		returns = true,
	},
	state_manager = {
		path = "util/AMAPP-StateManager.lua",
		deps = {},
		description = "Centralized state management",
		returns = true,
	},
	cluster_tree = {
		path = "util/AMAPP-ClusterTree.lua",
		deps = {},
		description = "Cluster tree utilities for hierarchy management",
		returns = true,
	},
	region_manager = {
		path = "util/AMAPP-RegionManager.lua",
		deps = {},
		description = "Region/Marker GUID tracking (uses C++ extension when available)",
		returns = true,
	},

	
	get_cluster = {
		path = "scripts/AMAPP-Get_cluster.lua",
		deps = {"constants"},
		description = "Retrieve cluster data",
	},
	get_items_in_cluster = {
		path = "scripts/AMAPP-Get_items_in_cluster.lua",
		deps = {"constants"},
		description = "Get items belonging to a cluster",
	},
	set_items_in_cluster = {
		path = "scripts/AMAPP-Set_items_in_cluster.lua",
		deps = {"constants", "get_items_in_cluster"},
		description = "Assign items to a cluster",
	},
	remove_items_in_cluster = {
		path = "scripts/AMAPP-Remove_items_in_cluster.lua",
		deps = {"constants"},
		description = "Remove items from a cluster",
	},

	
	create_cluster = {
		path = "scripts/AMAPP-Create_new_render_cluster.lua",
		deps = {"constants", "get_cluster", "update_cluster_state", "region_manager"},
		description = "Create new render cluster",
	},
	edit_cluster = {
		path = "scripts/AMAPP-Edit_render_cluster.lua",
		deps = {"constants", "get_cluster"},
		description = "Edit existing cluster",
	},
	delete_cluster = {
		path = "scripts/AMAPP-Delete_render_cluster.lua",
		deps = {"constants", "get_cluster", "update_cluster_state"},
		description = "Delete cluster and cleanup",
	},
	duplicate_cluster = {
		path = "scripts/AMAPP-Duplicate_cluster.lua",
		deps = {"constants", "get_cluster", "create_cluster"},
		description = "Duplicate existing cluster",
	},

	
	update_cluster_state = {
		path = "scripts/AMAPP-Update_render_cluster_table_ext_proj_state.lua",
		deps = {"constants", "table_serializer"},
		description = "Persist cluster state to project",
	},
	set_cluster_loop = {
		path = "scripts/AMAPP-Set_cluster_loop.lua",
		deps = {"constants"},
		description = "Set cluster loop properties",
	},
	set_cluster_boundaries = {
		path = "scripts/AMAPP-Set_cluster_boundaries.lua",
		deps = {"constants"},
		description = "Set cluster start/end boundaries",
	},
	cluster_color = {
		path = "scripts/AMAPP-New_cluster_color.lua",
		deps = {"constants"},
		description = "Cluster color management",
	},

	
	create_cluster_group = {
		path = "scripts/AMAPP-Create_cluster_group.lua",
		deps = {"constants"},
		description = "Create cluster group/hierarchy",
	},
	create_group = {
		path = "scripts/AMAPP-Create_new_group.lua",
		deps = {"constants", "update_cluster_state"},
		description = "Create implementation group",
	},

	
	create_connection = {
		path = "scripts/AMAPP-Create_connection.lua",
		deps = {"constants"},
		description = "Create connection between nodes",
	},
	delete_connection = {
		path = "scripts/AMAPP-Delete_connection.lua",
		deps = {"constants"},
		description = "Delete connection",
	},

	
	focus_clusters = {
		path = "scripts/AMAPP-Focus_view_selected_clusters.lua",
		deps = {"constants", "get_items_in_cluster"},
		description = "Focus view on selected clusters",
	},
	deactivate_cluster = {
		path = "scripts/AMAPP-Deactivate_selected_cluster.lua",
		deps = {"constants"},
		description = "Deactivate selected cluster",
	},
	get_region_name = {
		path = "scripts/AMAPP-Get_selected_region_name.lua",
		deps = {"constants"},
		description = "Get name of selected region",
	},

	
	render_clusters = {
		path = "scripts/AMAPP-Render_clusters.lua",
		deps = {"constants", "get_cluster", "get_items_in_cluster", "table_serializer"},
		description = "Render cluster audio files",
	},

	
	implementation_design = {
		path = "scripts/AMAPP-Implementation_design.lua",
		deps = {"constants", "json", "render_clusters", "table_serializer"},
		description = "Export implementation design JSON",
	},
	export_ecs = {
		path = "scripts/AMAPP-Export_ecs_schema.lua",
		deps = {"constants", "json", "table_serializer"},
		description = "Export ECS schema for Graph-UI",
	},
	migrate_schema = {
		path = "scripts/AMAPP-Migrate_schema_v1_to_v2.lua",
		deps = {"constants", "json"},
		description = "Migrate v1 schema to v2",
	},
	
	
	
	
	
	
	implement_waxml = {
		path = "scripts/AMAPP-Implement_to_WAXML.lua",
		deps = {"constants", "json"},
		description = "WAXML export",
	},
}

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------


function ModuleLoader:get_load_order(module_names)
	local order = {}
	local visited = {}
	local temp_visited = {}

	local function visit(name)
		if temp_visited[name] then
			error("Circular dependency detected: " .. name)
		end
		if visited[name] then
			return
		end

		temp_visited[name] = true

		local module = self.MODULES[name]
		if module then
			for _, dep in ipairs(module.deps) do
				visit(dep)
			end
		end

		temp_visited[name] = nil
		visited[name] = true
		table.insert(order, name)
	end

	for _, name in ipairs(module_names) do
		visit(name)
	end

	return order
end


function ModuleLoader:get_all_module_names()
	local names = {}
	for name, _ in pairs(self.MODULES) do
		table.insert(names, name)
	end
	return names
end

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------


function ModuleLoader:load_module(name)
	
	if self.loaded[name] then
		return self.loaded[name]
	end

	
	if self.loading[name] then
		error("Circular dependency detected while loading: " .. name)
	end

	local module_def = self.MODULES[name]
	if not module_def then
		error("Unknown module: " .. name)
	end

	
	self.loading[name] = true

	
	for _, dep in ipairs(module_def.deps) do
		self:load_module(dep)
	end

	
	local full_path = normalize_path(self.lib_path .. module_def.path)
	local loader, err = loadfile(full_path)

	if not loader then
		self.loading[name] = nil
		self.errors[name] = err
		error("Failed to load module '" .. name .. "': " .. tostring(err))
	end

	local success, result = pcall(loader)
	if not success then
		self.loading[name] = nil
		self.errors[name] = result
		error("Error executing module '" .. name .. "': " .. tostring(result))
	end

	
	self.loading[name] = nil
	self.loaded[name] = module_def.returns and result or true

	return self.loaded[name]
end


function ModuleLoader:load(...)
	local module_names = {...}
	local order = self:get_load_order(module_names)

	for _, name in ipairs(order) do
		self:load_module(name)
	end
end


function ModuleLoader:load_all()
	local all_names = self:get_all_module_names()
	local order = self:get_load_order(all_names)

	local loaded_count = 0
	local failed_count = 0

	for _, name in ipairs(order) do
		local success, err = pcall(function()
			self:load_module(name)
		end)

		if success then
			loaded_count = loaded_count + 1
		else
			failed_count = failed_count + 1
			self.errors[name] = err
		end
	end

	return loaded_count, failed_count
end


function ModuleLoader:load_core()
	local core_modules = {
		"constants",
		"table_serializer",
		"json",
		"region_manager",
		"get_cluster",
		"get_items_in_cluster",
		"set_items_in_cluster",
		"create_cluster",
		"delete_cluster",
		"update_cluster_state",
		"render_clusters",
	}

	self:load(table.unpack(core_modules))
end

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------


function ModuleLoader:is_loaded(name)
	return self.loaded[name] ~= nil
end


function ModuleLoader:get(name)
	return self.loaded[name]
end


function ModuleLoader:get_errors()
	return self.errors
end


function ModuleLoader:print_dependency_graph()
	local function Msg(str)
		reaper.ShowConsoleMsg(tostring(str) .. "\n")
	end

	Msg("=== AMAPP Module Dependency Graph ===\n")

	for name, module in pairs(self.MODULES) do
		local status = self.loaded[name] and "[LOADED]" or "[      ]"
		Msg(status .. " " .. name)
		Msg("       Path: " .. module.path)
		Msg("       Desc: " .. module.description)
		if #module.deps > 0 then
			Msg("       Deps: " .. table.concat(module.deps, ", "))
		else
			Msg("       Deps: (none)")
		end
		Msg("")
	end
end


function ModuleLoader:print_load_order()
	local function Msg(str)
		reaper.ShowConsoleMsg(tostring(str) .. "\n")
	end

	local order = self:get_load_order(self:get_all_module_names())

	Msg("=== AMAPP Module Load Order ===\n")
	for i, name in ipairs(order) do
		local status = self.loaded[name] and "+" or "-"
		Msg(string.format("%s %2d. %s", status, i, name))
	end
end

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------

function ModuleLoader.new(lib_path)
	local self = setmetatable({}, ModuleLoader)
	self.lib_path = normalize_path(lib_path)
	self.loaded = {}
	self.loading = {}
	self.errors = {}
	return self
end

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------


return function(lib_path)
	return ModuleLoader.new(lib_path)
end
