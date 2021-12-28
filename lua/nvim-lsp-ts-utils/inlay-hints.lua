local o = require("nvim-lsp-ts-utils.options")
local u = require("nvim-lsp-ts-utils.utils")

local api = vim.api
local INLAY_HINTS_METHOD = "typescript/inlayHints"
local M = {}

local ns = api.nvim_create_namespace("ts-inlay-hints")
M.ns = ns

-- enabled[bufnr] = false
M.enabled = {}

local function resolve_bufnr(bufnr)
    if bufnr == 0 then
        bufnr = api.nvim_get_current_buf()
    end
    return bufnr
end

local function buf_enabled(bufnr)
    bufnr = resolve_bufnr(bufnr)
    if bufnr ~= nil then
        return M.enabled[bufnr]
    end
end

local function set_buf_enabled(bufnr)
    M.enabled[resolve_bufnr(bufnr)] = true
end

local function set_buf_disabled(bufnr)
    M.enabled[resolve_bufnr(bufnr)] = false
end

-- end_line is inclusive
local function del_hints(bufnr, start_line, end_line)
    for _, tuple in ipairs(api.nvim_buf_get_extmarks(bufnr, ns, { start_line, 0 }, { end_line, -1 }, {})) do
        api.nvim_buf_del_extmark(bufnr, ns, tuple[1])
    end
end

local function del_all_hints()
    for bufnr, _ in pairs(M.enabled) do
        api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
    end
    M.enabled = {}
end

local function handler(err, result, ctx)
    local bufnr = ctx.bufnr
    if not err and result and buf_enabled(bufnr) then
        if not api.nvim_buf_is_loaded(bufnr) then
            return
        end

        local hints = result.inlayHints or {}
        local parsed = {}
        for _, value in ipairs(hints) do
            local pos = value.position
            local line = pos.line

            if parsed[line] then
                table.insert(parsed[line], value)
                table.sort(parsed[line], function(a, b)
                    return a.position.character < b.position.character
                end)
            else
                parsed[line] = {
                    value,
                }
            end
        end

        local lines_cnt = api.nvim_buf_line_count(bufnr)
        for line, value in pairs(parsed) do
            if line < lines_cnt then
                -- overwrite old extmarks
                del_hints(bufnr, line, line)

                for _, hint in ipairs(value) do
                    local format_opts = o.get().inlay_hints_format[hint.kind]
                    api.nvim_buf_set_extmark(ctx.bufnr, ns, line, -1, {
                        virt_text_pos = "eol",
                        virt_text = {
                            {
                                format_opts.text and format_opts.text(hint.text) or hint.text,
                                { o.get().inlay_hints_highlight, format_opts.highlight },
                            },
                        },
                        hl_mode = "combine",
                        priority = o.get().inlay_hints_priority,
                    })
                end
            end
        end
    end
end

function M.inlay_hints(bufnr)
    bufnr = resolve_bufnr(bufnr or 0)

    if buf_enabled(bufnr) then
        -- forbid duplicate enable
        return
    end
    set_buf_enabled(bufnr)

    local params = { textDocument = vim.lsp.util.make_text_document_params() }
    vim.lsp.buf_request(bufnr, INLAY_HINTS_METHOD, params, handler)

    local throttle = o.get().inlay_hints_throttle
    local function inlay_hints_request(start, new_end)
        params = vim.lsp.util.make_given_range_params({ start + 1, 0 }, { new_end + 1, 0 })
        vim.lsp.buf_request(bufnr, INLAY_HINTS_METHOD, params, handler)
    end
    if throttle > 0 then
        inlay_hints_request = u.throttle_fn(throttle, vim.schedule_wrap(inlay_hints_request))
    end

    local attached = api.nvim_buf_attach(bufnr, false, {
        on_lines = function(_, _, _, start, old_end, new_end)
            if u.get_tsserver_client() ~= nil and buf_enabled(bufnr) then
                -- clear old extmarks, this should not be throttled
                del_hints(bufnr, start, old_end)

                inlay_hints_request(start, new_end)
            else
                -- detach buffer
                return true
            end
        end,
        on_detach = function(_, _)
            M.disable_inlay_hints(bufnr)
        end,
    })

    if not attached then
        set_buf_disabled(bufnr)
        u.debug_log(string.format("failed to attach buffer %s to setup inlay hints", api.nvim_buf_get_name(bufnr)))
    end
end

-- Disable inlay hints for the given buffer, if nil passed, disable all inlay hints
function M.disable_inlay_hints(bufnr)
    if bufnr ~= nil then
        set_buf_disabled(bufnr)
        api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
    else
        del_all_hints()
    end
end

-- Toggle inlay hints for a buffer, defaults to current buffer
function M.toggle_inlay_hints(bufnr)
    bufnr = resolve_bufnr(bufnr or 0)
    if buf_enabled(bufnr) then
        M.disable_inlay_hints(bufnr)
    else
        M.inlay_hints(bufnr)
    end
end

return M
