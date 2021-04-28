local o = require("nvim-lsp-ts-utils.options")
local u = require("nvim-lsp-ts-utils.utils")
local s = require("nvim-lsp-ts-utils.state")
local loop = require("nvim-lsp-ts-utils.loop")
local rename_file = require("nvim-lsp-ts-utils.rename-file")

local should_handle = function(filename)
    -- filters out temporary neovim files and invalid filenames
    -- also filters out directories, which would need special handling
    return u.file.is_tsserver_filename(filename)
end

local should_ignore_event = function(source, path)
    -- ignore rename event when a file is saved
    if source == path then return true end
    -- ignore rename event when a file is deleted
    if not u.file.exists(path) then return true end

    return false
end

local source
local start_watcher = function()
    if s.get().watching then return end

    -- don't watch when root can't be determined
    local root = u.buffer.root()
    if not root then return end

    local dir = root .. o.get().watch_dir
    u.debug_log("watching directory " .. dir)

    loop.watch_dir(dir, function(filename)
        if not should_handle(filename) then return end
        if s.get().manual_rename_in_progress then return end

        local path = dir .. "/" .. filename
        if not source then
            source = path
            return
        end

        if should_ignore_event(source, path) then
            source = nil
            return
        end

        if source then
            u.debug_log("attempting to update imports")
            u.debug_log("source: " .. source)
            u.debug_log("target: " .. path)

            rename_file.on_move(source, path)
            source = nil
        end
    end)
end

return start_watcher
