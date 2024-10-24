-- lua/aurore/tools/editor.lua
local M = {}

M.setup = function()
    -- Any setup needed
end

-- Helper function to handle multiline text
local function write_multiple_lines(content)
    -- Convert string to table of lines if it isn't already
    local lines = type(content) == "string" 
        and vim.split(content, "\n", { plain = true })
        or content

    -- Get current buffer
    local bufnr = vim.api.nvim_get_current_buf()
    
    -- Get current line count
    local line_count = vim.api.nvim_buf_line_count(bufnr)
    
    -- Append the lines to the end of the buffer
    vim.api.nvim_buf_set_lines(bufnr, line_count, line_count, false, lines)
    
    return true, "Lines written successfully"
end

M.execute = function(cmd)
    if type(cmd) == "table" then
        if cmd.type == "create_file" then
            -- Create or open the file
            vim.cmd('edit ' .. cmd.filename)
            return true, "File opened"
            
        elseif cmd.type == "write_line" then
            -- Handle multiline content
            return write_multiple_lines(cmd.content)
            
        elseif cmd.type == "append_line" then
            -- Handle multiline content
            return write_multiple_lines(cmd.content)
            
        elseif cmd.type == "write_buffer" then
            -- Clear buffer and write content
            local bufnr = vim.api.nvim_get_current_buf()
            local lines = type(cmd.content) == "string" 
                and vim.split(cmd.content, "\n", { plain = true })
                or cmd.content
            vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
            return true, "Buffer written"
            
        elseif cmd.type == "save_buffer" then
            vim.cmd('write')
            return true, "File saved"
        end
    end
    
    -- Legacy support for string commands
    if type(cmd) == "string" then
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
