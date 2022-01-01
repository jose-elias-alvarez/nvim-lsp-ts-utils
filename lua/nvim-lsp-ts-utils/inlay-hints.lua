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
    M.enabled[resolve_bufnr(bufnr)] = nil
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

local function make_handler(handler_ctx)
    return function(err, result, ctx)
        local bufnr = ctx.bufnr
        local event = handler_ctx.event
        if
            not err
            and result
            and buf_enabled(bufnr)
            and event
            -- No tick in params means a whole update
            and (not ctx.params.tick or event.tick == ctx.params.tick)
            and api.nvim_buf_is_loaded(bufnr)
        then
            local start_line = event.start_line
            local end_line = event.end_line
            handler_ctx.event = nil

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

            for i = start_line, end_line do
                if not parsed[i] then
                    del_hints(bufnr, i, i)
                end
            end

            local lines_cnt = api.nvim_buf_line_count(bufnr)
            for line, value in pairs(parsed) do
                if line < lines_cnt then
                    local old_hints = api.nvim_buf_get_extmarks(bufnr, ns, { line, 0 }, { line, -1 }, {})
                    table.sort(old_hints, function(a, b)
                        return a[3] < b[3]
                    end)
                    for i = #value + 1, #old_hints do
                        api.nvim_buf_del_extmark(bufnr, ns, old_hints[i][1])
                    end

                    for i, hint in ipairs(value) do
                        local format_opts = o.get().inlay_hints_format[hint.kind]
                        api.nvim_buf_set_extmark(ctx.bufnr, ns, line, -1, {
                            id = old_hints[i] and old_hints[i][1] or nil, -- reuse existing id if possible
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
end

function M.inlay_hints(bufnr)
    bufnr = resolve_bufnr(bufnr or 0)

    if buf_enabled(bufnr) then
        -- forbid duplicate enable
        return
    end
    set_buf_enabled(bufnr)

    local params = { textDocument = vim.lsp.util.make_text_document_params() }
    vim.lsp.buf_request(bufnr, INLAY_HINTS_METHOD, params, make_handler({ event = { start_line = 0, end_line = -1 } }))

    local throttle = vim.o.updatetime
    local function inlay_hints_request(ctx)
        if ctx.event then
            params = vim.lsp.util.make_given_range_params(
                { ctx.event.start_line + 1, 0 },
                { ctx.event.end_line + 2, 0 }
            )
            -- Attach tick in params so that we can identify the newest response
            params.tick = ctx.event.tick
            vim.lsp.buf_request(bufnr, INLAY_HINTS_METHOD, params, make_handler(ctx))
        end
    end
    inlay_hints_request = u.throttle_fn(throttle, vim.schedule_wrap(inlay_hints_request))

    local ctx = { event = nil }

    local attached = api.nvim_buf_attach(bufnr, false, {
        on_lines = function(_, _, tick, start, old_end, new_end)
            local old_event = ctx.event or {}
            ctx.event = {
                tick = tick,
                start_line = math.min(old_event.start_line or 0, start),
                end_line = math.max(old_event.end_line or 0, old_end, new_end),
            }

            if u.get_tsserver_client() ~= nil and buf_enabled(bufnr) then
                inlay_hints_request(ctx)
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
