local u = require("nvim-lsp-ts-utils.utils")
local o = require("nvim-lsp-ts-utils.options")

local lsp = vim.lsp
local api = vim.api

local CODE_ACTION = "textDocument/codeAction"
local APPLY_EDIT = "_typescript.applyWorkspaceEdit"

local patterns = {
    RELATIVE_PATH = "^[.]+/",
    SRC = "^src",
    MODULE = "import.*from (.+)[;\n]?",
    -- Import 'useEffect' from module "React"
    IMPORT_WITH_TARGET = [['(%S+)'.+"(%S+)"]],
    NEW_IMPORT = "^Import",
    -- Add import from "next/app"
    IMPORT_WITHOUT_TARGET = [["(%S+)"]],
    ADD_IMPORT = "Add.+import",
    -- Update import from "next/app"
    UPDATE_IMPORT = "Update.+import",
}

local can_handle_action = function(action)
    return action.arguments
        and action.arguments[1]
        and action.arguments[1].documentChanges
        and action.arguments[1].documentChanges[1]
end

local action_matches_pattern = function(action)
    return action.title:match(patterns.NEW_IMPORT)
        or action.title:match(patterns.ADD_IMPORT)
        or action.title:match(patterns.UPDATE_IMPORT)
end

local source_is_local = function(source)
    return source:match(patterns.RELATIVE_PATH) or source:match(patterns.SRC)
end

local get_diagnostics = function(bufnr, client_id)
    local diagnostics = u.diagnostics.to_lsp(vim.diagnostic.get(bufnr, {
        namespace = lsp.diagnostic.get_namespace(client_id),
    }))

    local messages = {}
    -- filter for uniqueness
    diagnostics = vim.tbl_map(function(diagnostic)
        if not messages[diagnostic.message] then
            messages[diagnostic.message] = true
            return diagnostic
        end
    end, diagnostics)

    return diagnostics
end

local make_params = function(diagnostic)
    local params = lsp.util.make_range_params()
    params.range = diagnostic.range
    params.context = { diagnostics = { diagnostic } }

    return params
end

local response_handler_factory = function(callback)
    local priorities = o.get().import_all_priorities
    local to_scan, scanned = o.get().import_all_scan_buffers, 0
    local git_output = u.get_command_output("git", { "ls-files", "--cached", "--others", "--exclude-standard" })
    local buffers = vim.fn.getbufinfo({ listed = 1 })
    local current = api.nvim_get_current_buf()
    local should_check_buffer = function(b)
        return scanned < to_scan and b.bufnr ~= current and u.is_tsserver_file(b.name)
    end

    return function(responses)
        local imports = {}
        local should_handle_action = function(action)
            action = type(action.command) == "table" and action.command or action
            if action.command ~= APPLY_EDIT then
                return false
            end

            -- keep only actions that can be handled
            if not can_handle_action(action) then
                return false
            end

            -- keep only actions that look like imports
            if not action_matches_pattern(action) then
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
            if title:match(patterns.ADD_IMPORT) or title:match(patterns.UPDATE_IMPORT) then
                priority = priority + priorities.same_file
            end

            -- attempt to determine if source is local from path (won't work when basePath is set in tsconfig.json)
            local is_local = source_is_local(source)

            -- remove relative path markers
            while source:find(patterns.RELATIVE_PATH) do
                source = source:gsub(patterns.RELATIVE_PATH, "")
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

        local parse_action = function(action, index)
            local title = action.title

            local target, source = title:match(patterns.IMPORT_WITH_TARGET)
            source = source or title:match(patterns.IMPORT_WITHOUT_TARGET)
            if source and not target then
                target = string.format("anonymous_target_%d", index)
            end

            if not (target and source) then
                return
            end

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

        for i, action in ipairs(responses or {}) do
            if should_handle_action(action) then
                parse_action(action, i)
            end
        end

        callback(imports)
    end
end

local should_reorder = function(edits)
    local modules = {}
    for _, edit in ipairs(edits) do
        if edit.newText then
            local module = edit.newText:match(patterns.MODULE)
            if not module then
                return
            end

            local source = vim.trim(module)
            if modules[source] then
                return true
            end

            modules[source] = true
        end
    end
    return false
end

local apply_edits = function(edits, bufnr)
    if vim.tbl_count(edits) == 0 then
        return
    end

    lsp.util.apply_text_edits(edits, bufnr, "utf-16")

    if o.get().always_organize_imports or should_reorder(edits) then
        -- organize imports to merge separate import statements from the same file
        require("nvim-lsp-ts-utils.organize-imports").async(bufnr, function()
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
end

return function(bufnr, diagnostics)
    bufnr = bufnr or api.nvim_get_current_buf()

    local client = u.get_tsserver_client()
    if not client then
        print("No code actions available")
        return
    end

    diagnostics = diagnostics or get_diagnostics(bufnr, client.id)
    if vim.tbl_isempty(diagnostics) then
        print("No code actions available")
        return
    end

    local response_handler = response_handler_factory(function(all_imports)
        local edits = {}
        local push_edits = function(action)
            action = type(action.command) == "table" and action.command or action
            for _, edit in ipairs(action.arguments[1].documentChanges[1].edits) do
                table.insert(edits, edit)
            end
        end

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

        if vim.tbl_isempty(edits) then
            print("No code actions available")
            return
        end

        vim.schedule(function()
            apply_edits(edits, bufnr)
        end)
    end)

    -- stagger requests to prevent tsserver issues
    local last_request_time = vim.loop.now()
    local wait_for_request = function()
        vim.wait(250, function()
            return vim.loop.now() - last_request_time > 10
        end, 5)
        last_request_time = vim.loop.now()
    end

    local expected_response_count, response_count, responses = vim.tbl_count(diagnostics), 0, {}
    local get_response = function(diagnostic)
        local handler = function(_, response)
            responses = vim.list_extend(responses, response)
            response_count = response_count + 1
            if response_count == expected_response_count then
                response_handler(responses)
            end
        end

        wait_for_request()
        client.request(CODE_ACTION, make_params(diagnostic), handler, bufnr)
    end
    vim.tbl_map(get_response, diagnostics)

    vim.defer_fn(function()
        if response_count < expected_response_count then
            u.echo_warning("import all timed out")
        end
    end, o.get().import_all_timeout)
end
