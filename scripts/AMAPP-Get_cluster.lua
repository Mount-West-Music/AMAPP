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
dofile(mwm_lib_path .. "util/MWM-Table_serializer.lua")


function Get_Cluster(cluster)
	local _, cluster_table_string = reaper.GetProjExtState(0, "AMAPP", "CLUSTER_TABLE")
	local cluster_table = table.deserialize(cluster_table_string)
	if cluster_table == nil then cluster_table = {} end
	for _, c in pairs(cluster_table) do
		if c.cluster_guid == cluster.cluster_guid then
            return true, c
		end
    end
    return false
end