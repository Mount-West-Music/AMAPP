--[[
	Library/Component: AMAPP
	Copyright (c) 2026 Mount West Music AB
	All rights reserved.

	Description:
	Error handling utilities with safe wrappers for common operations.
	Integrates with Logger framework for consistent error reporting.

	Usage:
		local ErrorHandling = loadfile(lib_path .. "util/AMAPP-ErrorHandling.lua")()

		
		local result, err = ErrorHandling.safe_loadfile(path, "My Module")

		
		local data = ErrorHandling.safe_deserialize(str, "CLUSTER_TABLE", {})

		
		local file = ErrorHandling.safe_open(path, "r", "config file")
		ErrorHandling.safe_remove(path, "temp file")

	(c) 2026 Mount West Music AB. All rights reserved.
--]]

local ErrorHandling = {}

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------


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


local Logger
local function get_logger()
	if Logger then return Logger end

	local lib_path = reaper and reaper.GetExtState("AMAPP", "lib_path")
	if lib_path and lib_path ~= "" then
		local loader = loadfile(normalize_path(lib_path .. "util/AMAPP-Logger.lua"))
		if loader then
			Logger = loader()
		end
	end

	
	if not Logger then
		Logger = {
			debug = function(msg, ...) end,  
			info = function(msg, ...)
				if reaper then reaper.ShowConsoleMsg("[INFO] " .. string.format(msg, ...) .. "\n") end
			end,
			warn = function(msg, ...)
				if reaper then reaper.ShowConsoleMsg("[WARN] " .. string.format(msg, ...) .. "\n") end
			end,
			error = function(msg, ...)
				if reaper then reaper.ShowConsoleMsg("[ERROR] " .. string.format(msg, ...) .. "\n") end
			end,
		}
	end

	return Logger
end

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------






function ErrorHandling.safe_loadfile(path, description)
	description = description or path
	local log = get_logger()

	
	path = normalize_path(path)

	
	local loader, load_err = loadfile(path)
	if not loader then
		log.error("Failed to load %s: %s", description, load_err or "unknown error")
		return nil, load_err
	end

	
	local success, result = pcall(loader)
	if not success then
		log.error("Error executing %s: %s", description, result or "unknown error")
		return nil, result
	end

	log.debug("Successfully loaded: %s", description)
	return result
end






function ErrorHandling.require_module(path, description, is_critical)
	local result, err = ErrorHandling.safe_loadfile(path, description)

	if not result and is_critical then
		reaper.MB(
			string.format("Failed to load required module:\n%s\n\nError: %s\n\nPlease reinstall AMAPP.",
				description, err or "unknown"),
			"AMAPP Load Error",
			0
		)
	end

	return result, err
end

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------






function ErrorHandling.safe_deserialize(data_string, key_name, default)
	local log = get_logger()

	
	if not data_string or data_string == "" then
		log.debug("No data for %s, using default", key_name)
		return default
	end

	
	if not table.deserialize then
		log.error("table.deserialize not available for %s", key_name)
		return default
	end

	
	local success, result, err = pcall(table.deserialize, data_string)

	if not success then
		
		log.warn("Failed to deserialize %s (pcall error): %s", key_name, tostring(result))
		return default
	end

	if result == nil then
		
		if err then
			log.warn("Failed to deserialize %s: %s", key_name, tostring(err))
		else
			log.debug("Deserialized %s returned nil, using default", key_name)
		end
		return default
	end

	log.debug("Successfully deserialized: %s", key_name)
	return result
end

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------







function ErrorHandling.safe_open(path, mode, description)
	description = description or path
	local log = get_logger()

	local file, err = io.open(path, mode)
	if not file then
		log.warn("Failed to open %s (%s): %s", description, mode, err or "unknown")
		return nil, err
	end

	return file
end





function ErrorHandling.safe_remove(path, description)
	description = description or path
	local log = get_logger()

	local success, err = os.remove(path)
	if not success then
		
		log.debug("Failed to remove %s: %s", description, err or "unknown")
	end

	return success or false
