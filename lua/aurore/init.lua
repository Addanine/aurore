local M = {}

M.setup = function(opts)
    -- Load default config
    local config = require('aurore.config')
    
    -- Merge user options with defaults
    config.setup(opts)
    
    -- Initialize API with config
    require('aurore.api').setup(config.options)
    
    -- Initialize UI
    require('aurore.ui').setup()
    
    -- Initialize tools
    require('aurore.tools').setup()
end

return M
