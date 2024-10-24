local M = {}

local queue = {
    tasks = {},
    current = nil,
    ui = require('aurore.ui.status'),
}

function M.add_task(task)
    table.insert(queue.tasks, {
        description = task.description,
        callback = task.callback,
        status = 'pending'
    })
    
    M.update_ui()
    
    if not queue.current then
        M.process_next()
    end
end

function M.process_next()
    if #queue.tasks == 0 then
        queue.current = nil
        return
    end

    queue.current = table.remove(queue.tasks, 1)
    queue.current.status = 'running'
    
    M.update_ui()
    
    -- Execute task
    queue.current.callback(function(success)
        if success then
            queue.current.status = 'completed'
        else
            queue.current.status = 'failed'
        end
        
        M.update_ui()
        queue.current = nil
        M.process_next()
    end)
end

function M.update_ui()
    queue.ui.update({
        task_queue = queue.tasks,
        current_task = queue.current
    })
end

return M
