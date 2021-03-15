local define_commands = function()
    vim.cmd(
        "command! LspRenameFile lua require'nvim-lsp-ts-utils'.rename_file()")
    vim.cmd(
        "command! LspOrganize lua require'nvim-lsp-ts-utils'.organize_imports()")
    vim.cmd(
        "command! LspFixCurrent lua require'nvim-lsp-ts-utils'.fix_current()")
end

return define_commands
