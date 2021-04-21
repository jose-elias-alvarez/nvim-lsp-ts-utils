local o = require("nvim-lsp-ts-utils.options")

local tsserver_fts = {
    "javascript", "javascriptreact", "typescript", "typescriptreact"
}

local loop = vim.loop
local api = vim.api
local schedule = vim.schedule_wrap

local contains = function(list, candidate)
    for _, element in pairs(list) do
        if element == candidate then return true end
    end
    return false
end

local M = {}

M.echo_warning = function(message)
    vim.api.nvim_echo(
        {{"nvim-lsp-ts-utils: " .. message, "WarningMsg"}, {"\n"}}, true, {})
end

M.print_no_actions_message = function() print("No code actions available") end

M.file = {
    mv = function(source, target)
        local ok = loop.fs_rename(source, target)
        if not ok then
            return false, "failed to move " .. source .. " to " .. target
        end

        return true
    end,

    exists = function(path)
        local file = loop.fs_open(path, "r", 438)
        if not file then return false end

        return true
    end,

    is_tsserver_ft = function(bufnr)
        if not bufnr then bufnr = 0 end
        local ft = api.nvim_buf_get_option(bufnr, "filetype")
        if not contains(tsserver_fts, ft) then error("invalid filetype") end
    end
}

M.table = {contains = contains}

M.buffer = {
    name = function(bufnr)
        if bufnr == nil then bufnr = 0 end
        return api.nvim_buf_get_name(bufnr)
    end,

    to_string = function(bufnr)
        if bufnr == nil then bufnr = 0 end
        local content = api.nvim_buf_get_lines(bufnr, 0, -1, false)
        return table.concat(content, "\n")
    end
}

M.string = {
    split_at_newline = function(str)
        local split = {}
        for line in string.gmatch(str, "([^\n]*)\n?") do
            table.insert(split, line)
        end
        return split
    end
}

M.loop = {
    buf_to_stdin = function(cmd, args, handle_output)
        local output = ""

        local handle_stdout = schedule(function(err, chunk)
            if err then error("stdout error: " .. err) end

            if chunk then output = output .. chunk end
            if not chunk then handle_output(output) end
        end)

        local handle_stderr = function(err)
            if err then error("stderr: " .. err) end
        end

        local stdin = loop.new_pipe(true)
        local stdout = loop.new_pipe(false)
        local stderr = loop.new_pipe(false)

        local handle = loop.spawn(cmd, {
            args = args,
            stdio = {stdin, stdout, stderr}
        }, function() end)

        loop.read_start(stdout, handle_stdout)
        loop.read_start(stderr, handle_stderr)

        loop.write(stdin, M.buffer.to_string())
        loop.shutdown(stdin,
                      function() if handle then loop.close(handle) end end)
    end
}

return M
