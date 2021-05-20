local options = {
    disable_commands = false,
    enable_import_on_completion = false,
    complete_parens = false,
    signature_help_in_parens = false,
    import_on_completion_timeout = 5000,
    debug = false,
    update_imports_on_move = false,
    require_confirmation_on_move = false,
    watch_dir = "/src",
    -- eslint
    eslint_enable_code_actions = true,
    eslint_bin = "eslint",
    eslint_args = {"-f", "json", "--stdin", "--stdin-filename", "$FILENAME"},
    eslint_enable_diagnostics = false,
    eslint_diagnostics_debounce = 250,
    eslint_enable_disable_comments = true,
    -- formatting
    enable_formatting = false,
    formatter = "prettier",
    formatter_args = {"--stdin-filepath", "$FILENAME"},
    format_on_save = false,
    no_save_after_format = false,
    disable_integrations = false
}

local M = {}

M.set = function(user_options)
    options = vim.tbl_extend("force", options, user_options)
end

M.get = function() return options end

return M
