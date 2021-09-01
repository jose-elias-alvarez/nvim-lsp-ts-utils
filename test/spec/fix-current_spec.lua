local mock = require("luassert.mock")

local lsp = mock(vim.lsp, true)

describe("fix_current", function()
    before_each(function()
        lsp.util.make_range_params.returns({})
        lsp.diagnostic.get_line_diagnostics.returns("diagnostics")
    end)

    after_each(function()
        lsp.buf_request:clear()
        lsp.buf.execute_command:clear()
        lsp.diagnostic.get_line_diagnostics:clear()
        lsp.util.make_range_params:clear()
    end)

    local fix_current = require("nvim-lsp-ts-utils.fix-current")

    it("should call buf_request with bufnr, method, and params", function()
        fix_current()

        assert.stub(lsp.buf_request).was_called()
        assert.equals(lsp.buf_request.calls[1].refs[1], 0)
        assert.equals(lsp.buf_request.calls[1].refs[2], "textDocument/codeAction")
        assert.same(lsp.buf_request.calls[1].refs[3], { context = { diagnostics = "diagnostics" } })
    end)

    describe("exec_at_index", function()
        local callback
        before_each(function()
            fix_current()
            callback = lsp.buf_request.calls[1].refs[4]
        end)

        it("should call execute_command when action.command is a table", function()
            local action = { command = { name = "doSomething" } }

            callback(nil, { action })

            assert.stub(lsp.buf.execute_command).was_called_with(action.command)
        end)

        it("should call execute_command when action.command is a string", function()
            local action = { command = "doSomethingElse" }

            callback(nil, { action })

            assert.stub(lsp.buf.execute_command).was_called_with(action)
        end)
    end)
end)
