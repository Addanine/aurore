-- plugin/aurore.lua
if vim.g.loaded_aurore then
  return
end
vim.g.loaded_aurore = true

-- Create user command
vim.api.nvim_create_user_command('Aurore', function(opts)
    require('aurore.api').execute_task(table.concat(opts.fargs, ' '))
end, {
    nargs = '+',
    desc = 'Execute an AI task'
})
