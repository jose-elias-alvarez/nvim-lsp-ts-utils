# nvim-lsp-ts-utils

Utilities to improve the TypeScript development experience for Neovim's
built-in LSP client.

## Motivation

VS Code and [coc-tsserver](https://github.com/neoclide/coc-tsserver) are great
for TypeScript, so great that other LSP implementations don't give TypeScript a
lot of love. This is an attempt to rectify that, bit by bit.

## Features

- Organize imports (exposed as `:TSLspOrganize`)

  Async by default, but a sync variant is available and exposed as
  `:TSLspOrganizeSync` (useful for running on save).

- Fix current (exposed as `:TSLspFixCurrent`)

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

- ESLint diagnostics

  A lightweight and low-config alternative to
  [diagnostic-languageserver](https://github.com/iamcco/diagnostic-languageserver)
  or [efm-langserver](https://github.com/mattn/efm-langserver).

  Supports the following settings:

  - `eslint_enable_diagnostics`: enables ESLint diagnostics for the current
    buffer on `tsserver` attach. Set to `false` by default.

  - `eslint_diagnostics_debounce`: to simulate LSP behavior, the plugin gets
    ESLint diagnostic on text change. This variable modifies the amount of time
    between diagnostic refreshes. Set to `1000` (ms) by default.

  - `eslint_binary`: sets the binary used to get ESLint output.

    Uses `eslint` by
    default for compatibility, but I highly, highly recommend using
    [eslint_d](https://github.com/mantoni/eslint_d.js), which will get
    diagnostics instantly, even when working on large files.

- ESLint code actions

  Parses ESLint JSON output for the current file, converts fixes into code
  actions, and adds actions to disable rules for the current line or file.
  Works with Neovim's built-in code action handler as well as plugins like
  [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) and
  [lspsaga.nvim](https://github.com/glepnir/lspsaga.nvim).

  Supports the following settings:

  - `eslint_binary`: uses the same executable as ESLint diagnostics.

    Note that `eslint` will add a noticeable delay
    to each code action, so I recommend using `eslint_d` if at all possible.

  - `eslint_enable_disable_comments`: enables ESLint code actions to disable the
    violated rule for the current line / file. Set to `true` by default.

- Formatting via [Prettier](https://github.com/prettier/prettier)

  Another simple, out-of-the-box alternative to setting up a full diagnostic
  language server.

  Supports the following settings:

  - `enable_formatting`: enables formatting. Set to `false` by default, since I
    imagine most TypeScript developers are already using another solution.

    Note that you must also override `vim.lsp.buf_request` for formatting to
    work (see below).

  - `formatter`: sets the executable used for formatting. Set to `prettier` by
    default, and (probably) doesn't work with anything else right now, but
    feedback / PRs are welcome.

  - `format_on_save`: a quick way to enable formatting on save for `tsserver`
    filetypes. Set to `false` by default.

  - `no_save_after_format`: by default, the plugin will save the file after
    formatting, which works well with `format_on_save`. Set this to `false` to
    disable this behavior.

  - `keep_final_newline`: set to `false` by default, to match what happens
    when you run `!prettier --write %`.

  The plugin also exposes the formatter for non-LSP use. For example, to enable
  formatting on save for a non-`tsserver` filetype, use the following snippet:

  ```vim
  " add to ftplugin/filetype-goes-here.vim
  lua require'nvim-lsp-ts-utils'.format_on_save()
  ```

  Note that the implementation will disable other LSP formatters. If you want to
  run more than one formatter at once, please use `diagnostic-languageserver` or
  `efm-langserver`.

## Setup

Install using your favorite plugin manager and add to your
[nvim-lspconfig](https://github.com/neovim/nvim-lspconfig) `tsserver.setup` function.

An example showing the available settings and their defaults:

```lua
local nvim_lsp = require("lspconfig")

nvim_lsp.tsserver.setup {
    on_attach = function(_, bufnr)
        local ts_utils = require("nvim-lsp-ts-utils")

        ts_utils.setup {
            -- defaults
	    disable_commands = false,
	    enable_import_on_completion = false,
	    import_on_completion_timeout = 5000,
	    -- eslint
	    eslint_bin = "eslint",
	    eslint_enable_diagnostics = false,
	    eslint_diagnostics_debounce = 1000,
	    eslint_enable_disable_comments = true,
	    -- formatting
	    enable_formatting = false,
	    formatter = "prettier",
	    format_on_save = false,
	    no_save_after_format = false,
	    keep_final_newline = false
        }

        -- no default maps, so you may want to define some here
        vim.api.nvim_buf_set_keymap(bufnr, "n", "gs", ":TSLspOrganize<CR>", {silent = true})
        vim.api.nvim_buf_set_keymap(bufnr, "n", "qq", ":TSLspFixCurrent<CR>", {silent = true})
        vim.api.nvim_buf_set_keymap(bufnr, "n", "gr", ":TSLspRenameFile<CR>", {silent = true})
        vim.api.nvim_buf_set_keymap(bufnr, "n", "gi", ":TSLspImportAll<CR>", {silent = true})
    end
}
```

You must also override Neovim's default `buf_request` method for ESLint actions
and formatting to work:

```lua
local ts_utils = require("nvim-lsp-ts-utils")
ts_utils.setup {
    -- your options go here
}

-- must come after setup!
vim.lsp.buf_request = ts_utils.buf_request
```

By default, the plugin will define Vim commands for convenience. You can
disable this by passing `disable_commands = true` into `setup` and then calling
the Lua functions directly:

- Organize imports: `:lua require'nvim-lsp-ts-utils'.organize_imports()`
- Fix current: `:lua require'nvim-lsp-ts-utils'.fix_current()`
- Rename file: `:lua require'nvim-lsp-ts-utils'.rename_file()`
- Import all: `:lua require'nvim-lsp-ts-utils'.import_all()`

## Tests

I've covered most of the current functions with LSP integration tests using
[plenary.nvim](https://github.com/nvim-lua/plenary.nvim), which you can run by
running `./test.sh`.

Note that the current test suite requires you to have Plenary and nvim-lspconfig
installed via [packer.nvim](https://github.com/wbthomason/packer.nvim) due to my
complete ignorance about `runtimepath` and `packpath`. Sorry!

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

- [ ] Support for other formatters

  I haven't tried [eslint_d_slim](https://github.com/mikew/prettier_d_slim), but
  it seems like a natural fit. I'm also open to supporting any other formatters
  if there's demand.

- [ ] Watch project files and update imports on change.

  I've prototyped this using plenary jobs and
  [Watchman](https://facebook.github.io/watchman/) and am waiting for Plenary to
  merge async await jobs to make working with Watchman less painful.
