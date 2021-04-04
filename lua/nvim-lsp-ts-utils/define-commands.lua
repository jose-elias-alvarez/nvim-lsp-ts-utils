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

    -- deprecated command warnings
    vim.cmd(
        "command! LspRenameFile lua require'nvim-lsp-ts-utils.utils'.echo_warning('Deprecated! Please use :TSLspRenameFile')")
    vim.cmd(
        "command! LspOrganize lua require'nvim-lsp-ts-utils.utils'.echo_warning('Deprecated! Please use :TSLspOrganize')")
    vim.cmd(
        "command! LspFixCurrent lua require'nvim-lsp-ts-utils.utils'.echo_warning('Deprecated! Please use :TSLspFixCurrent')")
    vim.cmd(
        "command! LspImportAll lua require'nvim-lsp-ts-utils.utils'.echo_warning('Deprecated! Please use :TSLspImportAll')")
end

return define_commands
