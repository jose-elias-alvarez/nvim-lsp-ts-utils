local a = require("plenary.async_lib")

local u = require("nvim-lsp-ts-utils.utils")
local o = require("nvim-lsp-ts-utils.options")
local organize_imports = require("nvim-lsp-ts-utils.organize-imports")

local lsp = vim.lsp
local api = vim.api

local CODE_ACTION = "textDocument/codeAction"
local APPLY_EDIT = "_typescript.applyWorkspaceEdit"
local rel_path_pattern = "^[.]+/"

local get_diagnostics = function(bufnr)
    local diagnostics = lsp.diagnostic.get(bufnr)

    if not diagnostics or vim.tbl_isempty(diagnostics) then
        print("No code actions available")
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
    local priorities = o.get().import_all_priorities
    local to_scan, scanned = o.get().import_all_scan_buffers, 0
    local git_output = u.get_command_output("git", { "ls-files", "--cached", "--others", "--exclude-standard" })
    local buffers = vim.fn.getbufinfo({ listed = 1 })
    local current = api.nvim_get_current_buf()
    local should_check_buffer = function(b)
        return scanned < to_scan and b.bufnr ~= current and u.is_tsserver_file(b.name)
    end

    return function(responses)
        if not responses then
            return
        end

        local should_handle_action = function(action)
            action = type(action.command) == "table" and action.command or action
            if action.command ~= APPLY_EDIT then
                return false
            end

            local arguments, title = action.arguments, action.title
            -- keep only actions that can be handled
            if
                not (arguments and arguments[1] and arguments[1].documentChanges and arguments[1].documentChanges[1])
            then
                return false
            end

            -- keep only actions that look like imports
            if not ((title:match("Add") and title:match("existing import")) or title:match("Import")) then
                return false
            end

            return true
        end

        local scan_buffer = function(buffer, source, target)
            for _, line in ipairs(api.nvim_buf_get_lines(buffer.bufnr, 0, -1, false)) do
                -- continue until blank line
                if line == "" then
                    return false
                end
                if line:match("import") and line:find(target, nil, true) and line:find(source, nil, true) then
                    return true
                end
            end
        end

        local calculate_priority = function(title, source, target)
            local priority = 0
            if not priorities then
                return priority
            end

            -- check if already imported in the same file
            if title:match("Add") then
                priority = priority + priorities.same_file
            end

            local is_local
            -- attempt to determine if source is local from path (won't work when basePath is set in tsconfig.json)
            if source:match(rel_path_pattern) or source:match("src") then
                is_local = true
            end

            -- remove relative path patterns
            while source:find(rel_path_pattern) do
                source = source:gsub(rel_path_pattern, "")
            end

            -- check source against git files to determine if local
            if not is_local then
                for _, git_file in ipairs(git_output) do
                    if git_file:find(source, nil, true) then
                        is_local = true
                        break
                    end
                end
            end

            if is_local then
                priority = priority + priorities.local_files
            end

            -- check if buffer name matches source
            for _, b in ipairs(buffers) do
                if should_check_buffer(b) and source:find(vim.fn.fnamemodify(b.name, ":t:r"), nil, true) then
                    priority = priority + priorities.buffers
                    break
                end
            end

            -- check buffer content for import statements containing target and source
            for _, b in ipairs(buffers) do
                if should_check_buffer(b) then
                    local found = scan_buffer(b, source, target)
                    scanned = scanned + 1
                    if found then
                        priority = priority + priorities.buffer_content
                        break
                    end
                end
            end

            u.debug_log(string.format("assigning priority %d to action %s", priority, title))
            return priority
        end

        local parse_action = function(action)
            local title = action.title
            local target, source = title:match("%b''"), title:match('%b""')
            if not (target and source) then
                return
            end

            target = target:sub(2, -2)
            source = source:sub(2, -2)
            imports[target] = imports[target] or {}
            if o.get().import_all_select_source then
                -- don't push same source twice
                for _, existing in ipairs(imports[target]) do
                    if existing.source == source then
                        return
                    end
                end
                table.insert(imports[target], { action = action, source = source })
                return
            end

            local existing = imports[target][1]
            local priority = calculate_priority(title, source, target)
            -- checking < means that conflicts will resolve in favor of the first found import,
            -- which is consistent with VS Code's behavior
            if not existing or existing.priority < priority then
                imports[target] = { { priority = priority, action = action, source = source } }
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

    lsp.util.apply_text_edits(edits, bufnr)

    -- organize imports to merge separate import statements from the same file
    organize_imports.async(bufnr, function()
        -- remove empty lines created by merge
        local empty_start, empty_end
        for i, line in ipairs(api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
            if not empty_end and empty_start and line ~= "" then
                empty_end = i - 1
                break
            end
            if not empty_start and line == "" then
                empty_start = i
            end
        end
        if empty_start and empty_end and empty_start < empty_end then
            api.nvim_buf_set_lines(bufnr, empty_start, empty_end, false, {})
        end
    end)
end

return a.async_void(function(bufnr)
    local diagnostics = get_diagnostics(bufnr)
    if not diagnostics then
        return
    end

    local buf_request_all = a.wrap(vim.lsp.buf_request_all, 4)
    local edits, all_imports, messages = {}, {}, {}
    local push_edits = function(action)
        action = type(action.command) == "table" and action.command or action
        for _, edit in ipairs(action.arguments[1].documentChanges[1].edits) do
            table.insert(edits, edit)
        end
    end

    local response_handler = create_response_handler(all_imports)

    local last_request_time = vim.loop.now()
    local wait_for_request = function()
        vim.wait(250, function()
            return vim.loop.now() - last_request_time > 10
        end, 5)
        last_request_time = vim.loop.now()
    end

    local response_count = 0
    local get_responses = function(diagnostic)
        wait_for_request()

        local responses = a.await(buf_request_all(bufnr, CODE_ACTION, make_params(diagnostic)))
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

    a.await_all(futures)
    for k, imports in pairs(all_imports) do
        local index = 1
        if vim.tbl_count(imports) > 1 then
            local choices = {}
            for i, import in ipairs(imports) do
                table.insert(choices, string.format("%d %s", i, import.source))
            end
            index = vim.fn.confirm(
                string.format("Select an import source for %s:", k),
                table.concat(choices, "\n"),
                1,
                "Question"
            )
            if index == 0 then
                return
            end
        end
        push_edits(imports[index].action)
    end

    vim.schedule(function()
        apply_edits(edits, bufnr)
    end)
end)
