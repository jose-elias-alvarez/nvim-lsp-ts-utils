local lsp = vim.lsp
local u = require("nvim-lsp-ts-utils.utils")

local rename_file = function(target)
    local ft_ok, ft_err = pcall(u.check_filetype)
    if not ft_ok then
        error(ft_err)
        return
    end

    local bufnr = vim.fn.bufnr("%")
    local source = u.get_bufname()

    local status
    if not target then
        status, target = pcall(vim.fn.input, "New path: ", source, "file")
        if not status or target == "" or target == source then return end
    end

    local exists = u.file_exists(target)

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

    local _, err = u.move_file(source, target)
    if (err) then error(err) end

    vim.cmd("e " .. target)
    vim.cmd(bufnr .. "bwipeout!")
end

return rename_file
