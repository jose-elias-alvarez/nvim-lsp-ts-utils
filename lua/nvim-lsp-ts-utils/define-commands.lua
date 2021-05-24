local u = require("nvim-lsp-ts-utils.utils")
local o = require("nvim-lsp-ts-utils.options")

local define_commands = function()
    if not o.get().disable_commands then
        u.buf_command("TSLspRenameFile", "rename_file()")
        u.buf_command("TSLspOrganize", "organize_imports()")
        u.buf_command("TSLspOrganizeSync", "organize_imports_sync()")
        u.buf_command("TSLspRenameFile", "rename_file()")
        u.buf_command("TSLspFixCurrent", "fix_current()")
        u.buf_command("TSLspImportAll", "import_all()")
    end
end

return define_commands
