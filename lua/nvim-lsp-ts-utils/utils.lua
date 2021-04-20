local valid_filetypes = {
    "javascript", "javascriptreact", "typescript", "typescriptreact"
}

local M = {}

local contains = function(list, candidate)
    for _, element in pairs(list) do
        if element == candidate then return true end
    end
    return false
end
M.contains = contains

M.move_file = function(path1, path2)
    local ok = vim.loop.fs_rename(path1, path2)
    if not ok then
        return false, "failed to move " .. path1 .. " to " .. path2
    end

    return true
end

M.file_exists = function(path)
    local file = vim.loop.fs_open(path, "r", 438)
    if not file then return false end

    return true
end

local filetype_is_valid = function(filetype)
    return contains(valid_filetypes, filetype)
end

M.check_filetype = function()
    local filetype = vim.bo.filetype
    if not filetype_is_valid(filetype) then error("invalid filetype") end
end

M.echo_warning = function(message)
    vim.api.nvim_echo(
        {{"nvim-lsp-ts-utils: " .. message, "WarningMsg"}, {"\n"}}, true, {})
end

M.get_bufname = function(bufnr)
    if bufnr == nil then bufnr = 0 end
    return vim.api.nvim_buf_get_name(bufnr)
end

M.buffer_to_string = function(bufnr)
    if bufnr == nil then bufnr = 0 end
    local content = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    return table.concat(content, "\n")
end

M.print_no_actions_message = function() print("No code actions available") end

return M
