local scan_dir = require("plenary.scandir").scan_dir
local lspconfig = require("lspconfig/util")

local o = require("nvim-lsp-ts-utils.options")

local format = string.format
local uv = vim.loop
local api = vim.api
local exec = api.nvim_exec

local node_modules = "/node_modules/.bin"

local eslint_config_formats = {
    ".eslintrc",
    ".eslintrc.js",
    ".eslintrc.json",
    ".eslintrc.yml",
    ".eslintrc.yaml",
}
local prettier_config_formats = {
    ".prettierrc",
    ".prettierrc.js",
    ".prettierrc.json",
    ".prettierrc.yml",
    ".prettierrc.yaml",
}
local config_file_formats = {
    eslint = eslint_config_formats,
    eslint_d = eslint_config_formats,
    prettier = prettier_config_formats,
    prettierd = prettier_config_formats,
    prettier_d_slim = prettier_config_formats,
    git = { ".gitignore" },
}

local M = {}

M.tsserver_fts = {
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact",
}

M.tsserver_extension_pattern = "[.][tj][s]x?$"

M.is_tsserver_file = function(path)
    return string.match(path, M.tsserver_extension_pattern) ~= nil
end

M.echo_warning = function(message)
    api.nvim_echo({ { "nvim-lsp-ts-utils: " .. message, "WarningMsg" } }, true, {})
end

M.debug_log = function(target, force)
    if not o.get().debug and not force then
        return
    end

    if type(target) == "table" then
        print(vim.inspect(target))
    else
        print(target)
    end
end

M.buf_command = function(name, fn)
    vim.cmd(format("command! -buffer %s lua require'nvim-lsp-ts-utils'.%s", name, fn))
end

M.buf_augroup = function(name, event, fn)
    exec(
        format(
            [[
            augroup %s
                autocmd! * <buffer>
                autocmd %s <buffer> lua require'nvim-lsp-ts-utils'.%s
            augroup END
            ]],
            name,
            event,
            fn
        ),
        false
    )
end

M.print_no_actions_message = function()
    print("No code actions available")
end

M.file = {
    mv = function(source, target)
        local ok, err = uv.fs_rename(source, target)
        if not ok then
            error(format("failed to move %s to %s: %s", source, target, err))
        end
    end,

    dir_file = function(dir, depth)
        return scan_dir(dir, {
            depth = depth or 5,
            search_pattern = M.tsserver_extension_pattern,
        })[1]
    end,

    exists = function(path)
        local file = uv.fs_open(path, "r", 438)
        if file then
            uv.fs_close(file)
            return true
        end
        return false
    end,

    stat = function(path)
        local fd = uv.fs_open(path, "r", 438)
        if not fd then
            return nil
        end

        local stat = uv.fs_fstat(fd)
        uv.fs_close(fd)
        return stat
    end,

    is_dir = function(path)
        local stat = M.file.stat(path)
        if not stat then
            return false
        end

        return stat.type == "directory"
    end,

    extension = function(filename)
        return vim.fn.fnamemodify(filename, ":e")
    end,
}

M.resolve_bin = function(cmd)
    local local_bin = M.buffer.root() .. node_modules .. "/" .. cmd
    if M.file.exists(local_bin) then
        M.debug_log("using local executable " .. local_bin)
        return local_bin
    else
        M.debug_log("using system executable " .. cmd)
        return cmd
    end
end

M.config_file_exists = function(bin)
    local root = M.buffer.root()
    for _, config_file in pairs(config_file_formats[bin]) do
        if M.file.exists(root .. "/" .. config_file) then
            return true
        end
    end

    return false
end

M.cursor = {
    pos = function(winnr)
        if not winnr then
            winnr = 0
        end
        local pos = api.nvim_win_get_cursor(winnr)
        return pos[1], pos[2]
    end,

    set = function(row, col, winnr)
        if not winnr then
            winnr = 0
        end
        api.nvim_win_set_cursor(winnr, { row, col })
    end,
}

M.buffer = {
    name = function(bufnr)
        return api.nvim_buf_get_name(bufnr or api.nvim_get_current_buf())
    end,

    bufnr = function(name)
        local info = vim.fn.getbufinfo(name)[1]
        return info and info.bufnr or nil
    end,

    line = function(row, bufnr)
        return api.nvim_buf_get_lines(bufnr or api.nvim_get_current_buf(), row - 1, row, false)[1]
    end,

    insert_text = function(row, col, text, bufnr)
        api.nvim_buf_set_text(bufnr or api.nvim_get_current_buf(), row, col, row, col, { text })
    end,

    root = function(fname)
        fname = fname or M.buffer.name()

        return lspconfig.root_pattern(".git")(fname) or lspconfig.root_pattern(
            "tsconfig.json",
            "package.json",
            "jsconfig.json"
        )(fname) or _G._TEST and vim.fn.getcwd()
    end,
}

return M
