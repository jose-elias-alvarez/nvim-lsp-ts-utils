local mock = require("luassert.mock")
local stub = require("luassert.stub")

local options = require("nvim-lsp-ts-utils.options")
local u = require("nvim-lsp-ts-utils.utils")

local o = mock(options, true)

describe("client", function()
    stub(vim.lsp.util, "apply_workspace_edit")
    stub(vim.lsp.handlers, "textDocument/publishDiagnostics")

    after_each(function()
        o.get:clear()
        vim.lsp.util.apply_workspace_edit:clear()
        vim.lsp.handlers["textDocument/publishDiagnostics"]:clear()
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

    describe("handlers", function()
        local edit_handler
        local diagnostics_handler

        before_each(function()
            local mock_client = { handlers = {} }

            client.setup(mock_client)

            edit_handler = mock_client.handlers["workspace/applyEdit"]
            diagnostics_handler = mock_client.handlers["textDocument/publishDiagnostics"]
        end)

        describe("edit_handler", function()
            it("should fix range and apply edit", function()
                local workspace_edit = {
                    edit = {
                        changes = {
                            {
                                {
                                    range = {
                                        start = { character = -1, line = -1 },
                                        ["end"] = { character = -1, line = -1 },
                                    },
                                },
                            },
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

        describe("diagnostics_handler", function()
            local diagnostics_result

            before_each(function()
                diagnostics_result = {
                    diagnostics = {
                        { source = "eslint", severity = u.severities.hint, code = 80001 },
                        { source = "typescript", severity = u.severities.error, code = 80001 },
                        { source = "typescript", severity = u.severities.information, code = 80001 },
                        { source = "typescript", severity = u.severities.hint, code = 80000 },
                    },
                }
            end)

            it("should filter out hints and informations", function()
                o.get.returns({
                    filter_out_diagnostics_by_severity = { "information", u.severities.hint },
                    filter_out_diagnostics_by_code = {},
                })

                local expected_diagnostics_result = {
                    diagnostics = {
                        { source = "eslint", severity = u.severities.hint, code = 80001 },
                        { source = "typescript", severity = u.severities.error, code = 80001 },
                    },
                }

                diagnostics_handler(nil, nil, diagnostics_result, nil, nil, nil)

                assert.stub(vim.lsp.handlers["textDocument/publishDiagnostics"]).was_called_with(
                    nil,
                    nil,
                    expected_diagnostics_result,
                    nil,
                    nil,
                    nil
                )
            end)

            it("should filter out diagnostics by code", function()
                o.get.returns({
                    filter_out_diagnostics_by_severity = {},
                    filter_out_diagnostics_by_code = { 80001 },
                })

                local expected_diagnostics_result = {
                    diagnostics = {
                        { source = "eslint", severity = u.severities.hint, code = 80001 },
                        { source = "typescript", severity = u.severities.hint, code = 80000 },
                    },
                }

                diagnostics_handler(nil, nil, diagnostics_result, nil, nil, nil)

                assert.stub(vim.lsp.handlers["textDocument/publishDiagnostics"]).was_called_with(
                    nil,
                    nil,
                    expected_diagnostics_result,
                    nil,
                    nil,
                    nil
                )
            end)
        end)
    end)
end)
