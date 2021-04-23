local o = require("nvim-lsp-ts-utils.options")

local tsserver_fts = {
    "javascript", "javascriptreact", "typescript", "typescriptreact"
}

local uv = vim.loop
local api = vim.api
local schedule = vim.schedule_wrap

local contains = function(list, candidate)
    for _, element in pairs(list) do
        if element == candidate then return true end
    end
    return false
end

local close_handle = function(handle)
    if handle and not handle:is_closing() then handle:close() end
end

local M = {}

M.echo_warning = function(message)
    vim.api.nvim_echo({{"nvim-lsp-ts-utils: " .. message, "WarningMsg"}}, true,
                      {})
end

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
        return table.concat(content, "\n")
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
        local output, stderr_output = "", ""

        local handle_stdout = schedule(function(err, chunk)
            if err then error("stdout error: " .. err) end

            if chunk then output = output .. chunk end
            if not chunk then
                handler(stderr_output ~= "" and stderr_output or nil, output)
            end
        end)

        local handle_stderr = function(err, chunk)
            if err then error("stderr error: " .. err) end
            if chunk then stderr_output = stderr_output .. chunk end
        end

        local stdin = uv.new_pipe(true)
        local stdout = uv.new_pipe(false)
        local stderr = uv.new_pipe(false)
        local stdio = {stdin, stdout, stderr}

        local handle
        handle = uv.spawn(cmd, {args = args, stdio = stdio}, function()
            stdout:read_stop()
            stderr:read_stop()

            close_handle(stdin)
            close_handle(stdout)
            close_handle(stderr)
            close_handle(handle)
        end)

        uv.read_start(stdout, handle_stdout)
        uv.read_start(stderr, handle_stderr)

        stdin:write(M.buffer.to_string(), function() stdin:close() end)
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
