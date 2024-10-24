-- lua/aurore/tools/init.lua
local M = {}

M.setup = function()
    -- Initialize each tool module
end

-- Load tool modules
M.bash = require('aurore.tools.bash')
M.computer = require('aurore.tools.computer')
M.editor = require('aurore.tools.editor')

return M
