local mock = require("luassert.mock")
local stub = require("luassert.stub")

local lsputil = require("lspconfig.util")
local scandir = require("plenary.scandir")

local options = require("nvim-lsp-ts-utils.options")
local utils = require("nvim-lsp-ts-utils.utils")
local rename_file = require("nvim-lsp-ts-utils.rename-file")
local _loop = require("nvim-lsp-ts-utils.loop")

local o = mock(options, true)
local u = mock(utils, true)
local loop = mock(_loop, true)

describe("watcher", function()
    stub(vim, "defer_fn")
    stub(scandir, "scan_dir")
    stub(lsputil, "find_git_ancestor")
    stub(lsputil.path, "is_dir")
    stub(lsputil.path, "exists")
    local watcher = require("nvim-lsp-ts-utils.watcher")

    local mock_root = "/my/root/dir"
    after_each(function()
        vim.defer_fn:clear()
        lsputil.find_git_ancestor:clear()
        lsputil.path.is_dir:clear()
        lsputil.path.exists:clear()
        scandir.scan_dir:clear()
        u.buffer.root:clear()

        watcher.state.reset()
    end)

    describe("state", function()
        it("should contain default values", function()
            assert.equals(watcher.state.watching, false)
            assert.equals(watcher.state.unwatch, nil)
            assert.equals(watcher.state._source, nil)
        end)

        it("should reset state on reset()", function()
            watcher.state.watching = true
            watcher.state.unwatch = function()
                print("unwatching")
            end
            watcher.state._source = "test-file.ts"

            watcher.state.reset()

            assert.equals(watcher.state.watching, false)
            assert.equals(watcher.state.unwatch, nil)
            assert.equals(watcher.state._source, nil)
        end)

        describe("source", function()
            it("should set source on set()", function()
                watcher.state.source.set("test-file.ts")

                assert.equals(watcher.state._source, "test-file.ts")
            end)

            it("should get source on get()", function()
                watcher.state.source.set("test-file.ts")

                assert.equals(watcher.state.source.get(), "test-file.ts")
            end)

            it("should reset source on reset()", function()
                watcher.state.source.set("test-file.ts")

                watcher.state.source.reset()

                assert.equals(watcher.state.source.get(), nil)
            end)
        end)
    end)

    describe("start", function()
        after_each(function()
            loop.watch_dir:clear()
        end)

        it("should return immediately if already watching", function()
            watcher.state.watching = true

            watcher.start()

            assert.stub(u.buffer.root).was_not_called()
        end)

        it("should return if root cannot be determined", function()
            u.buffer.root.returns(nil)

            watcher.start()

            assert.equals(watcher.state.watching, false)
        end)

        describe("git project", function()
            before_each(function()
                u.buffer.root.returns(mock_root)
                lsputil.find_git_ancestor.returns(true)
            end)
            after_each(function()
                loop.watch_dir:clear()
            end)

            it("should call scan_dir with root dir and args", function()
                scandir.scan_dir.returns({})

                watcher.start()

                assert.stub(scandir.scan_dir).was_called_with(
                    mock_root,
                    { respect_gitignore = true, depth = 1, only_dirs = true }
                )
            end)

            it("should not start watching if scan_dir result is empty", function()
                scandir.scan_dir.returns({})

                watcher.start()

                assert.equals(watcher.state.watching, false)
            end)

            it("should call watch_dir with file path and start watching", function()
                scandir.scan_dir.returns({ "dir1", "dir2" })

                watcher.start()

                assert.equals(loop.watch_dir.calls[1].refs[1], "dir1")
                assert.equals(loop.watch_dir.calls[2].refs[1], "dir2")
                assert.equals(watcher.state.watching, true)
            end)

            it("should call callbacks on unwatch()", function()
                local callback = stub.new()
                loop.watch_dir.returns(callback)
                scandir.scan_dir.returns({ "dir1", "dir2", "dir3" })

                watcher.start()
                watcher.state.unwatch()

                assert.stub(callback).was_called(3)
            end)
        end)

        describe("watch_dir fallback", function()
            local watch_dir = "/my/watch/dir"
            before_each(function()
                o.get.returns({ watch_dir = watch_dir })
                lsputil.path.is_dir.returns(true)
                u.buffer.root.returns(mock_root)
                lsputil.find_git_ancestor.returns(false)
            end)
            after_each(function()
                o.get:clear()
                loop.watch_dir:clear()
            end)

            it("should return if watch_dir is not set", function()
                o.get.returns({})

                watcher.start()

                assert.equals(watcher.state.watching, false)
            end)

            it("should return if watch_dir is not dir", function()
                lsputil.path.is_dir.returns(false)

                watcher.start()

                assert.stub(lsputil.path.is_dir).was_called_with(mock_root .. watch_dir)
                assert.equals(watcher.state.watching, false)
            end)

            it("should start watching if watch_dir is dir", function()
                watcher.start()

                assert.equals(watcher.state.watching, true)
            end)

            it("should set unwatch to watch_dir callback", function()
                local callback = stub.new()
                loop.watch_dir.returns(callback)

                watcher.start()

                assert.equals(watcher.state.unwatch, callback)
            end)
        end)

        describe("on_error", function()
            local on_error
            before_each(function()
                o.get.returns({ watch_dir = "dir" })
                lsputil.path.is_dir.returns(true)

                watcher.start()
                on_error = loop.watch_dir.calls[1].refs[2].on_error
            end)
            after_each(function()
                u.echo_warning:clear()
                loop.watch_dir:clear()

                watcher.state.reset()
            end)

            it("should echo error message and reset state", function()
                watcher.state.watching = true

                on_error("something went wrong")

                assert.stub(u.echo_warning).was_called_with("error in watcher: something went wrong")
                assert.equals(watcher.state.watching, false)
            end)
        end)

        describe("on_event", function()
            stub(rename_file, "on_move")

            local watch_dir = "/my/watch/dir"
            local on_event
            before_each(function()
                o.get.returns({ watch_dir = watch_dir })
                u.is_tsserver_file.returns(true)
                lsputil.path.is_dir.returns(true)

                watcher.start()
                on_event = loop.watch_dir.calls[1].refs[2].on_event
            end)
            after_each(function()
                u.is_tsserver_file:clear()
                u.file.extension:clear()
                loop.watch_dir:clear()
                rename_file.on_move:clear()

                watcher.state.reset()
            end)

            it("should return if path is not tsserver file and has extension", function()
                u.is_tsserver_file.returns(false)
                u.file.extension.returns(".md")

                on_event("file.md")

                assert.stub(u.is_tsserver_file).was_called()
                assert.stub(u.file.extension).was_called()
                assert.equals(watcher.state.source.get(), nil)
            end)

            it("should set source if not set", function()
                on_event("file.ts")

                assert.equals(watcher.state.source.get(), mock_root .. watch_dir .. "/" .. "file.ts")
            end)

            it("should reset source in defer callback", function()
                on_event("file.ts")

                local callback = vim.defer_fn.calls[1].refs[1]
                callback()

                assert.equals(watcher.state.source.get(), nil)
            end)

            it("should reset source if source and target are the same", function()
                on_event("file.ts")
                on_event("file.ts")

                assert.stub(rename_file.on_move).was_not_called()
                assert.equals(watcher.state.source.get(), nil)
            end)

            it("should call on_move with source and target and reset source", function()
                local source = lsputil.path.join(mock_root, watch_dir, "file1.ts")
                local target = lsputil.path.join(mock_root, watch_dir, "file2.ts")
                lsputil.path.exists.on_call_with(source).returns(false)
                lsputil.path.exists.on_call_with(target).returns(true)

                on_event("file1.ts")
                on_event("file2.ts")

                assert.stub(rename_file.on_move).was_called_with(source, target)
                assert.equals(watcher.state.source.get(), nil)
            end)
        end)
    end)
end)
