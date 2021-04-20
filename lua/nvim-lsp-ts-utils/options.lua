local u = require("nvim-lsp-ts-utils.utils")

local options = {
    disable_commands = false,
    enable_import_on_completion = false,
    import_on_completion_timeout = 5000,
    eslint_bin = "eslint",
    eslint_enable_disable_comments = true,
    request_handlers = {}
}

local M = {}

M.set = function(user_options)
    if user_options.eslint_fix_current then
        u.echo_warning("Option eslint_fix_current has been removed (see readme)")
    end
    options = vim.tbl_extend("force", options, user_options)
end

M.get = function() return options end

return M

