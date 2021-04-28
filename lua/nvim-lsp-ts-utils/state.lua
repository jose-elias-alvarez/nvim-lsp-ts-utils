local initial_state = {watching = false, manual_rename_in_progress = false}
local state = initial_state

local M = {}

M.reset = function() state = initial_state end

M.set = function(values) state = vim.tbl_extend("force", state, values) end

M.get = function() return state end

return M
