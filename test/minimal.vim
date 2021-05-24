set hidden
set noswapfile

set rtp=$VIMRUNTIME
set rtp+=../plenary.nvim
set rtp+=../nvim-lspconfig
set rtp+=../null-ls
runtime! plugin/plenary.vim

lua << EOF
require("null-ls").setup {}
require'lspconfig'.tsserver.setup {
    on_attach = function(client)
        client.resolved_capabilities.document_formatting = false

        local ts_utils = require("nvim-lsp-ts-utils")
        ts_utils.setup {
            no_save_after_format = true,
            watch_dir = "",
            eslint_enable_code_actions = true,
            eslint_enable_diagnostics = true,
            enable_formatting = true
        }
        ts_utils.setup_client(client)
    end
}
EOF
