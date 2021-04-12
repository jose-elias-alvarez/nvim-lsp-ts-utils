local json = require("json")

local u = require("nvim-lsp-ts-utils.utils")
local o = require("nvim-lsp-ts-utils.options")

-- same as built-in codeAction handler
local select_code_action = function(actions)
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

local code_action_handler = function(_, _, actions)
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

            select_code_action(actions)
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

return code_action_handler
