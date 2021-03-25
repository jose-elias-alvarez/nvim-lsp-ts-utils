set rtp+=.
set rtp+=../plenary.nvim/
set hidden

lua require'lspconfig'.tsserver.setup {}

runtime! plugin/plenary.vim
