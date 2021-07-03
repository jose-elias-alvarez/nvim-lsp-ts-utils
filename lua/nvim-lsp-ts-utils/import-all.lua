local a = require("plenary.async_lib")

local u = require("nvim-lsp-ts-utils.utils")
local o = require("nvim-lsp-ts-utils.options")
local organize_imports = require("nvim-lsp-ts-utils.organize-imports")

local lsp = vim.lsp
local api = vim.api

local CODE_ACTION = "textDocument/codeAction"
local APPLY_EDIT = "_typescript.applyWorkspaceEdit"
local rel_path_pattern = "^[.]+/"

local priorities = {
    max = 3,
    high = 2,
    med = 1,
    low = 0,
}

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

local create_response_handler = function(imports)
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

        local scan_buffer = function(buffer, source)
            for _, line in ipairs(api.nvim_buf_get_lines(buffer.bufnr, 0, -1, false)) do
                -- continue until blank line
                if line == "" then
                    return false
                end
                if line:match("import") and line:find(source, nil, true) then
                    return true
                end
            end
        end

        local to_scan, scanned = o.get().import_all_scan_buffers, 0
        local buffers = vim.fn.getbufinfo({ listed = 1 })
        local current = api.nvim_get_current_buf()
        local calculate_priority = function(title)
            -- check if already imported in the same file
            if title:match("Add") then
                return priorities.max
            end

            local source = title:match('%b""')
            -- fallback in case source can't be determined
            if not source then
                return priorities.low
            end

            -- remove quotes
            source = source:sub(2, -2)

            -- attempt to determine if source is local (far from perfect and needs more patterns)
            if source:match(rel_path_pattern) or source:match("src") then
                return priorities.high
            end

            -- remove relative path patterns
            while source:find(rel_path_pattern) do
                source = source:gsub(rel_path_pattern, "")
            end

            for _, b in ipairs(buffers) do
                if b.bufnr ~= current and u.is_tsserver_file(b.name) then
                    -- check if buffer name matches source
                    if source:find(vim.fn.fnamemodify(b.name, ":t:r"), nil, true) then
                        return priorities.med
                    end

                    -- scan loaded buffers for source
                    if scanned < to_scan then
                        scanned = scanned + 1
                        local found = scan_buffer(b, source)
                        if found then
                            return priorities.med
                        end
                    end
                end
            end

            return priorities.low
        end

        local parse_action = function(action)
            local title = action.title
            local priority = o.get().import_all_disable_priority and priorities.low or calculate_priority(title)
            local target = title:match("%b''")
            if target then
                target = target:sub(2, -2)
                local existing = imports[target]
                -- checking < means that conflicts will resolve in favor of the first found import,
                -- which is consistent with VS Code's behavior
                if not existing or existing.priority < priority then
                    imports[target] = { priority = priority, action = action }
                end
            end
        end

        for _, response in ipairs(responses) do
            for _, result in pairs(response) do
                for _, action in pairs(result) do
                    if should_handle_action(action) then
                        parse_action(action)
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

    -- organize imports to merge separate import statements from the same file
    organize_imports.async(bufnr, function()
        -- remove empty lines created by merge
        local empty_start, empty_end
        for i, line in ipairs(api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
            if not empty_end and empty_start and line ~= "" then
                empty_end = i - 1
            end
            if not empty_start and line == "" then
                empty_start = i
            end
        end
        if empty_start < empty_end then
            api.nvim_buf_set_lines(bufnr, empty_start, empty_end, false, {})
        end
    end)
end

return a.async_void(function(bufnr)
    local diagnostics = get_diagnostics(bufnr)
    if not diagnostics then
        return
    end

    u.debug_log("received " .. vim.tbl_count(diagnostics) .. " diagnostics from tsserver")

    local buf_request_all = a.wrap(vim.lsp.buf_request_all, 4)
    local edits, imports, messages = {}, {}, {}
    local push_edits = function(action)
        for _, edit in ipairs(action.arguments[1].documentChanges[1].edits) do
            table.insert(edits, edit)
        end
    end

    local response_handler = create_response_handler(imports)

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
    for _, import in pairs(imports) do
        push_edits(import.action)
    end

    vim.schedule(function()
        apply_edits(edits, bufnr)
    end)
end)
