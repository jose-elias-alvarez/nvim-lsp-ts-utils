local o = require("nvim-lsp-ts-utils.options")
local u = require("nvim-lsp-ts-utils.utils")
local s = require("nvim-lsp-ts-utils.state")
local loop = require("nvim-lsp-ts-utils.loop")
local rename_file = require("nvim-lsp-ts-utils.rename-file")

local defer = vim.defer_fn

local should_handle = function(filename)
    -- filters out temporary neovim files and invalid filenames
    -- also filters out directories, which need special handling
    return u.file.is_tsserver_filename(filename)
end

local should_ignore_event = function(source, path)
    -- ignore rename event when a file is saved
    if source == path then return true end
    -- ignore rename event when a file is deleted
    if not u.file.exists(path) then return true end

    return false
end

local M = {}
local _unwatch
M.start = function()
    if s.get().watching then return end

    -- don't watch when root can't be determined
    local root = u.buffer.root()
    if not root then
        u.debug_log("project root could not be determined; watch aborted")
        return
    end

    local dir = root .. o.get().watch_dir
    u.debug_log("watching directory " .. dir)

    local source
    loop.watch_dir(dir, function(filename, _, unwatch)
        if not _unwatch then _unwatch = unwatch end
        if s.get().ignoring or not should_handle(filename) then return end

        local path = dir .. "/" .. filename
        if not source then
            source = path
            -- clear source after timeout to avoid triggering on non-move events
            -- 5 ms is generous, since uv.hrtime says the gap between the 2 events
            -- should rarely exceed 1-2 ms
            defer(function() source = nil end, 5)
            return
        end

        if should_ignore_event(source, path) then
            -- try to detect when the user is writing / deleting files and ignore all events
            -- especially relevant when running :wa after a big update
            s.ignore()
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

M.stop = function()
    if _unwatch then
        _unwatch()
        _unwatch = nil
        u.debug_log("watcher stopped")
    end
end

M.restart = function()
    M.stop()
    defer(M.start, 100)
end

return M
