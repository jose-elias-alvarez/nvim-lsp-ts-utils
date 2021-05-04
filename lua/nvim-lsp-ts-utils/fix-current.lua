local u = require("nvim-lsp-ts-utils.utils")

local lsp = vim.lsp

local exec_at_index = function(actions, index)
    if not actions or not actions[index] then
        u.print_no_actions_message()
        return
    end

    local action = actions[index]
    lsp.buf.execute_command(
        type(action.command) == "table" and action.command or action)
end

local fix_current = function(index)
    if not index then index = 1 end
    local params = lsp.util.make_range_params()
    params.context = {diagnostics = lsp.diagnostic.get_line_diagnostics()}

    lsp.buf_request(0, "textDocument/codeAction", params,
                    function(_, _, actions) exec_at_index(actions, index) end)
end

return fix_current
