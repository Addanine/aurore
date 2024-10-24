-- in lua/aurore/debug.lua
local M = {}

local debug_state = {
    enabled = false,
    log_file = nil,
    start_time = nil
}

function M.start_debug_session()
    debug_state.enabled = true
    debug_state.start_time = os.time()
    debug_state.log_file = string.format(
        '%s/aurore_debug_%s.log',
        vim.fn.stdpath('cache'),
        os.date('%Y%m%d_%H%M%S')
    )
end

function M.log(category, message)
    if not debug_state.enabled then return end
    
    local f = io.open(debug_state.log_file, 'a')
    if f then
        f:write(string.format(
            '[%s] %s: %s\n',
            os.date('%H:%M:%S'),
            category,
            message
        ))
        f:close()
    end
end

return M
