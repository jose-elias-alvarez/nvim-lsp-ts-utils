local stub = require("luassert.stub")

local api = vim.api

describe("utils", function()
    _G._TEST = true

    stub(api, "nvim_exec")
    after_each(function()
        api.nvim_exec:clear()
    end)

    local u = require("nvim-lsp-ts-utils.utils")

    describe("is_tsserver_file", function()
        local base = "/Users/jose/my-project/"

        it("should match js file path", function()
            local path = base .. "my-file.js"

            assert.truthy(u.is_tsserver_file(path))
        end)

        it("should match jsx file path", function()
            local path = base .. "my-file.jsx"

            assert.truthy(u.is_tsserver_file(path))
        end)

        it("should match ts file path", function()
            local path = base .. "my-file.ts"

            assert.truthy(u.is_tsserver_file(path))
        end)

        it("should match tsx file path", function()
            local path = base .. "my-file.tsx"

            assert.truthy(u.is_tsserver_file(path))
        end)

        it("should not match non-tsserver file path", function()
            local path = base .. "README.md"

            assert.falsy(u.is_tsserver_file(path))
        end)

        it("should not match when path contains extension", function()
            local path = base .. "js/my-misleading-file.css"

            assert.falsy(u.is_tsserver_file(path))
        end)

        it("should not match when filename contains extension", function()
            local path = base .. "js-styles.css"

            assert.falsy(u.is_tsserver_file(path))
        end)
    end)

    describe("echo_warning", function()
        stub(api, "nvim_echo")
        after_each(function()
            api.nvim_echo:clear()
        end)

        it("should call api.nvim_echo with args", function()
            u.echo_warning("something went wrong")

            assert.stub(api.nvim_echo).was_called_with(
                { { "nvim-lsp-ts-utils: something went wrong", "WarningMsg" } },
                true,
                {}
            )
        end)
    end)

    describe("file", function()
        describe("extension", function()
            it("should get file extension", function()
                local extension = u.file.extension("test.tsx")

                assert.equals(extension, "tsx")
            end)

            it("should return empty string if no file extension", function()
                local extension = u.file.extension("test")

                assert.equals(extension, "")
            end)
        end)
    end)
end)
