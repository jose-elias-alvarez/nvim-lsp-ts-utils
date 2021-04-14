local options = {
    disable_commands = false,
    enable_import_on_completion = false,
    import_on_completion_timeout = 5000,
    eslint_bin = "eslint",
    eslint_fix_current = false,
    eslint_enable_disable_comments = true
}

local M = {}
M.set = function(user_options)
    options = vim.tbl_extend("force", options, user_options)
end

M.get = function() return options end

return M

