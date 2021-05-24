local o = require("nvim-lsp-ts-utils.options")
local u = require("nvim-lsp-ts-utils.utils")

local api = vim.api
local lsp = vim.lsp

local invalid_next_chars = {
    "(", -- prevent class.method()() but not func(class.method())
    "\"", -- prevent class["privateMethod()"]
    "'"
}

local add_parens = function(bufnr)
    if vim.fn.mode() ~= "i" then return end
    local row, col = u.cursor.pos()

    local next_char = string.sub(u.buffer.line(row), col + 1, col + 1)
    if vim.tbl_contains(invalid_next_chars, next_char) then return end

    u.buffer.insert_text(row - 1, col, "()", bufnr)
    u.cursor.set(row, col + 1)

    if o.get().signature_help_in_parens then lsp.buf.signature_help() end
end

local should_fix_position = function(edits)
    local range = edits[1].range
    return range["end"].line == u.cursor.pos() - 1
end

local fix_position = function(edits)
    local new_text = edits[1].newText
    local _, newlines = string.gsub(new_text, "\n", "")

    local row, col = u.cursor.pos()
    u.cursor.set(row + newlines, col)
end

local should_add_parens = function(item)
    if not o.get().complete_parens then return false end

    return item.kind == 2 -- method
    or item.kind == 3 -- function
    or item.kind == 4 -- constructor
end

local M = {}
M.enable = function()
    u.buf_augroup("TSLspImportOnCompletion", "CompleteDone",
                         "import_on_completion()")
end

local last
M.handle = function()
    local bufnr = api.nvim_get_current_buf()
    local completed_item = vim.v.completed_item
    if not (completed_item and completed_item.user_data and
        completed_item.user_data.nvim and completed_item.user_data.nvim.lsp and
        completed_item.user_data.nvim.lsp.completion_item) then return end

    local item = completed_item.user_data.nvim.lsp.completion_item
    if last == item.label then return end

    last = item.label
    -- use timeout to prevent multiple imports, since CompleteDone can fire multiple times
    vim.defer_fn(function() last = nil end, o.get().import_on_completion_timeout)

    -- place after last check to set timeout on parens
    if should_add_parens(item) then add_parens(bufnr) end

    lsp.buf_request(bufnr, "completionItem/resolve", item,
                    function(_, _, result)
        if not (result and result.additionalTextEdits) then return end
        local edits = result.additionalTextEdits

        -- when an edit's range includes the current line, the cursor won't move
        -- which is annoying and messes up parens
        local should_fix = should_fix_position(edits)
        lsp.util.apply_text_edits(result.additionalTextEdits, bufnr)
        if should_fix then fix_position(edits) end
    end)
end
return M
