-- copy of default vim.lsp.handlers["textDocument/codeAction"]
local code_action_handler = function(actions)
    if actions == nil or vim.tbl_isempty(actions) then
        print("No code actions available")
        return
    end

    local option_strings = {"Code Actions:"}
    for i, action in ipairs(actions) do
        local title = action.title:gsub("\r\n", "\\r\\n")
        title = title:gsub("\n", "\\n")
        table.insert(option_strings, string.format("%d. %s", i, title))
    end

    local choice = vim.fn.inputlist(option_strings)
    if choice < 1 or choice > #actions then return end
    local action_chosen = actions[choice]
    if action_chosen.edit or type(action_chosen.command) == "table" then
        if action_chosen.edit then
            vim.lsp.util.apply_workspace_edit(action_chosen.edit)
        end
        if type(action_chosen.command) == "table" then
            vim.lsp.buf.execute_command(action_chosen.command)
        end
    else
        vim.lsp.buf.execute_command(action_chosen)
    end
end

return code_action_handler
