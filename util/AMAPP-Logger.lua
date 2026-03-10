--[[
	Library/Component: AMAPP
	Copyright (c) 2026 Mount West Music AB
	All rights reserved.

	Description:
	Centralized logging framework for AMAPP.
	Provides structured logging with levels, formatting, and output control.

	Usage:
		local Logger = loadfile(lib_path .. "util/AMAPP-Logger.lua")()
		Logger.info("Application started")
		Logger.debug("Processing cluster: %s", cluster_guid)
		Logger.warn("Missing parent: %s", parent_guid)
		Logger.error("Failed to render: %s", error_msg)

		
		Msg("Simple message")

	(c) 2026 Mount West Music AB. All rights reserved.
--]]

local Logger = {}

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------

Logger.LEVELS = {
	DEBUG = 1,
	INFO = 2,
	WARN = 3,
	ERROR = 4,
	NONE = 5,  
}

Logger.LEVEL_NAMES = {
	[1] = "DEBUG",
	[2] = "INFO",
	[3] = "WARN",
	[4] = "ERROR",
}

Logger.LEVEL_PREFIXES = {
	[1] = "[DEBUG]",
	[2] = "[INFO] ",
	[3] = "[WARN] ",
	[4] = "[ERROR]",
}

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------

local config = {
	level = Logger.LEVELS.INFO,      
	show_timestamp = false,          
	show_level = true,               
	show_source = false,             
	output_to_console = true,        
	output_to_file = false,          
	log_file_path = nil,             
	max_message_length = 10000,      
	indent_multiline = true,         
}

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------

local log_file_handle = nil
local message_count = 0
local session_start = os.time()

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------


local function get_timestamp()
	return os.date("%H:%M:%S")
end


local function get_source(level)
	local info = debug.getinfo(level + 2, "Sl")
	if info then
		local short_source = info.short_src:match("([^/\\]+)$") or info.short_src
		return string.format("%s:%d", short_source, info.currentline or 0)
	end
	return "unknown:0"
end


local function format_message(msg, ...)
	if select("#", ...) > 0 then
		local success, result = pcall(string.format, msg, ...)
		if success then
			return result
		else
			
			local parts = {tostring(msg)}
			for i = 1, select("#", ...) do
				table.insert(parts, tostring(select(i, ...)))
			end
			return table.concat(parts, " ")
		end
	end
	return tostring(msg)
end


local function truncate(msg)
	if #msg > config.max_message_length then
		return msg:sub(1, config.max_message_length) .. "... [truncated]"
	end
	return msg
end


local function indent_lines(msg, prefix_len)
	if not config.indent_multiline then return msg end

	local indent = string.rep(" ", prefix_len)
	local lines = {}
	local first = true

	for line in msg:gmatch("[^\n]+") do
		if first then
			table.insert(lines, line)
			first = false
		else
			table.insert(lines, indent .. line)
		end
	end

	return table.concat(lines, "\n")
end

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------


local function write_to_console(msg)
	if reaper and reaper.ShowConsoleMsg then
		reaper.ShowConsoleMsg(msg .. "\n")
	else
		print(msg)  
	end
end


local function write_to_file(msg)
	if not config.log_file_path then return end

	if not log_file_handle then
		log_file_handle = io.open(config.log_file_path, "a")
		if not log_file_handle then
			config.output_to_file = false  
			return
		end
	end

	log_file_handle:write(msg .. "\n")
	log_file_handle:flush()
end

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------