end






function ErrorHandling.safe_read_file(path, description)
	description = description or path
	local log = get_logger()

	local file, open_err = io.open(path, "r")
	if not file then
		log.warn("Failed to read %s: %s", description, open_err or "unknown")
		return nil, open_err
	end

	local contents, read_err = file:read("*a")
	file:close()

	if not contents then
		log.warn("Failed to read contents of %s: %s", description, read_err or "unknown")
		return nil, read_err
	end

	return contents
end







function ErrorHandling.safe_write_file(path, contents, description)
	description = description or path
	local log = get_logger()

	local file, open_err = io.open(path, "w")
	if not file then
		log.warn("Failed to write %s: %s", description, open_err or "unknown")
		return false, open_err
	end

	local success, write_err = file:write(contents)
	file:close()

	if not success then
		log.warn("Failed to write contents to %s: %s", description, write_err or "unknown")
		return false, write_err
	end

	return true
end

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------







function ErrorHandling.safe_call(func, description, ...)
	local log = get_logger()

	local results = {pcall(func, ...)}
	local success = table.remove(results, 1)

	if not success then
		log.error("%s failed: %s", description or "Operation", results[1] or "unknown error")
		return false, results[1]
	end

	return true, table.unpack(results)
end

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------





function ErrorHandling.create_error(message, context)
	local error_info = {
		message = message,
		timestamp = os.date("%Y-%m-%d %H:%M:%S"),
		context = context or {},
	}

	
	local trace = debug.traceback(nil, 2)
	if trace then
		error_info.stack = trace
	end

	return error_info
end



function ErrorHandling.log_error(error_info)
	local log = get_logger()

	log.error(error_info.message)

	if error_info.context then
		for k, v in pairs(error_info.context) do
			log.debug("  %s: %s", k, tostring(v))
		end
	end
end

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------


ErrorHandling.DISCORD_URL = "https://discord.gg/xs8AEhx6h2"



ErrorHandling.DISCORD_WEBHOOK_URL = "https://discord.com/api/webhooks/1478075742997971064/ZTSYUrTlYsI86PLf2WXaFP22yYTO2PhwAPhnHLXyEGVnhhCDp2XoNAqow73aJhfTQArp"



function ErrorHandling.get_system_info()
	local info = {
		os = reaper.GetOS(),
		reaper_version = reaper.GetAppVersion(),
		amapp_version = (AMAPP_CONSTANTS and AMAPP_CONSTANTS.META and AMAPP_CONSTANTS.META.VERSION) or "unknown",
		timestamp = os.date("%Y-%m-%d %H:%M:%S"),
		platform = package.config:sub(1, 1) == "\\" and "Windows" or "macOS/Linux",
	}

	
	local _, exe_path = reaper.get_action_context()
	if exe_path then
		info.script_path = exe_path
	end

	return info
end






function ErrorHandling.format_error_report(error_msg, stack_trace, context)
	local sys_info = ErrorHandling.get_system_info()
	local lines = {}

	table.insert(lines, "```")
	table.insert(lines, "=== AMAPP Error Report ===")
	table.insert(lines, "")
	table.insert(lines, "ERROR: " .. (error_msg or "Unknown error"))
	table.insert(lines, "")
	table.insert(lines, "--- System Info ---")
	table.insert(lines, "AMAPP Version: " .. sys_info.amapp_version)
	table.insert(lines, "REAPER Version: " .. sys_info.reaper_version)
	table.insert(lines, "OS: " .. sys_info.os)
	table.insert(lines, "Timestamp: " .. sys_info.timestamp)

	if context then
		table.insert(lines, "")
		table.insert(lines, "--- Context ---")
		for k, v in pairs(context) do
			table.insert(lines, string.format("%s: %s", k, tostring(v)))
		end
	end

	if stack_trace then
		table.insert(lines, "")
		table.insert(lines, "--- Stack Trace ---")
		table.insert(lines, stack_trace)
	end

	table.insert(lines, "```")

	return table.concat(lines, "\n")
