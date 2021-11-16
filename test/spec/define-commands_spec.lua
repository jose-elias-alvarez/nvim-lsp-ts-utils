local stub = require("luassert.stub")

local o = require("nvim-lsp-ts-utils.options")

local exists = function(cmd)
    return vim.fn.exists(":" .. cmd) > 0
end

describe("define_commands", function()
    stub(o, "get")
    before_each(function()
        o.get.returns({})
    end)
    after_each(function()
        o.get:clear()
    end)

    local define_commands = require("nvim-lsp-ts-utils.define-commands")

    it("should not define commands if option is disabled", function()
        o.get.returns({ disable_commands = true })

        define_commands()

        assert.equals(exists("TSLspRenameFile"), false)
        assert.equals(exists("TSLspOrganize"), false)
        assert.equals(exists("TSLspOrganizeSync"), false)
        assert.equals(exists("TSLspRenameFile"), false)
        assert.equals(exists("TSLspImportAll"), false)
    end)

    it("should define commands if option is not disabled", function()
        o.get.returns({ disable_commands = nil })

        define_commands()

        assert.equals(exists("TSLspRenameFile"), true)
        assert.equals(exists("TSLspOrganize"), true)
        assert.equals(exists("TSLspOrganizeSync"), true)
        assert.equals(exists("TSLspRenameFile"), true)
        assert.equals(exists("TSLspImportAll"), true)
    end)
end)
