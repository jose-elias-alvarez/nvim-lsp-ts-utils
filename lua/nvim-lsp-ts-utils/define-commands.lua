local define_commands = function()
    vim.cmd(
        "command! TSLspRenameFile lua require'nvim-lsp-ts-utils'.rename_file()")
    vim.cmd(
        "command! TSLspOrganize lua require'nvim-lsp-ts-utils'.organize_imports()")
    vim.cmd(
        "command! TSLspOrganizeSync lua require'nvim-lsp-ts-utils'.organize_imports_sync()")
    vim.cmd(
        "command! TSLspFixCurrent lua require'nvim-lsp-ts-utils'.fix_current()")
    vim.cmd(
        "command! TSLspImportAll lua require'nvim-lsp-ts-utils'.import_all()")
end

return define_commands
