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


function NewClusterColor(cluster_guid, color)
    local _, cluster_table_string = reaper.GetProjExtState(0, "AMAPP", "CLUSTER_TABLE")
    local cluster_table = table.deserialize(cluster_table_string)
    if cluster_table == nil then cluster_table = {} end
    for _, c in pairs(cluster_table) do
        if c.cluster_guid == cluster_guid then
            c.cluster_color = color
            break
        end
    end
    local cluster_sTable = table.serialize(cluster_table)
    reaper.SetProjExtState(0, "AMAPP", "CLUSTER_TABLE", cluster_sTable)
end