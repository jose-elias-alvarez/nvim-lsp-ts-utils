local o = require("nvim-lsp-ts-utils.options")

local M = {}

M.state = {
    enabled = false,
    ns = vim.api.nvim_create_namespace("ts-inlay-hints"),
}

function M.setup_autocommands()
    vim.cmd([[
       augroup TSInlayHints
       au BufEnter,BufWinEnter,TabEnter,BufWritePost,TextChanged,TextChangedI *.ts,*.js,*.tsx,*.jsx :lua require'nvim-lsp-ts-utils'.autocmd_fun()
       augroup END
   ]])
end

local function handler(err, result, ctx)
    if not err and result and M.state.enabled then
        vim.api.nvim_buf_clear_namespace(ctx.bufnr, 0, 0, -1)

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

        for key, value in pairs(parsed) do
            local line = tonumber(key)
            for _, hint in ipairs(value) do
                vim.api.nvim_buf_set_extmark(ctx.bufnr, M.state.ns, line, -1, {
                    virt_text_pos = "eol",
                    virt_text = { { hint.text, o.get().inlay_hints_highlight } },
                    hl_mode = "combine",
                })
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

local function hide(bufnr)
    vim.api.nvim_buf_clear_namespace(bufnr, M.state.ns, 0, -1)
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
