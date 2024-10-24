-- in lua/aurore/keymaps.lua
local M = {}

function M.setup()
    -- Cancel current task
    vim.keymap.set('n', '<leader>ac', function()
        -- Add cancel function
    end, { desc = 'Cancel AI Task' })

    -- Show task history
    vim.keymap.set('n', '<leader>ah', function()
        -- Add history viewer
    end, { desc = 'Show AI Task History' })

    -- Retry last task
    vim.keymap.set('n', '<leader>ar', function()
        -- Add retry function
    end, { desc = 'Retry Last AI Task' })
end

return M
