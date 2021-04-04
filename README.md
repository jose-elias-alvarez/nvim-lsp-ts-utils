# nvim-lsp-ts-utils

Utilities to improve the TypeScript development experience for Neovim's
built-in LSP client.

## Motivation

VS Code and [coc-tsserver](https://github.com/neoclide/coc-tsserver) are great
for TypeScript, so great that other LSP implementations don't give TypeScript a
lot of love. This is an attempt to rectify that, if only slightly.

These are simple Lua functions that you could write yourself and include
directly in your config. I put them together to save time digging through source
code and centralize information that would otherwise remain buried in Reddit
threads and random dotfile repos.

## Features

- Organize imports (exposed as `:TSLspOrganize`)

  I've seen different implementations floating around, but the version included
  here calls the specific command from `typescript-language-server`, which is
  faster and more reliable (and doesn't mess with the rest of the document).

  Async by default, but a sync variant is available and exposed as
  `:TSLspOrganizeSync` (useful for running on save).

- Fix current (exposed as `:TSLspFixCurrent`)

  A simple way to apply the first available code action to the current line
  without confirmation. Faster than calling `vim.lsp.buf.code_action()` when
  you already know what you want to do.

- Rename file and update imports (exposed as `:TSLspRenameFile`)

  One of my most missed features from VS Code / coc.nvim. Enter a new path
  (based on the current file's path) and watch the magic happen.

- Import all missing imports (exposed as `:TSLspImportAll`)

  This one's dirty. As far as I can tell, there's no way to reliably filter code
  actions, so the function matches against the action's title to determine
  whether it's an import action, then runs `:TSLspOrganize` afterwards to merge
  imports from the same source. I hope to improve the code, but for now, it
  works.

## Setup

Install using your favorite plugin manager and add to your
[nvim-lspconfig](https://github.com/neovim/nvim-lspconfig) `tsserver.setup` function.

A minimal example:

```lua
local nvim_lsp = require("lspconfig")

nvim_lsp.tsserver.setup {
    on_attach = function(client, bufnr)
        require("nvim-lsp-ts-utils").setup {}

        -- no default maps, so you may want to define some here
        vim.api.nvim_buf_set_keymap(bufnr, "n", "gs", ":TSLspOrganize<CR>", {silent = true})
        vim.api.nvim_buf_set_keymap(bufnr, "n", "qq", ":TSLspFixCurrent<CR>", {silent = true})
        vim.api.nvim_buf_set_keymap(bufnr, "n", "gr", ":TSLspRenameFile<CR>", {silent = true})
        vim.api.nvim_buf_set_keymap(bufnr, "n", "gi", ":TSLspImportAll<CR>", {silent = true})
    end
}
```

By default, the plugin will define Vim commands for convenience. You can
disable this by passing `disable_commands = true` into `setup` and then calling
the Lua functions directly:

- Organize imports: `:lua require'nvim-lsp-ts-utils'.organize_imports()`
- Fix current: `:lua require'nvim-lsp-ts-utils'.fix_current()`
- Rename file: `:lua require'nvim-lsp-ts-utils'.rename_file()`
- Import all: `:lua require'nvim-lsp-ts-utils'.import_all()`

Or you can add whichever functions you're interested in directly to your config.

## Limitations

coc-tsserver can replicate most VS Code features because it interfaces directly
with `tsserver`. We don't have the same luxury with
`typescript-language-server`, so implementing features depends on upstream
adoption (an area I hope to work on, too).

I'm also looking into how Treesitter can help cover some of the gaps.

## Tests

I've covered the current functions with LSP integration tests using
[plenary.nvim](https://github.com/nvim-lua/plenary.nvim). Run them with
`./test.sh`. Requires a working Neovim TypeScript LSP setup, naturally.

## Goals

- [ ] Add TypeScript / .tsx text objects.

  I'd like to include Treesitter-based text objects, like
  [nvim-treesitter-textobjects](https://github.com/nvim-treesitter/nvim-treesitter-textobjects),
  and am looking into the topic.

- [ ] Watch project files and update imports on change.

  Theoretically possible with something like
  [Watchman](https://facebook.github.io/watchman/), but way beyond my current
  Lua abilities.
