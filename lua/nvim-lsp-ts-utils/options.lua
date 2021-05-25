local validate = vim.validate

local eslint_executables = {"eslint", "eslint_d"}
local _eslint_args = {"-f", "json", "--stdin", "--stdin-filename", "$FILENAME"}
local eslint_args = {eslint = _eslint_args, eslint_d = _eslint_args}

local formatters = {"prettier", "prettier_d_slim", "eslint_d"}
local formatter_args = {
    prettier = {"--stdin-filepath", "$FILENAME"},
    prettier_d_slim = {"--stdin", "--stdin-filepath", "$FILENAME"},
    eslint_d = {"--fix-to-stdout", "--stdin", "--stdin-filename", "$FILENAME"}
}

local options = {
    debug = false,
    disable_commands = false,
    enable_import_on_completion = false,
    complete_parens = false,
    signature_help_in_parens = false,
    update_imports_on_move = false,
    require_confirmation_on_move = false,
    watch_dir = "/src",
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
    _initialized = false
}

local validate_options = function(user_options)
    local to_validate, validated = {}, {}
    for k, v in pairs(user_options) do
        if type(options[k]) ~= "nil" then
            if k == "eslint_bin" then
                to_validate[k] = {
                    v, function(a)
                        return not a or vim.tbl_contains(eslint_executables, a)
                    end, "eslint or eslint_d"
                }
            elseif k == "formatter" then
                to_validate[k] = {
                    v,
                    function(a)
                        return not a or vim.tbl_contains(formatters, a)
                    end, "prettier, prettier_d_slim, or eslint_d"
                }
            else
                to_validate[k] = {v, type(options[k]), true}
            end
            if v ~= nil then validated[k] = v end
        end
    end

    validate(to_validate)
    return validated
end

local M = {}

M.set = function(user_options)
    if options._initialized then return end
    local validated = validate_options(user_options)

    options = vim.tbl_extend("force", options, validated)
    options.eslint_args = eslint_args[options.eslint_bin]
    options.formatter_args = formatter_args[options.formatter]
    options._initialized = true
end

M.get = function() return options end

return M
