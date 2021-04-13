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

  Gets all code actions, then matches against the action's title to
  (imperfectly) determine whether it's an import action. Also runs
  `:TSLspOrganize` afterwards to merge imports from the same source.

  If you have [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
  installed, the function will run asynchronously, which provides a big
  performance and reliability boost. If not, it'll run slower and may time out.

- Import on completion

  Adds missing imports on completion confirm (`<C-y>`) when using the built-in
  LSP `omnifunc` (which is itself enabled by setting `vim.bo.omnifunc = "v:lua.vim.lsp.omnifunc"` somewhere in your LSP config). Enable by setting
  `enable_import_on_completion` to `true` inside `setup` (see below).

  Omnifunc users may want to bind `.` in insert mode to `.<C-x><C-o>`, but this
  can trigger imports twice. The plugin sets a timeout to avoid importing the
  same item twice in a short span of time, which you can change by setting
  `import_on_completion_timeout` in your setup function (`0` disables this
  behavior).

  Runs asynchronously and reliably. Probably behaves strangely with completion plugins that aren't
  [MUcomplete](https://github.com/lifepillar/vim-mucomplete), but let me know!

## Setup

Install using your favorite plugin manager and add to your
[nvim-lspconfig](https://github.com/neovim/nvim-lspconfig) `tsserver.setup` function.

A minimal example:

```lua
local nvim_lsp = require("lspconfig")

nvim_lsp.tsserver.setup {
    on_attach = function(client, bufnr)
        require("nvim-lsp-ts-utils").setup {
            -- defaults
            disable_commands = false,
            enable_import_on_completion = false,
	    import_on_completion_timeout = 5000
        }

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

I've covered most of the current functions with LSP integration tests using
[plenary.nvim](https://github.com/nvim-lua/plenary.nvim). Run them with
`./test.sh`. Requires a working Neovim TypeScript LSP setup, naturally.

## Goals

- [ ] Add TypeScript / .tsx text objects.

  I'd like to include Treesitter-based text objects, like
  [nvim-treesitter-textobjects](https://github.com/nvim-treesitter/nvim-treesitter-textobjects),
  and am looking into the topic.

- [ ] Watch project files and update imports on change.

  I've prototyped this using plenary jobs and
  [Watchman](https://facebook.github.io/watchman/). I'm waiting for
  @oberblastmeister's [async await jobs PR](https://github.com/nvim-lua/plenary.nvim/pull/101) to
  get merged, which should make working with Watchman a lot easier.
