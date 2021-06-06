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
  integrations and formatting (experimental)

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

## Experimental Features

The following features are **experimental**, meaning they are subject to change
and are not guaranteed to work out-of-the-box. These features need more testing
in real-world environments before I can consider them stable. Until then, users
of these features should prepare themselves for **bugs, unexpected behavior, and
breaking changes.**

If your goal is to get a stable, functional setup with minimal effort, see [this
article](https://jose-elias-alvarez.medium.com/configuring-neovims-lsp-client-for-typescript-development-5789d58ea9c)
for instructions on setting up ESLint diagnostics and formatting via
[diagnostic-languageserver](https://github.com/iamcco/diagnostic-languageserver).

Bug reports and feedback are, as always, greatly appreciated.

### null-ls Integrations

The plugin integrates with
[null-ls.nvim](https://github.com/jose-elias-alvarez/null-ls.nvim) to provide
ESLint code actions, diagnostics, and formatting. To enable null-ls itself, you
must install it via your plugin manager and add the following snippet to your
LSP configuration:

```lua
-- location doesn't matter, but place it in on_attach if you're unsure
require("null-ls").setup {}
```

- ESLint code actions

  Adds actions to fix ESLint issues or disable the violated rule for the current
  line / file.

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
  [prettierd](https://github.com/fsouza/prettierd),
  [prettier_d_slim](https://github.com/mikew/prettier_d_slim) and
  [eslint_d](https://github.com/mantoni/eslint_d.js/) as formatters. Formatting
  via vanilla `eslint` is not supported.

  Supports the following settings:

  - `enable_formatting`: enables formatting. Set to `false` by default.

  - `formatter`: sets the executable used for formatting. Set to `prettier` by
    default. Must be one of `prettier`, `prettierd`, `prettier_d_slim`, or
    `eslint_d`.

    Like `eslint_bin`, the plugin will look for a local
    executable in `node_modules` and fall back to a system-wide executable,
    which must be available on your `$PATH`.

  - `formatter_config_fallback`: sets a path to a fallback formatter config file
    that the plugin will use if it can't find a config file in the root
    directory. Set to `nil` by default.

    Note that if you've set `formatter` to `eslint_d`, the plugin will use
    `eslint_config_fallback` instead.

  Note that once you've enabled formatting, it'll run whenever you call the
  following command:

  ```vim
  :lua vim.lsp.buf.formatting()
  ```

  To avoid conflicts with existing LSP configurations, the plugin **will not**
  set up any formatting-related commands or autocommands. If you don't already
  have an LSP formatting setup, I recommend adding the following snippet to your
  `tsserver` `on_attach` callback:

  ```lua
  on_attach = function(client)
    -- disable tsserver formatting
    client.resolved_capabilities.document_formatting = false

    -- define an alias
    vim.cmd("command -buffer Formatting lua vim.lsp.buf.formatting()")

    -- format on save
    vim.cmd("autocmd BufWritePost <buffer> lua vim.lsp.buf.formatting()")
  end
  ```

### Other Experimental Features

- Update imports on file move

  Watches the root directory for file move / rename events and updates imports
  accordingly. The plugin will attempt to find a `.gitignore` file in the root
  directory and watch all non-ignored directories.

  Supports the following settings:

  - `update_imports_on_move`: enables this feature. Set to `false` by default.

  - `require_confirmation_on_move`: if `true`, prompts for confirmation before
    updating imports. Set to `false` by default.

  - `watch_dir`: sets a fallback directory that the plugin will watch for
    changes if it can't find a `.gitignore` in the root directory. Path is
    relative to the current root directory. Set to `nil` by default.

  Note that if the root directory is not recognized as a Git project and
  `watch_dir` is `nil` or fails to resolve, the plugin will not enable file
  watching.

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

-- enable null-ls integration (optional)
require("null-ls").setup {}

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
            eslint_config_fallback = nil,

            -- eslint diagnostics
            eslint_enable_diagnostics = false,
            eslint_diagnostics_debounce = 250,

            -- formatting
            enable_formatting = false,
            formatter = "prettier",
            formatter_config_fallback = nil,

            -- parentheses completion
            complete_parens = false,
            signature_help_in_parens = false,

            -- update imports on file move
            update_imports_on_move = false,
            require_confirmation_on_move = false,
            watch_dir = nil,
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
version of this document. If you don't see a setting in the list of defaults
above, that setting is no longer available.

Second, please try updating to the latest Neovim master and make sure you are
running the latest version of this plugin and its dependencies.

Third, please try setting `debug = true` in `setup` and inspecting the output in
`:messages` to make sure it matches what you expect. null-ls has an identical
debug option that you can use to help debug issues related to null-ls features.

If your issue relates to `eslint_d`, please try exiting Neovim, running
`eslint_d stop` from your command line, then restarting Neovim. `eslint_d` can
get "stuck" on a particular configuration when switching between projects, so
this step can resolve a lot of issues.

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
