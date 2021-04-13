local lsp = vim.lsp
local plenary_exists, a = pcall(require, "plenary.async_lib")
local u = require("nvim-lsp-ts-utils.utils")

local organize_imports = require("nvim-lsp-ts-utils.organize-imports")

local get_diagnostics = function()
    local diagnostics = vim.lsp.diagnostic.get(0)
    -- return nil on empty table to avoid double-checking
    return u.isempty(diagnostics) and nil or diagnostics
end

local get_import_params = function(entry)
    local params = lsp.util.make_range_params()
    params.range = entry.range
    params.context = {diagnostics = {entry}}

    return params
end

local push_import_edits = function(action, edits, imports)
    -- keep only edits
    if action.command ~= "_typescript.applyWorkspaceEdit" then return end
    -- keep only actions that look like imports
    if not ((string.match(action.title, "Add") and
        string.match(action.title, "existing import")) or
        string.match(action.title, "Import")) then return end

    local arguments = action.arguments
    if not arguments or not arguments[1] then return end

    local changes = arguments[1].documentChanges
    if not changes or not changes[1] then return end

    -- capture variable name, which should be surrounded by single quotes
    local import = string.match(action.title, "%b''")
    -- avoid importing same variable twice
    if import and not u.contains(imports, import) then
        for _, edit in ipairs(changes[1].edits) do
            table.insert(edits, edit)
        end
        table.insert(imports, import)
    end
end

local apply_edits = function(edits)
    if u.isempty(edits) then
        print("No code actions available")
        return
    end
    lsp.util.apply_text_edits(edits, 0)
    -- organize imports afterwards to merge separate import statements from the same file
    organize_imports.async()
end

local sync = function()
    local diagnostics = get_diagnostics()
    if not diagnostics then
        print("No code actions available")
        return
    end

    local get_edits = function()
        local edits = {}
        local titles = {}
        for _, entry in pairs(diagnostics) do
            local responses = lsp.buf_request_sync(0, "textDocument/codeAction",
                                                   get_import_params(entry), 500)
            if not responses then return end
            for _, response in ipairs(responses) do
                for _, result in pairs(response) do
                    for _, action in pairs(result) do
                        push_import_edits(action, edits, titles)
                    end
                end
            end
        end
        return edits
    end
    apply_edits(get_edits())
end

local async = function()
    if not plenary_exists then error("failed to load plenary.nvim") end

    local diagnostics = get_diagnostics()
    if not diagnostics then
        print("No code actions available")
        return
    end

    local get_edits = a.async(function()
        local edits = {}
        local titles = {}
        local futures = {}
        for _, entry in pairs(diagnostics) do
            table.insert(futures, a.future(
                             function()
                    local _, _, responses =
                        a.await(a.lsp.buf_request(0, "textDocument/codeAction",
                                                  get_import_params(entry)))
                    for _, response in ipairs(responses) do
                        push_import_edits(response, edits, titles)
                    end
                end))
        end
        a.await_all(futures)
        return edits
    end)
    a.run(get_edits(), apply_edits)
end

local import_all = function(force_sync)
    if plenary_exists and not force_sync then
        async()
    else
        sync()
    end
end

return import_all
