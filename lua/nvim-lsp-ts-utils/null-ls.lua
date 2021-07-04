local ok, null_ls = pcall(require, "null-ls")

local o = require("nvim-lsp-ts-utils.options")
local u = require("nvim-lsp-ts-utils.utils")

local api = vim.api
local set_lines = vim.api.nvim_buf_set_lines
local set_text = vim.api.nvim_buf_set_text

local M = {}

local get_offset_positions = function(content, start_offset, end_offset)
    -- ESLint uses character offsets, so convert to byte indexes to handle multibyte characters
    local to_string = table.concat(content, "\n")
    start_offset = vim.str_byteindex(to_string, start_offset + 1)
    end_offset = vim.str_byteindex(to_string, end_offset + 1)

    -- save original window position and virtualedit setting
    local view = vim.fn.winsaveview()
    local virtualedit = vim.opt.virtualedit
    vim.opt.virtualedit = "all"

    vim.cmd("go " .. start_offset)
    local cursor = api.nvim_win_get_cursor(0)
    local col = cursor[2]
    vim.cmd("go " .. end_offset)
    cursor = api.nvim_win_get_cursor(0)
    local end_row, end_col = cursor[1] - 1, cursor[2]

    -- restore state
    vim.fn.winrestview(view)
    vim.opt.virtualedit = virtualedit

    return col, end_col, end_row
end

local is_fixable = function(problem, row)
    if not problem or not problem.line then
        return false
    end

    if problem.endLine ~= nil then
        return problem.line - 1 <= row and problem.endLine - 1 >= row
    end
    if problem.fix ~= nil then
        return problem.line - 1 == row
    end

    return false
end

local get_message_range = function(problem)
    local row = problem.line and problem.line > 0 and problem.line - 1 or 0
    local col = problem.column and problem.column > 0 and problem.column - 1 or 0
    local end_row = problem.endLine and problem.endLine - 1 or 0
    local end_col = problem.endColumn and problem.endColumn - 1 or 0

    return { row = row, col = col, end_row = end_row, end_col = end_col }
end

local get_fix_range = function(problem, params)
    local row = problem.line - 1
    local offset = problem.fix.range[1]
    local end_offset = problem.fix.range[2]
    local col, end_col, end_row = get_offset_positions(params.content, offset, end_offset)

    return { row = row, col = col, end_row = end_row, end_col = end_col }
end

local generate_edit_action = function(title, new_text, range, params)
    return {
        title = title,
        action = function()
            set_text(params.bufnr, range.row, range.col, range.end_row, range.end_col, vim.split(new_text, "\n"))
        end,
    }
end

local generate_edit_line_action = function(title, new_text, row, params)
    return {
        title = title,
        action = function()
            set_lines(params.bufnr, row, row, false, { new_text })
        end,
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

local generate_disable_actions = function(message, indentation, params)
    local rule_id = message.ruleId

    local actions = {}
    local line_title = "Disable ESLint rule " .. rule_id .. " for this line"
    local line_new_text = indentation .. "// eslint-disable-next-line " .. rule_id
    local row = message.line and message.line > 0 and message.line - 1 or 0
    table.insert(actions, generate_edit_line_action(line_title, line_new_text, row, params))

    local file_title = "Disable ESLint rule " .. rule_id .. " for the entire file"
    local file_new_text = "/* eslint-disable " .. rule_id .. " */"
    table.insert(actions, generate_edit_line_action(file_title, file_new_text, 0, params))

    return actions
end

local code_action_handler = function(params)
    local row = params.row
    local indentation = string.match(params.content[row], "^%s+")
    if not indentation then
        indentation = ""
    end

    local rules, actions = {}, {}
    for _, message in ipairs(params.messages) do
        if is_fixable(message, row - 1) then
            if message.suggestions then
                for _, suggestion in ipairs(message.suggestions) do
                    table.insert(actions, generate_suggestion_action(suggestion, message, params))
                end
            end
            if message.fix then
                table.insert(actions, generate_fix_action(message, params))
            end
            if
                message.ruleId
                and o.get().eslint_enable_disable_comments
                and not vim.tbl_contains(rules, message.ruleId)
            then
                table.insert(rules, message.ruleId)
                vim.list_extend(actions, generate_disable_actions(message, indentation, params))
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
        source = "eslint",
    }
