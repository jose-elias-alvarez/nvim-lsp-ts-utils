local valid_filetypes = {
    "javascript", "javascriptreact", "typescript", "typescriptreact"
}

local M = {}

local list_contains = function(list, x)
    for _, v in pairs(list) do if v == x then return true end end
    return false
end
M.list_contains = list_contains

M.move_file = function(path1, path2)
    local ok = vim.loop.fs_rename(path1, path2)

    if not ok then
        return false, "failed to move " .. path1 .. " to " .. path2
    else
        return true
    end
end

M.file_exists = function(path)
    local file = io.open(path)

    if not file then
        return false
    else
        return true
    end
end

M.filetype_is_valid = function(filetype)
    return list_contains(valid_filetypes, filetype)
end

return M
