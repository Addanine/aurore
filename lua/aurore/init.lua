local M = {}

M.setup = function(opts)
    -- Load default config
    local config = require('aurore.config')
    
    -- Merge user options with defaults
    config.setup(opts)
    
    -- Initialize API
    require('aurore.api').setup()
    
    -- Initialize UI
    require('aurore.ui').setup()
    
    -- Initialize tools
    require('aurore.tools').setup()
end

return M