end

local diagnostic_handler = function(params)
    local diagnostics = {}
    if params.err then
        params.messages = { { message = params.err } }
    end

    for _, message in ipairs(params.messages) do
        table.insert(diagnostics, create_diagnostic(message))
    end

    return diagnostics
end

local on_output_factory = function(callback, handle_errors)
    return function(params)
        local output, err = params.output, params.err
        if err and handle_errors then
            return callback(params)
        end

        if not (output and output[1] and output[1].messages) then
            return
        end

        params.messages = output[1].messages
        return callback(params)
    end
end

local eslint_enabled = function()
    return o.get().eslint_enable_code_actions == true or o.get().eslint_enable_diagnostics == true
end

M.setup = function()
    if not ok then
        return
    end

    local name = "nvim-lsp-ts-utils"
    if null_ls.is_registered(name) then
        return
    end

    local sources = {}
    local add_source = function(method, generator)
        table.insert(sources, { method = method, generator = generator })
    end

    if eslint_enabled() then
        local eslint_bin = o.get().eslint_bin
        local eslint_opts = {
            command = u.resolve_bin(eslint_bin),
            args = o.get().eslint_args,
            format = "json_raw",
            to_stdin = true,
            check_exit_code = function(code)
                return code <= 1
            end,
            use_cache = true,
        }

        if not u.config_file_exists(eslint_bin) then
            local fallback = o.get().eslint_config_fallback
            if not fallback then
                u.debug_log("ESLint config file not found (config may still be valid; see diagnostics for errors)")
            else
                table.insert(eslint_opts.args, "--config")
                table.insert(eslint_opts.args, fallback)
            end
        end

        local make_eslint_opts = function(handler, method)
            local opts = vim.deepcopy(eslint_opts)
            opts.on_output = on_output_factory(handler, method == null_ls.methods.DIAGNOSTICS)
            return opts
        end

        if o.get().eslint_enable_code_actions then
            u.debug_log("enabling null-ls eslint code actions integration")

            local method = null_ls.methods.CODE_ACTION
            add_source(method, null_ls.generator(make_eslint_opts(code_action_handler, method)))
        end

        if o.get().eslint_enable_diagnostics then
            u.debug_log("enabling null-ls eslint diagnostics integration")

            local method = null_ls.methods.DIAGNOSTICS
            add_source(method, null_ls.generator(make_eslint_opts(diagnostic_handler, method)))
        end
    end

    if o.get().enable_formatting then
        local formatter = o.get().formatter
        local formatter_opts = {
            command = u.resolve_bin(formatter),
            args = o.get().formatter_args,
            to_stdin = true,
        }

        if not u.config_file_exists(formatter) then
            local fallback = formatter == "eslint_d" and o.get().eslint_config_fallback
                or o.get().formatter_config_fallback

            -- prettier works without a config
            if not fallback and formatter == "eslint_d" then
                u.debug_log("failed to resolve ESLint config")
            elseif fallback then
                table.insert(formatter_opts.args, "--config")
                table.insert(formatter_opts.args, fallback)
            end
        end

        u.debug_log("enabling null-ls formatting integration")
        add_source(null_ls.methods.FORMATTING, null_ls.formatter(formatter_opts))
    end

    if vim.tbl_count(sources) > 0 then
        null_ls.register({
            filetypes = u.tsserver_fts,
            name = name,
            sources = sources,
        })
        u.debug_log("successfully registered null-ls integrations")
    end
end

return M
