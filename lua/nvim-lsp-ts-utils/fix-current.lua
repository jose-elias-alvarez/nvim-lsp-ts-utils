local o = require("nvim-lsp-ts-utils.options")
local u = require("nvim-lsp-ts-utils.utils")
local code_action_handler = require("nvim-lsp-ts-utils.code-action-handler")

local lsp = vim.lsp

local exec_first = function(actions)
    if not actions or not actions[1] then
        u.print_no_actions_message()
        return
    end

    local first = actions[1]
    lsp.buf.execute_command(type(first.command) == "table" and first.command or
                                first)
end

local eslint_callback = function(_, _, actions)
    code_action_handler.custom(actions, exec_first)
end

local callback = function(_, _, actions) exec_first(actions) end

local fix_current = function()
    local params = lsp.util.make_range_params()
    params.context = {diagnostics = lsp.diagnostic.get_line_diagnostics()}

    lsp.buf_request(0, "textDocument/codeAction", params,
                    o.get().eslint_fix_current and eslint_callback or callback)
end

return fix_current
