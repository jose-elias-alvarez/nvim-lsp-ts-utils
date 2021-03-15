local lsp = vim.lsp
local define_commands = require("nvim-lsp-ts-utils.define-commands")
local u = require("nvim-lsp-ts-utils.utils")

local M = {}

M.organize_imports = function()
    local params = {
        command = "_typescript.organizeImports",
        arguments = {vim.api.nvim_buf_get_name(0)}
    }
    vim.lsp.buf.execute_command(params)
end

M.rename_file = function()
    local filetype = vim.bo.filetype
    if not u.filetype_is_valid(filetype) then error("Invalid filetype!") end

    local bufnr = vim.fn.bufnr("%")
    local source = vim.api.nvim_buf_get_name(0)
    local status, target = pcall(vim.fn.input, "New path: ", source)
    if not status or target == "" or target == source then return end

    local exists = u.file_exists(target)
    if (exists) then
        local confirm = vim.fn.confirm("File exists! Overwrite?", "&Yes\n&No")
        if confirm ~= 1 then return end
    end

    local params = {
        command = "_typescript.applyRenameFile",
        arguments = {
            {
                sourceUri = vim.uri_from_fname(source),
                targetUri = vim.uri_from_fname(target)
            }
        }
    }
    lsp.buf.execute_command(params)

    local modified = vim.fn.getbufvar(bufnr, "&modified")
    if (modified) then vim.cmd("noa w") end

    local _, err = u.move_file(source, target)
    if (err) then error(err) end

    vim.cmd("e " .. target)
    vim.cmd(bufnr .. "bwipeout!")
end

M.fix_current = function()
    local params = lsp.util.make_range_params()
    params.context = {diagnostics = vim.lsp.diagnostic.get_line_diagnostics()}

    local responses = lsp.buf_request_sync(0, "textDocument/codeAction", params)
    if not responses or not responses[1] or not responses[1].result[1] then
        return
    end

    local result = responses[1].result[1]
    lsp.buf.execute_command(result)
end

M.setup =
    function(opts) if not opts.disable_commands then define_commands() end end

return M
