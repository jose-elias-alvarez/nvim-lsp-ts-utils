local u = require("nvim-lsp-ts-utils.utils")
local lsp = vim.lsp

local M = {}
local get_organize_params = function()
    return {
        command = "_typescript.organizeImports",
        arguments = {u.get_bufname()}
    }
end

local organize_imports = function()
    lsp.buf.execute_command(get_organize_params())
end
M.async = organize_imports

local organize_imports_sync = function()
    lsp.buf_request_sync(0, "workspace/executeCommand", get_organize_params(),
                         500)
end
M.sync = organize_imports_sync
return M
