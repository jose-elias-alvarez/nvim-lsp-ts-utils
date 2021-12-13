local lspconfig = require("lspconfig")

local ts_utils = require("nvim-lsp-ts-utils")

local api = vim.api

local edit_test_file = function(name)
    vim.cmd("e " .. "test/files/" .. name)
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

    lspconfig.tsserver.setup({
        on_attach = function(client)
            client.resolved_capabilities.document_formatting = false
            ts_utils.setup_client(client)
        end,
    })
    ts_utils.setup({})

    after_each(function()
        vim.cmd("silent bufdo! bdelete!")
    end)

    describe("import_all", function()
        before_each(function()
            edit_test_file("import-all.ts")
            lsp_wait(1000)
        end)

        it("should import both missing types", function()
            ts_utils.import_all()
            lsp_wait()

            assert.equals(get_buf_content(1), [[import { User, UserNotification } from "./test-types";]])
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
end)
