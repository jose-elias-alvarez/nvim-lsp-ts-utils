local o = require("nvim-lsp-ts-utils.options")

local api = vim.api

local M = {}

M.severities = {
    error = 1,
    warning = 2,
    information = 3,
    hint = 4,
}

M.tsserver_fts = {
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact",
    "javascript.jsx",
    "typescript.tsx",
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

M.file = {
    dir_file = function(dir, depth)
        return require("plenary.scandir").scan_dir(dir, {
            depth = depth or 5,
            search_pattern = M.tsserver_extension_pattern,
        })[1]
    end,

    extension = function(filename)
        return vim.fn.fnamemodify(filename, ":e")
    end,
}

M.resolve_bin = function(cmd)
    local lsputil = require("lspconfig.util")

    local local_bin = lsputil.path.join(M.buffer.root(), "node_modules", ".bin", cmd)
    if lsputil.path.exists(local_bin) then
        M.debug_log("using local executable " .. local_bin)
        return local_bin
    else
        M.debug_log("using system executable " .. cmd)
        return cmd
    end
end

M.buffer = {
    root = function(bufname)
        local lsputil = require("lspconfig.util")
        bufname = bufname or api.nvim_buf_get_name(0)

        return lsputil.root_pattern("tsconfig.json", "package.json", "jsconfig.json")(bufname)
            or lsputil.root_pattern(".git")(bufname)
            or _G._TEST and vim.fn.getcwd()
    end,
}

M.get_command_output = function(cmd, args)
    local error
    local output, ret = require("plenary.job")
        :new({
            command = cmd,
            args = args,
            cwd = M.buffer.root(),
            on_stderr = function(_, data)
                M.debug_log(string.format("error running command %s: %s", cmd, data))
                error = true
            end,
        })
        :sync()
    M.debug_log(string.format("command %s exited with code %d", cmd, ret))
    error = error or ret ~= 0
    return error and {} or output
end

M.make_handler = function(fn)
    return function(...)
        local config_or_client_id = select(4, ...)
        local is_new = type(config_or_client_id) ~= "number"
        if is_new then
            fn(...)
        else
            local err = select(1, ...)
            local method = select(2, ...)
            local result = select(3, ...)
            local client_id = select(4, ...)
            local bufnr = select(5, ...)
            local config = select(6, ...)
            fn(err, result, { method = method, client_id = client_id, bufnr = bufnr }, config)
        end
    end
end

return M
