-- @description AMAPP: Render Selected Clusters
-- @author Mount West Music AB
-- @version 0.5.0
-- @about Triggers render of currently selected clusters in AMAPP

local lib_path = reaper.GetExtState("AMAPP", "lib_path")
if not lib_path or lib_path == "" then
    reaper.MB("AMAPP is not installed. Please run AMAPP once to initialize.", "AMAPP Action", 0)
    return
end

local amapp_hwnd = reaper.JS_Window_Find("AMAPP Cluster Manager", true)
if not amapp_hwnd then
    reaper.MB("AMAPP must be running to use this action.\n\nPlease open AMAPP first.", "AMAPP Action", 0)
    return
end

reaper.SetExtState("AMAPP", "action_request", "render_selected", false)
