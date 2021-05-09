set hidden
set noswapfile

set rtp=$VIMRUNTIME
set rtp+=../plenary.nvim
set rtp+=../nvim-lspconfig
runtime! plugin/plenary.vim

lua << EOF
require'lspconfig'.tsserver.setup {
    on_attach = function(client)
        local ts_utils = require("nvim-lsp-ts-utils")
        ts_utils.setup {
            no_save_after_format = true,
            watch_dir = ""
        }
        ts_utils.setup_client(client)
    end
}
EOF
