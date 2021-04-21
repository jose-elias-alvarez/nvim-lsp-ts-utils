local o = require("nvim-lsp-ts-utils.options")
local ts_utils = require("nvim-lsp-ts-utils")
local import_all = require("nvim-lsp-ts-utils.import-all")

ts_utils.setup({no_save_after_format = true})

vim.lsp.buf_request = ts_utils.buf_request

local pwd = vim.api.nvim_exec("pwd", true)
local base_path = "test/typescript/"

local get_file_content = function()
    return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end

describe("fix_current", function()
    after_each(function() vim.cmd("bufdo! bwipeout!") end)

    it("should import missing type", function()
        vim.cmd("e test/typescript/fix-current.ts")
        vim.wait(1000)

        vim.lsp.diagnostic.goto_prev()
        ts_utils.fix_current()
        vim.wait(500)

        assert.equals(vim.fn.search("{ User }", "nw"), 1)
    end)
end)

describe("request-handlers", function()
    after_each(function()
        vim.cmd("bufdo! bwipeout!")
        o.set({enable_formatting = false})
    end)

    it("should apply eslint fix", function()
        vim.cmd("e test/typescript/eslint-code-fix.js")
        vim.wait(500)
        vim.cmd("2")

        ts_utils.fix_current()
        vim.wait(500)

        assert.equals(vim.fn.search("===", "nwp"), 1)
    end)

    it("should show eslint diagnostics", function()
        vim.cmd("e test/typescript/eslint-code-fix.js")
        ts_utils.diagnostics()
        vim.wait(500)
        assert.equals(vim.api.nvim_win_get_cursor(0)[1], 1)

        vim.lsp.diagnostic.goto_next()

        assert.equals(vim.api.nvim_win_get_cursor(0)[1], 2)
    end)

    it("should format file on buf.formatting()", function()
        local formatted_line = [[import { User } from './test-types';]]
        o.set({enable_formatting = true})

        vim.cmd("e test/typescript/format.ts")
        vim.wait(500)
        assert.is_not.equals(get_file_content()[1], formatted_line)

        vim.lsp.buf.formatting()
        vim.wait(500)

        assert.equals(get_file_content()[1], formatted_line)
    end)

    it("should format file on buf.formatting_sync()", function()
        local formatted_line = [[import { User } from './test-types';]]
        o.set({enable_formatting = true})

        vim.cmd("e test/typescript/format.ts")
        vim.wait(500)
        assert.is_not.equals(get_file_content()[1], formatted_line)

        vim.lsp.buf.formatting_sync()
        vim.wait(500)

        assert.equals(get_file_content()[1], formatted_line)
    end)
end)

describe("import_all (sync)", function()
    after_each(function() vim.cmd("bufdo! bwipeout!") end)

    it("should import both missing types", function()
        vim.cmd("e test/typescript/import-all.ts")
        vim.wait(1000)

        vim.lsp.diagnostic.goto_prev()
        import_all(true)
        vim.wait(500)

        assert.equals(vim.fn.search("{ User, UserNotification }", "nw"), 1)
    end)
end)

describe("import all (async)", function()
    after_each(function() vim.cmd("bufdo! bwipeout!") end)

    it("should import both missing types", function()
        vim.cmd("e test/typescript/import-all.ts")
        vim.wait(1000)

        vim.lsp.diagnostic.goto_prev()
        import_all()
        vim.wait(500)

        assert.equals(vim.fn.search("{ User, UserNotification }", "nw"), 1)
    end)
end)

describe("organize_imports", function()
    after_each(function() vim.cmd("bufdo! bwipeout!") end)

    it("should remove unused import", function()
        vim.cmd("e test/typescript/organize-imports.ts")
        vim.wait(1000)

        ts_utils.organize_imports()
        vim.wait(500)

        assert.equals(vim.fn.search("Notification", "nw"), 0)
        assert.equals(vim.fn.search("User", "nw"), 1)
    end)
end)

describe("organize_imports_sync", function()
    after_each(function() vim.cmd("bufdo! bwipeout!") end)

    it("should remove unused import", function()
        vim.cmd("e test/typescript/organize-imports.ts")
        vim.wait(1000)

        ts_utils.organize_imports_sync()
        vim.wait(500)

        assert.equals(vim.fn.search("Notification", "nw"), 0)
        assert.equals(vim.fn.search("User", "nw"), 1)
    end)
end)

local rename_file_setup = function()
    local copy_test_file = function(original, target)
        os.execute(
            "cp " .. pwd .. "/test/typescript/" .. original .. " " .. pwd ..
                "/test/typescript/" .. target)
    end

    copy_test_file("file-to-be-moved.orig.ts", "file-to-be-moved.ts")
    copy_test_file("linked-file.orig.ts", "linked-file.ts")
    copy_test_file("existing-file.orig.ts", "existing-file.ts")
end

local rename_file_breakdown = function()
    vim.cmd("bufdo! bwipeout!")
    local delete_test_file = function(target)
        os.execute("rm " .. pwd .. "/test/typescript/" .. target ..
                       " 2> /dev/null")
    end

    delete_test_file("new-path.ts")
    delete_test_file("linked-file.ts")
    delete_test_file("file-to-be-moved.ts")
    delete_test_file("existing-file.ts")
end

describe("rename_file", function()
    before_each(function() rename_file_setup() end)
    after_each(function() rename_file_breakdown() end)
    it("should throw error on invalid filetype", function()
        vim.cmd("e " .. base_path .. "invalid_file.txt")

        vim.wait(1000)

        assert.has_errors(function() ts_utils.rename_file() end)
    end)

    it("should move file to specified path", function()
        vim.cmd("e " .. base_path .. "file-to-be-moved.ts")
        local original_content = get_file_content()
        vim.wait(1000)

        local new_path = pwd .. "/" .. base_path .. "new-path.ts"
        ts_utils.rename_file(new_path)
        vim.wait(200)

        local new_content = get_file_content()
        assert.equals(vim.fn.bufname(vim.fn.bufnr()), new_path)
        assert.same(original_content, new_content)
    end)

    it("should update imports in linked file", function()
        rename_file_setup()
        vim.cmd("e " .. base_path .. "file-to-be-moved.ts")
        vim.wait(1000)

        local new_path = pwd .. "/" .. base_path .. "new-path.ts"
        ts_utils.rename_file(new_path)
        vim.wait(200)

        vim.cmd("e " .. base_path .. "linked-file.ts")
        assert.equals(vim.fn.search("new-path", "nw"), 1)
    end)

    it("should overwrite existing file", function()
        rename_file_setup()
        vim.cmd("e " .. base_path .. "existing-file.ts")
        local original_content = get_file_content()

        vim.cmd("e " .. base_path .. "file-to-be-moved.ts")
        vim.wait(1000)
        local new_path = pwd .. "/" .. base_path .. "existing-file.ts"
        ts_utils.rename_file(new_path) -- prompt will be automatically accepted, it seems
        vim.wait(200)

        local new_content = get_file_content()
        assert.is.Not.same(original_content, new_content)
    end)
end)

