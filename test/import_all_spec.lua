local import_all = require("nvim-lsp-ts-utils.import-all")

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
