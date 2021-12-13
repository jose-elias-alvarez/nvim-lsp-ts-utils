local o = require("nvim-lsp-ts-utils.options")
local u = require("nvim-lsp-ts-utils.utils")

local api = vim.api

local M = {}

M.state = {
    enabled = false,
    ns = api.nvim_create_namespace("ts-inlay-hints"),
}

function M.setup_autocommands()
    u.buf_autocmd(
        "TSLspImportOnCompletion",
        "BufEnter,BufWinEnter,TabEnter,BufWritePost,TextChanged,TextChangedI",
        "autocmd_fun()"
    )
end

local function hide(bufnr)
    api.nvim_buf_clear_namespace(bufnr, M.state.ns, 0, -1)
end

local function handler(err, result, ctx)
    if not err and result and M.state.enabled then
        local bufnr = ctx.bufnr
        if not api.nvim_buf_is_loaded(bufnr) then
            return
        end

        hide(bufnr)

        local hints = result.inlayHints or {}
        local parsed = {}
        for _, value in ipairs(hints) do
            local pos = value.position
            local line_str = tostring(pos.line)

            if parsed[line_str] then
                table.insert(parsed[line_str], value)
                table.sort(parsed[line_str], function(a, b)
                    return a.position.character < b.position.character
                end)
            else
                parsed[line_str] = {
                    value,
                }
            end
        end

        local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
        for key, value in pairs(parsed) do
            local line = tonumber(key)
            if lines[line + 1] then
                for _, hint in ipairs(value) do
                    api.nvim_buf_set_extmark(ctx.bufnr, M.state.ns, line, -1, {
                        virt_text_pos = "eol",
                        virt_text = { { hint.text, o.get().inlay_hints_highlight } },
                        hl_mode = "combine",
                    })
                end
            end
        end
    end
end

local function show()
    local params = {
        textDocument = vim.lsp.util.make_text_document_params(),
    }
    vim.lsp.buf_request(0, "typescript/inlayHints", params, handler)
end

function M.autocmd_fun()
    if M.state.enabled then
        show()
        return
    end
    hide()
end

function M.inlay_hints()
    M.state.enabled = true
    show()
end

function M.disable_inlay_hints(bufnr)
    M.state.enabled = false
    hide(bufnr)
end

function M.toggle_inlay_hints()
    if M.state.enabled then
        M.disable_inlay_hints()
    else
        M.inlay_hints()
    end
end

return M
