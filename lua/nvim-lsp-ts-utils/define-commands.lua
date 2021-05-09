local u = require("nvim-lsp-ts-utils.utils")
local o = require("nvim-lsp-ts-utils.options")

local define_commands = function()
    if not o.get().disable_commands then
        u.define_buf_command("TSLspRenameFile", "rename_file()")
        u.define_buf_command("TSLspOrganize", "organize_imports()")
        u.define_buf_command("TSLspOrganizeSync", "organize_imports_sync()")
        u.define_buf_command("TSLspRenameFile", "rename_file()")
        u.define_buf_command("TSLspFixCurrent", "fix_current()")
        u.define_buf_command("TSLspImportAll", "import_all()")

        if o.get().enable_formatting then
            u.define_buf_command("TSLspFormat", "format()")
        end
    end

    if o.get().enable_formatting and o.get().format_on_save then
        u.define_buf_augroup("TSLspFormatOnSave", "BufWritePost", "format()")
    end
end

return define_commands
