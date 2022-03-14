local u = require("nvim-lsp-ts-utils.utils")

local lsp = vim.lsp

local method = "textDocument/codeAction"

local source_actions = {
    SourceAddMissingImportsTs = "source.addMissingImports.ts",
    SourceFixAllTs = "source.fixAll.ts",
    SourceRemoveUnusedTs = "source.removeUnused.ts",
    SourceOrganizeImportsTs = "source.organizeImports.ts",
}

local make_source_action_command = function(source_action)
    return function(bufnr)
        local client = u.get_tsserver_client()
        if not client then
            return
        end

        bufnr = bufnr or vim.api.nvim_get_current_buf()
        local context = {
            only = { source_action },
            diagnostics = vim.diagnostic.get(bufnr),
        }
        local params = lsp.util.make_range_params()
        params.context = context

        client.request(method, params, function(err, res)
            assert(not err, err)
            if
                res
                and res[1]
                and res[1].edit
                and res[1].edit.documentChanges
                and res[1].edit.documentChanges[1]
                and res[1].edit.documentChanges[1].edits
            then
                lsp.util.apply_text_edits(res[1].edit.documentChanges[1].edits, bufnr, client.offset_encoding)
            end
        end, bufnr)
    end
end

return {
    add_missing_imports = make_source_action_command(source_actions.SourceAddMissingImportsTs),
    fix_all = make_source_action_command(source_actions.SourceFixAllTs),
    remove_unused = make_source_action_command(source_actions.SourceRemoveUnusedTs),
    organize_imports = make_source_action_command(source_actions.SourceOrganizeImportsTs),
}
