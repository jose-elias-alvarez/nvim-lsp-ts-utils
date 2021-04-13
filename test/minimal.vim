set rtp+=.
set rtp+=../plenary.nvim/
set hidden
set noswapfile

lua require'lspconfig'.tsserver.setup {}

runtime! plugin/plenary.vim
