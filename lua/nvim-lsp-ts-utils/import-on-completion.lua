local o = require("nvim-lsp-ts-utils.options")
local lsp = vim.lsp

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
    local completed_item = vim.v.completed_item
    if not (completed_item and completed_item.user_data and
        completed_item.user_data.nvim and completed_item.user_data.nvim.lsp and
        completed_item.user_data.nvim.lsp.completion_item) then return end

    local item = completed_item.user_data.nvim.lsp.completion_item
    if last_imported == item.label then return end

    lsp.buf_request(0, "completionItem/resolve", item, function(_, _, result)
        if result and result.additionalTextEdits then
            lsp.util.apply_text_edits(result.additionalTextEdits, 0)

            last_imported = item.label
            vim.defer_fn(function() last_imported = "" end,
                         o.get().import_on_completion_timeout)
        end
    end)
end
return M
