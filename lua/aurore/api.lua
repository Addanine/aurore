local M = {}
local curl = require('plenary.curl')
local json = require('cjson')

local config = require('aurore.config').options
local tools = require('aurore.tools')

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

-- Function to check if operations were successful
local function check_operation_success(results)
    -- We'll implement this to check if commands succeeded
    return true, "" -- success, error_message
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

-- OpenAI API call
local function call_openai(prompt, context)
    local response = curl.post(ENDPOINTS.openai, {
        headers = {
            Authorization = "Bearer " .. config.openai_api_key,
            ["Content-Type"] = "application/json",
        },
        body = json.encode({
            model = config.openai_model or "gpt-4",
            messages = {
                { role = "system", content = AGENT_PROMPT },
                { role = "user", content = json.encode({
                    command = prompt,
                    context = context
                })}
            },
            temperature = 0.7,
            response_format = { type = "json_object" }
        })
    })
    
    if response.status ~= 200 then
        vim.notify("OpenAI API error: " .. (response.body or "Unknown error"), vim.log.levels.ERROR)
        return nil
    end
    
    local result = json.decode(response.body)
    return json.decode(result.choices[1].message.content)
end

-- Anthropic API call (similar to OpenAI but with their specific format)
local function call_anthropic(prompt, context)
    -- Similar to before but with the new agent prompt
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
M.setup = function()
    -- Verify API keys and dependencies
end

-- Main entry point for user commands
M.execute_task = function(prompt)
    run_agent(prompt)
end

return M
