set rtp+=.
set rtp+=../plenary.nvim/

lua require'lspconfig'.tsserver.setup {}

runtime! plugin/plenary.vim
