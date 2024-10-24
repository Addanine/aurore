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
        "vim_commands": [  // Neovim commands as structured objects
            {
                "type": "create_file",
                "filename": "example.py"
            },
            {
                "type": "write_buffer",
                "content": "print('hello world')"
            },
            {
                "type": "save_buffer"
            }
        ],
        "file_operations": [], // file operations to perform
        "message": "" // explanation for the user
    },
    "next_step": "What you plan to do next",
    "task_complete": false // true when the entire task is done
}

AVAILABLE VIM COMMANDS:
1. create_file: { type: "create_file", filename: "path/to/file" }
2. write_buffer: { 
    type: "write_buffer", 
    content: "# Title\n\nContent here\nMore content" 
   }
3. append_line: { 
    type: "append_line", 
    content: ["Line 1", "Line 2", "Line 3"]
   }
4. save_buffer: { type: "save_buffer" }

Note: When writing multiline content, you can either:
- Use "\n" in a single string
- Provide an array of lines
IMPORTANT:
- Think step by step
- Request user confirmation for dangerous operations
- Keep the user informed of your plan
- Continue executing steps until the task is complete
- Use structured commands for better reliability
- Provide detailed explanations in your "thought" field]]

-- Helper function to show fancy separator
local function show_separator()
    vim.api.nvim_echo({{"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", "Comment"}}, false, {})
end

-- Helper function to show status messages
local function show_status(icon, message, message_type)
    vim.api.nvim_echo({
        {icon .. " ", "None"},
        {message .. "\n", message_type or "None"}
    }, false, {})
end


-- OpenAI API call
local function call_openai(prompt, context)
    show_status("🌐", "Sending request to OpenAI...")
    
    -- Debug output
    vim.api.nvim_echo({{"Checking OpenAI API key... ", "None"}}, false, {})
    if not config.openai_api_key then
        show_status("❌", "OpenAI API key not found! Please set OPENAI_API_KEY environment variable", "ErrorMsg")
        return nil
    end

    local body = vim.json.encode({
        model = config.openai_model or "gpt-4",
        messages = {
            { role = "system", content = AGENT_PROMPT },
            { role = "user", content = vim.json.encode({
                command = prompt,
                context = context
            })}
        },
        temperature = 0.7
    })

    local headers = {
        ["Content-Type"] = "application/json",
        ["Authorization"] = "Bearer " .. config.openai_api_key
    }

    -- Debug the request
    vim.api.nvim_echo({{"Making API request...\n", "None"}}, false, {})
    
    local response = curl.post(ENDPOINTS.openai, {
        headers = headers,
        body = body,
        timeout = 30000, -- Increase timeout to 30 seconds
    })
    
    if not response or response.status ~= 200 then
        local error_msg = response and response.body or "No response"
        show_status("❌", "OpenAI API error: " .. error_msg, "ErrorMsg")
        return nil
    end
    
    local ok, result = pcall(vim.json.decode, response.body)
    if not ok then
        show_status("❌", "Failed to parse OpenAI response", "ErrorMsg")
        return nil
    end


    local content = result.choices[1].message.content
    local success, parsed = pcall(vim.json.decode, content)
    if success then
        return parsed
    else
        vim.api.nvim_echo({{"Failed to parse AI response content: ", "ErrorMsg"}, {content, "None"}}, false, {})
        return nil
    end
end


-- Anthropic API call
local function call_anthropic(prompt, context)
    show_status("🌐", "Sending request to Anthropic...")
    
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
        show_status("❌", "Anthropic API error: " .. (response.body or "Unknown error"), "ErrorMsg")
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
        show_status("❌", "Unknown AI provider: " .. tostring(config.ai_provider), "ErrorMsg")
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
            return false, "Vim command failed: " .. vim.inspect(vim_result.command)
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
        show_status("🔧", "Running command: " .. cmd)
        local success, output = tools.bash.execute(cmd)
        table.insert(results.command_outputs, {
            command = cmd,
            success = success,
            output = output
        })
        if success then
            show_status("✓", "Command completed: " .. output)
        else
            show_status("✗", "Command failed: " .. output, "ErrorMsg")
        end
    end
    
    -- Execute vim commands
    for _, cmd in ipairs(step.vim_commands or {}) do
        if type(cmd) == "table" then
            show_status("🔧", "Vim operation: " .. cmd.type .. (cmd.filename and (" on " .. cmd.filename) or ""))
        else
            show_status("🔧", "Vim command: " .. tostring(cmd))
        end
        
        local success, output = tools.editor.execute(cmd)
        if success then
            show_status("✓", "Operation completed")
        else
            show_status("✗", "Operation failed: " .. tostring(output), "ErrorMsg")
        end
        table.insert(results.vim_outputs, {
            command = cmd,
            success = success,
            output = output
        })
    end
    
    -- Handle file operations
    for _, op in ipairs(step.file_operations or {}) do
        show_status("🔧", "File operation: " .. vim.inspect(op))
        local success, output = tools.computer.handle_file_operation(op)
        if success then
            show_status("✓", "File operation completed")
        else
            show_status("✗", "File operation failed: " .. output, "ErrorMsg")
        end
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
    
    show_separator()
    show_status("🤖", "Starting task: " .. initial_prompt, "Title")
    
    -- Initial plan
    local response = send_ai_request(initial_prompt, context)
    if not response then return end
    
    -- Show initial plan
    show_separator()
    show_status("📋", "Planned steps:", "Title")
    for i, step in ipairs(response.plan) do
        show_status("", i .. ". " .. step)
    end
    
    -- Execute steps until task is complete
    local current_step = 0
    while not response.task_complete do
        current_step = current_step + 1
        show_separator()
        show_status("🔄", "Step " .. current_step .. "/" .. #response.plan .. ":", "Title")
        show_status("💭", response.thought, "Comment")
        
        -- Execute current step
        local step_results = execute_step(response.current_step)
        
        -- Check if successful
        local success, error = check_operation_success(step_results)
        if not success then
            show_status("❌", "Error: " .. error, "ErrorMsg")
            return
        end
        
        -- Show message to user
        if response.current_step.message then
            show_status("💬", response.current_step.message)
        end
        
        -- Get next step
        response = continue_execution(step_results, context, initial_prompt)
        if not response then return end
        
        -- Sleep briefly to make output readable
        vim.cmd('sleep 100m')
    end
    
    show_separator()
    show_status("✨", "Task completed!", "Title")
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
