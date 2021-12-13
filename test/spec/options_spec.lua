describe("config", function()
    local o = require("nvim-lsp-ts-utils.options")

    after_each(function()
        o.reset()
    end)

    describe("get", function()
        it("should get option", function()
            o.setup({ debug = true })

            assert.equals(o.get().debug, true)
        end)
    end)

    describe("reset", function()
        it("should reset options to defaults", function()
            o.setup({ debug = true })

            o.reset()

            assert.equals(o.get().debug, false)
        end)
    end)

    describe("setup", function()
        it("should only setup once", function()
            o.setup({ debug = true })

            o.setup({ debug = false })

            assert.equals(o.get().debug, true)
        end)
    end)
end)