end




local function copy_to_clipboard(text)
	
	if reaper.CF_SetClipboard then
		reaper.CF_SetClipboard(text)
		return true
	end

	return false
end




local function send_to_discord_webhook(report, callback)
	local log = get_logger()

	if not ErrorHandling.DISCORD_WEBHOOK_URL then
		log.warn("Discord webhook URL not configured")
		if callback then callback(false, "Webhook not configured") end
		return false
	end

	
	local truncated_report = report
	if #truncated_report > 1900 then
		truncated_report = truncated_report:sub(1, 1900) .. "\n... [truncated]```"
	end

	
	local json_content = truncated_report
		:gsub('\\', '\\\\')
		:gsub('"', '\\"')
		:gsub('\n', '\\n')
		:gsub('\r', '\\r')
		:gsub('\t', '\\t')

	local payload = '{"content": "' .. json_content .. '"}'

	
	local command
	local is_windows = reaper.GetOS():match("Win")

	if is_windows then
		
		
		local ps_payload = payload:gsub("'", "''")
		command = string.format(
			'powershell -nologo -noprofile -WindowStyle Hidden -ExecutionPolicy Bypass -Command "Invoke-RestMethod -Uri \'%s\' -Method POST -ContentType \'application/json\' -Body \'%s\'"',
			ErrorHandling.DISCORD_WEBHOOK_URL,
			ps_payload
		)
	else
		
		
		local lib_path = reaper.GetExtState("AMAPP", "lib_path") or ""
		local temp_file = lib_path .. "util/tmp/webhook_payload_" .. os.time() .. ".json"

		local file = io.open(temp_file, "w")
		if file then
			file:write(payload)
			file:close()

			
			command = string.format(
				'curl -s -X POST -H "Content-Type: application/json" -d @"%s" "%s" ; rm "%s"',
				temp_file,
				ErrorHandling.DISCORD_WEBHOOK_URL,
				temp_file
			)
		else
			log.warn("Could not create temp file for webhook payload")
			if callback then callback(false, "Could not create temp file") end
			return false
		end
	end

	
	log.debug("Sending webhook: %s", command:sub(1, 100) .. "...")
	local result = os.execute(command .. " &")

	
	
	local success = (result == true or result == 0 or result == nil)

	if success then
		log.info("Bug report sent to Discord webhook")
		if callback then callback(true, "Report sent successfully") end
	else
		log.warn("Failed to send bug report to Discord webhook (exit code: %s)", tostring(result))
		if callback then callback(false, "Failed to send") end
	end

	return success
end






