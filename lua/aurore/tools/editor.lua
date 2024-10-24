-- lua/aurore/tools/editor.lua
local M = {}

-- Helper functions for common operations
local function create_file(filename)
    vim.cmd('new ' .. vim.fn.fnameescape(filename))
    return true, "File created"
end

local function write_line(line, row)
    row = row or vim.api.nvim_win_get_cursor(0)[1]
    local ok, err = pcall(function()
        vim.api.nvim_buf_set_lines(0, row-1, row-1, false, {line})
    end)
    return ok, err or "Line written"
end

local function append_line(line)
    local last_line = vim.api.nvim_buf_line_count(0)
    return write_line(line, last_line + 1)
end

local function write_buffer(content)
    if type(content) == "string" then
        content = vim.split(content, "\n")
    end
    local ok, err = pcall(function()
        vim.api.nvim_buf_set_lines(0, 0, -1, false, content)
    end)
    return ok, err or "Buffer written"
end

local function save_buffer(filename)
    if filename then
        vim.cmd('write ' .. vim.fn.fnameescape(filename))
    else
        vim.cmd('write')
    end
    return true, "File saved"
end

M.setup = function()
    -- Any setup needed
end

M.execute = function(cmd)
    -- Handle command objects with type and params
    if type(cmd) == "table" then
        if cmd.type == "create_file" then
            return create_file(cmd.filename)
        elseif cmd.type == "write_line" then
            return write_line(cmd.content, cmd.row)
        elseif cmd.type == "append_line" then
            return append_line(cmd.content)
        elseif cmd.type == "write_buffer" then
            return write_buffer(cmd.content)
        elseif cmd.type == "save_buffer" then
            return save_buffer(cmd.filename)
        end
    end

    -- Handle string commands (legacy support)
    if type(cmd) == "string" then
        -- If it's an insert command, handle it specially
        if cmd:match("^insert") then
            local text = cmd:match("insert%s+(.+)")
            if text then
                local line = vim.api.nvim_get_current_line()
                local row, col = unpack(vim.api.nvim_win_get_cursor(0))
                vim.api.nvim_buf_set_text(0, row-1, col, row-1, col, {text})
                return true, "Text inserted"
            end
        end
        
        -- For other commands, use pcall with vim.cmd
        local ok, result = pcall(vim.cmd, cmd)
        if not ok then
            vim.notify("Failed to execute vim command: " .. cmd, vim.log.levels.ERROR)
            return false, result
        end
        return ok, result
    end
    return false, "Invalid command type"
end

M.get_visual_selection = function()
    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")
    local lines = vim.fn.getline(start_pos[2], end_pos[2])
    return table.concat(lines, "\n")
end

return M
