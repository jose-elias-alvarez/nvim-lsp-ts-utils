local null_ls = require("null-ls")

local u = require("nvim-lsp-ts-utils.utils")
local ts_utils = require("nvim-lsp-ts-utils")
local import_all = require("nvim-lsp-ts-utils.import-all")
local watcher = require("nvim-lsp-ts-utils.watcher")

local api = vim.api
local lsp = vim.lsp

local base_path = "test/files/"
local full_path = vim.fn.getcwd() .. "/" .. base_path

local edit_test_file = function(name)
    vim.cmd("e " .. base_path .. name)
end

local copy_test_file = function(original, target)
    u.file.cp(full_path .. original, full_path .. target, true)
end

local delete_test_file = function(target)
    u.file.rm(full_path .. target, true)
end

local get_buf_content = function(line)
    local content = api.nvim_buf_get_lines(api.nvim_get_current_buf(), 0, -1, false)
    assert.equals(vim.tbl_isempty(content), false)

    return line and content[line] or content
end

local lsp_wait = function(time)
    vim.wait(time or 400)
end

describe("e2e", function()
    null_ls.setup()

    require("lspconfig").tsserver.setup({
        on_attach = function(client)
            client.resolved_capabilities.document_formatting = false
            require("nvim-lsp-ts-utils").setup_client(client)
        end,
    })

    ts_utils.setup({
        watch_dir = "",
        eslint_enable_code_actions = true,
        eslint_enable_diagnostics = true,
        enable_formatting = true,
    })

    after_each(function()
        vim.cmd("silent bufdo! bdelete!")
    end)

    describe("fix_current", function()
        before_each(function()
            -- file declares an instance of User but does not import it from test-types.ts
            edit_test_file("fix-current.ts")
            lsp_wait(1000)
        end)

        it("should import missing type", function()
            vim.lsp.diagnostic.goto_prev()
            ts_utils.fix_current()
            lsp_wait()

            -- check that import statement has been added
            assert.equals(get_buf_content(1), [[import { User } from "./test-types";]])
        end)
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
            before_each(function()
                edit_test_file("eslint-code-fix.js")
                lsp_wait()
            end)

            it("should show eslint diagnostics", function()
                local diagnostics = lsp.diagnostic.get()

                assert.equals(vim.tbl_count(diagnostics), 1)
                assert.equals(diagnostics[1].code, "eqeqeq")
                assert.equals(diagnostics[1].message, "Expected '===' and instead saw '=='.")
                assert.equals(diagnostics[1].source, "eslint")
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
                ts_utils.fix_current()
                lsp_wait()

                -- check that eslint fix has been applied, replacing == with ===
                assert.equals(get_buf_content(2), [[  if (typeof user.name === "string") {]])
            end)

            it("should add disable rule comment with matching indentation", function()
                -- specify index to choose disable action
                ts_utils.fix_current(2)
                lsp_wait()

                assert.equals(get_buf_content(2), "  // eslint-disable-next-line eqeqeq")
            end)
        end)
    end)

    describe("organize_imports", function()
        before_each(function()
            -- file imports both User and Notification but only uses User
            edit_test_file("organize-imports.ts")
            lsp_wait(1000)
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

    describe("rename_file", function()
        before_each(function()
            copy_test_file("file-to-be-moved.orig.ts", "file-to-be-moved.ts")
            copy_test_file("linked-file.orig.ts", "linked-file.ts")
            copy_test_file("existing-file.orig.ts", "existing-file.ts")
        end)
        after_each(function()
            delete_test_file("new-path.ts")
            delete_test_file("linked-file.ts")
            delete_test_file("file-to-be-moved.ts")
            delete_test_file("existing-file.ts")
        end)

        it("should move file to specified path", function()
            edit_test_file("file-to-be-moved.ts")
            lsp_wait(1000)
            local content = get_buf_content()

            local new_path = full_path .. "new-path.ts"
            ts_utils.rename_file(new_path)
            lsp_wait()

            assert.equals(vim.fn.bufname(api.nvim_get_current_buf()), new_path)
            assert.same(content, get_buf_content())
        end)

        it("should overwrite existing file", function()
            edit_test_file("existing-file.ts")
            local content = get_buf_content()

            edit_test_file("file-to-be-moved.ts")
            lsp_wait(1000)
            local new_path = full_path .. "existing-file.ts"
            ts_utils.rename_file(new_path) -- prompt will be automatically accepted, it seems
            lsp_wait()

            assert.is.Not.same(content, get_buf_content())
        end)

        it("should update imports in linked file on manual rename", function()
            edit_test_file("file-to-be-moved.ts")
            lsp_wait(1000)

            local new_path = full_path .. "new-path.ts"
            ts_utils.rename_file(new_path)
            lsp_wait()

            edit_test_file("linked-file.ts")
            assert.equals(get_buf_content(1), [[import { testFunction } from "./new-path";]])
        end)

        it("should update imports in linked file on move", function()
            edit_test_file("file-to-be-moved.ts")
            watcher.start()
            lsp_wait(1000)

            local new_path = full_path .. "new-path.ts"
            u.file.mv(full_path .. "file-to-be-moved.ts", new_path)
            lsp_wait()

            edit_test_file("linked-file.ts")
            assert.equals(get_buf_content(1), [[import { testFunction } from "./new-path";]])
        end)
    end)

    describe("formatting", function()
        before_each(function()
            copy_test_file("formatting.orig.ts", "formatting.ts")

            -- file has bad spacing, no semicolon, and double quotes, all of which violate prettier rules
            edit_test_file("formatting.ts")
            lsp_wait(1000)
        end)
        after_each(function()
            delete_test_file("formatting.ts")
        end)

        it("should format file via lsp formatting", function()
            lsp.buf.formatting()
            lsp_wait()

            assert.equals(get_buf_content(1), [[import { User } from './test-types';]])
        end)
    end)

    describe("edit_handler", function()
        before_each(function()
            copy_test_file("move-to-new-file.orig.ts", "move-to-new-file.ts")
            edit_test_file("move-to-new-file.ts")
            lsp_wait(1000)
        end)
        after_each(function()
            delete_test_file("move-to-new-file.ts")
            delete_test_file("functionToMove.ts")
        end)

        it("should fix range so that code action actually works", function()
            vim.api.nvim_win_set_cursor(0, { 3, 10 })

            ts_utils.fix_current()
            lsp_wait()

            assert.equals(u.file.exists(full_path .. "functionToMove.ts"), true)
            assert.equals(get_buf_content(1), [[import { functionToMove } from "./functionToMove";]])

            edit_test_file("functionToMove.ts")
            assert.equals(get_buf_content(3), "export function functionToMove() {")
        end)
    end)
end)

null_ls.shutdown()
