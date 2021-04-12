local lsp = vim.lsp
local json = require("json")
local plenary_exists, a = pcall(require, "plenary.async_lib")

local basename = "nvim-lsp-ts-utils."
local o = require(basename .. "options")
local define_commands = require(basename .. "define-commands")
local u = require(basename .. "utils")

local M = {}

local get_organize_params = function()
    return {
        command = "_typescript.organizeImports",
        arguments = {u.get_bufname()}
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
    local ft_ok, ft_err = pcall(u.check_filetype)
    if not ft_ok then
        error(ft_err)
        return
    end

    local bufnr = vim.fn.bufnr("%")
    local source = u.get_bufname()

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

local enable_import_on_completion = function()
    vim.api.nvim_exec([[
    augroup TSLspImportOnCompletion
        autocmd!
        autocmd CompleteDone * lua require'nvim-lsp-ts-utils'.import_on_completion()
    augroup END
    ]], false)
end

local last_imported = ""
M.import_on_completion = function()
    local completed_item = vim.v.completed_item
    if not (completed_item and completed_item.user_data and
        completed_item.user_data.nvim and completed_item.user_data.nvim.lsp and
        completed_item.user_data.nvim.lsp.completion_item) then return end

    local item = completed_item.user_data.nvim.lsp.completion_item
    if last_imported == item.label then return end

    lsp.buf_request(0, "completionItem/resolve", item, function(_, _, result)
        if result and result.additionalTextEdits then
            lsp.util.apply_text_edits(result.additionalTextEdits, 0)

            last_imported = item.label
            vim.defer_fn(function() last_imported = "" end,
                         o.get().import_on_completion_timeout)
        end
    end)
end

M.setup = function(user_options)
    o.set(user_options)
    if not o.get().disable_commands then define_commands() end
    if o.get().enable_import_on_completion then enable_import_on_completion() end
end

-- same as built-in codeAction handler
local handle_code_actions = function(actions)
    if actions == nil or u.isempty(actions) then
        print("No code actions available")
        return
    end

    local option_strings = {"Code Actions:"}
    for i, action in ipairs(actions) do
        local title = action.title:gsub("\r\n", "\\r\\n")
        title = title:gsub("\n", "\\n")
        table.insert(option_strings, string.format("%d. %s", i, title))
    end

    local choice = vim.fn.inputlist(option_strings)
    if choice < 1 or choice > #actions then return end
    local action_chosen = actions[choice]
    if action_chosen.edit or type(action_chosen.command) == "table" then
        if action_chosen.edit then
            vim.lsp.util.apply_workspace_edit(action_chosen.edit)
        end
        if type(action_chosen.command) == "table" then
            vim.lsp.buf.execute_command(action_chosen.command)
        end
    else
        vim.lsp.buf.execute_command(action_chosen)
    end
end

local create_edit_action = function(title, new_text, range, text_document)
    return {
        title = title,
        command = "_typescript.applyWorkspaceEdit",
        arguments = {
            {
                documentChanges = {
                    {
                        edits = {{newText = new_text, range = range}},
                        textDocument = text_document
                    }
                }
            }
        }
    }
end

local create_code_action_from_suggestion =
    function(suggestion, range, text_document, actions)
        local title = suggestion.desc
        local new_text = suggestion.fix.text
        table.insert(actions,
                     create_edit_action(title, new_text, range, text_document))
    end

local create_code_action_from_fix = function(problem, range, text_document,
                                             actions)
    local title = "Apply suggested fix for ESLint rule " .. problem.ruleId
    local new_text = problem.fix.text
    table.insert(actions,
                 create_edit_action(title, new_text, range, text_document))
end

local create_disable_code_actions = function(problem, current_line,
                                             text_document, actions)
    print("creating disable code actions")
    local rule_id = problem.ruleId
    local line_title = "Disable ESLint rule " .. problem.ruleId ..
                           " for this line"
    local line_new_text = "// eslint-disable-next-line " .. rule_id .. "\n"
    local line_range = {
        start = {line = current_line, character = 0},
        ["end"] = {line = current_line, character = 0}
    }

    local doc_title = "Disable ESLint rule " .. problem.ruleId ..
                          " for the entire file"
    local doc_new_text = "/* eslint-disable " .. rule_id .. " */\n"
    local doc_range = {
        start = {line = 0, character = 0},
        ["end"] = {line = 0, character = 0}
    }

    table.insert(actions, create_edit_action(line_title, line_new_text,
                                             line_range, text_document))
    table.insert(actions, create_edit_action(doc_title, doc_new_text, doc_range,
                                             text_document))
end

local problem_is_fixable = function(problem, current_line)
    if not problem or problem.line == nil or problem.column == nil then
        return false
    end
    if problem.endLine ~= nil then
        return problem.line - 1 <= current_line and problem.endLine - 1 >=
                   current_line
    end
    if problem.fix ~= nil then return problem.line - 1 == current_line end
    return false
end

local convert_offset = function(line, start_offset, end_offset)
    local start_char, end_char
    local line_offset = vim.api.nvim_buf_get_offset(0, line)
    local line_end_char = string.len(vim.fn.getline(line + 1))
    for j = 0, line_end_char do
        local char_offset = line_offset + j
        if char_offset == start_offset then start_char = j end
        if char_offset == end_offset then end_char = j end
    end
    return start_char, end_char
end

local get_suggestion_range = function(problem)
    local start_line = problem.line - 1
    local start_char = problem.column - 1
    local end_line = problem.endLine - 1
    local end_char = problem.endColumn - 1

    return {
        start = {line = start_line, character = start_char},
        ["end"] = {line = end_line, character = end_char}
    }
end

local get_fix_range = function(problem)
    local line = problem.line - 1
    local start_offset = problem.fix.range[1]
    local end_offset = problem.fix.range[2]
    local start_char, end_char = convert_offset(line, start_offset, end_offset)

    return {
        start = {line = line, character = start_char},
        ["end"] = {line = line, character = end_char}
    }
end

local parse_eslint_messages = function(messages, actions)
    local text_document = vim.lsp.util.make_text_document_params()
    local current_line = vim.api.nvim_win_get_cursor(0)[1] - 1

    for _, problem in ipairs(messages) do
        if problem_is_fixable(problem, current_line) then
            if problem.suggestions then
                for _, suggestion in ipairs(problem.suggestions) do
                    create_code_action_from_suggestion(suggestion,
                                                       get_suggestion_range(
                                                           problem),
                                                       text_document, actions)
                end
            end
            if problem.fix then
                create_code_action_from_fix(problem, get_fix_range(problem),
                                            text_document, actions)
            end
            if problem.ruleId then
                create_disable_code_actions(problem, current_line,
                                            text_document, actions)
            end
        end
    end
end

M.code_action_handler = function(_, _, actions)
    local ft_ok, ft_err = pcall(u.check_filetype)
    if not ft_ok then
        error(ft_err)
        return
    end

    local handle_output = u.schedule(function(err, data)
        if err then
            error("eslint output error: ", err)
            return
        end
        if data then
            local ok, decoded = pcall(json.decode, data)
            if not ok then
                error("failed to parse eslint json output")
                return
            end

            if decoded[1] and not u.isempty(decoded[1]) and decoded[1].messages and
                not u.isempty(decoded[1].messages) then
                local messages = decoded[1].messages
                parse_eslint_messages(messages, actions)
            end

            handle_code_actions(actions)
        end
    end)

    local stdout = u.loop.new_pipe(false)
    local stderr = u.loop.new_pipe(false)

    local handle
    handle = u.loop.spawn(o.get().eslint_bin, {
        args = {"-f", "json", u.get_bufname()},
        stdio = {stdout, stderr}
    }, function()
        stdout:read_stop()
        stderr:read_stop()
        stdout:close()
        stderr:close()
        handle:close()
    end)

    u.loop.read_start(stdout, handle_output)
    u.loop.read_start(stderr, handle_output)
end

return M
