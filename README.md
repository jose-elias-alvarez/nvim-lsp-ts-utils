# nvim-lsp-ts-utils

Utilities to improve the TypeScript development experience for Neovim's
built-in LSP client.

## Motivation

VS Code and [coc-tsserver](https://github.com/neoclide/coc-tsserver) are great
for TypeScript, so great that other LSP implementations don't give TypeScript a
lot of love. This is an attempt to rectify that, bit by bit.

This plugin is **in beta status**. It has basic (and expanding) test coverage,
and I use almost 100% of what's in it every day at work, but since we're dealing
with changing APIs and unpredictable environments, bugs are inevitable. If
something doesn't work, please let me know!

Breaking changes are also a possibility until features are completely stable, so
please keep an eye on your plugin manager's change log when you update and look
for a `!`, which indicates that you may have to update your config.

## Requirements

The plugin requires some utilities from
[nvim-lspconfig](https://github.com/neovim/nvim-lspconfig), which you are
(probably) already using to configure `typescript-language-server`.

Having [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) installed will
make some things faster, but at the moment it's not strictly required.

## Features

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

  If you have [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
  installed, the function will run asynchronously, which provides a big
  performance and reliability boost. If not, it'll run slower and may time out.

- Import on completion

  Adds missing imports on completion confirm (`<C-y>`) when using the built-in
  LSP `omnifunc` (which is itself enabled by setting
  `vim.bo.omnifunc = "v:lua.vim.lsp.omnifunc"` somewhere in your LSP config).

  Enable by setting `enable_import_on_completion` to `true` inside `setup` (see
  below).

  Binding `.` in insert mode to `.<C-x><C-o>` can trigger imports twice. The
  plugin sets a timeout to avoid importing the same item twice in a short span
  of time, which you can change by setting `import_on_completion_timeout` in
  your setup function (`0` disables this behavior).

- Fix invalid ranges

  `tsserver` uses non-compliant ranges in some code actions (most notably "Move
  to a new file"), which makes them [not work properly in
  Neovim](https://github.com/neovim/neovim/issues/14469). The plugin fixes these
  ranges so that the affected actions work as expected.

  This feature is enabled by calling `setup_client` in your configuration (see
  below).

- ESLint code actions

  Parses ESLint JSON output for the current file, converts fixes into code
  actions, and adds actions to disable rules for the current line or file.
  Works with Neovim's built-in code action handler as well as plugins like
  [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) and
  [lspsaga.nvim](https://github.com/glepnir/lspsaga.nvim).

  Supports the following settings:

  - `eslint_enable_code_actions`: enables ESLint code actions. Set to `true` by default.

  - `eslint_bin`: sets the binary used to get ESLint output. Looks for a local
    executable in `node_modules` and falls back to a system-wide executable,
    which must be available on your `$PATH`.

    Uses `eslint` by
    default for compatibility, but I highly, highly recommend using
    [eslint_d](https://github.com/mantoni/eslint_d.js). `eslint` will add a
    noticeable delay to each code action.

  - `eslint_args`: defines the arguments passed to `eslint_bin`. Messing with this
    will probably break the integration!

  - `eslint_enable_disable_comments`: enables ESLint code actions to disable the
    violated rule for the current line / file. Set to `true` by default.

## Experimental Features

**The following features are experimental! Bug reports and feedback are greatly appreciated.**

- ESLint diagnostics

  A lightweight and low-config alternative to
  [diagnostic-languageserver](https://github.com/iamcco/diagnostic-languageserver)
  or [efm-langserver](https://github.com/mattn/efm-langserver).

  Supports the following settings:

  - `eslint_enable_diagnostics`: enables ESLint diagnostics for the current
    buffer on `tsserver` attach. Set to `false` by default.

  - `eslint_diagnostics_debounce`: to simulate LSP behavior, the plugin
    subscribes to buffer changes and refreshes ESLint diagnostics on change.
    This variable modifies the amount of time between the last change and the
    next refresh. Set to `250` (ms) by default.

  - `eslint_bin` and `eslint_args`: applies the same settings as ESLint code
    actions.

- Formatting

  Another simple, out-of-the-box alternative to setting up a full diagnostic
  language server. Uses native Neovim APIs to format files asynchronously.

  Currently supports [Prettier](https://github.com/prettier/prettier)
  out-of-the-box and [prettier_d_slim](https://github.com/mikew/prettier_d_slim)
  and [eslint_d](https://github.com/mantoni/eslint_d.js/) with additional
  configuration. Formatting via vanilla `eslint` is not supported.

  If enabled, the plugin will define a command to format the file, exposed as
  `:TSLspFormat`.

  Supports the following settings:

  - `enable_formatting`: enables formatting. Set to `false` by default, since I
    imagine most TypeScript developers are already using another solution.

  - `formatter`: sets the executable used for formatting. Set to `prettier` by
    default. Like `eslint_bin`, the plugin will look for a local
    executable in `node_modules` and fall back to a system-wide executable,
    which must be available on your `$PATH`.

    See [this wiki
    page](https://github.com/jose-elias-alvarez/nvim-lsp-ts-utils/wiki/Setting-up-other-formatters)
    for instructions on setting up other formatters.

  - `formatter_args`: defines the arguments passed to `formatter`. You
    don't need to change this unless you plan on using something besides
    `prettier`.

  - `format_on_save`: a quick way to enable formatting on save for `tsserver`
    filetypes. Set to `false` by default.

  - `no_save_after_format`: by default, the plugin will save the file after
    formatting, which works well with `format_on_save`. Set this to `true` to
    disable this behavior.

  The plugin also exposes the formatter for non-LSP use. For example, to enable
  formatting on save for a non-`tsserver` filetype, use the following snippet:

  ```vim
  " add to ftplugin/filetype-goes-here.vim
  augroup FormatOnSave
      autocmd! * <buffer>
      autocmd BufWritePost <buffer> lua require'nvim-lsp-ts-utils'.format()
  augroup END
  ```

  Note that the implementation will disable other LSP formatters. If you want to
  fix the file with both ESLint and Prettier at the same time, see the
  [wiki](https://github.com/jose-elias-alvarez/nvim-lsp-ts-utils/wiki/Setting-up-other-formatters)
  for instructions on setting up `eslint_d`, which supports running both at
  once.

- Update imports on file move

  Watches a given directory for file move / rename events (even from outside of
  Neovim!) and updates imports accordingly.

  Supports the following settings:

  - `update_imports_on_move`: enables this feature. Set to `false` by default.

  - `require_confirmation_on_move`: if `true`, prompts for confirmation before
    updating imports. Set to `false` by default.

  - `watch_dir`: sets the directory that the plugin will watch for changes,
    relative to your root path (where `tsconfig.json` or `package.json` is
    located). Set to `/src` by default.

- Parentheses completion

  Automatically inserts `()` after confirming completion on a function, method,
  or constructor. Intended for use with `vim.lsp.omnifunc`.

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
        local ts_utils = require("nvim-lsp-ts-utils")

        -- defaults
        ts_utils.setup {
            debug = false,
            disable_commands = false,
            enable_import_on_completion = false,
            import_on_completion_timeout = 5000,

            -- eslint
            eslint_enable_code_actions = true,
            eslint_bin = "eslint",
            eslint_args = {"-f", "json", "--stdin", "--stdin-filename", "$FILENAME"},
            eslint_enable_disable_comments = true,

	    -- experimental settings!
            -- eslint diagnostics
            eslint_enable_diagnostics = false,
            eslint_diagnostics_debounce = 250,

            -- formatting
            enable_formatting = false,
            formatter = "prettier",
            formatter_args = {"--stdin-filepath", "$FILENAME"},
            format_on_save = false,
            no_save_after_format = false,

            -- parentheses completion
            complete_parens = false,
            signature_help_in_parens = false,

	    -- update imports on file move
	    update_imports_on_move = false,
	    require_confirmation_on_move = false,
	    watch_dir = "/src",
        }

        -- required to enable ESLint code actions and formatting
        ts_utils.setup_client(client)

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
- Fix current issue: `:lua require'nvim-lsp-ts-utils'.fix_current()`
- Rename file: `:lua require'nvim-lsp-ts-utils'.rename_file()`
- Import all: `:lua require'nvim-lsp-ts-utils'.import_all()`

Once enabled, you can run formatting either by calling
`vim.lsp.buf.formatting()` or pass the request through the plugin by calling
`:lua require 'nvim-lsp-ts-utils'.format()`.

## Troubleshooting

First, please check your config and make sure it's in line with the latest
readme.

Second, please update to the latest Neovim master, as that's what the plugin is
built and tested on.

Third, if your issue is related to linting or formatting, please try setting
`debug = true` in `setup` and inspecting the output in `:messages` to make sure
it matches what you expect.

If those options don't help, please open up an issue and provide as much
information as possible about your error, including debug output when relevant.
Thank you for helping the plugin grow and improve!

## Tests

I've covered most of the current functions with LSP integration tests using
[plenary.nvim](https://github.com/nvim-lua/plenary.nvim), which you can run by
running `make test`. The test suite has the same requirements as the plugin, and
testing ESLint code actions and formatting requires `eslint` and `prettier` to
be on your `$PATH`.

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
