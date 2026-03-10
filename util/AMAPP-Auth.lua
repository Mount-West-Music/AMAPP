--[[
    AMAPP-Auth.lua
    Authorization wrapper for AMAPP C++ extension

    This module provides a Lua interface to the C++ auth functions.
    If the C++ extension is not loaded, authentication will fail
    (dev mode must be explicitly enabled and is stripped in release builds).
]]

local Auth = {}










if BUILD_TYPE == nil then BUILD_TYPE = "production" end
if DEV_MODE_AVAILABLE == nil then DEV_MODE_AVAILABLE = false end



Auth.FEATURE_NONE           = 0
Auth.FEATURE_BASIC          = 1       
Auth.FEATURE_RENDER         = 2       
Auth.FEATURE_WWISE          = 4       
Auth.FEATURE_WAXML          = 8       
Auth.FEATURE_BATCH          = 16      
Auth.FEATURE_ADVANCED_UI    = 32      
Auth.FEATURE_IMPLEMENTATION = 64      



Auth.TIER_SCOUT       = 0xFFFFFFFF  
Auth.TIER_CARTOGRAPHER = 0xFFFFFFFF  
Auth.TIER_EXPEDITION  = 0xFFFFFFFF  
Auth.TIER_PHOENIX     = 0xFFFFFFFF  


local session_token = nil
local extension_available = false
local dev_mode = false  


local function check_extension()
    if extension_available then return true end

    if reaper.AMAPP_Authenticate then
        extension_available = true
        return true
    end

    return false
end



function Auth.init()
    check_extension()

    if extension_available then
        local version = reaper.AMAPP_GetAuthVersion()
        
    end

    return extension_available
end



function Auth.is_extension_loaded()
    return check_extension()
end




function Auth.authenticate(license_key)
    if not license_key or license_key == "" then
        return false, "No license key provided"
    end

    if not check_extension() then
        if dev_mode then
            session_token = "DEV_MODE_TOKEN"
            return true, nil
        end
        return false, "Auth extension not loaded"
    end

    local token = reaper.AMAPP_Authenticate(license_key)

    if token and token ~= "" then
        session_token = token
        return true, nil
    else
        session_token = nil
        return false, "Invalid license key"
    end
end



function Auth.is_authenticated()
    if dev_mode and session_token == "DEV_MODE_TOKEN" then
        return true
    end

    if not check_extension() then
        return dev_mode
    end

    if not session_token then
        return false
    end

    return reaper.AMAPP_ValidateSession(session_token)
end



function Auth.get_session_token()
    return session_token
end



function Auth.get_features()
    if dev_mode and not extension_available then
        return Auth.TIER_FULL  
    end

    if not check_extension() then
        return Auth.FEATURE_NONE
    end

    return reaper.AMAPP_GetFeatureFlags()
end




function Auth.has_feature(feature)
    if dev_mode and not extension_available then
        return true  
    end

    if not check_extension() then
        return false
    end

    return reaper.AMAPP_HasFeature(feature)
end



function Auth.get_hardware_id()
    if not check_extension() then
        return nil
    end

    return reaper.AMAPP_GetHardwareId()
end


function Auth.deauthenticate()
    session_token = nil

    if check_extension() then
        reaper.AMAPP_Deauthenticate()
    end
end



function Auth.get_version()
    if not check_extension() then
        return "lua-only"
    end

    return reaper.AMAPP_GetAuthVersion()
end





function Auth.set_dev_mode(enabled)
    if not DEV_MODE_AVAILABLE then
        
        return false
    end

    dev_mode = enabled
    if enabled then
        session_token = "DEV_MODE_TOKEN"
    end
    return true
end



function Auth.is_dev_mode()
    return dev_mode and DEV_MODE_AVAILABLE
end



function Auth.is_dev_mode_available()
    return DEV_MODE_AVAILABLE
end



function Auth.get_build_type()
    return BUILD_TYPE
end





function Auth.check_access(required_feature)
    if not Auth.is_authenticated() then
        return false, "Not authenticated"
    end

    if required_feature and not Auth.has_feature(required_feature) then
        return false, "Feature not available in your license tier"
    end

    return true, nil
end




function Auth.get_tier_name(tier_code)
    if tier_code == "P" then
        return "Phoenix"
    elseif tier_code == "E" then
        return "Expedition"
    elseif tier_code == "C" then
        return "Cartographer"
    elseif tier_code == "S" then
        return "Scout"
    else
        return "Unknown"
    end
end

return Auth
