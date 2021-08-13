local ok, null_ls = pcall(require, "null-ls")

local o = require("nvim-lsp-ts-utils.options")
local u = require("nvim-lsp-ts-utils.utils")

local api = vim.api

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
    -- (1,0)-indexed
    local cursor = api.nvim_win_get_cursor(0)
    local col = cursor[2] + 1
    vim.cmd("go " .. end_offset)
    cursor = api.nvim_win_get_cursor(0)
    local end_row, end_col = cursor[1], cursor[2] + 1

    -- restore state
    vim.fn.winrestview(view)
    vim.opt.virtualedit = virtualedit

    return col, end_col, end_row
end

local is_fixable = function(problem, row)
    if not problem or not problem.line then
        return false
    end

    if problem.endLine then
        return problem.line <= row and problem.endLine >= row
    end

    if problem.fix then
        return problem.line - 1 == row
    end

    return false
end

local get_message_range = function(problem)
    -- 1-indexed
    local row = problem.line or 1
    local col = problem.column or 1
    local end_row = problem.endLine or 1
    local end_col = problem.endColumn or 1

    return { row = row, col = col, end_row = end_row, end_col = end_col }
end

local get_fix_range = function(problem, params)
    -- 1-indexed
    local row = problem.line
    local offset = problem.fix.range[1]
    local end_offset = problem.fix.range[2]
    local col, end_col, end_row = get_offset_positions(params.content, offset, end_offset)

    return { row = row, col = col, end_row = end_row, end_col = end_col }
end

local generate_edit_action = function(title, new_text, range, params)
    return {
        title = title,
        action = function()
            -- 0-indexed
            api.nvim_buf_set_text(
                params.bufnr,
                range.row - 1,
                range.col - 1,
                range.end_row - 1,
                range.end_col - 1,
                vim.split(new_text, "\n")
            )
        end,
    }
end

local generate_edit_line_action = function(title, new_text, row, params)
    return {
        title = title,
        action = function()
            -- 0-indexed
            api.nvim_buf_set_lines(params.bufnr, row - 1, row - 1, false, { new_text })
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
    table.insert(actions, generate_edit_line_action(line_title, line_new_text, message.line, params))

    local file_title = "Disable ESLint rule " .. rule_id .. " for the entire file"
    local file_new_text = "/* eslint-disable " .. rule_id .. " */"
    table.insert(actions, generate_edit_line_action(file_title, file_new_text, 0, params))

    return actions
end

local code_action_handler = function(params)
    local row = params.row
    local indentation = params.content[row]:match("^%s+") or ""

    local rules, actions = {}, {}
    for _, message in ipairs(params.messages) do
        if is_fixable(message, row) then
            if message.suggestions then
                for _, suggestion in ipairs(message.suggestions) do
                    table.insert(actions, generate_suggestion_action(suggestion, message, params))
                end
            end

            if message.fix then
                table.insert(actions, generate_fix_action(message, params))
            end

            if message.ruleId and o.get().eslint_enable_disable_comments and not rules[message.ruleId] then
                rules[message.ruleId] = true
                vim.list_extend(actions, generate_disable_actions(message, indentation, params))
            end
        end
    end

    return actions
end

local on_output = function(params)
    local output = params.output

    if not (output and output[1] and output[1].messages) then
        return
    end

    params.messages = output[1].messages
    return code_action_handler(params)
end

M.setup = function()
    if not ok then
        return
    end

    local name = "nvim-lsp-ts-utils"
    if null_ls.is_registered(name) then
        return
    end

    if o.get().eslint_enable_code_actions or o.get().eslint_enable_diagnostics then
        local eslint_bin = o.get().eslint_bin
        local eslint_args = o.get().eslint_args

        if not u.config_file_exists(eslint_bin) then
            local fallback = o.get().eslint_config_fallback
            if not fallback then
                u.debug_log("ESLint config file not found (config may still be valid; see diagnostics for errors)")
            else
                table.insert(eslint_args, "--config")
                table.insert(eslint_args, fallback)
            end
        end

        if o.get().eslint_enable_code_actions then
            local generator_opts = {
                command = u.resolve_bin(eslint_bin),
                args = eslint_args,
                format = "json_raw",
                to_stdin = true,
                check_exit_code = function(code)
                    return code <= 1
                end,
                use_cache = true,
                on_output = on_output,
            }

            u.debug_log("enabling null-ls eslint code actions integration")
            null_ls.register({
                name = eslint_bin,
                filetypes = u.tsserver_fts,
                method = null_ls.methods.CODE_ACTION,
                generator = null_ls.generator(generator_opts),
            })
        end

        if o.get().eslint_enable_diagnostics then
            local builtin = null_ls.builtins.diagnostics[eslint_bin]
            assert(builtin, eslint_bin .. " is not an available diagnostics source")

            builtin._opts.args = eslint_args
            if o.get().eslint_show_rule_id then
                builtin._opts.diagnostics_format = "#{m} [#{c}]"
            end

            u.debug_log("enabling null-ls eslint diagnostics integration")
            null_ls.register(builtin)
        end
    end

    if o.get().enable_formatting then
        local formatter = o.get().formatter
        local is_eslint_formatter = formatter:find("eslint") ~= nil

        local builtin = null_ls.builtins.formatting[formatter]
        assert(builtin, formatter .. " is not an available formatter")

        local extra_args = {}
        local args = builtin._opts.args
        builtin._opts.args = function(params)
            local original_args = type(args) == "function" and args(params) or args
            return vim.list_extend(original_args, extra_args)
        end

        if not u.config_file_exists(formatter) then
            local fallback = is_eslint_formatter and o.get().eslint_config_fallback or o.get().formatter_config_fallback

            -- prettier works without a config, so we only want this for eslint and and friends
            if not fallback and is_eslint_formatter then
                u.debug_log("failed to resolve ESLint config")
            elseif fallback then
                table.insert(extra_args, "--config")
                table.insert(extra_args, fallback)
            end
        end

        u.debug_log("enabling null-ls formatting integration")
        null_ls.register(builtin)
    end

    null_ls.register_name(name)
    u.debug_log("successfully registered null-ls integrations")
end

return M
