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


function Set_Cluster_Boundaries(cluster)
	local _, cluster_table_string = reaper.GetProjExtState(0, "AMAPP", "CLUSTER_TABLE")
	local cluster_table = table.deserialize(cluster_table_string)
	if cluster_table == nil then cluster_table = {} end
	for _, c in pairs(cluster_table) do
		if c.cluster_guid == cluster.cluster_guid then
            if cluster.is_loop ~= nil then
                c.is_loop       = cluster.is_loop
            end
            c.c_start           = cluster.c_start       or c.c_start
            c.c_end             = cluster.c_end         or c.c_end

            if cluster.c_entry == nil or cluster.c_qn_entry == nil then
                c.c_entry       = nil
                c.c_qn_entry    = nil
            elseif cluster.c_entry and cluster.c_start >= cluster.c_entry then
                c.c_entry       = nil
                c.c_qn_entry    = nil
            else
                c.c_entry       = cluster.c_entry       or c.c_entry
                c.c_qn_entry    = cluster.c_qn_entry    or c.c_qn_entry
            end

            if cluster.c_exit == nil or cluster.c_qn_exit == nil then
                c.c_exit        = nil
                c.c_qn_exit     = nil
            elseif cluster.c_exit and cluster.c_end <= cluster.c_exit then
                c.c_exit        = nil
                c.c_qn_exit     = nil
            else
                c.c_exit        = cluster.c_exit        or c.c_exit
                c.c_qn_exit     = cluster.c_qn_exit     or c.c_qn_exit
            end

            c.c_qn_start        = cluster.c_qn_start
            c.c_qn_end          = cluster.c_qn_end

            
            
            
            
            

            
            
            
            
            

            break
		end
    end
    local cluster_sTable = table.serialize(cluster_table)
    reaper.SetProjExtState(0, "AMAPP", "CLUSTER_TABLE", cluster_sTable)
end