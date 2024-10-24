local M = {}

local defaults = {
    ai_provider = "openai",
    openai_api_key = nil,
    openai_model = "gpt-4o",
    anthropic_api_key = nil,
    anthropic_model = "claude-3-5-sonnet-20241022",
    ui = {
        border = "rounded",
        width = 0.8,
        height = 0.8,
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
