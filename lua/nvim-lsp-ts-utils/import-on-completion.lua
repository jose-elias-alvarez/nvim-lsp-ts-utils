local o = require("nvim-lsp-ts-utils.options")

local api = vim.api
local lsp = vim.lsp

local add_parens = function(bufnr)
    local pos = api.nvim_win_get_cursor(0)
    local row = pos[1] - 1
    local col = pos[2]

    api.nvim_buf_set_text(bufnr, row, col, row, col, {"()"})
    api.nvim_win_set_cursor(0, {row + 1, col + 1})

    if o.get().signature_help_in_parens then lsp.buf.signature_help() end
end

local is_function = function(item)
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
            lsp.util.apply_text_edits(result.additionalTextEdits, bufnr)
            last_imported = item.label
            vim.defer_fn(function() last_imported = "" end,
                         o.get().import_on_completion_timeout)
        end

        if o.get().complete_parens and is_function(item) then
            add_parens(bufnr)
        end
    end)
end
return M
