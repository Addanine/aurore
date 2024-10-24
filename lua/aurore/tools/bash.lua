-- lua/aurore/tools/bash.lua
local M = {}

M.setup = function()
    -- Any setup needed for bash commands
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

return M
