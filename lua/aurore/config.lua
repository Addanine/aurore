local M = {}

local defaults = {
    ai_provider = "openai", -- or "anthropic"
    api_key = nil, -- will prompt user if not set
    ui = {
        border = "rounded",
        width = 0.8,    -- percentage of screen width
        height = 0.8,   -- percentage of screen height
    },
    keymaps = {
        toggle = "<leader>ai",
        submit = "<CR>",
        close = "q",
    }
}

M.options = {}

M.setup = function(opts)
    M.options = vim.tbl_deep_extend("force", {}, defaults, opts or {})
end

return M
