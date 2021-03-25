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

- Organize imports (exposed as `:LspOrganize`)

  I've seen different implementations floating around, but the version included
  here calls the specific command from `typescript-language-server`, which is
  faster and more reliable (and doesn't mess with the rest of the document).

- Fix current (exposed as `:LspFixCurrent`)

  A simple way to apply the first available code action to the current line
  without confirmation. Faster than calling `vim.lsp.buf.code_action()` when
  you already know what you want to do.

- Rename file and update imports (exposed as `:LspRenameFile`)

  One of my most missed features from VS Code / coc.nvim. Enter a new path
  (based on the current file's path) and watch the magic happen.

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
        vim.api.nvim_buf_set_keymap(bufnr, "n", "gs", ":LspOrganize<CR>", {silent = true})
        vim.api.nvim_buf_set_keymap(bufnr, "n", "qq", ":LspFixCurrent<CR>", {silent = true})
        vim.api.nvim_buf_set_keymap(bufnr, "n", "gr", ":LspRenameFile<CR>", {silent = true})
    end
}
```

By default, the plugin will define Vim commands for convenience. You can
disable this by passing `disable_commands = true` into `setup` and then calling
the Lua functions directly:

- Organize imports: `:lua require'nvim-lsp-ts-utils'.organize_imports()`
- Fix current: `:lua require'nvim-lsp-ts-utils'.fix_current()`
- Rename file: `:lua require'nvim-lsp-ts-utils'.rename_file()`

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

Theoretically possible
with something like [Watchman](https://facebook.github.io/watchman/), but
way beyond my current Lua abilities.

- [ ] Add an "add all missing imports" function, like VS Code's
      `source.addMissingImports`.

Trickier than expected, and unless it's possible to reliably get _only_ relevant
code actions, probably not worth it.

- [ ] ~~Make sure everything works on Linux (it should)~~ and on Windows (it
      shouldn't).

I have no idea what `os.execute` will do on Windows, but `LspRenameFile` uses
`mv`, which (as far as I know) won't work.
