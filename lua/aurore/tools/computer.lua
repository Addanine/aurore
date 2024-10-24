-- lua/aurore/tools/computer.lua
local M = {}

M.setup = function()
    -- Any setup needed
end

M.handle_file_operation = function(operation)
    if operation.type == "write" then
        local file = io.open(operation.path, "w")
        if not file then
            return false, "Failed to open file for writing"
        end
        file:write(operation.content)
        file:close()
        return true, "File written successfully"
    end
    
    return false, "Unknown operation type"
end

return M
