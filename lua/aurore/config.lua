local M = {}

local defaults = {
    -- AI Provider Settings
    ai_provider = "anthropic",
    openai_api_key = nil,
    openai_model = "gpt-4",
    anthropic_api_key = nil,
    anthropic_model = "claude-3-5-sonnet-20241022",
    
    -- UI Configuration
    ui = {
        window_position = "bottom", -- or "right", "float"
        show_progress = true,
        window_size = {
            width = 0.8,  -- Percentage of screen
            height = 0.4,
            min_width = 80,
            min_height = 10
        },
        colors = {
            border = "Normal",
            title = "Title",
            progress = "Special",
            error = "ErrorMsg",
            success = "String",
            warning = "WarningMsg"
        },
        icons = {
            success = "✓",
            error = "✗",
            warning = "⚠",
            info = "ℹ",
            working = "🔄",
            git = "🌿",
            file = "📄",
            folder = "📁",
            server = "🌐"
        },
        notifications = {
            enabled = true,
            position = "bottom-right", -- or "top-right", "top", "bottom"
            timeout = 3000
        },
        floating = {
            border = "rounded", -- or "single", "double", "solid"
            winblend = 0,      -- transparency (0-100)
            zindex = 50
        }
    },

    -- Keymaps
    keymaps = {
        cancel_task = "<leader>ac",
        show_history = "<leader>ah",
        retry_task = "<leader>ar",
        toggle_ui = "<leader>au",
        create_checkpoint = "<leader>as",
        restore_checkpoint = "<leader>ar",
    },

    -- Feature Toggles
    features = {
        git_integration = true,
        lsp_integration = true,
        debug_mode = false,
        auto_recovery = true,
        auto_documentation = true,
        file_backups = true,
        command_confirmation = true,
        syntax_highlighting = true,
        auto_formatting = true,
        spell_check = false,
        task_suggestions = true,
        code_actions = true,
        snippets = true
    },

    -- Task Configuration
    task = {
        max_retries = 3,
        timeout = 30000,
        max_iterations = 5,
        confirmation = {
            dangerous_commands = true,
            file_overwrites = true,
            git_operations = true
        },
        history = {
            enabled = true,
            max_entries = 100,
            save_to_file = true,
            file_path = vim.fn.stdpath("data") .. "/aurore_history.json"
        }
    },

    -- Git Settings
    git = {
        auto_commit = false,
        commit_message_prefix = "[Aurore AI] ",
        verify_commits = true,
        push_on_complete = false,
        create_branches = true,
        branch_prefix = "aurore/"
    },

    -- Documentation Settings
    docs = {
        auto_generate = true,
        format = "markdown", -- or "html", "org"
        include_timestamps = true,
        include_system_info = true,
        output_dir = "docs/aurore",
        templates = {
            task = "templates/task.md",
            readme = "templates/readme.md"
        }
    },

    -- Debug Settings
    debug = {
        log_level = "info", -- "debug", "info", "warn", "error"
        file_logging = true,
        log_path = vim.fn.stdpath("cache") .. "/aurore/debug.log",
        max_log_size = 1024 * 1024, -- 1MB
        console_logging = true,
        performance_tracking = true,
        trace_api_calls = true
    },

    -- Security Settings
    security = {
        allowed_commands = {
            patterns = {
                "^git",
                "^npm",
                "^python",
                "^pip"
            }
        },
        blocked_commands = {
            patterns = {
                "^rm%s+%-rf%s+/",
                "^sudo%s+rm",
                "^sudo%s+dd"
            }
        },
        require_confirmation = {
            patterns = {
                "^rm",
                "^mv",
                "^git%s+push",
                "^sudo"
            }
        }
    },

    -- File Operations
    files = {
        backup = {
            enabled = true,
            directory = vim.fn.stdpath("data") .. "/aurore_backups",
            max_backups = 5,
            compression = true
        },
        ignore_patterns = {
            "node_modules",
            ".git",
            "*.pyc",
            "__pycache__"
        },
        auto_format = {
            on_save = true,
            formatters = {
                python = "black",
                javascript = "prettier",
                lua = "stylua"
            }
        }
    },

    -- Performance Settings
    performance = {
        cache = {
            enabled = true,
            size = 100,
            ttl = 3600
        },
        rate_limiting = {
            enabled = true,
            max_requests = 10,
            window_seconds = 60
        },
        chunk_size = 1024 * 1024, -- 1MB for file operations
        lazy_loading = true
    },

    -- Language Specific Settings
    languages = {
        python = {
            venv_handling = true,
            preferred_formatter = "black",
            test_framework = "pytest"
        },
        javascript = {
            package_manager = "npm",
            preferred_formatter = "prettier",
            test_framework = "jest"
        },
        -- Add more language-specific settings
    },

    -- Project Templates
    templates = {
        python = {
            basic = {
                files = {"main.py", "requirements.txt", "README.md"},
                venv = true,
                git = true
            },
            flask = {
                files = {"app.py", "requirements.txt", "templates/"},
                dependencies = {"flask", "python-dotenv"}
            }
        },
        javascript = {
            react = {
                files = {"src/", "package.json", "README.md"},
                dependencies = {"react", "react-dom"}
            }
        }
    },

    -- Hooks
    hooks = {
        before_task = function(task) end,
        after_task = function(task, result) end,
        on_error = function(error) end,
        before_commit = function(files) end,
        after_commit = function(hash) end
    }
}

M.options = {}

function M.setup(opts)
    M.options = vim.tbl_deep_extend("force", {}, defaults, opts or {})
end

return M
