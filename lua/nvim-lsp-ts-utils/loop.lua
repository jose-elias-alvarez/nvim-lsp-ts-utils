local uv = vim.loop
local schedule = vim.schedule_wrap

local M = {}

M.watch_dir = function(dir, opts)
    local on_event, on_error = opts.on_event, opts.on_error

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

        on_event(filename, events)
    end)

    uv.fs_event_start(handle, dir, { recursive = true }, callback)
    return unwatch
end

return M
