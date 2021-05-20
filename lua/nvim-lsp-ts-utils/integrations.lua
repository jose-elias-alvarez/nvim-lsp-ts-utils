local o = require("nvim-lsp-ts-utils.options")
local u = require("nvim-lsp-ts-utils.utils")
local s = require("nvim-lsp-ts-utils.state")

local ok, null_ls = pcall(require, "null-ls")

local M = {}

local convert_offset = function(row, params, start_offset, end_offset)
    local start_char, end_char
    local line_offset = vim.api.nvim_buf_get_offset(params.bufnr, row)
    local line_end_char = string.len(params.content[row + 1])
    for j = 0, line_end_char do
        local char_offset = line_offset + j
        if char_offset == start_offset then start_char = j end
        if char_offset == end_offset then end_char = j end
    end
    return start_char, end_char
end

local is_fixable = function(problem, row)
    if not problem or problem.line == nil then return false end
    if problem.endLine ~= nil then
        return problem.line - 1 <= row and problem.endLine - 1 >= row
    end
    if problem.fix ~= nil then return problem.line - 1 == row end

    return false
end

local get_message_range = function(problem)
    local row = (problem.line and problem.line > 0 and problem.line - 1) or 0
    local col =
        (problem.column and problem.column > 0 and problem.column - 1) or 0
    local end_row = problem.endLine and problem.endLine - 1 or 0
    local end_col = problem.endColumn and problem.endColumn - 1 or 0

    return {row = row, col = col, end_row = end_row, end_col = end_col}
end

local get_fix_range = function(problem, params)
    local row = problem.line - 1
    local offset = problem.fix.range[1]
    local end_offset = problem.fix.range[2]
    local col, end_col = convert_offset(row, params, offset, end_offset)

    return {row = row, col = col, end_row = row, end_col = end_col}
end

local generate_edit_action = function(title, new_text, range, params)
    return {
        title = title,
        action = function()
            vim.api.nvim_buf_set_text(params.bufnr, range.row, range.col,
                                      range.end_row, range.end_col, {new_text})
        end
    }
end

local generate_edit_line_action = function(title, new_text, row, params)
    return {
        title = title,
        action = function()
            vim.api
                .nvim_buf_set_lines(params.bufnr, row, row, false, {new_text})
        end
    }
end

local generate_suggestion_action = function(suggestion, message, params)
    local title = suggestion.desc
    local new_text = suggestion.fix.text
    local range = get_message_range(message)

    return generate_edit_action(title, new_text, range, params)
end

local generate_fix_action = function(message, params)
    local title = "Apply suggested fix for ESLint rule " .. message.ruleId
    local new_text = message.fix.text
    local range = get_fix_range(message, params)

    return generate_edit_action(title, new_text, range, params)
end

local generate_disable_actions = function(message, indentation, params, rules)
    local rule_id = message.ruleId
    if (vim.tbl_contains(rules, rule_id)) then return end
    table.insert(rules, rule_id)

    local actions = {}
    local line_title = "Disable ESLint rule " .. message.ruleId ..
                           " for this line"
    local line_new_text = indentation .. "// eslint-disable-next-line " ..
                              rule_id
    table.insert(actions, generate_edit_line_action(line_title, line_new_text,
                                                    params.row - 1, params))

    local file_title = "Disable ESLint rule " .. message.ruleId ..
                           " for the entire file"
    local file_new_text = "/* eslint-disable " .. rule_id .. " */"
    table.insert(actions, generate_edit_line_action(file_title, file_new_text,
                                                    0, params))

    return actions
end

local on_code_action_output = function(params)
    local output = params.output
    if not (output[1] and output[1].messages) then return end

    local messages = output[1].messages
    local row = params.row
    local indentation = string.match(params.content[row], "^%s+")
    if not indentation then indentation = "" end

    local rules, actions = {}, {}
    for _, message in ipairs(messages) do
        if is_fixable(message, row - 1) then
            if message.suggestions then
                for _, suggestion in ipairs(message.suggestions) do
                    table.insert(actions, generate_suggestion_action(suggestion,
                                                                     message,
                                                                     params))
                end
            end
            if message.fix then
                table.insert(actions, generate_fix_action(message, params))
            end
            if message.ruleId and o.get().eslint_enable_disable_comments then
                vim.list_extend(actions, generate_disable_actions(message,
                                                                  indentation,
                                                                  params, rules))
            end
        end
    end
    return actions
end

local create_diagnostic = function(message)
    local range = get_message_range(message)

    return {
        message = message.message,
        code = message.ruleId,
        row = range.row + 1,
        col = range.col,
        end_row = range.end_row + 1,
        end_col = range.end_col,
        -- eslint severity can be:
        -- 1: warning
        -- 2: error
        -- lsp severity is the opposite
        severity = message.severity == 1 and 2 or 1,
        source = "eslint"
    }
end

local on_diagnostic_output = function(params)
    local output = params.output
    if not (output[1] and output[1].messages) then return end

    local messages = output[1].messages
    local diagnostics = {}
    for _, message in ipairs(messages) do
        table.insert(diagnostics, create_diagnostic(message))
    end

    return diagnostics
end

M.setup = function()
    if not ok then return end
    if not s.get().null_ls then s.set({null_ls = true}) end

    local sources = {}
    if o.get().eslint_enable_code_actions then
        local eslint_code_actions = null_ls.generator(
                                        {
                command = o.get().eslint_bin,
                args = o.get().eslint_args,
                format = "json",
                to_stdin = true,
                on_output = on_code_action_output
            })
        table.insert(sources, {
            method = null_ls.methods.CODE_ACTION,
            generator = eslint_code_actions
        })
    end

    if o.get().eslint_enable_diagnostics then
        local eslint_diagnostics = null_ls.generator(
                                       {
                command = o.get().eslint_bin,
                args = o.get().eslint_args,
                format = "json",
                to_stdin = true,
                on_output = on_diagnostic_output
            })
        table.insert(sources, {
            method = null_ls.methods.DIAGNOSTICS,
            generator = eslint_diagnostics
        })
    end

    null_ls.register({
        filetypes = u.tsserver_fts,
        name = "nvim-lsp-ts-utils",
        sources = sources
    })
end

return M
