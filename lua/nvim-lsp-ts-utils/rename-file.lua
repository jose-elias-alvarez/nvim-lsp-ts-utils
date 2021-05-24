local o = require("nvim-lsp-ts-utils.options")
local u = require("nvim-lsp-ts-utils.utils")
local s = require("nvim-lsp-ts-utils.state")

local lsp = vim.lsp
local api = vim.api

local rename_file = function(source, target)
    lsp.buf.execute_command({
        command = "_typescript.applyRenameFile",
        arguments = {
            {
                sourceUri = vim.uri_from_fname(source),
                targetUri = vim.uri_from_fname(target)
            }
        }
    })
end

-- needs testing with additional file manager plugins
local special_filetypes = {"netrw", "dirvish", "nerdtree"}

local in_special_buffer = function()
    return vim.bo.buftype ~= "" or
               vim.tbl_contains(special_filetypes, vim.bo.filetype)
end

local M = {}

M.manual = function(target)
    local bufnr = api.nvim_get_current_buf()
    local source = u.buffer.name(bufnr)

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

    rename_file(source, target)

    local modified = vim.fn.getbufvar(bufnr, "&modified")
    if modified then vim.cmd("silent noautocmd w") end

    -- prevent watcher callback from triggering
    s.ignore()
    u.file.mv(source, target)

    vim.cmd("e " .. target)
    vim.cmd(bufnr .. "bwipeout!")
end

M.on_move = function(source, target, is_dir)
    if source == target then return end

    if o.get().require_confirmation_on_move then
        local confirm = vim.fn.confirm("Update imports for file " .. target ..
                                           "?", "&Yes\n&No")
        if confirm ~= 1 then return end
    end

    local source_bufnr = is_dir and nil or u.buffer.bufnr(source)

    -- workspace/applyEdit needs to load buffers, so some buffer types neeed special handling
    if in_special_buffer() then
        local original_buffer = api.nvim_win_get_buf(0)
        local buffer_to_add = target
        if is_dir then
            -- opening directories doesn't work, so load first file in directory as a workaround
            buffer_to_add = target .. "/" .. u.file.dir_file(target, 1)
        end

        -- temporarily load buffer into window
        local target_bufnr = vim.fn.bufadd(buffer_to_add)
        vim.fn.bufload(buffer_to_add)
        vim.fn.setbufvar(target_bufnr, "&buflisted", 1)
        api.nvim_win_set_buf(0, target_bufnr)

        rename_file(source, target)

        -- restore original buffer after rename
        api.nvim_win_set_buf(0, original_buffer)
    else
        rename_file(source, target)
        -- if source was loaded, edit target, since source will be closed
        if source_bufnr then vim.cmd("e " .. target) end
    end

    if source_bufnr then vim.cmd(source_bufnr .. "bwipeout!") end
end

return M
