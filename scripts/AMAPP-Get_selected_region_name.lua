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

function GetRegionByInput(_inputString)
	local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
	local num_total = num_markers + num_regions
	local i = 0
	while i < num_total do
		local retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, i)
		if isrgn and name == _inputString then
			return i, name, pos, rgnend, name, markrgnindexnumber, color
		end
		i = i + 1
	end
	return 0
end