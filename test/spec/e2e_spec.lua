local null_ls = require("null-ls")
local lspconfig = require("lspconfig")

local ts_utils = require("nvim-lsp-ts-utils")
local import_all = require("nvim-lsp-ts-utils.import-all")
local tu = require("test.utils")

local api = vim.api
local lsp = vim.lsp

local base_path = "test/files/"

local edit_test_file = function(name)
    vim.cmd("e " .. base_path .. name)
end

local get_buf_content = function(line)
    local content = api.nvim_buf_get_lines(api.nvim_get_current_buf(), 0, -1, false)
    assert.equals(vim.tbl_isempty(content), false)

    return line and content[line] or content
end

local lsp_wait = function(wait_time)
    vim.wait(wait_time or 400)
end

describe("e2e", function()
    assert(vim.fn.executable("typescript-language-server") > 0, "typescript-language-server is not installed")

    _G._TEST = true
    null_ls.config({ debug = true })
    lspconfig["null-ls"].setup({})

    lspconfig.tsserver.setup({
        on_attach = function(client)
            client.resolved_capabilities.document_formatting = false
            ts_utils.setup_client(client)
        end,
    })

    ts_utils.setup({
        eslint_enable_code_actions = true,
        eslint_enable_diagnostics = true,
        enable_formatting = true,
        update_imports_on_move = true,
    })

    after_each(function()
        vim.cmd("silent bufdo! bdelete!")
    end)

    describe("import_all", function()
        before_each(function()
            edit_test_file("import-all.ts")
            lsp_wait(1000)
        end)

        it("should import both missing types", function()
            import_all()
            lsp_wait()

            assert.equals(get_buf_content(1), [[import { User, UserNotification } from "./test-types";]])
        end)
    end)

    describe("eslint", function()
        describe("diagnostics", function()
            it("should show eslint diagnostics", function()
                edit_test_file("eslint-code-fix.js")
                lsp_wait()

                local diagnostics = vim.diagnostic.get(0)

                assert.equals(vim.tbl_count(diagnostics), 1)
                assert.equals(diagnostics[1].code, "eqeqeq")
                assert.equals(diagnostics[1].message, "Expected '===' and instead saw '=='.")
                assert.equals(diagnostics[1].source, "eslint")

                assert.equals(diagnostics[1].lnum, 1)
                assert.equals(diagnostics[1].col, 23)
                assert.equals(diagnostics[1].end_lnum, 1)
                assert.equals(diagnostics[1].end_col, 25)
            end)
        end)

        describe("code actions", function()
            before_each(function()
                -- file contains ==, which is a violation of eqeqeq
                edit_test_file("eslint-code-fix.js")
                lsp_wait()

                -- jump to line containing error
                vim.cmd("2")
            end)

            it("should apply eslint fix", function()
                tu.apply_first_code_action()
                lsp_wait()

                -- check that eslint fix has been applied, replacing == with ===
                assert.equals(get_buf_content(2), [[  if (typeof user.name === "string") {]])
            end)
        end)

        it("should use local executable", function()
            local generator = require("null-ls.generators").get_available("typescript", null_ls.methods.DIAGNOSTICS)[1]

            assert.equals(generator.opts.command, vim.fn.getcwd() .. "/test/node_modules/.bin/eslint")
        end)
    end)

    describe("organize_imports", function()
        before_each(function()
            -- file imports both User and Notification but only uses User
            edit_test_file("organize-imports.ts")
            lsp_wait()
        end)

        it("should remove unused import (sync)", function()
            ts_utils.organize_imports_sync()
            lsp_wait()

            assert.equals(get_buf_content(1), [[import { User } from "./test-types";]])
        end)

        it("should remove unused import (async)", function()
            ts_utils.organize_imports()
            lsp_wait()

            assert.equals(get_buf_content(1), [[import { User } from "./test-types";]])
        end)
    end)

    describe("formatting", function()
        it("should format file via lsp formatting", function()
            edit_test_file("formatting.ts")
            assert.equals(get_buf_content(1), [[import {User} from "./test-types"]])
            lsp_wait()

            lsp.buf.formatting()
            lsp_wait(500)

            assert.equals(get_buf_content(1), [[import { User } from './test-types';]])
        end)

        it("should use local executable", function()
            local generator = require("null-ls.generators").get_available("typescript", null_ls.methods.FORMATTING)[1]

            assert.equals(generator.opts.command, vim.fn.getcwd() .. "/test/node_modules/.bin/prettier")
        end)
    end)
end)
