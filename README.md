# nvim-lsp-ts-utils

Utilities to improve the TypeScript development experience for Neovim's
built-in LSP client.

## Motivation

VS Code and [coc-tsserver](https://github.com/neoclide/coc-tsserver) are great
for TypeScript, so great that other LSP implementations don't give TypeScript a
lot of love. This is an attempt to rectify that, bit by bit.

This plugin is **in beta status**. Its main features are stable and tested, but
since we're dealing with unpredictable environments, bugs are always a
possibility. If something doesn't work, please let me know!

## Requirements

- [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig), which you are
  (probably) already using to configure `typescript-language-server`.

- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)

- [null-ls](https://github.com/jose-elias-alvarez/null-ls.nvim) for ESLint
  integration and formatting

## Built-in Features

- Organize imports (exposed as `:TSLspOrganize`)

  Async by default, but a sync variant is available and exposed as
  `:TSLspOrganizeSync` (useful for running on save).

- Fix current problem (exposed as `:TSLspFixCurrent`)

  A simple way to apply the first available code action to the current line
  without confirmation.

- Rename file and update imports (exposed as `:TSLspRenameFile`)

  One of my most missed features from VS Code / coc.nvim. Enter a new path
  (based on the current file's path) and watch the magic happen.

- Import all missing imports (exposed as `:TSLspImportAll`)

  Gets all code actions, then matches against the action's title to
  (imperfectly) determine whether it's an import action. Also organizes imports
  afterwards to merge imports from the same source.

- Import on completion

  Adds missing imports on completion confirm (`<C-y>`) when using the built-in
  LSP `omnifunc` (which is itself enabled by setting
  `vim.bo.omnifunc = "v:lua.vim.lsp.omnifunc"` somewhere in your LSP config).

  Enable by setting `enable_import_on_completion` to `true` inside `setup` (see
  below).

- Fix invalid ranges

  `tsserver` uses non-compliant ranges in some code actions (most notably "Move
  to a new file"), which makes them [not work properly in
  Neovim](https://github.com/neovim/neovim/issues/14469). The plugin fixes these
  ranges so that the affected actions work as expected.

  You can enable this feature by calling `setup_client` in your configuration (see
  below).

## null-ls Integrations

- ESLint code actions

  Adds actions to fix ESLint issues or disable the violated rule for the current line / file.

  Supports the following settings:

  - `eslint_enable_code_actions`: enables ESLint code actions. Set to `true` by default.

  - `eslint_enable_disable_comments`: enables ESLint code actions to disable the
    violated rule for the current line / file. Set to `true` by default.

  - `eslint_bin`: sets the binary used to get ESLint output. Looks for a local
    executable in `node_modules` and falls back to a system-wide executable,
    which must be available on your `$PATH`.

    Uses `eslint` by default for compatibility, but I highly, highly recommend
    using [eslint_d](https://github.com/mantoni/eslint_d.js). `eslint` will add
    a noticeable delay to each code action.

  - `eslint_config_fallback`: sets a path to a fallback ESLint config file that
    the plugin will use if it can't find a config file in the root directory.
    Set to `nil` by default.

- ESLint diagnostics

  Shows ESLint diagnostics for the current buffer as LSP diagnostics.

  Supports the following settings:

  - `eslint_enable_diagnostics`: enables ESLint diagnostics for the current
    buffer on `tsserver` attach. Set to `false` by default.

  - `eslint_bin` and `eslint_config_fallback`: applies the same settings as
    ESLint code actions. Like code actions, using `eslint_d` will improve your
    experience.

- Formatting

  Provides asynchronous formatting via null-ls.

  The plugin supports [Prettier](https://github.com/prettier/prettier),
  [prettier_d_slim](https://github.com/mikew/prettier_d_slim) and
  [eslint_d](https://github.com/mantoni/eslint_d.js/) as formatters. Formatting
  via vanilla `eslint` is not supported.

  Supports the following settings:

  - `enable_formatting`: enables formatting. Set to `false` by default.

  - `formatter`: sets the executable used for formatting. Set to `prettier` by
    default. Must be one of `prettier`, `prettier_d_slim`, or `eslint_d`.

  - `formatter_config_fallback`: sets a path to a fallback formatter config file
    that the plugin will use if it can't find a config file in the root
    directory. Set to `nil` by default.

    Like `eslint_bin`, the plugin will look for a local
    executable in `node_modules` and fall back to a system-wide executable,
    which must be available on your `$PATH`.

- Update imports on file move

  Watches a given directory for file move / rename events and updates imports accordingly.

  Supports the following settings:

  - `update_imports_on_move`: enables this feature. Set to `false` by default.

  - `require_confirmation_on_move`: if `true`, prompts for confirmation before
    updating imports. Set to `false` by default.

  - `watch_dir`: sets the directory that the plugin will watch for changes,
    relative to your root path (the folder that contains `tsconfig.json` or
    `package.json`) Set to `/src` by default.

- Parentheses completion

  Automatically inserts `()` after confirming completion on a function, method,
  or constructor, for use with `vim.lsp.omnifunc`.

  Supports the following settings:

  - `complete_parens`: enables or disables this feature. Set to `false` by
    default.

  - `signature_help_in_parens`: automatically triggers
    `vim.lsp.buf.signature_help` after inserting `()`. Set to `false` by
    default.

## Setup

Install using your favorite plugin manager and add to your
[nvim-lspconfig](https://github.com/neovim/nvim-lspconfig) `tsserver.setup` function.

An example showing the available settings and their defaults:

```lua
local nvim_lsp = require("lspconfig")

nvim_lsp.tsserver.setup {
    on_attach = function(client, bufnr)
        -- disable tsserver formatting if you plan on formatting via null-ls
        client.resolved_capabilities.document_formatting = false

        local ts_utils = require("nvim-lsp-ts-utils")

        -- defaults
        ts_utils.setup {
            debug = false,
            disable_commands = false,
            enable_import_on_completion = false,

            -- eslint
            eslint_enable_code_actions = true,
            eslint_enable_disable_comments = true,
            eslint_bin = "eslint",

            -- eslint diagnostics
            eslint_enable_diagnostics = false,
            eslint_diagnostics_debounce = 250,

            -- formatting
            enable_formatting = false,
            formatter = "prettier",

            -- parentheses completion
            complete_parens = false,
            signature_help_in_parens = false,

            -- update imports on file move
            update_imports_on_move = false,
            require_confirmation_on_move = false,
            watch_dir = "/src",
        }

        -- required to fix code action ranges
        ts_utils.setup_client(client)

        -- no default maps, so you may want to define some here
        vim.api.nvim_buf_set_keymap(bufnr, "n", "gs", ":TSLspOrganize<CR>", {silent = true})
        vim.api.nvim_buf_set_keymap(bufnr, "n", "qq", ":TSLspFixCurrent<CR>", {silent = true})
        vim.api.nvim_buf_set_keymap(bufnr, "n", "gr", ":TSLspRenameFile<CR>", {silent = true})
        vim.api.nvim_buf_set_keymap(bufnr, "n", "gi", ":TSLspImportAll<CR>", {silent = true})
    end
}
```

## Troubleshooting

First, please check your config and make sure it's in line with the latest
readme.

Second, please try updating to the latest Neovim master.

Third, please try setting `debug = true` in `setup` and inspecting the output in
`:messages` to make sure it matches what you expect.

If those options don't help, please open up an issue and provide as much
information as possible about your error, including debug output when relevant.
Thank you for helping the plugin grow and improve!

## Tests

Run `make test` in the root of the project to run the test suite. The suite has the
same requirements as the plugin, and running the full suite requires having
null-ls installed and having `eslint` and `prettier` on your `$PATH`.

## Goals

- [ ] ESLint code action feature parity with [vscode-eslint](https://github.com/microsoft/vscode-eslint)

  The VS Code plugin supports 3 more code actions: `applySameFixes`,
  `applyAllFixes`, and `openRuleDoc`. Implementing them shouldn't be too hard
  (though `openRuleDoc` should be opt-in, since it requires ESLint to use the
  heavier `json-with-metadata` format).

- [ ] TSLint / stylelint code action support?

  I'm not familiar with these at all, but since they both support CLI JSON
  output, the plugin should be able to handle them in the same way it handles
  ESLint. I'm a little concerned about speed and handling output from more than
  one linter, so I'd appreciate input from users of these linters.
