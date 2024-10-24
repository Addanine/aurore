-- in lua/aurore/recovery.lua
local M = {}

local function create_checkpoint()
    return {
        buffers = {},
        cursor_positions = {},
        timestamp = os.time()
    }
end

function M.save_checkpoint()
    local checkpoint = create_checkpoint()
    
    -- Save current buffer states
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(bufnr) then
            checkpoint.buffers[bufnr] = {
                lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false),
                name = vim.api.nvim_buf_get_name(bufnr)
            }
        end
    end
    
    return checkpoint
end

function M.restore_checkpoint(checkpoint)
    -- Restore buffer states
    for bufnr, state in pairs(checkpoint.buffers) do
        if vim.api.nvim_buf_is_valid(bufnr) then
            vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, state.lines)
        end
    end
end

return M
