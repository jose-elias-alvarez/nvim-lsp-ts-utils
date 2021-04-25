local plenary_exists, a = pcall(require, "plenary.async_lib")
local u = require("nvim-lsp-ts-utils.utils")
local organize_imports = require("nvim-lsp-ts-utils.organize-imports")

local lsp = vim.lsp
local api = vim.api
local isempty = vim.tbl_isempty

local get_diagnostics = function(bufnr)
    local diagnostics = vim.lsp.diagnostic.get(bufnr)
    -- return nil on empty table to avoid double-checking
    return isempty(diagnostics) and nil or diagnostics
end

local get_import_params = function(entry)
    local params = lsp.util.make_range_params()
    params.range = entry.range
    params.context = {diagnostics = {entry}}

    return params
end

local push_import_edits = function(responses, edits, imports)
    for _, response in ipairs(responses) do
        for _, result in pairs(response) do
            for _, action in pairs(result) do
                -- keep only edits
                if action.command ~= "_typescript.applyWorkspaceEdit" then
                    break
                end
                -- keep only actions that look like imports
                if not ((string.match(action.title, "Add") and
                    string.match(action.title, "existing import")) or
                    string.match(action.title, "Import")) then
                    break
                end

                local arguments = action.arguments
                if not arguments or not arguments[1] then break end

                local changes = arguments[1].documentChanges
                if not changes or not changes[1] then break end

                -- capture variable name, which should be surrounded by single quotes
                local import = string.match(action.title, "%b''")
                -- avoid importing same variable twice
                if import and not u.table.contains(imports, import) then
                    for _, edit in ipairs(changes[1].edits) do
                        table.insert(edits, edit)
                    end
                    table.insert(imports, import)
                end
            end
        end
    end
end

local apply_edits = function(edits, bufnr)
    if isempty(edits) then
        u.print_no_actions_message()
        return
    end
    lsp.util.apply_text_edits(edits, bufnr)

    -- organize imports afterwards to merge separate import statements from the same file
    organize_imports.async()
end

local sync = function(bufnr)
    local diagnostics = get_diagnostics(bufnr)
    if not diagnostics then
        u.print_no_actions_message()
        return
    end

    local get_edits = function()
        local edits = {}
        local titles = {}
        for _, entry in pairs(diagnostics) do
            local responses = lsp.buf_request_sync(bufnr,
                                                   "textDocument/codeAction",
                                                   get_import_params(entry), 500)
            if not responses then break end
            push_import_edits(responses, edits, titles)
        end
        return edits
    end

    apply_edits(get_edits(), bufnr)
end

local async = function(bufnr)
    if not plenary_exists then error("failed to load plenary.nvim") end

    local diagnostics = get_diagnostics(bufnr)
    if not diagnostics then
        u.print_no_actions_message()
        return
    end

    local get_edits = a.async(function()
        local edits = {}
        local titles = {}
        local futures = {}

        for _, entry in pairs(diagnostics) do
            table.insert(futures, a.future(
                             function()
                    local responses = a.await(
                                          a.lsp.buf_request_all(bufnr,
                                                                "textDocument/codeAction",
                                                                get_import_params(
                                                                    entry)))
                    if not responses then return end
                    push_import_edits(responses, edits, titles)
                end))
        end

        a.await_all(futures)
        return edits
    end)

    a.run(get_edits(), function(edits) apply_edits(edits, bufnr) end)
end

local import_all = function(force_sync, bufnr)
    if not bufnr then bufnr = api.nvim_get_current_buf() end

    if plenary_exists and not force_sync then
        async(bufnr)
    else
        sync(bufnr)
    end
end

return import_all
