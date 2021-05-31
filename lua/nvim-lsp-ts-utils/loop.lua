local uv = vim.loop
local schedule = vim.schedule_wrap
local validate = vim.validate

local M = {}

M.watch_dir = function(dir, opts)
    local on_event, on_error = opts.on_event, opts.on_error
    validate({
        dir = { dir, "string" },
        on_event = { on_event, "function" },
        on_error = { on_error, "function", true },
    })

    local handle = uv.new_fs_event()
    local unwatch = function()
        uv.fs_event_stop(handle)
    end

    local callback = schedule(function(err, filename, events)
        if err then
            if on_error then
                on_error(err)
            end
            unwatch()
            error(err)
        end

        on_event(filename, events, unwatch)
    end)

    uv.fs_event_start(handle, dir, { recursive = true }, callback)
    return unwatch
end

return M
