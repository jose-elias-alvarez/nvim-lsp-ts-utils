local s = require("nvim-lsp-ts-utils.state")
local u = require("nvim-lsp-ts-utils.utils")
local o = require("nvim-lsp-ts-utils.options")
local loop = require("nvim-lsp-ts-utils.loop")

local api = vim.api
local lsp = vim.lsp
local json_decode = vim.fn.json_decode

local eslint_bin, formatter_bin

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

local push_disable_code_actions = function(problem, row, indentation,
                                           text_document, actions, rules)
    local rule_id = problem.ruleId
    if (u.table.contains(rules, rule_id)) then return end
    table.insert(rules, rule_id)

    local line_title = "Disable ESLint rule " .. problem.ruleId ..
                           " for this line"
    local line_new_text = indentation .. "// eslint-disable-next-line " ..
                              rule_id .. "\n"
    local line_range = {
        start = {line = row, character = 0},
        ["end"] = {line = row, character = 0}
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

local problem_is_fixable = function(problem, col)
    if not problem or problem.line == nil or problem.column == nil then
        return false
    end
    if problem.endLine ~= nil then
        return problem.line - 1 <= col and problem.endLine - 1 >= col
    end
    if problem.fix ~= nil then return problem.line - 1 == col end
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

local get_diagnostic_range = function(diagnostic)
    local start_line = (diagnostic.line and diagnostic.line > 0 and
                           diagnostic.line - 1) or 0
    local start_char = (diagnostic.column and diagnostic.column > 0 and
                           diagnostic.column - 1) or 0
    local end_line = diagnostic.endLine and diagnostic.endLine - 1 or 0
    local end_char = diagnostic.endColumn and diagnostic.endColumn - 1 or 0

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
    local row = api.nvim_win_get_cursor(0)[1] - 1
    local indentation = string.match(u.buffer.line(row + 1), "^%s+")
    if not indentation then indentation = "" end

    local rules = {}
    for _, problem in ipairs(messages) do
        if not problem_is_fixable(problem, row) then break end

        if problem.suggestions then
            for _, suggestion in ipairs(problem.suggestions) do
                push_suggestion_code_action(suggestion,
                                            get_diagnostic_range(problem),
                                            text_document, actions)
            end
        end
        if problem.fix then
            push_fix_code_action(problem, get_fix_range(problem), text_document,
                                 actions)
        end
        if problem.ruleId and o.get().eslint_enable_disable_comments then
            push_disable_code_actions(problem, row, indentation, text_document,
                                      actions, rules)
        end
    end
end

local handle_eslint_actions = function(_, parsed, actions, callback)
    if parsed and parsed[1] and parsed[1].messages then
        parse_eslint_messages(parsed[1].messages, actions)
    end

    callback(actions)
end

local eslint_handler = function(bufnr, handler)
    if not eslint_bin then eslint_bin = u.find_bin(o.get().eslint_bin) end
    local args = u.parse_args(o.get().eslint_args, bufnr)

    loop.buf_to_stdin(eslint_bin, args, function(error_output, output)
        -- don't attempt to parse after error
        if error_output then
            handler(error_output, nil)
            return
        end
        -- don't attempt to parse nil output
        if not output then
            handler(nil, nil)
            return
        end

        local ok, parsed = pcall(json_decode, output)
        local eslint_err
        if not ok then
            if string.match(output, "Error") then
                -- ESLint CLI errors are text strings, so return error as-is
                eslint_err = output
            else
                -- if parse failed, return json.decode error output
                eslint_err = "Failed to parse JSON: " .. parsed
            end
        end

        handler(eslint_err, parsed)
    end)
end

local format = function(formatter, args, bufnr)
    if not bufnr then bufnr = api.nvim_get_current_buf() end
    local parsed_args = u.parse_args(args and args or o.get().formatter_args,
                                     bufnr)
    if not formatter_bin then
        if not formatter then formatter = o.get().formatter end
        formatter_bin = u.find_bin(formatter)
    end

    loop.buf_to_stdin(formatter_bin, parsed_args, function(error_output, output)
        if error_output or not output then return end
        if not api.nvim_buf_is_loaded(bufnr) then return end

        api.nvim_buf_set_lines(bufnr, 0, api.nvim_buf_line_count(bufnr), false,
                               u.string.split_at_newline(output))
        if not o.get().no_save_after_format then
            vim.cmd("noautocmd :update")
        end
    end)
end
M.format = format

local fix_range = function(range)
    if range["end"].character == -1 then range["end"].character = 0 end
    if range["end"].line == -1 then range["end"].line = 0 end
    if range.start.character == -1 then range.start.character = 0 end
    if range.start.line == -1 then range.start.line = 0 end
end

local validate_changes = function(changes)
    for _, _change in pairs(changes) do
        for _, change in ipairs(_change) do
            if change.range then fix_range(change.range) end
        end
    end
end

local edit_handler = function(_, _, workspace_edit)
    if workspace_edit.edit and workspace_edit.edit.changes then
        validate_changes(workspace_edit.edit.changes)
    end
    local status, result = pcall(lsp.util.apply_workspace_edit,
                                 workspace_edit.edit)
    return {applied = status, failureReason = result}
end

M.setup_client = function(client)
    if client.ts_utils_setup_complete then return end
    client.handlers["workspace/applyEdit"] = edit_handler

    local original_request = client.request
    client.request = function(method, params, handler, bufnr)
        handler = handler or lsp.handlers[method]

        -- internal methods (currently import_all) may want to skip this
        if method == "textDocument/codeAction" and not s.get().null_ls and
            o.get().eslint_enable_code_actions and not params.skip_eslint then
            local inject_handler = function(err, _, actions, client_id, _,
                                            config)
                eslint_handler(bufnr, function(eslint_err, parsed)
                    handle_eslint_actions(eslint_err, parsed, actions or {},
                                          function(injected)
                        handler(err, method, injected, client_id, bufnr, config)
                    end)
                end)
            end
            return original_request(method, params, inject_handler, bufnr)
        end

        if method == "textDocument/formatting" and o.get().enable_formatting then
            format(nil, nil, bufnr)
            -- return false to prevent attempting to cancel nonexistent request
            return false
        end

        return original_request(method, params, handler, bufnr)
    end
    client.ts_utils_setup_complete = true
end

local create_diagnostic = function(message)
    -- eslint severity can be:
    -- 1: warning
    -- 2: error
    -- lsp severity is the opposite
    return {
        message = message.message,
        code = message.ruleId,
        range = get_diagnostic_range(message),
        severity = message.severity == 1 and 2 or 1,
        source = "eslint"
    }
end

local handle_eslint_diagnostics = function(err, parsed, bufnr)
    local params = {diagnostics = {}, uri = vim.uri_from_bufnr(bufnr)}

    -- insert err as diagnostic warning
    if err then
        table.insert(params.diagnostics,
                     create_diagnostic({message = err, severity = 2}))
    end

    if parsed and parsed[1] and parsed[1].messages then
        for _, message in ipairs(parsed[1].messages) do
            table.insert(params.diagnostics, create_diagnostic(message))
        end
    end

    -- use fake client_id to avoid interference w/ actual LSP clients and enable caching
    lsp.handlers["textDocument/publishDiagnostics"](nil, nil, params, 9999, nil,
                                                    {})
end

local get_diagnostics = function(bufnr)
    if not bufnr then bufnr = api.nvim_get_current_buf() end

    eslint_handler(bufnr, function(err, parsed)
        handle_eslint_diagnostics(err, parsed, bufnr)
    end)
end

M.diagnostics = get_diagnostics

M.enable_diagnostics = function()
    if s.get().null_ls then return end
    local bufnr = api.nvim_get_current_buf()

    local callback = vim.schedule_wrap(function() get_diagnostics(bufnr) end)
    -- immediately get buffer diagnostics
    local timer = loop.timer(0, nil, true, callback)

    api.nvim_buf_attach(bufnr, false, {
        on_lines = function()
            -- restart timer on text change
            timer.restart(o.get().eslint_diagnostics_debounce)
        end
    })
end

return M
