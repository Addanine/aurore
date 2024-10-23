local M = {}

-- Store UI state
local state = {
    win = nil,
    buf = nil,
    total_steps = 0,
    current_step = 0
}

-- Create a floating window
function M.create_progress_window()
    -- Calculate window size
    local width = 60
    local height = 10
    local win_opts = {
        relative = 'editor',
        width = width,
        height = height,
        row = (vim.o.lines - height) * 0.5,
        col = (vim.o.columns - width) * 0.5,
        style = 'minimal',
        border = 'rounded'
    }

    -- Create buffer
    state.buf = vim.api.nvim_create_buf(false, true)
    
    -- Create window
    state.win = vim.api.nvim_open_win(state.buf, false, win_opts)
    
    -- Set buffer options
    vim.api.nvim_buf_set_option(state.buf, 'modifiable', false)
    
    return state.buf, state.win
end

-- Update progress display
function M.update_progress(step, total, message)
    if not state.win or not vim.api.nvim_win_is_valid(state.win) then
        M.create_progress_window()
    end
    
    state.current_step = step
    state.total_steps = total
    
    -- Create progress bar
    local width = 50
    local filled = math.floor(width * (step / total))
    local progress_bar = string.rep('█', filled) .. string.rep('░', width - filled)
    
    -- Create content
    local lines = {
        '',
        '  Aurore AI Assistant',
        '  ' .. string.rep('─', 56),
        '',
        string.format('  Progress: %d/%d', step, total),
        '  ' .. progress_bar,
        '',
        '  ' .. (message or 'Processing...'),
    }
    
    -- Update buffer
    vim.api.nvim_buf_set_option(state.buf, 'modifiable', true)
    vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(state.buf, 'modifiable', false)
end

-- Close progress window
function M.close_progress()
    if state.win and vim.api.nvim_win_is_valid(state.win) then
        vim.api.nvim_win_close(state.win, true)
    end
    state.win = nil
    state.buf = nil
end

return M
