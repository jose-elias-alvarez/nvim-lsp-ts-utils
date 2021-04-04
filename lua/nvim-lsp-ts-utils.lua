local lsp = vim.lsp
local define_commands = require("nvim-lsp-ts-utils.define-commands")
local u = require("nvim-lsp-ts-utils.utils")

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

M.fix_current = function()
local organize_imports_sync = function()
    lsp.buf_request_sync(0, "workspace/executeCommand", get_organize_params(),
                         500)
end
M.organize_imports_sync = organize_imports_sync
    local params = lsp.util.make_range_params()
    params.context = {diagnostics = vim.lsp.diagnostic.get_line_diagnostics()}

    local responses = lsp.buf_request_sync(0, "textDocument/codeAction", params,
                                           500)
    if not responses then
        print("No code actions available")
        return
    end
    for _, response in ipairs(responses) do
        for _, result in pairs(response) do
            for _, action in pairs(result) do
                lsp.buf.execute_command(action)
            end
        end
    end
end

M.rename_file = function(target)
    local filetype = vim.bo.filetype
    if not u.filetype_is_valid(filetype) then error("Invalid filetype!") end

    local bufnr = vim.fn.bufnr("%")
    local source = vim.api.nvim_buf_get_name(0)

    local status
    if not target then
        status, target = pcall(vim.fn.input, "New path: ", source)
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

local push_import_edits = function(action, edits, text)
    if action.command ~= "_typescript.applyWorkspaceEdit" then return end
    if not ((string.match(action.title, "Add") and
        string.match(action.title, "existing import")) or
        string.match(action.title, "Import")) then return end

    local arguments = action.arguments
    if not arguments or not arguments[1] then return end

    local changes = arguments[1].documentChanges
    if not changes or not changes[1] then return end

    for _, edit in ipairs(changes[1].edits) do
        if not u.list_contains(text, edit.newText) then
            table.insert(edits, edit)
            table.insert(text, edit.newText)
        end
    end
end

M.import_all = function()
    local diagnostics = vim.lsp.diagnostic.get(0)
    if not diagnostics or vim.tbl_isempty(diagnostics) then
        print("No code actions available")
        return
    end

    local edits = {}
    local text = {}
    for _, entry in pairs(diagnostics) do
        local params = lsp.util.make_range_params()
        params.range = entry.range
        params.context = {diagnostics = {entry}}

        local responses = lsp.buf_request_sync(0, "textDocument/codeAction",
                                               params, 500)
        if not responses then return end
        for _, response in ipairs(responses) do
            for _, result in pairs(response) do
                for _, action in pairs(result) do
                    push_import_edits(action, edits, text)
                end
            end
        end
    end

    if vim.tbl_isempty(edits) then
        print("No code actions available")
        return
    end
    lsp.util.apply_text_edits(edits, 0)
    organize_imports()
end

M.setup =
    function(opts) if not opts.disable_commands then define_commands() end end

return M
