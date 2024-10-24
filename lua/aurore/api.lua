-- api.lua
local curl = require('plenary.curl')
local ui = require('aurore.ui.status')
local recovery = require('aurore.recovery')
local debug = require('aurore.debug')
local docs = require('aurore.docs')

-- Create module
local M = {}

-- Store config at module level
M.config = nil

-- State management
local task_history = {}
local current_task = nil

-- Retry configuration (unchanged)
local RETRY_CONFIG = {
    max_attempts = 3,
    initial_delay = 1000,
    max_delay = 5000
}

-- API endpoints (unchanged)
local ENDPOINTS = {
    openai = "https://api.openai.com/v1/chat/completions",
    anthropic = "https://api.anthropic.com/v1/messages",
}


-- Agent system prompt
local AGENT_PROMPT = [[You are an autonomous AI agent with direct access to a computer through Neovim. You can:
1. Execute terminal commands
2. Modify files
3. Control Neovim
4. Plan and execute multi-step tasks
5. Check server status using tools.bash.check_server(url, port)
6. Manage git repositories with git.auto_commit(description)
7. Get LSP diagnostics with lsp.get_diagnostics()
8. Apply LSP suggestions with lsp.apply_suggestion(suggestion)

When working with servers:
- You can check if a server is running using the check_server function
- Always verify server status after starting one
- Include proper shutdown instructions in documentation

When working with git:
- You can automatically stage and commit changes
- Provide meaningful commit messages
- Group related changes together

When working with LSP:
- Check for diagnostics before making changes
- Apply suggested fixes when available
- Verify changes after applying fixes

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
            }
        ],
        "file_operations": [], // file operations to perform
        "message": "" // explanation for the user
    },
    "next_step": "What you plan to do next",
    "task_complete": false // true when the entire task is done
}

IMPORTANT GUIDELINES:
1. Do not repeat operations on the same file
2. Mark task_complete as true when:
   - All files are created and written
   - All tests have passed
   - No more modifications are needed
3. Avoid repeating the same operations
4. Track your progress and don't recreate existing files
5. When a file is complete, move on to the next task
6. Consider a task complete when all specified requirements are met]]



local task_state = {
    files_created = {},
    operations_performed = {},
    current_iteration = 0,
    max_iterations = 5
}


-- Helper function for retry logic
local function retry_with_backoff(fn)
    local attempt = 1
    local delay = RETRY_CONFIG.initial_delay

    while attempt <= RETRY_CONFIG.max_attempts do
        debug.log('retry', string.format('Attempt %d/%d', attempt, RETRY_CONFIG.max_attempts))
        
        local success, result = pcall(fn)
        if success then
            return result
        end

        ui.update({
            status = string.format("Attempt %d failed, retrying in %dms...", attempt, delay)
        })

        vim.cmd(string.format('sleep %dm', delay / 1000))
        
        attempt = attempt + 1
        delay = math.min(delay * 2, RETRY_CONFIG.max_delay)
    end
    
    return nil, "Max retry attempts reached"
end

-- API call implementations
local function call_openai(prompt, context)
    debug.log('api_call', 'Sending request to OpenAI')
    ui.update({ status = "Sending request to OpenAI..." })
    
    local function make_request()
        return curl.post(ENDPOINTS.openai, {
            headers = {
                Authorization = "Bearer " .. config.options.openai_api_key,
                ["Content-Type"] = "application/json",
            },
            body = vim.json.encode({
                model = config.options.openai_model or "gpt-4",
                messages = {
                    { role = "system", content = AGENT_PROMPT },
                    { role = "user", content = vim.json.encode({
                        command = prompt,
                        context = context
                    })}
                },
                temperature = 0.7
            }),
            timeout = config.options.task.timeout or 30000
        })
    end

    local response = retry_with_backoff(make_request)
    
    if not response or response.status ~= 200 then
        debug.log('api_error', 'OpenAI API error: ' .. (response and response.body or "No response"))
        ui.update({ status = "API Error", error = response and response.body or "Request failed" })
        return nil
    end
    
    local ok, result = pcall(vim.json.decode, response.body)
    if not ok then
        debug.log('api_error', 'Failed to parse OpenAI response')
        return nil
    end

    local content = result.choices[1].message.content
    local success, parsed = pcall(vim.json.decode, content)
    if success then
        return parsed
    else
        debug.log('api_error', 'Failed to parse AI response as JSON')
        return nil
    end
