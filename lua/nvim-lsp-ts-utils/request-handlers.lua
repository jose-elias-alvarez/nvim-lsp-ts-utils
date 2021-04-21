local json = require("json")
local u = require("nvim-lsp-ts-utils.utils")
local o = require("nvim-lsp-ts-utils.options")

local api = vim.api
local lsp = vim.lsp
local isempty = vim.tbl_isempty
local buf_request = vim.deepcopy(lsp.buf_request)

local M = {}

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

local push_suggestion_code_action = function(suggestion, range, text_document,
                                             actions)
    local title = suggestion.desc
    local new_text = suggestion.fix.text
    table.insert(actions,
                 create_edit_action(title, new_text, range, text_document))
end

local push_fix_code_action = function(problem, range, text_document, actions)
    local title = "Apply suggested fix for ESLint rule " .. problem.ruleId
    local new_text = problem.fix.text
    table.insert(actions,
                 create_edit_action(title, new_text, range, text_document))
end

local push_disable_code_actions = function(problem, current_line, text_document,
                                           actions, rules)
    local rule_id = problem.ruleId
    if (u.table.contains(rules, rule_id)) then return end
    table.insert(rules, rule_id)

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
    local line_offset = api.nvim_buf_get_offset(0, line)
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
    local text_document = lsp.util.make_text_document_params()
    local current_line = api.nvim_win_get_cursor(0)[1] - 1

    local rules = {}
    for _, problem in ipairs(messages) do
        if problem_is_fixable(problem, current_line) then
            if problem.suggestions then
                for _, suggestion in ipairs(problem.suggestions) do
                    push_suggestion_code_action(suggestion,
                                                get_suggestion_range(problem),
                                                text_document, actions)
                end
            end
            if problem.fix then
                push_fix_code_action(problem, get_fix_range(problem),
                                     text_document, actions)
            end
            if problem.ruleId and o.get().eslint_enable_disable_comments then
                push_disable_code_actions(problem, current_line, text_document,
                                          actions, rules)
            end
        end
    end
end

local handle_actions = function(actions, callback)
    local ft_ok, ft_err = pcall(u.file.is_tsserver_ft)
    if not ft_ok then error(ft_err) end

    u.loop.buf_to_stdin(o.get().eslint_bin, {
        "-f", "json", "--stdin", "--stdin-filename", u.buffer.name()
    }, function(err, output)
        if err then return end
        local ok, parsed = pcall(json.decode, output)
        if not ok then
            if string.match(output, "Error") then
                u.echo_warning("ESLint error: " .. output)
            else
                u.echo_warning("failed to parse eslint json output: " .. parsed)
            end
        end

        if parsed[1] and not isempty(parsed[1]) and parsed[1].messages and
            not isempty(parsed[1].messages) then
            local messages = parsed[1].messages
            parse_eslint_messages(messages, actions)
        end

        -- run callback even if ESLint output parsing fails to ensure code actions are always available
        callback(actions)
    end)
end

local format = function(bufnr)
    if not bufnr then bufnr = api.nvim_get_current_buf() end

    u.loop.buf_to_stdin(o.get().formatter,
                        {"--stdin-filepath", u.buffer.name(bufnr)},
                        function(err, output)
        if err or not output then return end
        api.nvim_buf_set_lines(bufnr, 0, api.nvim_buf_line_count(bufnr), false,
                               u.string.split_at_newline(output))
        if not o.get().no_save_after_format then
            vim.cmd("noautocmd :update")
        end
    end)
end
M.format = format

M.buf_request = function(bufnr, method, params, handler)
    handler = handler or lsp.handlers[method]

    if method == "textDocument/codeAction" then
        local inject_handler = function(err, _, actions, client_id, _, config)
            handle_actions(actions or {}, function(injected)
                handler(err, method, injected, client_id, bufnr, config)
            end)
        end
        return buf_request(bufnr, method, params, inject_handler)
    end

    if method == "textDocument/formatting" and o.get().enable_formatting then
        format(bufnr)
        -- return empty values for client_request_ids and _cancel_all_requests
        return {}, function() end
    end

    return buf_request(bufnr, method, params, handler)
end

return M
