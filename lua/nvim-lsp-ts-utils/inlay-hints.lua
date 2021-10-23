local M = {}

M.ns = vim.api.nvim_create_namespace("ts-inlay-hints")

local function handler(err, result, ctx)
    if not err and result then
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
                vim.api.nvim_buf_set_extmark(
                    ctx.bufnr,
                    M.ns,
                    line,
                    -1,
                    { virt_text_pos = "eol", virt_text = { { hint.text, "Comment" } }, hl_mode = "combine" }
                )
            end
        end
    end
end

function M.inlay_hints()
    local params = {
        textDocument = vim.lsp.util.make_text_document_params(),
    }
    vim.lsp.buf_request(0, "typescript/inlayHints", params, handler)
end

return M