end

local function call_anthropic(prompt, context)
    debug.log('api_call', 'Sending request to Anthropic')
    ui.update({ status = "Sending request to Anthropic..." })
    
    local function make_request()
        return curl.post(ENDPOINTS.anthropic, {
            headers = {
                ["X-Api-Key"] = config.options.anthropic_api_key,
                ["Content-Type"] = "application/json",
                ["anthropic-version"] = "2023-06-01"
            },
            body = vim.json.encode({
                model = config.options.anthropic_model or "claude-3-5-sonnet-20241022",
                max_tokens = 4096,
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
            }),
            timeout = config.options.task.timeout or 30000
        })
    end

    local response = retry_with_backoff(make_request)
    
    if not response or response.status ~= 200 then
        debug.log('api_error', 'Anthropic API error: ' .. (response and response.body or "No response"))
        ui.update({ status = "API Error", error = response and response.body or "Request failed" })
        return nil
    end
    
    local ok, result = pcall(vim.json.decode, response.body)
    if not ok then
        debug.log('api_error', 'Failed to parse Anthropic response')
        return nil
    end

    if not result.content or not result.content[1] or not result.content[1].text then
        debug.log('api_error', 'Unexpected Anthropic response format')
        return nil
    end

    local ok2, parsed = pcall(vim.json.decode, result.content[1].text)
    if ok2 then
        return parsed
    else
        debug.log('api_error', 'Failed to parse AI response as JSON')
        return nil
    end
end

-- Main API request function
local function send_ai_request(prompt, context)
    debug.log('request', string.format('Sending request - Provider: %s', config.options.ai_provider))
    
    if config.options.ai_provider == "openai" then
        return call_openai(prompt, context)
    elseif config.options.ai_provider == "anthropic" then
        return call_anthropic(prompt, context)
    else
        debug.log('error', 'Unknown AI provider: ' .. tostring(config.options.ai_provider))
        ui.update({ status = "Error", error = "Unknown AI provider" })
        return nil
    end
end

-- Operation tracking
local function is_repetitive_operation(operation)
    local op_key = vim.inspect(operation)
    task_state.operations_performed[op_key] = (task_state.operations_performed[op_key] or 0) + 1
    return task_state.operations_performed[op_key] > 2
end

local function track_file_operation(filename)
    if task_state.files_created[filename] then
        return false
    end
    task_state.files_created[filename] = true
    return true
end

