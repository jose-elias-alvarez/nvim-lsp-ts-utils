local lspconfig = require("lspconfig/util")

local o = require("nvim-lsp-ts-utils.options")

local format = string.format
local uv = vim.loop
local api = vim.api
local exec = api.nvim_exec

local tsserver_fts = {
    "javascript", "javascriptreact", "typescript", "typescriptreact"
}
local tsserver_extensions = {"js", "jsx", "ts", "tsx"}
local node_modules = "/node_modules/.bin"

local M = {}
M.tsserver_fts = tsserver_fts

M.echo_warning = function(message)
    vim.api.nvim_echo({{"nvim-lsp-ts-utils: " .. message, "WarningMsg"}}, true,
                      {})
end

M.debug_log = function(target)
    if not o.get().debug then return end

    if type(target) == "table" then
        print(vim.inspect(target))
    else
        print(target)
    end
end

M.buf_command = function(name, fn)
    vim.cmd(format("command! -buffer %s lua require'nvim-lsp-ts-utils'.%s",
                   name, fn))
end

M.buf_augroup = function(name, event, fn)
    exec(format([[
    augroup %s
        autocmd! * <buffer>
        autocmd %s <buffer> lua require'nvim-lsp-ts-utils'.%s
    augroup END
    ]], name, event, fn), false)
end

M.print_no_actions_message = function() print("No code actions available") end

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

M.file = {
    mv = function(source, target)
        local ok = uv.fs_rename(source, target)
        if not ok then
            error("failed to move " .. source .. " to " .. target)
        end
    end,

    cp = function(source, target)
        local ok = uv.fs_copyfile(source, target)
        if not ok then
            error("failed to copy " .. source .. " to " .. target)
        end
    end,

    rm = function(path, force)
        local ok = uv.fs_unlink(path)
        if not force and not ok then error("failed to remove " .. path) end
    end,

    dir_file = function(dir, index)
        local handle = uv.fs_scandir(dir)
        for i = 1, index do
            local file = uv.fs_scandir_next(handle)
            if i == index and file then return file end
        end
        return nil
    end,

    exists = function(path)
        local file = uv.fs_open(path, "r", 438)
        if file then
            uv.fs_close(file)
            return true
        end
        return false
    end,

    check_ft = function(bufnr)
        if not bufnr then bufnr = 0 end
        local ft = api.nvim_buf_get_option(bufnr, "filetype")
        if not M.table.contains(tsserver_fts, ft) then
            error("invalid filetype")
        end
    end,

    stat = function(path)
        local fd = uv.fs_open(path, "r", 438)
        if not fd then return nil end

        local stat = uv.fs_fstat(fd)
        uv.fs_close(fd)
        return stat
    end,

    extension = function(filename) return vim.fn.fnamemodify(filename, ":e") end,

    has_tsserver_extension = function(filename)
        local extension = M.file.extension(filename)
        -- assume no extension == directory (which needs to be validated)
        return extension == "" or
                   M.table.contains(tsserver_extensions, extension)
    end
}

M.find_bin = function(cmd)
    local local_bin = M.buffer.root() .. node_modules .. "/" .. cmd
    if M.file.exists(local_bin) then
        M.debug_log("using local executable " .. local_bin)
        return local_bin
    else
        M.debug_log("using system executable " .. cmd)
        return cmd
    end
end

M.eslint_config_exists = function()
    local root = M.buffer.root()
    local config_file_formats = {
        ".eslintrc", ".eslintrc.js", ".eslintrc.json", ".eslintrc.yml",
        ".eslintrc.yaml"
    }
    for _, config_file in pairs(config_file_formats) do
        if M.file.exists(root .. "/" .. config_file) then return true end
    end

    return false
end

M.table = {
    contains = function(list, candidate)
        for _, element in pairs(list) do
            if element == candidate then return true end
        end
        return false
    end,

    len = function(table)
        local count = 0
        for _ in pairs(table) do count = count + 1 end
        return count
    end
}

M.cursor = {
    pos = function(winnr)
        if not winnr then winnr = 0 end
        local pos = api.nvim_win_get_cursor(winnr)
        return pos[1], pos[2]
    end,

    set = function(row, col, winnr)
        if not winnr then winnr = 0 end
        api.nvim_win_set_cursor(winnr, {row, col})
    end
}

M.buffer = {
    name = function(bufnr)
        if not bufnr then bufnr = api.nvim_get_current_buf() end
        return api.nvim_buf_get_name(bufnr)
    end,

    bufnr = function(name)
        local info = vim.fn.getbufinfo(name)[1]
        return info and info.bufnr or nil
    end,

    to_string = function(bufnr)
        if not bufnr then bufnr = api.nvim_get_current_buf() end
        local content = api.nvim_buf_get_lines(bufnr, 0, -1, false)
        return table.concat(content, "\n") .. "\n"
    end,

    line = function(row, bufnr)
        return
            api.nvim_buf_get_lines(bufnr and bufnr or 0, row - 1, row, false)[1]
    end,

    insert_text = function(row, col, text, bufnr)
        if not bufnr then bufnr = api.nvim_get_current_buf() end
        api.nvim_buf_set_text(bufnr, row, col, row, col, {text})
    end,

    root = function(fname)
        if not fname then fname = M.buffer.name() end
        return lspconfig.root_pattern("tsconfig.json")(fname) or
                   lspconfig.root_pattern("package.json", "jsconfig.json",
                                          ".git")(fname)
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

return M
