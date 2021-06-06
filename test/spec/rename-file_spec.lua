local mock = require("luassert.mock")
local stub = require("luassert.stub")

local utils = require("nvim-lsp-ts-utils.utils")
local options = require("nvim-lsp-ts-utils.options")

local u = mock(utils, true)
local o = mock(options, true)

describe("rename_file", function()
    stub(vim, "cmd")
    stub(vim.fn, "confirm")
    stub(vim.lsp, "get_active_clients")
    stub(vim.api, "nvim_get_current_buf")

    local mock_source, mock_target = "source.ts", "target.ts"
    local bufnr = 44
    before_each(function()
        vim.api.nvim_get_current_buf.returns(bufnr)
        u.buffer.name.returns(mock_source)
    end)

    after_each(function()
        vim.lsp.get_active_clients:clear()
        vim.fn.confirm:clear()
        vim.cmd:clear()
        vim.api.nvim_get_current_buf:clear()
        u.buffer.name:clear()
        o.get:clear()
    end)

    local rename_file = require("nvim-lsp-ts-utils.rename-file")

    describe("manual", function()
        stub(vim.fn, "input")
        stub(vim.fn, "getbufvar")

        before_each(function()
            vim.lsp.get_active_clients.returns({})
        end)
        after_each(function()
            vim.fn.input:clear()
            vim.fn.getbufvar:clear()

            u.file.exists:clear()
        end)

        describe("prompt", function()
            it("should prompt for user input if target is not specified ", function()
                rename_file.manual()

                assert.stub(vim.fn.input).was_called()
            end)

            it("should not prompt if target is specified", function()
                rename_file.manual(mock_target)

                assert.stub(vim.fn.input).was_not_called()
            end)

            it("should return if input returns error", function()
                vim.fn.input.invokes(function()
                    error("canceled")
                end)

                rename_file.manual()

                assert.stub(u.file.exists).was_not_called()
            end)

            it("should return if input returns empty string", function()
                vim.fn.input.returns("")

                rename_file.manual()

                assert.stub(u.file.exists).was_not_called()
            end)

            it("should return if input returns source", function()
                vim.fn.input.returns(mock_source)

                rename_file.manual()

                assert.stub(u.file.exists).was_not_called()
            end)
        end)

        describe("exists", function()
            it("should check if target exists", function()
                rename_file.manual(mock_target)

                assert.stub(u.file.exists).was_called_with(mock_target)
            end)

            it("should confirm if target exists", function()
                u.file.exists.returns(true)

                rename_file.manual(mock_target)

                assert.stub(vim.fn.confirm).was_called()
            end)

            it("should not confirm if force argument is set", function()
                u.file.exists.returns(true)

                rename_file.manual(mock_target, true)

                assert.stub(vim.fn.confirm).was_not_called()
            end)

            it("should return if confirm returns ~= 1", function()
                vim.fn.confirm.returns(2)
                u.file.exists.returns(true)

                rename_file.manual(mock_target)

                assert.stub(vim.fn.getbufvar).was_not_called()
            end)
        end)

        it("should write source if modified", function()
            vim.fn.getbufvar.returns(true)

            rename_file.manual(mock_target, true)

            assert.stub(vim.fn.getbufvar).was_called_with(bufnr, "&modified")
            assert.stub(vim.cmd).was_called_with("silent noautocmd w")
        end)

        it("should call mv util with source and target", function()
            rename_file.manual(mock_target, true)

            assert.stub(u.file.mv).was_called_with(mock_source, mock_target)
        end)

        it("should open target and bdelete source", function()
            rename_file.manual(mock_target, true)

            assert.stub(vim.cmd).was_called_with("e " .. mock_target)
            assert.stub(vim.cmd).was_called_with(bufnr .. "bdelete!")
        end)
    end)

    describe("on_move", function()
        stub(vim.api, "nvim_get_current_win")
        stub(vim.api, "nvim_get_current_buf")
        stub(vim.api, "nvim_win_get_config")
        stub(vim.api, "nvim_win_set_buf")
        stub(vim.api, "nvim_open_win")
        stub(vim.api, "nvim_set_current_win")
        stub(vim.api, "nvim_win_close")
        stub(vim.api, "nvim_buf_is_loaded")
        stub(vim.fn, "bufadd")
        stub(vim.fn, "bufload")
        stub(vim.fn, "setbufvar")
        stub(vim.fn, "getbufinfo")

        local target_bufnr = 102
        local original_win = 55
        local original_bufnr = 12
        before_each(function()
            vim.api.nvim_get_current_win.returns(original_win)
            vim.api.nvim_get_current_buf.returns(original_bufnr)
            vim.api.nvim_win_get_config.returns({})
            vim.fn.bufadd.returns(target_bufnr)
            vim.fn.getbufinfo.returns({})

            o.get.returns({})
            u.file.extension.returns(nil)
            u.file.is_dir.returns(nil)
        end)

        after_each(function()
            vim.api.nvim_get_current_win:clear()
            vim.api.nvim_get_current_buf:clear()
            vim.api.nvim_win_get_config:clear()
            vim.api.nvim_win_set_buf:clear()
            vim.api.nvim_open_win:clear()
            vim.api.nvim_buf_is_loaded:clear()
            vim.fn.bufadd:clear()
            vim.fn.bufload:clear()
            vim.fn.setbufvar:clear()
            vim.fn.getbufinfo:clear()

            u.file.extension:clear()
            u.file.is_dir:clear()
            u.file.dir_file:clear()
        end)

        it("should prompt for confirmation if option is set", function()
            o.get.returns({ require_confirmation_on_move = true })

            rename_file.on_move(mock_source, mock_target)

            assert.stub(vim.fn.confirm).was_called()
        end)

        it("should not prompt for confirmation if option is not set", function()
            o.get.returns({ require_confirmation_on_move = nil })

            rename_file.on_move(mock_source, mock_target)

            assert.stub(vim.fn.confirm).was_not_called()
        end)

        it("should return if confirm returns ~= 1", function()
            o.get.returns({ require_confirmation_on_move = true })
            vim.fn.confirm.returns(2)

            rename_file.on_move(mock_source, mock_target)

            assert.stub(vim.api.nvim_get_current_win).was_not_called()
        end)

        it("should call dir_file if target is dir", function()
            u.file.extension.returns("")
            u.file.is_dir.returns(true)

            rename_file.on_move(mock_source, mock_target)

            assert.stub(u.file.dir_file).was_called_with(mock_target)
        end)

        it("should add, load, and set buflisted on target", function()
            rename_file.on_move(mock_source, mock_target)

            assert.stub(vim.fn.bufadd).was_called_with(mock_target)
            assert.stub(vim.fn.bufload).was_called_with(mock_target)
            assert.stub(vim.fn.setbufvar).was_called_with(target_bufnr, "&buflisted", 1)
        end)

        it("should open and close temporary window", function()
            local temp_win_id = 752
            vim.api.nvim_open_win.returns(temp_win_id)

            rename_file.on_move(mock_source, mock_target)

            assert.stub(vim.api.nvim_open_win).was_called_with(target_bufnr, true, {
                relative = "editor",
                height = 1,
                width = 1,
                row = 1,
                col = 1,
            })
            assert.stub(vim.api.nvim_set_current_win).was_called_with(original_win)
            assert.stub(vim.api.nvim_win_close).was_called_with(temp_win_id, true)
        end)

        it("should edit target if source file was focused", function()
            vim.api.nvim_get_current_buf.returns(original_bufnr)
            u.buffer.bufnr.returns(original_bufnr)

            rename_file.on_move(mock_source, mock_target)

            assert.stub(vim.cmd).was_called_with("e " .. mock_target)
        end)

        it("should delete source buffer if loaded", function()
            vim.api.nvim_buf_is_loaded.returns(true)

            rename_file.on_move(mock_source, mock_target)

            assert.stub(vim.cmd).was_called_with(original_bufnr .. "bdelete!")
        end)

        describe("floating window", function()
            it("should get window config and source buffer info", function()
                rename_file.on_move(mock_source, mock_target)

                assert.stub(vim.api.nvim_win_get_config).was_called_with(original_win)
                assert.stub(vim.fn.getbufinfo).was_called_with(original_bufnr)
            end)

            it("should load target buffer into source window", function()
                u.buffer.bufnr.returns(original_bufnr)
                vim.api.nvim_win_get_config.returns({ relative = "window" })
                vim.fn.getbufinfo.returns({ { windows = { 5000 } } })

                rename_file.on_move(mock_source, mock_target)

                assert.stub(vim.api.nvim_win_set_buf).was_called_with(5000, target_bufnr)
            end)
        end)
    end)

    describe("rename_file", function()
        local request = stub.new()
        stub(vim, "uri_from_fname")

        local mock_uri, mock_client = "mock_uri", nil
        before_each(function()
            vim.uri_from_fname.returns(mock_uri)

            mock_client = { request = request, name = "tsserver" }
            vim.lsp.get_active_clients.returns({ mock_client })
        end)

        after_each(function()
            request:clear()
            vim.uri_from_fname:clear()
            u.echo_warning:clear()
        end)

        it("should loop over clients and call client.request with command if name matches", function()
            rename_file.manual(mock_target, true)

            assert.stub(vim.lsp.get_active_clients).was_called()
            assert.stub(vim.uri_from_fname).was_called_with(mock_source)
            assert.stub(vim.uri_from_fname).was_called_with(mock_target)
            assert.stub(request).was_called_with("workspace/executeCommand", {
                command = "_typescript.applyRenameFile",
                arguments = {
                    {
                        sourceUri = mock_uri,
                        targetUri = mock_uri,
                    },
                },
            })
        end)

        it("should echo warning if no client found", function()
            mock_client.name = nil

            rename_file.manual(mock_target, true)

            assert.stub(request).was_not_called()
            assert.stub(u.echo_warning).was_called_with("failed to rename file: tsserver not running")
        end)

        it("should echo warning if client response is falsy", function()
            request.returns(false)

            rename_file.manual(mock_target, true)

            assert.stub(u.echo_warning).was_called_with("failed to rename file: tsserver request failed")
        end)
    end)
end)
