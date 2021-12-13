local u = require("nvim-lsp-ts-utils.utils")

local api = vim.api
local lsp = vim.lsp

local should_fix_position = function(edits)
    local range = edits[1].range
    local pos = api.nvim_win_get_cursor(0)
    return range["end"].line == pos[1] - 1
end

local fix_position = function(edits)
    local new_text = edits[1].newText
    local _, new_lines = string.gsub(new_text, "\n", "")

    local pos = api.nvim_win_get_cursor(0)
    local row, col = pos[1], pos[2]
    api.nvim_win_set_cursor(0, { row + new_lines, col })
end

local M = {}
M.enable = function()
    u.buf_autocmd("TSLspImportOnCompletion", "CompleteDone", "import_on_completion()")
end

local last
M.handle = function()
    local bufnr = api.nvim_get_current_buf()
    local completed_item = vim.v.completed_item
    if
        not (
            completed_item
            and completed_item.user_data
            and completed_item.user_data.nvim
            and completed_item.user_data.nvim.lsp
            and completed_item.user_data.nvim.lsp.completion_item
        )
    then
        return
    end

    local item = completed_item.user_data.nvim.lsp.completion_item
    if last == item.label then
        return
    end

    last = item.label
    -- use timeout to prevent multiple imports, since CompleteDone can fire multiple times
    vim.defer_fn(function()
        last = nil
    end, 5000)

    lsp.buf_request(
        bufnr,
        "completionItem/resolve",
        item,
        u.make_handler(function(_, result)
            if not (result and result.additionalTextEdits) then
                return
            end
            local edits = result.additionalTextEdits

            -- when an edit's range includes the current line, the cursor won't move, which is annoying
            local should_fix = should_fix_position(edits)
            lsp.util.apply_text_edits(result.additionalTextEdits, bufnr)
            if should_fix then
                fix_position(edits)
            end
        end)
    )
end
return M
