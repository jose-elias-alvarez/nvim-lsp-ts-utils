local valid_filetypes = {
    "javascript", "javascriptreact", "typescript", "typescriptreact"
}

local M = {}

M.loop = vim.loop
M.schedule = vim.schedule_wrap
M.isempty = vim.tbl_isempty

local contains = function(list, x)
    for _, v in pairs(list) do if v == x then return true end end
    return false
end
M.contains = contains

M.move_file = function(path1, path2)
    local ok = vim.loop.fs_rename(path1, path2)

    if not ok then
        return false, "failed to move " .. path1 .. " to " .. path2
    else
        return true
    end
end

M.file_exists = function(path)
    local file = vim.loop.fs_open(path, "r", 438)

    if not file then
        return false
    else
        return true
    end
end

local filetype_is_valid = function(filetype)
    return contains(valid_filetypes, filetype)
end
M.check_filetype = function()
    local filetype = vim.bo.filetype
    if not filetype_is_valid(filetype) then error("invalid filetype") end
end

M.echo_warning = function(message)
    vim.cmd("echohl WarningMsg | echo '" .. message .. "' | echohl None")
end

M.get_bufname = function(bufnr)
    if bufnr == nil then bufnr = 0 end
    return vim.api.nvim_buf_get_name(bufnr)
end

return M
