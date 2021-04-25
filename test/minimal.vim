set hidden
set noswapfile

lua << EOF
require'lspconfig'.tsserver.setup {
    on_attach = function(client)
        local ts_utils = require("nvim-lsp-ts-utils")
        ts_utils.setup {
            no_save_after_format = true
        }
        ts_utils.setup_client(client)
    end
}
EOF
