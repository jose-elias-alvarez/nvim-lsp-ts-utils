local mock = require("luassert.mock")
local stub = require("luassert.stub")

local uv = mock(vim.loop, true)

describe("loop", function()
    stub(vim, "schedule_wrap")

    local dir = "/my/mock/dir"
    local handle = 50
    before_each(function()
        uv.new_fs_event.returns(handle)
    end)
    after_each(function()
        uv.new_fs_event:clear()
        uv.fs_event_stop:clear()
        vim.schedule_wrap:clear()
    end)

    local loop = require("nvim-lsp-ts-utils.loop")

    describe("watch_dir", function()
        it("should call fs_event_start with args", function()
            vim.schedule_wrap.returns("scheduled")

            loop.watch_dir(dir, {})

            assert.equals(uv.fs_event_start.calls[1].refs[1], handle)
            assert.equals(uv.fs_event_start.calls[1].refs[2], dir)
            assert.same(uv.fs_event_start.calls[1].refs[3], { recursive = true })
            assert.equals(uv.fs_event_start.calls[1].refs[4], "scheduled")
        end)

        it("should return unwatch callback", function()
            local unwatch = loop.watch_dir(dir, {})

            unwatch()

            assert.stub(uv.fs_event_stop).was_called_with(handle)
        end)

        describe("callback", function()
            local on_error, on_event = stub.new(), stub.new()

            local callback
            before_each(function()
                loop.watch_dir(dir, { on_error = on_error, on_event = on_event })
                callback = vim.schedule_wrap.calls[1].refs[1]
            end)
            after_each(function()
                on_event:clear()
                on_error:clear()
            end)

            it("should throw error and unwatch", function()
                local error = "something went wrong"

                assert.has_error(function()
                    callback(error)
                end)

                assert.stub(uv.fs_event_stop).was_called_with(handle)
            end)

            it("should call on_error callback", function()
                local error = "something went wrong"

                assert.has_error(function()
                    callback(error)
                end)

                assert.stub(on_error).was_called_with(error)
            end)

            it("should call on_event callback with filename and events", function()
                local filename = "test-file.ts"
                local events = { rename = true }

                callback(nil, filename, events)

                assert.stub(on_event).was_called_with(filename, events)
            end)
        end)
    end)
end)
