local o = require("nvim-lsp-ts-utils.options")
local u = require("nvim-lsp-ts-utils.utils")

local api = vim.api
local lsp = vim.lsp

local add_parens = function(bufnr)
    local row, col = u.cursor.pos()
    -- check next char to prevent ()()
    local next_char = string.sub(u.buffer.line(row), col + 1, col + 1)
    if next_char == "(" then return end

    u.buffer.insert_text(row - 1, col, "()", bufnr)
    u.cursor.set(row, col + 1)

    if o.get().signature_help_in_parens then lsp.buf.signature_help() end
end

local fix_position = function(result)
    if not (result.additionalTextEdits[1] and
        result.additionalTextEdits[1].newText) then return end

    local new_text = result.additionalTextEdits[1].newText
    local newlines = 0
    for _ in string.gmatch(new_text, "\n") do newlines = newlines + 1 end

    local row, col = u.cursor.pos()
    u.cursor.set(row + newlines, col)
end

local should_add_parens = function(item)
    -- 2: method
    -- 3: function
    -- 4: constructor
    return item.kind == 2 or item.kind == 3 or item.kind == 4
end

local M = {}
M.enable = function()
    vim.api.nvim_exec([[
    augroup TSLspImportOnCompletion
        autocmd! * <buffer>
        autocmd CompleteDone <buffer> lua require'nvim-lsp-ts-utils'.import_on_completion()
    augroup END
    ]], false)
end

local last_imported = ""
M.handle = function()
    local bufnr = api.nvim_get_current_buf()
    local completed_item = vim.v.completed_item
    if not (completed_item and completed_item.user_data and
        completed_item.user_data.nvim and completed_item.user_data.nvim.lsp and
        completed_item.user_data.nvim.lsp.completion_item) then return end

    local item = completed_item.user_data.nvim.lsp.completion_item
    if last_imported == item.label then return end

    lsp.buf_request(bufnr, "completionItem/resolve", item,
                    function(_, _, result)
        if not result then return end

        if result.additionalTextEdits then
            -- when newText includes the current line, the cursor stays in the same position
            -- which is annoying and will mess up parens if not fixed
            local should_fix = u.cursor.pos() == 1
            lsp.util.apply_text_edits(result.additionalTextEdits, bufnr)
            if should_fix then fix_position(result) end

            last_imported = item.label
            vim.defer_fn(function() last_imported = "" end,
                         o.get().import_on_completion_timeout)
        end

        if o.get().complete_parens and should_add_parens(item) then
            add_parens(bufnr)
        end
    end)
end
return M
