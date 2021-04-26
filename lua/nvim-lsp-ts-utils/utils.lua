local o = require("nvim-lsp-ts-utils.options")

local uv = vim.loop
local api = vim.api
local schedule = vim.schedule_wrap

local tsserver_fts = {
    "javascript", "javascriptreact", "typescript", "typescriptreact"
}

local contains = function(list, candidate)
    for _, element in pairs(list) do
        if element == candidate then return true end
    end
    return false
end

local close_handle = function(handle)
    if handle and not handle:is_closing() then handle:close() end
end

local code_is_ok = function(code, cmd)
    if code == 0 then return true end
    -- eslint (but not eslint_d!) exits w/ 1 if linting was successful but errors exceed threshold
    -- eslint_d error has to be caught by reading output, since it exits w/ 1 in both cases
    if cmd == "eslint" and code == 1 then return true end
    return false
end

local M = {}

M.echo_warning = function(message)
    vim.api.nvim_echo({{"nvim-lsp-ts-utils: " .. message, "WarningMsg"}}, true,
                      {})
end

M.removed_warning = function(method)
    M.echo_warning(method ..
                       " has been removed! Please see the readme for instructions.")
end

local debug_log = function(target)
    if not o.get().debug then return end

    if type(target) == "table" then
        print(vim.inspect(target))
    else
        print(target)
    end
end
M.debug_log = debug_log

M.print_no_actions_message = function() print("No code actions available") end

M.file = {
    mv = function(source, target)
        local ok = uv.fs_rename(source, target)
        if not ok then
            return false, "failed to move " .. source .. " to " .. target
        end

        return true
    end,

    exists = function(path)
        local file = uv.fs_open(path, "r", 438)
        if not file then return false end

        return true
    end,

    is_tsserver_ft = function(bufnr)
        if not bufnr then bufnr = 0 end
        local ft = api.nvim_buf_get_option(bufnr, "filetype")
        if not contains(tsserver_fts, ft) then error("invalid filetype") end
    end
}

M.table = {
    contains = contains,

    len = function(table)
        local count = 0
        for _ in pairs(table) do count = count + 1 end
        return count
    end
}

M.buffer = {
    name = function(bufnr)
        if bufnr == nil then bufnr = 0 end
        return api.nvim_buf_get_name(bufnr)
    end,

    to_string = function(bufnr)
        if bufnr == nil then bufnr = 0 end
        local content = api.nvim_buf_get_lines(bufnr, 0, -1, false)
        return table.concat(content, "\n") .. "\n"
    end,

    line = function(line, bufnr)
        return api.nvim_buf_get_lines(bufnr and bufnr or 0, line - 1, line,
                                      false)[1]
    end
}

M.string = {
    split_at_newline = function(str)
        local split = {}
        for line in string.gmatch(str, "([^\n]*)\n?") do
            table.insert(split, line)
        end
        -- remove final empty newline
        table.remove(split)
        return split
    end
}

M.loop = {
    buf_to_stdin = function(cmd, args, handler)
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
                    debug_log("command " .. cmd .. " output was empty")
                    output = nil
                else
                    debug_log("command " .. cmd .. " output:\n" .. output)
                end
                if error_output == "" then
                    debug_log("command " .. cmd .. " error output was empty")
                    error_output = nil
                else
                    debug_log("command " .. cmd .. " error output:\n" ..
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

        debug_log("spawning command " .. cmd .. " with args:")
        debug_log(args)
        handle = uv.spawn(cmd, {args = args, stdio = stdio},
                          function(code, signal)
            ok = code_is_ok(code, cmd)
            debug_log("command " .. cmd .. " exited with code " .. code)
            debug_log("exiting with signal " .. signal)

            stdout:read_stop()
            stderr:read_stop()
            debug_log("stdout and stderr pipes closed")

            close_handle(stdin)
            close_handle(stdout)
            close_handle(stderr)
            close_handle(handle)
            debug_log("handles closed")
        end)

        uv.read_start(stdout, handle_stdout)
        uv.read_start(stderr, handle_stderr)

        debug_log("writing content of buffer " .. M.buffer.name() .. " to stdin")
        stdin:write(M.buffer.to_string(), function()
            stdin:close()
            debug_log("stdin pipe closed")
        end)
    end
}

M.parse_args = function(args, bufnr)
    local parsed = {}
    for _, arg in pairs(args) do
        if arg == "$FILENAME" then
            table.insert(parsed, M.buffer.name(bufnr))
        else
            table.insert(parsed, arg)
        end
    end
    return parsed
end

return M
