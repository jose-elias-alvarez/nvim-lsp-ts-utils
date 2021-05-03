local o = require("nvim-lsp-ts-utils.options")
local u = require("nvim-lsp-ts-utils.utils")
local s = require("nvim-lsp-ts-utils.state")

local uv = vim.loop
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

M.on_move = function(source, target, is_dir)
    if source == target then return end

    if o.get().require_confirmation_on_move then
        local confirm = vim.fn.confirm("Update imports for file " .. target ..
                                           "?", "&Yes\n&No")
        if confirm ~= 1 then return end
    end

    local source_bufnr, target_bufnr
    if not is_dir then
        source_bufnr = u.buffer.bufnr(source)
        target_bufnr = u.buffer.bufnr(target)
    end
    if target_bufnr then vim.cmd(target_bufnr .. "bwipeout!") end

    -- when the focused window contains a terminal buffer,
    -- execute_command only seems to work when the target file(s) are open
    if vim.bo.buftype == "terminal" then
        local terminal_win = api.nvim_get_current_win()
        -- open target in a split window (a lousy workaround, but it works)
        if is_dir then
            -- opening directories doesn't work, so get and open first file in directory
            local handle = uv.fs_scandir(target)
            local file = uv.fs_scandir_next(handle)
            vim.cmd("new " .. target .. "/" .. file)
        else
            vim.cmd("new " .. target)
        end
        rename_file(source, target)

        -- return to terminal window
        vim.api.nvim_set_current_win(terminal_win)
    else
        -- no special handling for regular buffers
        rename_file(source, target)

        -- close and reopen renamed file(s)
        if source_bufnr then
            vim.cmd("e " .. target)
            vim.cmd(source_bufnr .. "bwipeout!")
        end
    end
end

return M
