local stub = require("luassert.stub")

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

        it("should throw if simple config type does not match", function()
            local ok, err = pcall(o.setup, { debug = "true" })

            assert.equals(ok, false)
            assert.matches("expected boolean", err)
        end)

        it("should set config value with table override", function()
            o.setup({ watch_dir = "src/" })

            assert.equals(o.get().watch_dir, "src/")
        end)

        it("should throw if table override config type does not match", function()
            local ok, err = pcall(o.setup, { watch_dir = true })

            assert.equals(ok, false)
            assert.matches("expected string, nil", err)
        end)

        it("should throw if config value is private", function()
            local ok, err = pcall(o.setup, { _initialized = true })

            assert.equals(ok, false)
            assert.matches("expected nil", err)
        end)

        it("should set config value with function override", function()
            o.setup({ eslint_bin = "eslint" })

            assert.equals(o.get().eslint_bin, "eslint")
        end)

        it("should throw if function override config type does not match", function()
            local ok, err = pcall(o.setup, { eslint_bin = "something-else" })

            assert.equals(ok, false)
            assert.matches("expected eslint, eslint_d", err)
        end)
    end)
end)
