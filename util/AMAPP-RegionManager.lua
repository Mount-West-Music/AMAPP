--[[
    Library/Component: AMAPP
    Copyright (c) 2026 Mount West Music AB
    All rights reserved.

    AMAPP-RegionManager.lua
    Region/Marker GUID Tracking System

    This module provides a unified API for region management using the C++ extension.
    The C++ extension handles the two-index problem in REAPER's marker/region API.
--]]

local RegionManager = {}
RegionManager.__index = RegionManager


local function RequireCppExtension()
    if reaper.AMAPP_GetEnumIndexFromGUID == nil then
        error("AMAPP C++ extension (reaper_amapp) is not loaded. Please restart REAPER.", 2)
    end
end

---@param guid string The GUID to look up
---@return number enumIndex The enumeration index, or -1 if not found
function RegionManager.GetEnumIndexFromGUID(guid)
    RequireCppExtension()
    return reaper.AMAPP_GetEnumIndexFromGUID(guid)
end

---@param enumIndex number The enumeration index
---@return number displayIndex The user-visible display index, or -1 if not found
function RegionManager.GetDisplayIndexFromEnum(enumIndex)
    RequireCppExtension()
    return reaper.AMAPP_GetDisplayIndexFromEnum(enumIndex)
end

---@param enumIndex number The enumeration index
---@return string guid The GUID string, or empty string if not found
function RegionManager.GetGUIDFromEnumIndex(enumIndex)
    RequireCppExtension()
    local retval, guid = reaper.AMAPP_GetGUIDFromEnumIndex(enumIndex)
    return retval and guid or ""
end

---@param position number Start position in seconds
---@param regionEnd number End position in seconds
---@param name string Region name
---@param color number|nil Color value (0x01BBGGRR format), optional
---@return string guid The GUID of the created region, or empty string on failure
function RegionManager.CreateRegionWithGUID(position, regionEnd, name, color)
    RequireCppExtension()
    local retval, guid = reaper.AMAPP_CreateRegionWithGUID(position, regionEnd, name, color or 0)
    return retval and guid or ""
end

---@param guid string The GUID to validate
---@return boolean exists True if region still exists
function RegionManager.ValidateRegionGUID(guid)
    RequireCppExtension()
    return reaper.AMAPP_ValidateRegionGUID(guid)
end

---@param guid string The GUID of the region to delete
---@return boolean success True if deletion successful
function RegionManager.DeleteRegionByGUID(guid)
    RequireCppExtension()
    return reaper.AMAPP_DeleteRegionByGUID(guid)
end

---@param guid string The GUID of the region
---@param newPosition number|nil New start position, or nil to keep current
---@param newEnd number|nil New end position, or nil to keep current
---@return boolean success True if update successful
function RegionManager.UpdateRegionBoundaries(guid, newPosition, newEnd)
    RequireCppExtension()
    return reaper.AMAPP_UpdateRegionBoundaries(guid, newPosition or -1, newEnd or -1)
end

---@param guid string The GUID of the region
---@param newColor number New color value (0x01BBGGRR format)
---@return boolean success True if update successful
function RegionManager.UpdateRegionColor(guid, newColor)
    RequireCppExtension()
    return reaper.AMAPP_UpdateRegionColor(guid, newColor)
end

---@class RegionInfo
---@field enumIndex number 0-based enumeration index
---@field displayIndex number User-visible marker/region number
---@field position number Start position in seconds
---@field regionEnd number End position in seconds
---@field name string Region name
---@field guid string Unique GUID
---@field color number Color value
---@field isRegion boolean True if region, false if marker

---@param guid string The GUID to look up
---@return RegionInfo|nil info Region information, or nil if not found
function RegionManager.GetRegionByGUID(guid)
    RequireCppExtension()
    local retval, pos, rgnend, name, color, enumIdx, displayIdx =
        reaper.AMAPP_GetRegionByGUID(guid)
    if retval then
        return {
            enumIndex = enumIdx,
            displayIndex = displayIdx,
            position = pos,
            regionEnd = rgnend,
            name = name,
            guid = guid,
            color = color,
            isRegion = true
        }
    end
    return nil
end

---@param name string The region name to look up
---@return RegionInfo|nil info Region information, or nil if not found
function RegionManager.GetRegionByName(name)
    RequireCppExtension()
    local retval, guid, pos, rgnend, color, enumIdx =
        reaper.AMAPP_GetRegionByName(name)
    if retval then
        local _, _, _, _, _, displayIdx = reaper.EnumProjectMarkers3(0, enumIdx)
        return {
            enumIndex = enumIdx,
            displayIndex = displayIdx,
            position = pos,
            regionEnd = rgnend,
            name = name,
            guid = guid,
            color = color,
            isRegion = true
        }
    end
    return nil
end

---@return boolean True if C++ extension is loaded
function RegionManager.IsCppExtensionLoaded()
    return reaper.AMAPP_GetEnumIndexFromGUID ~= nil
end

---Cache all region display indices (GUID -> displayIndex mapping)
---Call this before operations that may reorder regions (like timeline renumbering)
---@return table<string, number> cache A table mapping region GUIDs to their display indices
function RegionManager.CacheAllRegionIndices()
    local cache = {}
    local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
    local total = num_markers + num_regions

    for i = 0, total - 1 do
        local retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers3(0, i)
        if retval and isrgn then
            
            local guid = RegionManager.GetGUIDFromEnumIndex(i)
            if guid and guid ~= "" then
                cache[guid] = markrgnindexnumber
            end
        end
    end

    return cache
end

---Restore region display indices from a cached mapping
---Call this after operations that may have reordered regions
---@param cache table<string, number> The cached GUID -> displayIndex mapping
---@return boolean success True if all indices were restored successfully
function RegionManager.RestoreRegionIndices(cache)
    if not cache then return false end

    local success = true
    for guid, targetIndex in pairs(cache) do
        
        local enumIndex = RegionManager.GetEnumIndexFromGUID(guid)
        if enumIndex >= 0 then
            
            local retval, isrgn, pos, rgnend, name, currentIndex, color = reaper.EnumProjectMarkers3(0, enumIndex)
            if retval and isrgn and currentIndex ~= targetIndex then
                
                
                local ok = reaper.SetProjectMarkerByIndex2(0, enumIndex, true, pos, rgnend, targetIndex, name, color or 0, 0)
                if not ok then
                    success = false
                end
            end
        else
            
            success = false
        end
    end

    return success
end

return RegionManager
