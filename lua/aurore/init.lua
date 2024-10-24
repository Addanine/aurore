local M = {}

M.setup = function(opts)
    -- Debug prints
    vim.notify("Loading aurore with opts: " .. vim.inspect(opts))
    
    -- First load config
    local config = require('aurore.config')
    vim.notify("Config loaded")
    
    -- Setup config
    config.setup(opts)
    vim.notify("Config setup complete")

    -- Initialize components
    require('aurore.api').setup(config.options)
    require('aurore.ui').setup(config.options)
    require('aurore.tools').setup()
end

return M
