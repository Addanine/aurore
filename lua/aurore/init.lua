local M = {}

M.setup = function(opts)
    -- Only show messages if quiet is not enabled
    if not opts.quiet then
        vim.notify("Loading aurore with opts: " .. vim.inspect(opts))
    end
    
    local config = require('aurore.config')
    config.setup(opts)
    
    require('aurore.api').setup(config.options)
    require('aurore.ui').setup(config.options)
    require('aurore.tools').setup()
end

return M
