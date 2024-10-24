-- init.lua
local M = {}

-- Helper function to safely require a module
local function safe_require(module)
    local ok, result = pcall(require, module)
    if not ok then
        vim.notify(string.format("Failed to require '%s': %s", module, result), vim.log.levels.ERROR)
        return nil
    end
    return result
end

M.setup = function(opts)
    -- Load and setup config first
    local config = safe_require('aurore.config')
    if not config then
        return
    end
    
    -- Setup config with options
    config.setup(opts)
    
    -- Store the configured options
    local options = config.options
    
    -- Components to initialize in order
    local components = {
        { name = 'debug', required = false },
        { name = 'api', required = true },
        { name = 'ui', required = true },
        { name = 'tools', required = true },
        { name = 'keymaps', required = false },
        { name = 'recovery', required = false },
        { name = 'queue', required = false },
        { name = 'git', required = false },
        { name = 'lsp', required = false }
    }
    
    -- Initialize each component with the config options
    for _, component in ipairs(components) do
        local module = safe_require('aurore.' .. component.name)
        if module then
            if type(module.setup) == 'function' then
                local ok, err = pcall(module.setup, options)
                if not ok then
                    vim.notify(string.format("Failed to setup '%s': %s", component.name, err), vim.log.levels.ERROR)
                    if component.required then
                        return
                    end
                end
            end
        elseif component.required then
            vim.notify(string.format("Required component '%s' could not be loaded", component.name), vim.log.levels.ERROR)
            return
        end
    end

    -- Set up global command
    vim.api.nvim_create_user_command('Aurore', function(opts)
        local api = safe_require('aurore.api')
        if api then
            api.execute_task(table.concat(opts.fargs, ' '))
        end
    end, {
        nargs = '+',
        desc = 'Execute an AI task'
    })

    vim.notify("Aurore initialized successfully", vim.log.levels.INFO)
end

return M
