-- In lua/aurore/tools/bash.lua
local M = {}

M.setup = function()
    -- Any setup needed
end

M.execute = function(cmd)
    local handle = io.popen(cmd)
    if not handle then
        return false, "Failed to execute command"
    end
    
    local result = handle:read("*a")
    handle:close()
    
    return true, result
end

-- Add new function for checking server status
M.check_server = function(url, port)
    -- Try curl first (more reliable)
    local curl_cmd = string.format("curl -s -o /dev/null -w '%%{http_code}' http://%s:%s", url, port)
    local success, result = M.execute(curl_cmd)
    
    if success and result:match("200") then
        return true, "Server is running"
    end
    
    -- Fallback to nc (netcat) to check if port is open
    local nc_cmd = string.format("nc -z %s %s", url, port)
    success, _ = M.execute(nc_cmd)
    
    if success then
        return true, "Port is open"
    end
    
    return false, "Server is not responding"
end

return M
