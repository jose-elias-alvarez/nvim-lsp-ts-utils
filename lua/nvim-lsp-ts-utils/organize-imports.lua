local lsp = vim.lsp
local api = vim.api

local METHOD = "workspace/executeCommand"

local M = {}
local make_params = function(bufnr)
    return {
        command = "_typescript.organizeImports",
        arguments = { api.nvim_buf_get_name(bufnr) },
    }
end

local organize_imports = function(bufnr, post)
    bufnr = bufnr or api.nvim_get_current_buf()

    lsp.buf_request_all(bufnr, METHOD, make_params(bufnr), function(err)
        if not err and post then
            post()
        end
    end)
end
M.async = organize_imports

local organize_imports_sync = function(bufnr, timeout)
    bufnr = bufnr or api.nvim_get_current_buf()

    return lsp.buf_request_sync(bufnr, METHOD, make_params(bufnr), timeout)
end
M.sync = organize_imports_sync

return M
