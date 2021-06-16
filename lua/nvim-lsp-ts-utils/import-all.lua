local a = require("plenary.async_lib")

local u = require("nvim-lsp-ts-utils.utils")
local o = require("nvim-lsp-ts-utils.options")
local organize_imports = require("nvim-lsp-ts-utils.organize-imports")

local lsp = vim.lsp

local CODE_ACTION = "textDocument/codeAction"
local APPLY_EDIT = "_typescript.applyWorkspaceEdit"

local get_diagnostics = function(bufnr)
    local diagnostics = lsp.diagnostic.get(bufnr)

    if not diagnostics or vim.tbl_isempty(diagnostics) then
        u.print_no_actions_message()
        return nil
    end

    local filtered = {}
    for _, diagnostic in pairs(diagnostics) do
        if diagnostic.source == "typescript" then
            table.insert(filtered, diagnostic)
        end
    end
    return filtered
end

local make_params = function(entry)
    local params = lsp.util.make_range_params()
    params.range = entry.range
    params.context = { diagnostics = { entry } }

    -- caught by null-ls
    params._null_ls_ignore = true

    return params
end

local create_response_handler = function(edits, imports)
    return function(responses)
        if not responses then
            return
        end

        local should_handle_action = function(action)
            if action.command ~= APPLY_EDIT then
                return false
            end

            -- keep only actions that look like imports
            if
                not (
                    (string.match(action.title, "Add") and string.match(action.title, "existing import"))
                    or string.match(action.title, "Import")
                )
            then
                return false
            end

            local arguments = action.arguments
            if not arguments or not arguments[1] then
                return false
            end

            local changes = arguments[1].documentChanges
            if not changes or not changes[1] then
                return false
            end

            return true
        end

        local push_edits = function(action)
            -- avoid importing same variable twice
            local import = string.match(action.title, "%b''")
            if import and not vim.tbl_contains(imports, import) then
                for _, edit in ipairs(action.arguments[1].documentChanges[1].edits) do
                    table.insert(edits, edit)
                end
                table.insert(imports, import)
            end
        end

        for _, response in ipairs(responses) do
            for _, result in pairs(response) do
                for _, action in pairs(result) do
                    if should_handle_action(action) then
                        push_edits(action)
                    end
                end
            end
        end
    end
end

local apply_edits = function(edits, bufnr)
    if vim.tbl_count(edits) == 0 then
        return
    end

    u.debug_log("applying " .. vim.tbl_count(edits) .. " edits")
    lsp.util.apply_text_edits(edits, bufnr)

    -- organize imports afterwards to merge separate import statements from the same file
    organize_imports.async()
end

return a.async_void(function(bufnr)
    local diagnostics = get_diagnostics(bufnr)
    if not diagnostics then
        return
    end

    u.debug_log("received " .. vim.tbl_count(diagnostics) .. " diagnostics from tsserver")

    local buf_request_all = a.wrap(vim.lsp.buf_request_all, 4)
    local edits, imports, messages = {}, {}, {}
    local response_handler = create_response_handler(edits, imports)

    local last_request_time = vim.loop.now()
    local wait_for_request = function()
        vim.wait(250, function()
            return vim.loop.now() - last_request_time > 25
        end, 5)
        last_request_time = vim.loop.now()
    end

    local response_count = 0
    local get_responses = function(diagnostic)
        u.debug_log("awaiting responses for diagnostic: " .. diagnostic.message)
        wait_for_request()

        local responses = a.await(buf_request_all(bufnr, CODE_ACTION, make_params(diagnostic)))
        u.debug_log("received " .. vim.tbl_count(responses) .. " responses for diagnostic: " .. diagnostic.message)
        response_count = response_count + 1
        return responses
    end

    local futures = {}
    local future_factory = function(diagnostic)
        return a.future(function()
            response_handler(get_responses(diagnostic))
        end)
    end

    for _, diagnostic in pairs(diagnostics) do
        if not vim.tbl_contains(messages, diagnostic.message) then
            table.insert(messages, diagnostic.message)
            table.insert(futures, future_factory(diagnostic))
        end
    end

    local expected_response_count = vim.tbl_count(futures)
    vim.defer_fn(function()
        if response_count < expected_response_count then
            u.echo_warning("import all timed out")
        end
    end, o.get().import_all_timeout)

    u.debug_log("awaiting code action results from " .. vim.tbl_count(futures) .. " futures")
    a.await_all(futures)
    vim.schedule(function()
        apply_edits(edits, bufnr)
    end)
end)
