local u = require("nvim-lsp-ts-utils.utils")
local s = require("nvim-lsp-ts-utils.state")

local uv = vim.loop
local schedule = vim.schedule_wrap

local close_handle = function(handle)
    if handle and not handle:is_closing() then handle:close() end
end

local exit_code_is_ok = function(code, cmd)
    if code == 0 then return true end
    -- eslint (but not eslint_d!) exits w/ 1 if linting was successful but errors exceed threshold
    -- eslint_d error has to be caught by reading output, since it exits w/ 1 in both cases
    if (string.match(cmd, "eslint")) and code == 1 then return true end
    return false
end

local M = {}

M.buf_to_stdin = function(cmd, args, handler)
    local handle, ok
    local output, error_output = "", ""

    local handle_stdout = schedule(function(err, chunk)
        if err then error("stdout error: " .. err) end

        if chunk then output = output .. chunk end
        if not chunk then
            -- wait for exit code
            vim.wait(5000, function() return ok ~= nil end, 10)
            if not ok and error_output == "" then
                error_output = output
                output = ""
            end

            -- convert empty strings to nil to make error handling easier in handlers
            if output == "" then
                u.debug_log("command " .. cmd .. " output was empty")
                output = nil
            else
                u.debug_log("command " .. cmd .. " output:\n" .. output)
            end
            if error_output == "" then
                u.debug_log("command " .. cmd .. " error output was empty")
                error_output = nil
            else
                u.debug_log("command " .. cmd .. " error output:\n" ..
                                error_output)
            end
            handler(error_output, output)
        end
    end)

    local handle_stderr = function(err, chunk)
        if err then error("stderr error: " .. err) end
        if chunk then error_output = error_output .. chunk end
    end

    local stdin = uv.new_pipe(true)
    local stdout = uv.new_pipe(false)
    local stderr = uv.new_pipe(false)
    local stdio = {stdin, stdout, stderr}

    u.debug_log("spawning command " .. cmd .. " with args:")
    u.debug_log(args)
    handle = uv.spawn(cmd, {args = args, stdio = stdio}, function(code, signal)
        ok = exit_code_is_ok(code, cmd)
        u.debug_log("command " .. cmd .. " exited with code " .. code)
        u.debug_log("exiting with signal " .. signal)

        stdout:read_stop()
        stderr:read_stop()
        u.debug_log("stdout and stderr pipes closed")

        close_handle(stdin)
        close_handle(stdout)
        close_handle(stderr)
        close_handle(handle)
        u.debug_log("handles closed")
    end)

    uv.read_start(stdout, handle_stdout)
    uv.read_start(stderr, handle_stderr)

    u.debug_log("writing content of buffer " .. u.buffer.name() .. " to stdin")
    stdin:write(u.buffer.to_string(), function()
        stdin:close()
        u.debug_log("stdin pipe closed")
    end)
end

M.watch_dir = function(dir, on_event)
    local handle = uv.new_fs_event()

    local unwatch = function()
        s.set({watching = false})
        uv.fs_event_stop(handle)
    end

    local callback = schedule(function(err, filename, events)
        if err then
            unwatch()
            error(err)
        else
            on_event(filename, events, unwatch)
        end
    end)

    uv.fs_event_start(handle, dir, {recursive = true}, callback)
    s.set({watching = true})
end

return M
