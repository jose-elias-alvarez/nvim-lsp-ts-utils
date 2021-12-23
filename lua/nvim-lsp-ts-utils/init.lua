local o = require("nvim-lsp-ts-utils.options")
local u = require("nvim-lsp-ts-utils.utils")

local client = require("nvim-lsp-ts-utils.client")
local define_commands = require("nvim-lsp-ts-utils.define-commands")
local organize_imports = require("nvim-lsp-ts-utils.organize-imports")
local import_all = require("nvim-lsp-ts-utils.import-all")
local rename_file = require("nvim-lsp-ts-utils.rename-file")
local import_on_completion = require("nvim-lsp-ts-utils.import-on-completion")
local watcher = require("nvim-lsp-ts-utils.watcher")
local inlay_hints = require("nvim-lsp-ts-utils.inlay-hints")
local utils = require("nvim-lsp-ts-utils.utils")

local M = {}
M.organize_imports = organize_imports.async
M.organize_imports_sync = organize_imports.sync

M.rename_file = rename_file.manual
M.start_watcher = watcher.start
M.stop_watcher = watcher.stop
M.restart_watcher = watcher.restart

M.setup_client = client.setup

M.import_on_completion = import_on_completion.handle

M.import_all = import_all
M.import_current = function()
    local bufnr = vim.api.nvim_get_current_buf()
    local lnum = vim.api.nvim_win_get_cursor(0)[1] - 1

    local line_diagnostics = vim.diagnostic.get(bufnr, { lnum = lnum })
    import_all(bufnr, u.diagnostics.to_lsp(line_diagnostics))
end

M.inlay_hints = inlay_hints.inlay_hints
M.disable_inlay_hints = inlay_hints.disable_inlay_hints
M.toggle_inlay_hints = inlay_hints.toggle_inlay_hints
M.autocmd_fun = inlay_hints.autocmd_fun

M.init_options = utils.init_options

-- setup should be called on attach, so everything here should be buffer-local or idempotent
M.setup = function(user_options)
    if vim.fn.has("nvim-0.6.0") == 0 then
        u.echo_warning("nvim-lsp-ts-utils requires nvim 0.6.0+")
        return
    end

    o.setup(user_options)
    define_commands()

    if o.get().auto_inlay_hints then
        inlay_hints.inlay_hints()
    end

    if o.get().enable_import_on_completion then
        import_on_completion.enable()
    end
    if o.get().update_imports_on_move then
        watcher.start()
    end
end

return M
