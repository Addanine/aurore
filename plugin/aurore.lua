local aurore = require('aurore')

vim.api.nvim_create_user_command('Aurore', function(opts)
    aurore.execute_task(opts.args)
end, {
    nargs = '+',
    desc = 'Execute an AI task'
})
