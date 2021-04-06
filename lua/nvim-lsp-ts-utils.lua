local lsp = vim.lsp
local define_commands = require("nvim-lsp-ts-utils.define-commands")
local u = require("nvim-lsp-ts-utils.utils")
local plenary_exists, a = pcall(require, "plenary.async_lib")

local M = {}

local get_organize_params = function()
    return {
        command = "_typescript.organizeImports",
        arguments = {vim.api.nvim_buf_get_name(0)}
    }
end

local organize_imports = function()
    lsp.buf.execute_command(get_organize_params())
end
M.organize_imports = organize_imports

local organize_imports_sync = function()
    lsp.buf_request_sync(0, "workspace/executeCommand", get_organize_params(),
                         500)
end
M.organize_imports_sync = organize_imports_sync

local get_diagnostics = function()
    local diagnostics = vim.lsp.diagnostic.get(0)
    -- return nil on empty table to avoid double-checking
    return vim.tbl_isempty(diagnostics) and nil or diagnostics
end

local get_import_params = function(entry)
    local params = lsp.util.make_range_params()
    params.range = entry.range
    params.context = {diagnostics = {entry}}

    return params
end

local push_import_edits = function(action, edits, text)
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

    for _, edit in ipairs(changes[1].edits) do
        -- avoid running edits that result in identical text twice
        if not u.list_contains(text, edit.newText) then
            table.insert(edits, edit)
            table.insert(text, edit.newText)
        end
    end
end

local apply_edits = function(edits)
    if vim.tbl_isempty(edits) then
        print("No code actions available")
        return
    end
    lsp.util.apply_text_edits(edits, 0)
    -- organize imports afterwards to merge separate import statements from the same file
    organize_imports()
end

local import_all_sync = function()
    local diagnostics = get_diagnostics()
    if not diagnostics then
        print("No code actions available")
        return
    end

    local get_edits = function()
        local edits = {}
        local text = {}
        for _, entry in pairs(diagnostics) do
            local responses = lsp.buf_request_sync(0, "textDocument/codeAction",
                                                   get_import_params(entry), 500)
            if not responses then return end
            for _, response in ipairs(responses) do
                for _, result in pairs(response) do
                    for _, action in pairs(result) do
                        push_import_edits(action, edits, text)
                    end
                end
            end
        end
        return edits
    end
    apply_edits(get_edits())
end
-- export for testing (and in the unlikely case someone prefers to use it)
M.import_all_sync = import_all_sync

local import_all = function()
    local diagnostics = get_diagnostics()
    if not diagnostics then
        print("No code actions available")
        return
    end

    local get_edits = a.async(function()
        local edits = {}
        local text = {}
        local futures = {}
        for _, entry in pairs(diagnostics) do
            table.insert(futures, a.future(
                             function()
                    local _, _, responses =
                        a.await(a.lsp.buf_request(0, "textDocument/codeAction",
                                                  get_import_params(entry)))
                    for _, response in ipairs(responses) do
                        push_import_edits(response, edits, text)
                    end
                end))
        end
        a.await_all(futures)
        return edits
    end)
    a.run(get_edits(), apply_edits)
end

M.fix_current = function()
    local params = lsp.util.make_range_params()
    params.context = {diagnostics = vim.lsp.diagnostic.get_line_diagnostics()}

    lsp.buf_request(0, "textDocument/codeAction", params,
                    function(_, _, responses)
        if not responses or not responses[1] then
            print("No code actions available")
            return
        end

        lsp.buf.execute_command(responses[1])
    end)
end

M.rename_file = function(target)
    local filetype = vim.bo.filetype
    if not u.filetype_is_valid(filetype) then error("Invalid filetype!") end

    local bufnr = vim.fn.bufnr("%")
    local source = vim.api.nvim_buf_get_name(0)

    local status
    if not target then
        status, target = pcall(vim.fn.input, "New path: ", source, "file")
        if not status or target == "" or target == source then return end
    end

    local exists = u.file_exists(target)

    if exists then
        local confirm = vim.fn.confirm("File exists! Overwrite?", "&Yes\n&No")
        if confirm ~= 1 then return end
    end

    local params = {
        command = "_typescript.applyRenameFile",
        arguments = {
            {
                sourceUri = vim.uri_from_fname(source),
                targetUri = vim.uri_from_fname(target)
            }
        }
    }
    lsp.buf.execute_command(params)

    local modified = vim.fn.getbufvar(bufnr, "&modified")
    if (modified) then vim.cmd("silent noa w") end

    local _, err = u.move_file(source, target)
    if (err) then error(err) end

    vim.cmd("e " .. target)
    vim.cmd(bufnr .. "bwipeout!")
end

M.import_all = function()
    if plenary_exists then
        import_all()
    else
        import_all_sync()
    end
end

M.setup =
    function(opts) if not opts.disable_commands then define_commands() end end

return M
