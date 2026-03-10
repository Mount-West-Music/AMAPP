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


local mwm_lib_path
local mwm_lib_path = reaper.GetExtState("AMAPP", "lib_path")
if not mwm_lib_path or mwm_lib_path == "" then
    reaper.MB("Couldn't load the AMAPP Library. Please install the AMAPP by running the AMAPP_installation.lua ReaScript!", "Error!", 0)
    return
end
dofile(mwm_lib_path .. "util/MWM-Table_serializer.lua")

reaper.ShowConsoleMsg("")
function Msg(param)
  reaper.ShowConsoleMsg(tostring(param).."\n")
end


function UpdateRenderClusterExtProjState(cluster_table)
	reaper.PreventUIRefresh(1)

	local cluster_sTable = table.serialize(cluster_table)
	reaper.SetProjExtState(0, "AMAPP", "CLUSTER_TABLE", cluster_sTable)

	reaper.MarkProjectDirty(0)
	reaper.UpdateArrange()
	reaper.PreventUIRefresh(-1)
end