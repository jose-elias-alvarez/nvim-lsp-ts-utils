local u = require("nvim-lsp-ts-utils.utils")

local lsp = vim.lsp

local M = {}
M.apply_first_code_action = function()
    local params = lsp.util.make_range_params()
    params.context = { diagnostics = lsp.diagnostic.get_line_diagnostics() }

    lsp.buf_request_all(
        0,
        "textDocument/codeAction",
        params,
        u.make_handler(function(actions)
            local action = actions[1].result[1]

            assert(action, "no actions available")
            lsp.buf.execute_command(type(action.command) == "table" and action.command or action)
        end)
    )
end

return M
