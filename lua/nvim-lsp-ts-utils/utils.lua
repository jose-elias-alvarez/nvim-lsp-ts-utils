local o = require("nvim-lsp-ts-utils.options")

local api = vim.api
local lsp = vim.lsp

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

-- The init_options that are passed to lspconfig while setting up tsserver. The
-- configuration seen below is needed for inlay hints to work properly.
M.init_options = {
    hostInfo = "neovim",
    preferences = {
        includeInlayParameterNameHints = "all",
        includeInlayParameterNameHintsWhenArgumentMatchesName = true,
        includeInlayFunctionParameterTypeHints = true,
        includeInlayVariableTypeHints = true,
        includeInlayPropertyDeclarationTypeHints = true,
        includeInlayFunctionLikeReturnTypeHints = true,
        includeInlayEnumMemberValueHints = true,
    },
}

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

M.buffer = {
    root = function(bufname)
        local lsputil = require("lspconfig.util")
        bufname = bufname or api.nvim_buf_get_name(0)

        return lsputil.root_pattern("tsconfig.json", "package.json", "jsconfig.json")(bufname)
            or lsputil.root_pattern(".git")(bufname)
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

M.diagnostics = {
    to_lsp = function(diagnostics)
        return vim.tbl_map(function(diagnostic)
            return vim.tbl_extend("error", {
                range = {
                    start = {
                        line = diagnostic.lnum,
                        character = diagnostic.col,
                    },
                    ["end"] = {
                        line = diagnostic.end_lnum,
                        character = diagnostic.end_col,
                    },
                },
                severity = diagnostic.severity,
                message = diagnostic.message,
                source = diagnostic.source,
            }, diagnostic.user_data and (diagnostic.user_data.lsp or {}) or {})
        end, diagnostics)
    end,
}

M.get_tsserver_client = function()
    for _, client in ipairs(lsp.get_active_clients()) do
        if client.name == "tsserver" or client.name == "typescript" then
            return client
        end
    end
end

M.buf_autocmd = function(name, event, func)
    api.nvim_exec(
        string.format(
            [[
            augroup %s
                autocmd! * <buffer>
                autocmd %s <buffer> lua require'nvim-lsp-ts-utils'.%s
            augroup END
            ]],
            name,
            event,
            func
        ),
        false
    )
end

M.throttle_fn = function(ms, fn)
    local last_time = 0
    local timer = vim.loop.new_timer()
    return function(...)
        local now = vim.loop.now()
        local args = {...}
        if now - last_time > ms then
            last_time = now
            fn(unpack(args))
        end
        timer:stop()
        timer:start(ms - now + last_time, 0, function()
            last_time = vim.loop.now()
            fn(unpack(args))
        end)
    end
end

return M
