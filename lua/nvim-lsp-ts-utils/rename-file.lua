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

local M = {}

M.manual = function(target)
    local ft_ok, ft_err = pcall(u.file.check_ft)
    if not ft_ok then error(ft_err) end

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

M.on_move = function(source, target)
    if source == target then return end

    if o.get().require_confirmation_on_move then
        local confirm = vim.fn.confirm("Update imports for file " .. target ..
                                           "?", "&Yes\n&No")
        if confirm ~= 1 then return end
    end

    local source_bufnr = u.buffer.bufnr(source)
    local target_bufnr = u.buffer.bufnr(target)
    if target_bufnr then vim.cmd(target_bufnr .. "bwipeout!") end

    -- coc.nvim prefers using bufadd and bufload on recent vim versions,
    -- but it seems that the target needs to be open in an active window
    -- in order for execute_command to do anything
    if vim.bo.buftype == "terminal" then
        local terminal_win = api.nvim_get_current_win()
        vim.cmd([[noa keepalt 1new +setl\ bufhidden=wipe]])
        vim.cmd([[noa edit +setl\ bufhidden=hide ]] .. target)
        vim.cmd([[filetype detect]])
        rename_file(source, target)

        -- try to prevent closing last non-floating window
        -- this behaves terribly if the moves multiple loaded files and needs a better solution
        if not source_bufnr or api.nvim_win_get_config(terminal_win).relative ~=
            "editor" then vim.cmd([[noa close]]) end
        if source_bufnr then vim.cmd(source_bufnr .. "bwipeout!") end
        vim.api.nvim_set_current_win(terminal_win)
    else
        -- non-terminal buffers don't need any special handling, except to close and re-open
        -- moved file(s) if they were open
        rename_file(source, target)
        if source_bufnr then
            vim.cmd("e " .. target)
            vim.cmd(source_bufnr .. "bwipeout!")
        end
    end
end

return M
