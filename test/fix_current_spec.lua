local ts_utils = require("nvim-lsp-ts-utils")

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

