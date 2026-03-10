
local function split_version(version)
    local parts = {}
    for num in version:gmatch("(%d+)") do
        table.insert(parts, tonumber(num))
    end
    return parts
end


local function is_version_lower(version_a, version_b)
    local a_parts = split_version(version_a)
    local b_parts = split_version(version_b)

    for i = 1, math.max(#a_parts, #b_parts) do
        local a_num = a_parts[i] or 0
        local b_num = b_parts[i] or 0

        if a_num < b_num then
            return true 
        elseif a_num > b_num then
            return false 
        end
    end

    return false 
end