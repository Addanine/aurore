local M = {}

function M.get_status()
    local branch = vim.fn.system('git rev-parse --abbrev-ref HEAD'):gsub('\n', '')
    local changes = vim.fn.system('git status --porcelain'):gsub('\n', '')
    local changed_files = #vim.split(changes, '\n')
    
    return {
        branch = branch,
        changed_files = changed_files,
        has_changes = changed_files > 0
    }
end

function M.stage_file(file)
    return vim.fn.system('git add ' .. file)
end

function M.commit(message)
    return vim.fn.system('git commit -m "' .. message .. '"')
end

function M.push()
    return vim.fn.system('git push')
end

-- Function for AI to use
function M.auto_commit(description)
    local status = M.get_status()
    if status.has_changes then
        M.stage_file('.')
        local message = string.format('[Aurore AI] %s', description)
        M.commit(message)
        return true, "Changes committed successfully"
    end
    return false, "No changes to commit"
end

return M