local function log(level, msg, ...)
	
	if level < config.level then return end

	
	local formatted = format_message(msg, ...)
	formatted = truncate(formatted)

	
	local prefix_parts = {}

	if config.show_timestamp then
		table.insert(prefix_parts, get_timestamp())
	end

	if config.show_level then
		table.insert(prefix_parts, Logger.LEVEL_PREFIXES[level] or "[???]")
	end

	if config.show_source then
		table.insert(prefix_parts, get_source(2))
	end

	local prefix = ""
	if #prefix_parts > 0 then
		prefix = table.concat(prefix_parts, " ") .. " "
	end

	
	local output = prefix .. indent_lines(formatted, #prefix)

	
	if config.output_to_console then
		write_to_console(output)
	end

	if config.output_to_file then
		write_to_file(output)
	end

	message_count = message_count + 1
end

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------

function Logger.debug(msg, ...)
	log(Logger.LEVELS.DEBUG, msg, ...)
end

function Logger.info(msg, ...)
	log(Logger.LEVELS.INFO, msg, ...)
end

function Logger.warn(msg, ...)
	log(Logger.LEVELS.WARN, msg, ...)
end

function Logger.error(msg, ...)
	log(Logger.LEVELS.ERROR, msg, ...)
end


function Logger.msg(msg)
	log(Logger.LEVELS.INFO, tostring(msg))
end

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------


function Logger.set_level(level)
	if type(level) == "string" then
		level = Logger.LEVELS[level:upper()] or Logger.LEVELS.INFO
	end
	config.level = level
end


function Logger.get_level()
	return config.level
end


function Logger.show_timestamp(enabled)
	config.show_timestamp = enabled
end


function Logger.show_level(enabled)
	config.show_level = enabled
end


function Logger.show_source(enabled)
	config.show_source = enabled
end


function Logger.set_console_output(enabled)
	config.output_to_console = enabled
end


function Logger.set_log_file(path)
	
	if log_file_handle then
		log_file_handle:close()
		log_file_handle = nil
	end

	config.log_file_path = path
	config.output_to_file = (path ~= nil)
end


function Logger.configure(options)
	if options.level then Logger.set_level(options.level) end
	if options.show_timestamp ~= nil then config.show_timestamp = options.show_timestamp end
	if options.show_level ~= nil then config.show_level = options.show_level end
	if options.show_source ~= nil then config.show_source = options.show_source end
	if options.output_to_console ~= nil then config.output_to_console = options.output_to_console end
	if options.log_file then Logger.set_log_file(options.log_file) end
	if options.max_message_length then config.max_message_length = options.max_message_length end
end

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------


function Logger.get_message_count()
	return message_count
end


function Logger.get_session_duration()
	return os.time() - session_start
end


function Logger.separator(char, length)
	char = char or "-"
	length = length or 60
	log(Logger.LEVELS.INFO, string.rep(char, length))
end


function Logger.table(t, name, max_depth)
	max_depth = max_depth or 3
	name = name or "table"

	local function dump(tbl, indent, depth)
		if depth > max_depth then
			return indent .. "... (max depth reached)"
		end

		local lines = {}
		for k, v in pairs(tbl) do
			local key_str = tostring(k)
			if type(v) == "table" then
				table.insert(lines, indent .. key_str .. " = {")
				table.insert(lines, dump(v, indent .. "  ", depth + 1))
				table.insert(lines, indent .. "}")
			else
				table.insert(lines, indent .. key_str .. " = " .. tostring(v))
			end
		end
		return table.concat(lines, "\n")
	end

	log(Logger.LEVELS.DEBUG, "%s = {\n%s\n}", name, dump(t, "  ", 1))
end


function Logger.time(label, func)
	local start = os.clock()
	local result = {func()}
	local elapsed = os.clock() - start
	log(Logger.LEVELS.DEBUG, "%s completed in %.4f seconds", label, elapsed)
	return table.unpack(result)
end


function Logger.timer(label)
	local start = os.clock()
	return {
		stop = function()
			local elapsed = os.clock() - start
			log(Logger.LEVELS.DEBUG, "%s: %.4f seconds", label, elapsed)
			return elapsed
		end
	}
end


function Logger.debug_if(condition, msg, ...)
	if condition then Logger.debug(msg, ...) end
end

function Logger.info_if(condition, msg, ...)
	if condition then Logger.info(msg, ...) end
end

function Logger.warn_if(condition, msg, ...)
	if condition then Logger.warn(msg, ...) end
end

function Logger.error_if(condition, msg, ...)
	if condition then Logger.error(msg, ...) end
end


function Logger.assert(condition, msg, ...)
	if not condition then
		local formatted = format_message(msg or "Assertion failed", ...)
		Logger.error(formatted)
		error(formatted, 2)
	end
	return condition
end

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------


function Logger.install_global()
	_G.Msg = function(msg)
		if reaper and reaper.ShowConsoleMsg then
			reaper.ShowConsoleMsg(tostring(msg) .. "\n")
		else
			print(tostring(msg))
		end
	end
end


function Logger.create_msg_function()
	return function(msg)
		Logger.msg(msg)
	end
end

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------


function Logger.close()
	if log_file_handle then
		log_file_handle:close()
		log_file_handle = nil
	end
end

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------


function Logger.preset_development()
	Logger.configure({
		level = "DEBUG",
		show_timestamp = true,
		show_level = true,
		show_source = true,
	})
end


function Logger.preset_production()
	Logger.configure({
		level = "WARN",
		show_timestamp = false,
		show_level = true,
		show_source = false,
	})
end


function Logger.preset_debug()
	Logger.configure({
		level = "DEBUG",
		show_timestamp = true,
		show_level = true,
		show_source = true,
	})
end

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------


Logger.install_global()

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------

return Logger
