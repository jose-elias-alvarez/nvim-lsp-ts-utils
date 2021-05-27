local o = require("nvim-lsp-ts-utils.options")
local u = require("nvim-lsp-ts-utils.utils")

local lsp = vim.lsp
local api = vim.api
local fn = vim.fn

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

local is_special_buffer = function()
    return vim.bo.buftype ~= "" or
               vim.tbl_contains(special_filetypes, vim.bo.filetype)
end

local M = {}

M.manual = function(target)
    local bufnr = api.nvim_get_current_buf()
    local source = u.buffer.name(bufnr)

    local status
    if not target then
        status, target = pcall(fn.input, "New path: ", source, "file")
        if not status or target == "" or target == source then return end
    end

    local exists = u.file.exists(target)
    if exists then
        local confirm = fn.confirm("File exists! Overwrite?", "&Yes\n&No")
        if confirm ~= 1 then return end
    end

    rename_file(source, target)

    local modified = fn.getbufvar(bufnr, "&modified")
    if modified then vim.cmd("silent noautocmd w") end

    u.file.mv(source, target)

    vim.cmd("e " .. target)
    vim.cmd(bufnr .. "bwipeout!")
end

M.on_move = function(source, target)
    if source == target then return end

    if o.get().require_confirmation_on_move then
        local confirm = fn.confirm("Update imports for file " .. target .. "?",
                                   "&Yes\n&No")
        if confirm ~= 1 then return end
    end

    local is_dir = u.file.extension(target) == "" and u.file.is_dir(target)
    local source_bufnr = is_dir and nil or u.buffer.bufnr(source)

    -- workspace/applyEdit seems to need access to a visible window,
    -- so some buffer types neeed special handling
    if is_special_buffer() then
        local buffer_to_add = target
        if is_dir then
            -- opening directories doesn't work, so load first file in directory
            buffer_to_add = target .. "/" .. u.file.dir_file(target, 1)
        end

        local target_bufnr = fn.bufadd(buffer_to_add)
        vim.fn.bufload(buffer_to_add)
        fn.setbufvar(target_bufnr, "&buflisted", 1)

        local original_win = api.nvim_get_current_win()

        -- handle renaming from a floating window
        -- when the source is loaded in a background window
        if source_bufnr and api.nvim_win_get_config(original_win).relative ~= "" then
            local info = fn.getbufinfo(source_bufnr)[1]
            if info and info.windows and info.windows[1] then
                api.nvim_win_set_buf(info.windows[1], target_bufnr)
            end
        end

        -- create temporary floating window to contain target
        local temp_win = api.nvim_open_win(target_bufnr, true, {
            relative = "editor",
            height = 1,
            width = 1,
            row = 1,
            col = 1
        })
        rename_file(source, target)

        -- restore original window layout after rename
        api.nvim_set_current_win(original_win)
        api.nvim_win_close(temp_win, true)
    else
        rename_file(source, target)
        -- if source was loaded, edit target, since source will be closed
        if source_bufnr then vim.cmd("e " .. target) end
    end

    if source_bufnr then vim.cmd(source_bufnr .. "bwipeout!") end
end

return M
