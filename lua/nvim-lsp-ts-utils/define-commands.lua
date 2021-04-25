local o = require("nvim-lsp-ts-utils.options")

local define_commands = function()
    if not o.get().disable_commands then
        vim.cmd(
            "command! -buffer TSLspRenameFile lua require'nvim-lsp-ts-utils'.rename_file()")
        vim.cmd(
            "command! -buffer TSLspOrganize lua require'nvim-lsp-ts-utils'.organize_imports()")
        vim.cmd(
            "command! -buffer TSLspOrganizeSync lua require'nvim-lsp-ts-utils'.organize_imports_sync()")
        vim.cmd(
            "command! -buffer TSLspFixCurrent lua require'nvim-lsp-ts-utils'.fix_current()")
        vim.cmd(
            "command! -buffer TSLspImportAll lua require'nvim-lsp-ts-utils'.import_all()")
        vim.cmd(
            "command! -buffer TSLspFormat lua require'nvim-lsp-ts-utils'.format()")
    end

    if o.get().enable_formatting and o.get().format_on_save then
        vim.api.nvim_exec([[
        augroup TSLspFormatOnSave
            autocmd! * <buffer>
            autocmd BufWritePost <buffer> lua require'nvim-lsp-ts-utils'.format()
        augroup END
        ]], false)
    end
end

return define_commands
