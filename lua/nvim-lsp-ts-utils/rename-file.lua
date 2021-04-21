local u = require("nvim-lsp-ts-utils.utils")
local lsp = vim.lsp

local rename_file = function(target)
    local ft_ok, ft_err = pcall(u.file.is_tsserver_ft)
    if not ft_ok then error(ft_err) end

    local bufnr = vim.api.nvim_get_current_buf()
    local source = u.buffer.name()

    local status
    if not target then
        status, target = pcall(vim.fn.input, "New path: ", source, "file")
        if not status or target == "" or target == source then return end
    end

    local exists = u.file.exists(target)

    if exists then
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
    if (modified) then vim.cmd("silent noa w") end

    local _, err = u.file.mv(source, target)
    if (err) then error(err) end

    vim.cmd("e " .. target)
    vim.cmd(bufnr .. "bwipeout!")
end

return rename_file
