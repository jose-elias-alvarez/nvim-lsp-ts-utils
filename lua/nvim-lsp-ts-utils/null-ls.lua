local o = require("nvim-lsp-ts-utils.options")
local u = require("nvim-lsp-ts-utils.utils")

local M = {}

-- DEPRECATION NOTICE: these integrations are provided for backwards compatibility but will be removed
M.setup = function()
    local ok, null_ls = pcall(require, "null-ls")
    if not ok then
        return
    end

    local name = "nvim-lsp-ts-utils"
    if null_ls.is_registered(name) then
        return
    end

    if o.get().eslint_enable_code_actions or o.get().eslint_enable_diagnostics then
        local eslint_bin = o.get().eslint_bin or "eslint"

        if o.get().eslint_enable_code_actions then
            local builtin = null_ls.builtins.code_actions[eslint_bin]
            assert(builtin, "invalid eslint bin: " .. eslint_bin)

            local opts = vim.tbl_extend(
                "keep",
                o.get().eslint_opts or {},
                { filetypes = u.tsserver_fts, prefer_local = "node_modules/.bin" }
            )

            u.debug_log("enabling null-ls eslint code actions integration")
            null_ls.register(builtin.with(opts))
        end

        if o.get().eslint_enable_diagnostics then
            local builtin = null_ls.builtins.diagnostics[eslint_bin]
            assert(builtin, "invalid eslint bin: " .. eslint_bin)

            local opts = vim.tbl_extend(
                "keep",
                o.get().eslint_opts or {},
                { filetypes = u.tsserver_fts, prefer_local = "node_modules/.bin" }
            )

            u.debug_log("enabling null-ls eslint diagnostics integration")
            null_ls.register(builtin.with(opts))
        end
    end

    if o.get().enable_formatting then
        local formatter = o.get().formatter or "prettier"
        local builtin = null_ls.builtins.formatting[formatter]
        assert(builtin, "invalid formatter: " .. formatter)

        local opts = vim.tbl_extend(
            "keep",
            o.get().formatter_opts or {},
            { filetypes = u.tsserver_fts, prefer_local = "node_modules/.bin" }
        )

        u.debug_log("enabling null-ls formatting integration")
        null_ls.register(builtin.with(opts))
    end

    null_ls.register_name(name)
    u.debug_log("successfully registered null-ls integrations")
end

return M
