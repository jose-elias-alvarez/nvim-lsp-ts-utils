local lsp = vim.lsp

local o = require("nvim-lsp-ts-utils.options")
local u = require("nvim-lsp-ts-utils.utils")

local APPLY_EDIT = "workspace/applyEdit"
local PUBLISH_DIAGNOSTICS = "textDocument/publishDiagnostics"

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

local diagnostics_handler = function(err, method, result, client_id, buf_nr, config)
    local filter_out_diagnostics_by_severity = o.get().filter_out_diagnostics_by_severity
    local filter_out_diagnostics_by_code = o.get().filter_out_diagnostics_by_code

    -- Convert string severities to numbers
    filter_out_diagnostics_by_severity = vim.tbl_map(function(severity)
        if type(severity) == "string" then
            return u.severities[severity]
        end

        return severity
    end, filter_out_diagnostics_by_severity)

    if #filter_out_diagnostics_by_severity > 0 or #filter_out_diagnostics_by_code > 0 then
        local filtered_diagnostics = vim.tbl_filter(function(diagnostic)
            -- Only filter out Typescript LS diagnostics
            if diagnostic.source ~= "typescript" then
                return true
            end

            -- Filter out diagnostics with forbidden severity
            if vim.tbl_contains(filter_out_diagnostics_by_severity, diagnostic.severity) then
                return false
            end

            -- Filter out diagnostics with forbidden code
            if vim.tbl_contains(filter_out_diagnostics_by_code, diagnostic.code) then
                return false
            end

            return true
        end, result.diagnostics)

        result.diagnostics = filtered_diagnostics
    end

    return lsp.handlers[PUBLISH_DIAGNOSTICS](err, method, result, client_id, buf_nr, config)
end

local M = {}

M.setup = function(client)
    if client._ts_utils_setup_complete then
        return
    end

    client.handlers[APPLY_EDIT] = edit_handler
    client.handlers[PUBLISH_DIAGNOSTICS] = diagnostics_handler

    client._ts_utils_setup_complete = true
end

return M