-- Execute a single step
local function execute_step(step)
    debug.log('step', 'Executing step: ' .. vim.inspect(step))
    
    -- Create checkpoint before executing step
    local checkpoint = recovery.save_checkpoint()
    
    local results = {
        command_outputs = {},
        vim_outputs = {},
        file_operations = {},
    }
    
    -- Execute shell commands
    for _, cmd in ipairs(step.commands or {}) do
        debug.log('command', 'Executing command: ' .. cmd)
        ui.update({ current_operation = "Running: " .. cmd })
        
        -- Check for dangerous commands
        if cmd:match('^%s*rm%s') or cmd:match('^%s*sudo%s') then
            if not vim.fn.confirm('Execute potentially dangerous command: ' .. cmd, '&Yes\n&No', 2) == 1 then
                debug.log('command', 'User rejected dangerous command: ' .. cmd)
                goto continue
            end
        end
        
        local success, output = tools.bash.execute(cmd)
        table.insert(results.command_outputs, {
            command = cmd,
            success = success,
            output = output
        })
        
        debug.log('command_result', string.format('Success: %s, Output: %s', success, output))
        
        ::continue::
    end
    
    -- Execute vim commands
    for _, cmd in ipairs(step.vim_commands or {}) do
        if type(cmd) == "table" then
            if cmd.type == "create_file" then
                if not track_file_operation(cmd.filename) then
                    debug.log('skip', 'File already exists: ' .. cmd.filename)
                    goto continue
                end
            end
            
            if is_repetitive_operation(cmd) then
                debug.log('skip', 'Skipping repetitive operation: ' .. vim.inspect(cmd))
                goto continue
            end
        end
        
        debug.log('vim', 'Executing vim command: ' .. vim.inspect(cmd))
        ui.update({ current_operation = "Vim: " .. (type(cmd) == "table" and cmd.type or cmd) })
        
        local success, output = tools.editor.execute(cmd)
        table.insert(results.vim_outputs, {
            command = cmd,
            success = success,
            output = output
        })
        
        ::continue::
    end
    
    -- Handle file operations
    for _, op in ipairs(step.file_operations or {}) do
        debug.log('file', 'Executing file operation: ' .. vim.inspect(op))
        ui.update({ current_operation = "File operation: " .. op.type })
        
        local success, output = tools.computer.handle_file_operation(op)
        table.insert(results.file_operations, {
            operation = op,
            success = success,
            output = output
        })
    end
    
    return results
end

-- Continue execution with context
local function continue_execution(previous_results, task_context, initial_prompt)
    local context = vim.tbl_deep_extend("force", task_context or {}, {
        previous_results = previous_results,
        initial_prompt = initial_prompt,
        cwd = vim.fn.getcwd(),
        current_file = vim.fn.expand('%:p'),
    })
    
    debug.log('continue', 'Continuing execution with context')
    return send_ai_request("Continue with the next step based on previous results.", context)
end

