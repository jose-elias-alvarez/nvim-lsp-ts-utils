local u = require("nvim-lsp-ts-utils.utils")

local lsp = vim.lsp

local exec_first = function(actions)
    if not actions or not actions[1] then
        u.print_no_actions_message()
        return
    end

    local action = actions[1]
    lsp.buf.execute_command(type(action.command) == "table" and action.command or action)
end

-- deprecated
local fix_current = function()
    local params = lsp.util.make_range_params()
    params.context = { diagnostics = lsp.diagnostic.get_line_diagnostics() }

    lsp.buf_request(
        0,
        "textDocument/codeAction",
        params,
        u.make_handler(function(_, actions)
            exec_first(actions)
        end)
    )
end

return fix_current
