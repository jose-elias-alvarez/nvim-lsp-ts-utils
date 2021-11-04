local validate = vim.validate

local eslint_executables = { "eslint", "eslint_d" }
local _eslint_args = { "-f", "json", "--stdin", "--stdin-filename", "$FILENAME" }
local eslint_args = { eslint = _eslint_args, eslint_d = _eslint_args }

local formatters = { "prettier", "prettierd", "prettier_d_slim", "eslint_d", "eslint" }

local defaults = {
    debug = false,
    disable_commands = false,

    -- import all
    import_all_timeout = 5000,
    import_all_priorities = {
        buffers = 4,
        buffer_content = 3,
        local_files = 2,
        same_file = 1,
    },
    import_all_select_source = false,
    import_all_scan_buffers = 100,

    -- completion
    enable_import_on_completion = false,

    -- watcher
    update_imports_on_move = false,
    watch_dir = nil,
    require_confirmation_on_move = false,

    -- eslint
    eslint_enable_code_actions = true,
    eslint_enable_disable_comments = true,
    eslint_bin = "eslint",
    eslint_enable_diagnostics = false,
    eslint_opts = {},

    -- formatting
    enable_formatting = false,
    formatter = "prettier",
    formatter_opts = {},

    -- diagnostic filtering
    filter_out_diagnostics_by_severity = {},
    filter_out_diagnostics_by_code = {},

    -- inlay hints
    auto_inlay_hints = true,
    inlay_hints_highlight = "Comment",

    -- internal
    _initialized = false,
}

local type_overrides = {
    watch_dir = { "string", "nil" },
    eslint_bin = function(a)
        if a == "_get_msg" then
            return table.concat(eslint_executables, ", ")
        end
        return not a or vim.tbl_contains(eslint_executables, a)
    end,
    formatter = function(a)
        if a == "_get_msg" then
            return table.concat(formatters, ", ")
        end
        return not a or vim.tbl_contains(formatters, a)
    end,
    eslint_config_fallback = { "string", "function", "nil" },
    formatter_config_fallback = { "string", "function", "nil" },
}

local wanted_type = function(k)
    if vim.startswith(k, "_") then
        return "nil", true
    end

    local override = type_overrides[k]
    if type(override) == "string" then
        return override, true
    end
    if type(override) == "table" then
        return function(a)
            return vim.tbl_contains(override, type(a))
        end,
            table.concat(override, ", ")
    end
    if type(override) == "function" then
        return override, override("_get_msg")
    end

    return type(defaults[k]), true
end

local options = vim.deepcopy(defaults)

local validate_options = function(user_options)
    local to_validate, validated = {}, {}

    local get_wanted = function(config_table)
        for k in pairs(config_table) do
            local wanted, optional = wanted_type(k)
            to_validate[k] = { user_options[k], wanted, optional }

            validated[k] = user_options[k]
        end
    end
    get_wanted(options)
    get_wanted(type_overrides)

    validate(to_validate)
    return validated
end

local M = {}

M.setup = function(user_options)
    if options._initialized then
        return
    end
    local validated = validate_options(user_options)

    options = vim.tbl_extend("force", options, validated)
    options.eslint_args = options.eslint_bin and eslint_args[options.eslint_bin]
    options._initialized = true
end

M.get = function()
    local _options = {}
    for k, v in pairs(options) do
        _options[k] = type(v) == "function" and v() or v
    end
    return _options
end

M.reset = function()
    options = vim.deepcopy(defaults)
end

return M
