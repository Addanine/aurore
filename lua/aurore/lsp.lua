local M = {}

function M.get_diagnostics()
    local diagnostics = vim.diagnostic.get(0)
    local result = {}
    
    for _, diagnostic in ipairs(diagnostics) do
        table.insert(result, {
            line = diagnostic.lnum + 1,
            severity = diagnostic.severity,
            message = diagnostic.message
        })
    end
    
    return result
end

function M.get_suggestions()
    local params = vim.lsp.util.make_range_params()
    params.context = {
        diagnostics = vim.lsp.diagnostic.get_line_diagnostics()
    }
    
    local result = vim.lsp.buf_request_sync(0, 'textDocument/codeAction', params, 1000)
    return result
end

function M.apply_suggestion(suggestion)
    if suggestion.edit then
        vim.lsp.util.apply_workspace_edit(suggestion.edit)
    end
    
    if suggestion.command then
        vim.lsp.buf.execute_command(suggestion.command)
    end
end

return M
