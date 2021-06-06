local stub = require("luassert.stub")

describe("client", function()
    stub(vim.lsp.util, "apply_workspace_edit")

    after_each(function()
        vim.lsp.util.apply_workspace_edit:clear()
    end)

    local client = require("nvim-lsp-ts-utils.client")

    describe("setup", function()
        local handler = stub.new()
        local mock_client
        before_each(function()
            mock_client = { handlers = { ["workspace/applyEdit"] = handler } }
        end)

        it("should override client handler", function()
            client.setup(mock_client)

            assert.is.Not.equals(mock_client.handlers["workspace/applyEdit"], handler)
            assert.equals(mock_client._ts_utils_setup_complete, true)
        end)

        it("should not override client handler if setup is complete", function()
            mock_client._ts_utils_setup_complete = true

            client.setup(mock_client)

            assert.equals(mock_client.handlers["workspace/applyEdit"], handler)
        end)
    end)

    describe("edit_handler", function()
        local edit_handler
        before_each(function()
            local mock_client = { handlers = {} }

            client.setup(mock_client)

            edit_handler = mock_client.handlers["workspace/applyEdit"]
        end)

        it("should fix range and apply edit", function()
            local workspace_edit = {
                edit = {
                    changes = {
                        { { range = { start = { character = -1, line = -1 }, ["end"] = { character = -1, line = -1 } } } },
                    },
                },
            }

            edit_handler(nil, nil, workspace_edit)

            assert.stub(vim.lsp.util.apply_workspace_edit).was_called_with({
                changes = {
                    {
                        {

                            range = { start = { character = 0, line = 0 }, ["end"] = { character = 0, line = 0 } },
                        },
                    },
                },
            })
        end)

        it("should return apply_workspace_edit status and result", function()
            vim.lsp.util.apply_workspace_edit.invokes(function()
                error("something went wrong")
            end)

            local res = edit_handler(nil, nil, {})

            assert.equals(res.applied, false)
            assert.truthy(string.find(res.failureReason, "something went wrong"))
        end)
    end)
end)
