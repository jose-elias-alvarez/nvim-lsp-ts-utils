local initial_state = {watching = false, ignoring = false, null_ls = nil}
local state = initial_state

local defer = vim.defer_fn

local M = {}

M.reset = function() state = initial_state end

M.set = function(values) state = vim.tbl_extend("force", state, values) end
M.get = function() return state end

-- watcher
M.ignore = function(timeout)
    if not timeout then timeout = 500 end

    state.ignoring = true
    defer(function() state.ignoring = false end, timeout)
end

return M
