local lsp = vim.lsp

local fix_current = function()
    local params = lsp.util.make_range_params()
    params.context = {diagnostics = vim.lsp.diagnostic.get_line_diagnostics()}

    lsp.buf_request(0, "textDocument/codeAction", params,
                    function(_, _, responses)
        if not responses or not responses[1] then
            print("No code actions available")
            return
        end

        lsp.buf.execute_command(responses[1])
    end)
end

return fix_current
