local o = require("nvim-lsp-ts-utils.options")
local u = require("nvim-lsp-ts-utils.utils")

local lsp = vim.lsp
local api = vim.api
local fn = vim.fn

local rename_file = function(source, target)
    local client_found, request_ok
    for _, client in ipairs(lsp.get_active_clients()) do
        if not client_found and (client.name == "tsserver" or client.name == "typescript") then
            client_found = true
            request_ok = client.request("workspace/executeCommand", {
                command = "_typescript.applyRenameFile",
                arguments = {
                    {
                        sourceUri = vim.uri_from_fname(source),
                        targetUri = vim.uri_from_fname(target),
                    },
                },
            })
        end
    end

    if not client_found then
        u.echo_warning("failed to rename file: tsserver not running")
    elseif not request_ok then
        u.echo_warning("failed to rename file: tsserver request failed")
    end
end

local M = {}

M.manual = function(target, force)
    local lsputil = require("lspconfig.util")

    local bufnr = api.nvim_get_current_buf()
    local source = api.nvim_buf_get_name(bufnr)

    local status
    if not target then
        status, target = pcall(fn.input, "New path: ", source, "file")
        if not status or not target or target == "" or target == source then
            return
        end
    end

    local exists = lsputil.path.exists(target)
    if exists and not force then
        local confirm = fn.confirm("File exists! Overwrite?", "&Yes\n&No")
        if confirm ~= 1 then
            return
        end
    end

    rename_file(source, target)

    if fn.getbufvar(bufnr, "&modified") then
        vim.cmd("silent noautocmd w")
    end

    local ok, err = vim.loop.fs_rename(source, target)
    if not ok then
        error(string.format("failed to move %s to %s: %s", source, target, err))
    end

    vim.cmd("e " .. target)
    vim.cmd(bufnr .. "bdelete!")
end

M.on_move = function(source, target)
    local lsputil = require("lspconfig.util")
    if source == target then
        return
    end

    if o.get().require_confirmation_on_move then
        local confirm = fn.confirm("Update imports for file " .. target .. "?", "&Yes\n&No")
        if confirm ~= 1 then
            return
        end
    end

    local original_win = api.nvim_get_current_win()
    local original_bufnr = api.nvim_get_current_buf()

    local is_dir = u.file.extension(target) == "" and lsputil.path.is_dir(target)
    local source_bufnr = is_dir and nil or fn.bufadd(source)

    local buffer_to_add = target
    if is_dir then
        -- opening directories won't work, so load first file in directory
        buffer_to_add = u.file.dir_file(target)
    end
    if not buffer_to_add then
        return
    end

    local target_bufnr = fn.bufadd(buffer_to_add)
    fn.bufload(buffer_to_add)
    fn.setbufvar(target_bufnr, "&buflisted", 1)

    -- handle renaming from a floating window when the source is loaded in a background window
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
        col = 1,
    })
    rename_file(source, target)

    -- restore original window layout after rename
    api.nvim_set_current_win(original_win)
    api.nvim_win_close(temp_win, true)

    if source_bufnr then
        if source_bufnr == original_bufnr then
            vim.cmd("e " .. buffer_to_add)
        end

        if api.nvim_buf_is_loaded(source_bufnr) then
            vim.cmd(source_bufnr .. "bdelete!")
        end
    end
end

return M