function ErrorHandling.show_error_dialog(error_msg, stack_trace, context, options)
	local log = get_logger()

	
	if type(options) == "boolean" then
		options = {show_discord = options}
	end
	options = options or {}
	local show_discord = (options.show_discord == nil) and true or options.show_discord
	local allow_auto_send = (options.allow_auto_send == nil) and true or options.allow_auto_send

	
	if not stack_trace then
		stack_trace = debug.traceback(nil, 2)
	end

	
	log.error("User-facing error: %s", error_msg)
	if stack_trace then
		log.debug("Stack trace:\n%s", stack_trace)
	end

	
	local report = ErrorHandling.format_error_report(error_msg, stack_trace, context)

	
	local can_auto_send = allow_auto_send and ErrorHandling.DISCORD_WEBHOOK_URL ~= nil

	if not show_discord then
		
		reaper.MB("An unexpected error occurred:\n\n" .. error_msg, "AMAPP Error", 0)
		return report
	end

	
	local choice_msg = string.format(
		"An unexpected error occurred:\n\n%s\n\n" ..
		"----------------------------------------\n\n" ..
		"Would you like to send a bug report?\n\n" ..
		"Reports are anonymous and only contain technical\n" ..
		"information (error message, version, OS).\n" ..
		"No personal data is collected.",
		error_msg
	)

	if can_auto_send then
		
		
		
		
		local result = reaper.MB(
			choice_msg .. "\n\n" ..
			"• Yes = Send report automatically\n" ..
			"• No = Copy to clipboard (manual)\n" ..
			"• Cancel = Don't send",
			"AMAPP Error - Send Bug Report?",
			3  
		)

		if result == 6 then  
			
			local sent = send_to_discord_webhook(report)
			if sent then
				reaper.MB(
					"Anonymous bug report sent successfully!\n\n" ..
					"Thank you for helping improve AMAPP.",
					"Report Sent",
					0
				)
			else
				
				copy_to_clipboard(report)
				reaper.MB(
					"Could not send automatically.\n\n" ..
					"The error details have been copied to your clipboard.\n" ..
					"Please paste in our Discord #bug-reports channel:\n\n" ..
					ErrorHandling.DISCORD_URL,
					"Please Report Manually",
					0
				)
			end
		elseif result == 7 then  
			
			local copied = copy_to_clipboard(report)
			if copied then
				reaper.MB(
					"Error details copied to clipboard!\n\n" ..
					"Please paste in our Discord #bug-reports channel:\n\n" ..
					ErrorHandling.DISCORD_URL,
					"Report Copied",
					0
				)
			else
				reaper.MB(
					"Could not copy to clipboard.\n\n" ..
					"Please report this error on our Discord:\n" ..
					ErrorHandling.DISCORD_URL .. "\n\n" ..
					"Include:\n" ..
					"• What you were doing when the error occurred\n" ..
					"• AMAPP version: " .. (AMAPP_CONSTANTS and AMAPP_CONSTANTS.META and AMAPP_CONSTANTS.META.VERSION or "unknown") .. "\n" ..
					"• REAPER version: " .. reaper.GetAppVersion(),
					"Please Report on Discord",
					0
				)
			end
		end
		
	else
		
		
		local result = reaper.MB(
			choice_msg .. "\n\n" ..
			"• Yes = Copy error details to clipboard\n" ..
			"• No = Don't send",
			"AMAPP Error - Send Bug Report?",
			4  
		)

		if result == 6 then  
			local copied = copy_to_clipboard(report)
			if copied then
				reaper.MB(
					"Error details copied to clipboard!\n\n" ..
					"Please paste in our Discord #bug-reports channel:\n\n" ..
					ErrorHandling.DISCORD_URL,
					"Report Copied",
					0
				)
			else
				reaper.MB(
					"Could not copy to clipboard.\n\n" ..
					"Please report this error on our Discord:\n" ..
					ErrorHandling.DISCORD_URL,
					"Please Report on Discord",
					0
				)
			end
		end
	end

	return report
end







function ErrorHandling.send_bug_report(error_msg, stack_trace, context, callback)
	if not stack_trace then
		stack_trace = debug.traceback(nil, 2)
	end

	local report = ErrorHandling.format_error_report(error_msg, stack_trace, context)
	return send_to_discord_webhook(report, callback)
end






function ErrorHandling.with_user_error_handling(func, description)
	return function(...)
		local success, result = pcall(func, ...)
		if not success then
			local stack = debug.traceback(nil, 2)
			ErrorHandling.show_error_dialog(
				string.format("%s failed: %s", description or "Operation", tostring(result)),
				stack,
				{operation = description}
			)
			return nil
		end
		return result
	end
end







function ErrorHandling.pcall_with_dialog(func, description, ...)
	local args = {...}
	local results = {pcall(function() return func(table.unpack(args)) end)}
	local success = table.remove(results, 1)

	if not success then
		local stack = debug.traceback(nil, 2)
		ErrorHandling.show_error_dialog(
			string.format("%s failed: %s", description or "Operation", tostring(results[1])),
			stack,
			{operation = description}
		)
		return false, results[1]
	end

	return true, table.unpack(results)
end

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------

return ErrorHandling
