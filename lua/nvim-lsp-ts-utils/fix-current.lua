local lsp = vim.lsp
local o = require("nvim-lsp-ts-utils.options")
local code_action_handler = require("nvim-lsp-ts-utils.code-action-handler")

local exec_first = function(actions)
    if not actions or not actions[1] then
        print("No code actions available")
        return
    end

    lsp.buf.execute_command(actions[1])
end

local eslint_callback = function(_, _, actions)
    code_action_handler.custom(actions, exec_first)
end

local callback = function(_, _, actions) exec_first(actions) end

local fix_current = function()
    local params = lsp.util.make_range_params()
    params.context = {diagnostics = vim.lsp.diagnostic.get_line_diagnostics()}

    lsp.buf_request(0, "textDocument/codeAction", params,
                    o.get().eslint_fix_current and eslint_callback or callback)
end

return fix_current
