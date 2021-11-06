local o = require("nvim-lsp-ts-utils.options")

local buf_command = function(name, fn)
    vim.cmd(string.format("command! -buffer %s lua require'nvim-lsp-ts-utils'.%s", name, fn))
end

local define_commands = function()
    if not o.get().disable_commands then
        buf_command("TSLspRenameFile", "rename_file()")
        buf_command("TSLspOrganize", "organize_imports()")
        buf_command("TSLspOrganizeSync", "organize_imports_sync()")
        buf_command("TSLspFixCurrent", "fix_current()")
        buf_command("TSLspImportAll", "import_all()")
        -- Inlay hints
        buf_command("TSLspInlayHints", "inlay_hints()")
        buf_command("TSLspDisableInlayHints", "disable_inlay_hints()")
        buf_command("TSLspToggleInlayHints", "toggle_inlay_hints()")
    end
end

return define_commands
