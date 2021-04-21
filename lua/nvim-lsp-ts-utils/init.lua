local o = require("nvim-lsp-ts-utils.options")
local u = require("nvim-lsp-ts-utils.utils")

local request_handlers = require("nvim-lsp-ts-utils.request-handlers")
local define_commands = require("nvim-lsp-ts-utils.define-commands")
local organize_imports = require("nvim-lsp-ts-utils.organize-imports")
local import_all = require("nvim-lsp-ts-utils.import-all")
local fix_current = require("nvim-lsp-ts-utils.fix-current")
local rename_file = require("nvim-lsp-ts-utils.rename-file")
local import_on_completion = require("nvim-lsp-ts-utils.import-on-completion")

local M = {}
M.organize_imports = organize_imports.async
M.organize_imports_sync = organize_imports.sync

M.fix_current = fix_current

M.rename_file = rename_file

M.code_action_handler = function()
    u.echo_warning("code_action_handler has been removed (see readme)")
end
M.custom_action_handler = function()
    u.echo_warning("custom_action_handler has been removed (see readme)")
end
M.buf_request_sync = function()
    u.echo_warning("buf_request_sync handler has been removed (see readme)")
end

M.buf_request = request_handlers.buf_request

M.import_on_completion = import_on_completion.handle

M.import_all = import_all

M.setup = function(user_options)
    o.set(user_options)
    if not o.get().disable_commands then define_commands() end
    if o.get().enable_import_on_completion then import_on_completion.enable() end
end

return M
