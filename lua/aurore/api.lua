local M = {}
local curl = require('plenary.curl')

-- Store config reference
local config = nil
local tools = nil

-- API endpoints
local ENDPOINTS = {
    openai = "https://api.openai.com/v1/chat/completions",
    anthropic = "https://api.anthropic.com/v1/messages",
}

-- Agent system prompt that encourages autonomous behavior
local AGENT_PROMPT = [[You are an autonomous AI agent with direct access to a computer through Neovim. You can:
1. Execute terminal commands
2. Modify files
3. Control Neovim
4. Plan and execute multi-step tasks

RESPONSE FORMAT:
Always respond with JSON in this structure:
{
    "thought": "Your current thinking process",
    "plan": ["Step 1", "Step 2", ...],
    "current_step": {
        "commands": [], // shell commands to execute
        "vim_commands": [], // neovim commands to execute
        "file_operations": [], // file operations to perform
        "message": "" // explanation for the user
    },
    "next_step": "What you plan to do next",
    "task_complete": false // true when the entire task is done
}

IMPORTANT:
- Think step by step
- Request user confirmation for dangerous operations
- Keep the user informed of your plan
- Continue executing steps until the task is complete
- You can read file contents and command outputs to inform your next steps]]

-- OpenAI API call
local function call_openai(prompt, context)
    local response = curl.post(ENDPOINTS.openai, {
        headers = {
            Authorization = "Bearer " .. config.openai_api_key,
            ["Content-Type"] = "application/json",
        },
        body = vim.json.encode({
            model = config.openai_model or "gpt-4",
            messages = {
                { role = "system", content = AGENT_PROMPT },
                { role = "user", content = vim.json.encode({
                    command = prompt,
                    context = context
                })}
            },
            temperature = 0.7,
            -- Remove the response_format parameter since it's not supported
        })
    })
    
    if response.status ~= 200 then
        vim.notify("OpenAI API error: " .. (response.body or "Unknown error"), vim.log.levels.ERROR)
        return nil
    end
    
    local result = vim.json.decode(response.body)
    -- Since we're not forcing JSON format, we need to parse the content as JSON
    local content = result.choices[1].message.content
    -- The content might already be JSON, so we need to handle both cases
    local success, parsed = pcall(vim.json.decode, content)
    if success then
        return parsed
    else
        vim.notify("Failed to parse AI response as JSON", vim.log.levels.ERROR)
        return nil
    end
end



-- Anthropic API call
local function call_anthropic(prompt, context)
    local response = curl.post(ENDPOINTS.anthropic, {
        headers = {
            ["X-Api-Key"] = config.anthropic_api_key,
            ["Content-Type"] = "application/json",
            ["anthropic-version"] = "2023-06-01"
        },
        body = vim.json.encode({
            model = config.anthropic_model or "claude-3-opus-20240229",
            max_tokens = 1024,
            messages = {
                {
                    role = "user",
                    content = string.format([[%s
Context: %s
Command: %s
Respond only with JSON in the specified format.]], 
                        AGENT_PROMPT,
                        vim.json.encode(context),
                        prompt
                    )
                }
            }
        })
    })
    
    if response.status ~= 200 then
        vim.notify("Anthropic API error: " .. (response.body or "Unknown error"), vim.log.levels.ERROR)
        return nil
    end
    
    local result = vim.json.decode(response.body)
    return vim.json.decode(result.content[1].text)
end

-- Send request to AI provider
local function send_ai_request(prompt, context)
    if config.ai_provider == "openai" then
        return call_openai(prompt, context)
    elseif config.ai_provider == "anthropic" then
        return call_anthropic(prompt, context)
    else
        vim.notify("Unknown AI provider: " .. tostring(config.ai_provider), vim.log.levels.ERROR)
        return nil
    end
end

-- Function to check if operations were successful
local function check_operation_success(results)
    for _, cmd_result in ipairs(results.command_outputs or {}) do
        if not cmd_result.success then
            return false, "Command failed: " .. cmd_result.command
        end
    end
    
    for _, vim_result in ipairs(results.vim_outputs or {}) do
        if not vim_result.success then
            return false, "Vim command failed: " .. vim_result.command
        end
    end
    
    for _, file_result in ipairs(results.file_operations or {}) do
        if not file_result.success then
            return false, "File operation failed: " .. vim.inspect(file_result.operation)
        end
    end
    
    return true, ""
end

-- Execute a single step of the agent's plan
local function execute_step(step)
    local results = {
        command_outputs = {},
        vim_outputs = {},
        file_operations = {},
    }
    
    -- Execute shell commands
    for _, cmd in ipairs(step.commands or {}) do
        local success, output = tools.bash.execute(cmd)
        table.insert(results.command_outputs, {
            command = cmd,
            success = success,
            output = output
        })
    end
    
    -- Execute vim commands
    for _, cmd in ipairs(step.vim_commands or {}) do
        local success, output = tools.editor.execute(cmd)
        table.insert(results.vim_outputs, {
            command = cmd,
            success = success,
            output = output
        })
    end
    
    -- Handle file operations
    for _, op in ipairs(step.file_operations or {}) do
        local success, output = tools.computer.handle_file_operation(op)
        table.insert(results.file_operations, {
            operation = op,
            success = success,
            output = output
        })
    end
    
    return results
end

-- Function to continue agent execution
local function continue_execution(previous_results, task_context, initial_prompt)
    local context = vim.tbl_extend("force", task_context or {}, {
        previous_results = previous_results,
        initial_prompt = initial_prompt,
        cwd = vim.fn.getcwd(),
        current_file = vim.fn.expand('%:p'),
    })
    
    return send_ai_request("Continue with the next step based on previous results.", context)
end

-- Main agent loop
local function run_agent(initial_prompt)
    local context = {
        cwd = vim.fn.getcwd(),
        current_file = vim.fn.expand('%:p'),
        filetype = vim.bo.filetype,
        initial_prompt = initial_prompt
    }
    
    -- Initial plan
    local response = send_ai_request(initial_prompt, context)
    if not response then return end
    
    -- Show initial plan to user
    vim.api.nvim_echo({{"AI Plan:\n", "Title"}}, false, {})
    for i, step in ipairs(response.plan) do
        vim.api.nvim_echo({{i .. ". " .. step .. "\n", "Normal"}}, false, {})
    end
    
    -- Execute steps until task is complete
    while not response.task_complete do
        -- Show current thought process
        vim.api.nvim_echo({{"Thinking: " .. response.thought .. "\n", "Comment"}}, false, {})
        
        -- Execute current step
        local step_results = execute_step(response.current_step)
        
        -- Check if successful
        local success, error = check_operation_success(step_results)
        if not success then
            vim.notify("Error executing step: " .. error, vim.log.levels.ERROR)
            return
        end
        
        -- Show message to user
        if response.current_step.message then
            vim.api.nvim_echo({{"AI: " .. response.current_step.message .. "\n", "Normal"}}, false, {})
        end
        
        -- Get next step
        response = continue_execution(step_results, context, initial_prompt)
        if not response then return end
        
        -- Optional: sleep briefly to not overwhelm the system
        vim.cmd('sleep 100m')
    end
    
    vim.api.nvim_echo({{"Task completed!\n", "Title"}}, false, {})
end

-- Initialize the API
M.setup = function(opts)
    config = opts
    tools = require('aurore.tools')
end

-- Main entry point for user commands
M.execute_task = function(prompt)
    run_agent(prompt)
end

return M
