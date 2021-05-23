local has_null_ls, null_ls = pcall(require, "null-ls")

local ts_utils = require("nvim-lsp-ts-utils")
local integrations = require("nvim-lsp-ts-utils.integrations")
local o = require("nvim-lsp-ts-utils.options")

local base_path = "test/files/"

local edit_test_file = function(name) vim.cmd("e " .. base_path .. name) end

local get_file_content = function()
    return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end

describe("integrations", function()
    if not has_null_ls then
        print("did not run integration tests (null-ls not installed)")
        return
    end

    describe("null_ls", function()
        o.set({
            enable_eslint_code_actions = true,
            eslint_enable_diagnostics = true
        })
        null_ls.setup {}
        integrations.setup()

        after_each(function() vim.cmd("bufdo! bwipeout!") end)

        it("should apply eslint fix", function()
            -- file contains ==, which is a violation of eqeqeq
            edit_test_file("eslint-code-fix.js")
            vim.wait(500)
            vim.cmd("2")

            ts_utils.fix_current()
            vim.wait(500)

            -- check that eslint fix has been applied, replacing == with ===
            assert.equals(vim.fn.search("===", "nwp"), 1)
        end)

        it("should add disable rule comment with matching indentation",
           function()
            edit_test_file("eslint-code-fix.js")
            vim.wait(500)
            vim.cmd("2")

            ts_utils.fix_current(2)
            vim.wait(500)

            assert.equals(get_file_content()[2],
                          "  // eslint-disable-next-line eqeqeq")
        end)

        it("should show eslint diagnostics", function()
            edit_test_file("eslint-code-fix.js")
            ts_utils.diagnostics()
            vim.wait(500)
            assert.equals(vim.api.nvim_win_get_cursor(0)[1], 1)

            vim.lsp.diagnostic.goto_next()

            -- error is on line 2, so diagnostic.goto_next should move cursor down
            assert.equals(vim.api.nvim_win_get_cursor(0)[1], 2)
            -- assert that diagnostics are only coming from null-ls
            assert.equals(vim.tbl_count(vim.lsp.diagnostic.get()), 1)
        end)
    end)
end)

null_ls.shutdown()
