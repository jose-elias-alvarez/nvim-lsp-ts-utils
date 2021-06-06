local lsp = vim.lsp

local APPLY_EDIT = "workspace/applyEdit"

local fix_range = function(range)
    if range["end"].character == -1 then
        range["end"].character = 0
    end
    if range["end"].line == -1 then
        range["end"].line = 0
    end
    if range.start.character == -1 then
        range.start.character = 0
    end
    if range.start.line == -1 then
        range.start.line = 0
    end
end

local validate_changes = function(changes)
    for _, _change in pairs(changes) do
        for _, change in ipairs(_change) do
            if change.range then
                fix_range(change.range)
            end
        end
    end
end

local edit_handler = function(_, _, workspace_edit)
    if workspace_edit.edit and workspace_edit.edit.changes then
        validate_changes(workspace_edit.edit.changes)
    end

    local status, result = pcall(lsp.util.apply_workspace_edit, workspace_edit.edit)
    return { applied = status, failureReason = result }
end

local M = {}

M.setup = function(client)
    if client._ts_utils_setup_complete then
        return
    end

    client.handlers[APPLY_EDIT] = edit_handler
    client._ts_utils_setup_complete = true
end

return M
