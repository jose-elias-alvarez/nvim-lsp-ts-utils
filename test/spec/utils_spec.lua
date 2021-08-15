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

    describe("buf_command", function()
        stub(vim, "cmd")
        after_each(function()
            vim.cmd:clear()
        end)

        it("should call vim.cmd with formatted command", function()
            u.buf_command("MyCommand", "my_function()")

            assert.stub(vim.cmd).was_called_with(
                "command! -buffer MyCommand lua require'nvim-lsp-ts-utils'.my_function()"
            )
        end)
    end)

    describe("buf_augroup", function()
        it("should call exec with formatted augroup", function()
            u.buf_augroup("MyAugroup", "BufEnter", "my_function()")

            assert.stub(api.nvim_exec).was_called_with(
                [[
            augroup MyAugroup
                autocmd! * <buffer>
                autocmd BufEnter <buffer> lua require'nvim-lsp-ts-utils'.my_function()
            augroup END
            ]],
                false
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

    describe("resolve_bin", function()
        before_each(function()
            stub(u.file, "exists")
        end)
        after_each(function()
            u.file.exists:revert()
        end)

        it("should return local bin path if local bin exists", function()
            u.file.exists.returns(true)

            local bin = u.resolve_bin("eslint")

            assert.truthy(string.find(bin, "node_modules/.bin"))
        end)

        it("should return cmd if local bin does not exist", function()
            u.file.exists.returns(false)

            local bin = u.resolve_bin("eslint")

            assert.equals(bin, "eslint")
        end)
    end)

    describe("config_file_exists", function()
        local root = u.buffer.root()

        before_each(function()
            stub(u.file, "exists")
        end)
        after_each(function()
            u.file.exists:revert()
        end)

        it("should check eslint config files", function()
            u.config_file_exists("eslint")

            assert.stub(u.file.exists).was_called_with(root .. "/" .. ".eslintrc")
            assert.stub(u.file.exists).was_called_with(root .. "/" .. ".eslintrc.js")
            assert.stub(u.file.exists).was_called_with(root .. "/" .. ".eslintrc.json")
            assert.stub(u.file.exists).was_called_with(root .. "/" .. ".eslintrc.yml")
            assert.stub(u.file.exists).was_called_with(root .. "/" .. ".eslintrc.yaml")
        end)

        it("should check eslint_d config files", function()
            u.config_file_exists("eslint_d")

            assert.stub(u.file.exists).was_called_with(root .. "/" .. ".eslintrc")
            assert.stub(u.file.exists).was_called_with(root .. "/" .. ".eslintrc.js")
            assert.stub(u.file.exists).was_called_with(root .. "/" .. ".eslintrc.json")
            assert.stub(u.file.exists).was_called_with(root .. "/" .. ".eslintrc.yml")
            assert.stub(u.file.exists).was_called_with(root .. "/" .. ".eslintrc.yaml")
        end)

        it("should check prettier config files", function()
            u.config_file_exists("prettier")

            assert.stub(u.file.exists).was_called_with(root .. "/" .. ".prettierrc")
            assert.stub(u.file.exists).was_called_with(root .. "/" .. ".prettierrc.js")
            assert.stub(u.file.exists).was_called_with(root .. "/" .. ".prettierrc.json")
            assert.stub(u.file.exists).was_called_with(root .. "/" .. ".prettierrc.yml")
            assert.stub(u.file.exists).was_called_with(root .. "/" .. ".prettierrc.yaml")
        end)

        it("should check git config files", function()
            u.config_file_exists("git")

            assert.stub(u.file.exists).was_called_with(root .. "/" .. ".gitignore")
        end)

        it("should return true if config file found", function()
            u.file.exists.returns(true)

            local exists = u.config_file_exists("git")

            assert.equals(exists, true)
        end)

        it("should return true if no config files found", function()
            u.file.exists.returns(false)

            local exists = u.config_file_exists("git")

            assert.equals(exists, false)
        end)
    end)
end)
