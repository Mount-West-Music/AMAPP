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
	reaper.ShowConsoleMsg(tostring(param).."\n")
end


function Create_New_Set(new_set_id)
	reaper.PreventUIRefresh(1)
	local _, set_table_string = reaper.GetProjExtState(0, "AMAPP", "SET_TABLE")
	local set_table = table.deserialize(set_table_string)
	if set_table == nil then set_table = {} end
	for k, v in pairs(set_table) do
		if v.set_id == new_set_id then
			reaper.MB("A set with that name already exists. Try a different name"
			, "Choose a unique name!", 0)
			return
		end
	end
	local set_guid = reaper.genGuid()
	local new_set = {set_guid = set_guid, set_id = new_set_id}
	table.insert(set_table, new_set)
	local set_sTable = table.serialize(set_table)
	reaper.SetProjExtState(0, "AMAPP", "SET_TABLE", set_sTable)
	reaper.MarkProjectDirty(0)
	reaper.UpdateArrange()
	reaper.PreventUIRefresh(-1)
end