-- Main execution loop
local function run_agent(initial_prompt)
    debug.log('task_start', 'Starting new task: ' .. initial_prompt)
    
    -- Check if config is initialized
    if not M.config then
        error("Aurore not properly initialized. Please call setup() first.")
    end
    
    -- Reset task state
    task_state = {
        files_created = {},
        operations_performed = {},
        current_iteration = 0,
        max_iterations = M.config.task.max_iterations or 5
    }
    
    -- Initialize current task
    current_task = {
        prompt = initial_prompt,
        steps = {},
        start_time = os.time()
    }
    
    local context = {
        cwd = vim.fn.getcwd(),
        current_file = vim.fn.expand('%:p'),
        filetype = vim.bo.filetype,
        initial_prompt = initial_prompt
    }
    
    -- Create initial checkpoint
    local checkpoint = recovery.save_checkpoint()
    
    -- Get initial plan
    local response = send_ai_request(initial_prompt, context)
    if not response then 
        debug.log('error', 'Failed to get initial response from AI')
        ui.update({ status = "Error", error = "Failed to get AI response" })
        return 
    end
    
    -- Show initial plan
    ui.update({
        task = {
            description = initial_prompt,
            plan = response.plan,
            current_step = 0,
            total_steps = #response.plan
        }
    })
    
    -- Execute steps until task is complete
    while not response.task_complete and task_state.current_iteration < task_state.max_iterations do
        task_state.current_iteration = task_state.current_iteration + 1
        
        debug.log('step', string.format('Executing step %d/%d', task_state.current_iteration, #response.plan))
        ui.update({
            task = {
                current_step = task_state.current_iteration,
                total_steps = #response.plan,
                thought = response.thought
            }
        })
        
        -- Execute current step
        local step_results = execute_step(response.current_step)
        
        -- Save step in task history
        table.insert(current_task.steps, {
            thought = response.thought,
            action = response.current_step,
            results = step_results
        })
        
        -- Check for errors
        local success, error = pcall(function()
            -- Handle results
            if vim.tbl_count(step_results.command_outputs) == 0 and
               vim.tbl_count(step_results.vim_outputs) == 0 and
               vim.tbl_count(step_results.file_operations) == 0 then
                debug.log('warning', 'Step produced no outputs')
            end
        end)
        
        if not success then
            debug.log('error', 'Error in step execution: ' .. error)
            if M.config.features.auto_recovery then
                debug.log('recovery', 'Attempting to restore checkpoint')
                recovery.restore_checkpoint(checkpoint)
            end
            ui.update({ status = "Error", error = "Step execution failed" })
            break
        end
        
        -- Get next step
        response = continue_execution(step_results, context, initial_prompt)
        if not response then 
            debug.log('error', 'Failed to get next step from AI')
            ui.update({ status = "Error", error = "Failed to get next AI response" })
            break 
        end
        
        -- Create new checkpoint
        checkpoint = recovery.save_checkpoint()
        
        -- Optional delay to prevent overwhelming the system
        if M.config.performance and M.config.performance.delay_between_steps then
            vim.cmd('sleep ' .. M.config.performance.delay_between_steps .. 'm')
        else
            vim.cmd('sleep 100m')
        end
    end
    
    -- Task completion
    if response and response.task_complete then
        debug.log('task_complete', 'Task completed successfully')
        
        -- Generate documentation if enabled
        if M.config.features.auto_documentation then
            local documentation = docs.generate_task_doc(current_task)
            local doc_path = M.config.docs.output_dir .. '/AURORE_TASKS.md'
            vim.fn.mkdir(vim.fn.fnamemodify(doc_path, ':h'), 'p')
            vim.fn.writefile(vim.split(documentation, '\n'), doc_path, 'a')
        end
        
        -- Update task history
        current_task.end_time = os.time()
        current_task.success = true
        table.insert(task_history, current_task)
        
        -- Handle successful completion
        ui.update({ 
            status = "Task completed!",
            task = {
                description = initial_prompt,
                completion_time = os.time() - current_task.start_time,
                success = true
            }
        })
        
        -- Trigger completion hooks if configured
        if M.config.hooks and M.config.hooks.after_task then
            pcall(M.config.hooks.after_task, current_task)
        end
    else
        debug.log('task_incomplete', 'Task did not complete successfully')
        
        -- Update task history
        current_task.end_time = os.time()
        current_task.success = false
        table.insert(task_history, current_task)
        
        -- Handle failure
        ui.update({ 
            status = "Task failed", 
            error = "Maximum iterations reached or execution failed",
            task = {
                description = initial_prompt,
                completion_time = os.time() - current_task.start_time,
                success = false
            }
        })
        
        -- Trigger error hooks if configured
        if M.config.hooks and M.config.hooks.on_error then
            pcall(M.config.hooks.on_error, {
                task = current_task,
                error = "Task did not complete successfully",
                iterations = task_state.current_iteration
            })
        end
    end
    
    -- Clean up
    if state.win then
        vim.defer_fn(function()
            ui.close()
        end, 3000) -- Close UI after 3 seconds
    end
end
-- Module exports
local M = {}

M.setup = function(opts)
    M.config = opts
    debug.log('setup', 'API module initialized with config: ' .. vim.inspect(opts))
end


M.execute_task = function(prompt)
    run_agent(prompt)
end

M.show_history = function()
    local lines = {}
    for i, task in ipairs(task_history) do
        table.insert(lines, string.format("%d. %s", i, task.prompt))
        table.insert(lines, string.format("   Duration: %ds", task.end_time - task.start_time))
        table.insert(lines, string.format("   Success: %s", task.success))
        table.insert(lines, string.format("   Steps: %d", #task.steps))
        table.insert(lines, "")
    end
    
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    
    vim.api.nvim_open_win(buf, true, {
        relative = 'editor',
        width = math.min(120, vim.o.columns - 4),
        height = math.min(#lines, vim.o.lines - 4),
        row = 1,
        col = 1,
        style = 'minimal',
        border = 'rounded'
    })
end

return M
