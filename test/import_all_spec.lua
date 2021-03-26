local ts_utils = require("nvim-lsp-ts-utils")

describe("import_all", function()
    after_each(function() vim.cmd("bufdo! bwipeout!") end)

    it("should import both missing types", function()
        vim.cmd("e test/typescript/import-all.ts")
        vim.wait(1000)

        vim.lsp.diagnostic.goto_prev()
        ts_utils.import_all()
        vim.wait(500)

        assert.equals(vim.fn.search("{ User, UserNotification }", "nw"), 1)
    end)
end)

