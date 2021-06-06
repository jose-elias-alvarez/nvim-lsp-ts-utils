local validate = vim.validate

local eslint_executables = { "eslint", "eslint_d" }
local _eslint_args = { "-f", "json", "--stdin", "--stdin-filename", "$FILENAME" }
local eslint_args = { eslint = _eslint_args, eslint_d = _eslint_args }

local formatters = { "prettier", "prettierd", "prettier_d_slim", "eslint_d" }
local formatter_args = {
    prettier = { "--stdin-filepath", "$FILENAME" },
    prettier_d_slim = { "--stdin", "--stdin-filepath", "$FILENAME" },
    eslint_d = { "--fix-to-stdout", "--stdin", "--stdin-filename", "$FILENAME" },
    prettierd = { "$FILENAME" },
}

local defaults = {
    debug = false,
    disable_commands = false,
    -- completion
    enable_import_on_completion = false,
    complete_parens = false,
    signature_help_in_parens = false,
    -- watcher
    update_imports_on_move = false,
    watch_dir = nil,
    require_confirmation_on_move = false,
    -- eslint
    eslint_enable_code_actions = true,
    eslint_enable_disable_comments = true,
    eslint_bin = "eslint",
    eslint_config_fallback = nil,
    eslint_enable_diagnostics = false,
    -- formatting
    enable_formatting = false,
    formatter = "prettier",
    formatter_config_fallback = nil,
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
    eslint_config_fallback = { "string", "nil" },
    formatter_config_fallback = { "string", "nil" },
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
        end, table.concat(
            override,
            ", "
        )
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
    options.formatter_args = options.formatter and formatter_args[options.formatter]
    options._initialized = true
end

M.get = function()
    return options
end

M.reset = function()
    options = vim.deepcopy(defaults)
end

return M
