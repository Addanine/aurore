local M = {}

-- Store UI state
local state = {
    win = nil,
    buf = nil,
    server_status = {},
    task_queue = {},
    git_status = {},
}

local function create_status_window()
    if state.win and vim.api.nvim_win_is_valid(state.win) then
        return
    end

    local width = math.floor(vim.o.columns * 0.8)
    local height = math.floor(vim.o.lines * 0.4)
    
    -- Create buffer
    state.buf = vim.api.nvim_create_buf(false, true)
    
    -- Set buffer options
    vim.api.nvim_buf_set_option(state.buf, 'modifiable', false)
    vim.api.nvim_buf_set_option(state.buf, 'buftype', 'nofile')
    
    -- Create window
    state.win = vim.api.nvim_open_win(state.buf, false, {
        relative = 'editor',
        width = width,
        height = height,
        row = vim.o.lines - height - 2,
        col = math.floor((vim.o.columns - width) / 2),
        style = 'minimal',
        border = 'rounded'
    })

    -- Set window options
    vim.api.nvim_win_set_option(state.win, 'wrap', false)
    
    return state.win
end

function M.update(data)
    if not state.win or not vim.api.nvim_win_is_valid(state.win) then
        create_status_window()
    end

    local lines = {
        "╭─ Aurore Status ─────────────────────────────╮",
        "│                                             │",
    }

    -- Add server status if available
    if data.server_status then
        table.insert(lines, "│  Server Status:                              │")
        for url, status in pairs(data.server_status) do
            table.insert(lines, string.format("│    %s: %s", url, status))
        end
    end

    -- Add task queue info
    if data.task_queue then
        table.insert(lines, "│                                             │")
        table.insert(lines, "│  Task Queue:                                │")
        for i, task in ipairs(data.task_queue) do
            table.insert(lines, string.format("│    %d. %s", i, task.description))
        end
    end

    -- Add git status
    if data.git_status then
        table.insert(lines, "│                                             │")
        table.insert(lines, "│  Git Status:                                │")
        table.insert(lines, string.format("│    Branch: %s", data.git_status.branch))
        table.insert(lines, string.format("│    Changes: %d files", data.git_status.changed_files))
    end

    table.insert(lines, "╰─────────────────────────────────────────────╯")

    -- Update buffer content
    vim.api.nvim_buf_set_option(state.buf, 'modifiable', true)
    vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(state.buf, 'modifiable', false)
end

function M.close()
    if state.win and vim.api.nvim_win_is_valid(state.win) then
        vim.api.nvim_win_close(state.win, true)
    end
    state.win = nil
    state.buf = nil
end

return M
