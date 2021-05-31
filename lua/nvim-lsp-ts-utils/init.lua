local o = require("nvim-lsp-ts-utils.options")

local client = require("nvim-lsp-ts-utils.client")
local define_commands = require("nvim-lsp-ts-utils.define-commands")
local organize_imports = require("nvim-lsp-ts-utils.organize-imports")
local import_all = require("nvim-lsp-ts-utils.import-all")
local fix_current = require("nvim-lsp-ts-utils.fix-current")
local rename_file = require("nvim-lsp-ts-utils.rename-file")
local import_on_completion = require("nvim-lsp-ts-utils.import-on-completion")
local watcher = require("nvim-lsp-ts-utils.watcher")
local null_ls = require("nvim-lsp-ts-utils.null-ls")

local M = {}
M.organize_imports = organize_imports.async
M.organize_imports_sync = organize_imports.sync

M.fix_current = fix_current

M.rename_file = rename_file.manual
M.start_watcher = watcher.start
M.stop_watcher = watcher.stop
M.restart_watcher = watcher.restart

M.setup_client = client.setup

M.import_on_completion = import_on_completion.handle

M.import_all = import_all

M.setup = function(user_options)
    o.set(user_options)
    null_ls.setup()
    define_commands()

    if o.get().enable_import_on_completion then
        import_on_completion.enable()
    end
    if o.get().update_imports_on_move then
        watcher.start()
    end
end

return M
