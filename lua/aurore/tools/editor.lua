-- lua/aurore/tools/editor.lua
local M = {}

M.setup = function()
    -- Any setup needed
end

M.execute = function(cmd)
    local ok, result = pcall(vim.cmd, cmd)
    return ok, result
end

M.get_visual_selection = function()
    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")
    local lines = vim.fn.getline(start_pos[2], end_pos[2])
    return table.concat(lines, "\n")
end

return M
