describe("utils", function()
    local u = require("nvim-lsp-ts-utils.utils")

    describe("tsserver_extensions", function()
        local base = "/Users/jose/my-project/"
        local matches = function(str)
            return string.match(str, u.tsserver_extensions)
        end

        it("should match js file path", function()
            local path = base .. "my-file.js"

            assert.truthy(matches(path))
        end)

        it("should match jsx file path", function()
            local path = base .. "my-file.jsx"

            assert.truthy(matches(path))
        end)

        it("should match ts file path", function()
            local path = base .. "my-file.ts"

            assert.truthy(matches(path))
        end)

        it("should match tsx file path", function()
            local path = base .. "my-file.tsx"

            assert.truthy(matches(path))
        end)

        it("should not match non-tsserver file path", function()
            local path = base .. "README.md"

            assert.falsy(matches(path))
        end)

        it("should not match when path contains extension", function()
            local path = base .. "js/my-misleading-file.css"

            assert.falsy(matches(path))
        end)

        it("should not match when filename contains extension", function()
            local path = base .. "js-styles.css"

            assert.falsy(matches(path))
        end)
    end)
end)
