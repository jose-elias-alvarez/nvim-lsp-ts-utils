local ts_utils = require("nvim-lsp-ts-utils")

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
