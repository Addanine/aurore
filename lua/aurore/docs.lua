-- in lua/aurore/docs.lua
local M = {}

function M.generate_task_doc(task_history)
    local doc = {
        "# Task Documentation",
        "",
        "## Steps Performed",
        ""
    }
    
    for _, step in ipairs(task_history) do
        table.insert(doc, string.format("1. %s", step.description))
        if step.output then
            table.insert(doc, "   ```")
            table.insert(doc, step.output)
            table.insert(doc, "   ```")
        end
    end
    
    return table.concat(doc, "\n")
end

return M
