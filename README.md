# nvim-lsp-ts-utils

Utilities to improve the TypeScript development experience for Neovim's
built-in LSP client.

## Requirements

- [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig), which you are
  (probably) already using to configure `typescript-language-server`

- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)

- [null-ls](https://github.com/jose-elias-alvarez/null-ls.nvim) for ESLint
  integrations and formatting (optional)

## Features

- Organize imports (exposed as `:TSLspOrganize`)

  Async by default. A sync variant is available and exposed as
  `:TSLspOrganizeSync` (useful for running on save).

- Rename file and update imports (exposed as `:TSLspRenameFile`)

  Enter a new path (based on the current file's path) and watch the magic
  happen.

- Import all missing imports (exposed as `:TSLspImportAll`)

  Gets all code actions, then matches against the action's title to determine
  whether it's an import action. Also organizes imports afterwards to merge
  imports from the same source.

  By default, the command will resolve conflicting imports by checking other
  imports in the same file and other open buffers. In Git repositories, it will
  check project files to improve accuracy. You can alter the weight given to
  each factor by modifying `import_all_priorities` (see below). This feature
  has a minimal performance impact, but you can disable it entirely by setting
  `import_all_priorities` to `nil`.

  `:TSLspImportAll` will also scan the content of other open buffers to resolve
  import priority, limited by `import_all_scan_buffers`. This has a positive
  impact on import accuracy but may affect performance when run with a large
  number (100+) of loaded buffers.

  Instead of priority, you could also set `import_all_select_source` to `true`,
  which will prompt you to choose from the available options when there's a
  conflict.

- Import on completion

  Adds missing imports on completion confirm (`<C-y>`) when using the built-in
  LSP `omnifunc`. Enable by setting `enable_import_on_completion` to `true`
  inside `setup` (see below).

- Fix invalid ranges

  `tsserver` uses non-compliant ranges in some code actions (most notably "Move
  to a new file"), which makes them [not work properly in
  Neovim](https://github.com/neovim/neovim/issues/14469). The plugin fixes these
  ranges so that the affected actions work as expected.

  You can enable this feature by calling `setup_client` in your configuration (see
  below).

- Inlay hints (exposed as `:TSLspInlayHints`/`:TSLspDisableInlayHints`/`:TSLspToggleInlayHints`)

  `tsserver` has added experimental support for inlay hints from Typescript v4.4.2
  Note that init_options need to be set for this feature to work. Please see [Setup](#setup)

  Supports the following settings:

  - `auto_inlay_hints` (boolean): Set inlay hints on every new buffer visited
    automatically. Note that it would stop doing so if `:TSDisableInlayHints` is
    called, and will continue if `:TSLspInlayHints` is called. If false, `:TSInlayHints`
    needs to be called for every buffer to see it's inlay hints.
    Defaults to True.

  - `inlay_hints_highlight ` (string): Highlight group to be used for the inlay
    hints. 
    Defaults to "Comment".

- Filter `tsserver` diagnostics

  Some `tsserver` diagnostics may be annoying or can result in duplicated
  messages when used with a linter. For example, to disable the hint about
  RequireJS modules, set `filter_out_diagnostics_by_code` to `{ 80001 }` and to
  disable all hints, set `filter_out_diagnostics_by_severity` to `{ "hint" }`.

  Like fixing invalid ranges, this function requires calling `setup_client` in
  your configuration (see below).

  Note: filtering out `tsserver` error about unresolved variables (error code 2304) will break `:TSLspImportAll` functionality.

### ESLint Integrations

The plugin integrates with
[null-ls.nvim](https://github.com/jose-elias-alvarez/null-ls.nvim) to provide
ESLint code actions and diagnostics.

**NOTE:** null-ls wraps the ESLint CLI and may have trouble handling complex
project structures. For cases (e.g. monorepos) where running `eslint $FILENAME`
from the command line does not produce the expected output, I recommend the
[ESLint language
server](https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#eslint),
which can also provide diagnostics, code actions, and ESLint formatting.

To enable null-ls, install it via your plugin manager and add the following
snippet to your LSP configuration:

```lua
require("null-ls").config {}
require("lspconfig")["null-ls"].setup {}
```

- Code actions

  Adds actions to fix ESLint issues when a fix exists or disable the violated
  rule for the current line / file.

  Supports the following settings:

  - `eslint_enable_code_actions` (boolean): enables ESLint code actions. Set to
    `true` by default (so installing and setting up null-ls will automatically
    enable code actions).

  - `eslint_enable_disable_comments` (boolean): enables ESLint code actions to
    disable the violated rule for the current line / file. Set to `true` by
    default.

  - `eslint_bin` (string): sets the binary used to get ESLint output. Looks for
    a local executable in `node_modules` and falls back to a system-wide
    executable, which must be available on your `$PATH`.

    Uses `eslint` by default for compatibility, but I highly, highly recommend
    using [eslint_d](https://github.com/mantoni/eslint_d.js). `eslint` will add
    a noticeable delay to each code action.

- Diagnostics

  Shows ESLint diagnostics for the current buffer.

  Supports the following settings:

  - `eslint_enable_diagnostics` (boolean): enables ESLint diagnostics for the
    current buffer on `tsserver` attach. Set to `false` by default.

  - `eslint_bin` and `eslint_config_fallback`: applies the same settings as
    ESLint code actions. Like code actions, using `eslint_d` will improve your
    experience.

  - `eslint_opts` (table): allows modifying the options passed to the null-ls
    diagnostics source, as described
    [here](https://github.com/jose-elias-alvarez/null-ls.nvim/blob/main/doc/BUILTINS.md#configuration).

### Formatting

The plugin can also provide formatting via null-ls (see above for setup
instructions) and supports [Prettier](https://github.com/prettier/prettier),
[prettierd](https://github.com/fsouza/prettierd),
[prettier_d_slim](https://github.com/mikew/prettier_d_slim),
[ESLint](https://github.com/eslint/eslint), and
[eslint_d](https://github.com/mantoni/eslint_d.js/)

Prettier and prettier_d_slim support range formatting for `tsserver`
filetypes. All other formatters do not (and would require upstream changes to
add support, so it's not something we can handle here).

Please note that vanilla ESLint is an absurdly slow formatter and is not
suitable for running on save.

Supports the following settings:

- `enable_formatting` (boolean): enables formatting. Set to `false` by
  default.

- `formatter` (string): sets the executable used for formatting. Set to
  `prettier` by default. Must be one of `prettier`, `prettierd`,
  `prettier_d_slim`, `eslint`, or `eslint_d`.

  Like `eslint_bin`, the plugin will look for a local
  executable in `node_modules` and fall back to a system-wide executable,
  which must be available on your `$PATH`.

- `formatter_opts` (table): allows modifying the options passed to the null-ls
  diagnostics source, as described
  [here](https://github.com/jose-elias-alvarez/null-ls.nvim/blob/main/doc/BUILTINS.md#configuration).

Once you've enabled formatting, it'll run whenever you call either of the
following commands:

```vim
" runs asynchronously
:lua vim.lsp.buf.formatting()

" blocks until formatting completes
:lua vim.lsp.buf.formatting_sync()
```

Prettier and prettier_d_slim support range formatting for `tsserver`
filetypes, which you can run by visually selecting part of the buffer and
calling the following command (the part before `lua` is automatically filled
in when you enter command mode from visual mode):

```vim
:'<,'>lua vim.lsp.buf.range_formatting()
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
  vim.cmd("command -buffer FormattingSync lua vim.lsp.buf.formatting_sync()")

  -- format on save
  vim.cmd("autocmd BufWritePre <buffer> lua vim.lsp.buf.formatting_sync()")
end
```

### Experimental Features

- Update imports on file move

  Watches the root directory for file move / rename events and updates imports
  accordingly. The plugin will attempt to determine if the current root
  directory has a Git root and watch all non-ignored directories.

  Supports the following settings:

  - `update_imports_on_move` (boolean): enables this feature. Set to `false` by
    default.

  - `require_confirmation_on_move` (boolean): if `true`, prompts for
    confirmation before updating imports. Set to `false` by default.

  - `watch_dir` (string, nil): sets a fallback directory that the plugin will
    watch for changes if it can't find a Git root from the current root
    directory. Path is relative to the current root directory. Set to `nil` by
    default.

  Note that if the root directory does not have a Git root and `watch_dir` is
  `nil` or fails to resolve, the plugin will not enable file watching. This is
  to prevent performance issues from watching `node_modules` and irreversible
  changes from modifying files not under version control.

## Setup

Install using your favorite plugin manager and add to your
[nvim-lspconfig](https://github.com/neovim/nvim-lspconfig) `tsserver.setup` function.

An example showing the available settings and their defaults:

```lua
local nvim_lsp = require("lspconfig")

-- enable null-ls integration (optional)
require("null-ls").config {}
require("lspconfig")["null-ls"].setup {}

-- make sure to only run this once!
nvim_lsp.tsserver.setup {
    -- Only needed for inlayHints. Merge this table with your settings or copy
    -- it from the source if you want to add your own init_options.
	init_options = require("nvim-lsp-ts-utils").init_options,
    --
    on_attach = function(client, bufnr)
        -- disable tsserver formatting if you plan on formatting via null-ls
        client.resolved_capabilities.document_formatting = false
        client.resolved_capabilities.document_range_formatting = false

        local ts_utils = require("nvim-lsp-ts-utils")

        -- defaults
        ts_utils.setup {
            debug = false,
            disable_commands = false,
            enable_import_on_completion = false,

            -- import all
            import_all_timeout = 5000, -- ms
            -- lower numbers indicate higher priority
            import_all_priorities = {
                same_file = 1, -- add to existing import statement
                local_files = 2, -- git files or files with relative path markers
                buffer_content = 3, -- loaded buffer content
                buffers = 4, -- loaded buffer names
            },
            import_all_scan_buffers = 100,
            import_all_select_source = false,

            -- eslint
            eslint_enable_code_actions = true,
            eslint_enable_disable_comments = true,
            eslint_bin = "eslint",
            eslint_enable_diagnostics = false,
            eslint_opts = {},

            -- formatting
            enable_formatting = false,
            formatter = "prettier",
            formatter_opts = {},

            -- update imports on file move
            update_imports_on_move = false,
            require_confirmation_on_move = false,
            watch_dir = nil,

            -- filter diagnostics
            filter_out_diagnostics_by_severity = {},
            filter_out_diagnostics_by_code = {},

            -- inlay hints
            auto_inlay_hints = true,
            inlay_hints_highlight = "Comment",
        }

        -- required to fix code action ranges and filter diagnostics
        ts_utils.setup_client(client)

        -- no default maps, so you may want to define some here
        local opts = { silent = true }
        vim.api.nvim_buf_set_keymap(bufnr, "n", "gs", ":TSLspOrganize<CR>", opts)
        vim.api.nvim_buf_set_keymap(bufnr, "n", "gr", ":TSLspRenameFile<CR>", opts)
        vim.api.nvim_buf_set_keymap(bufnr, "n", "gi", ":TSLspImportAll<CR>", opts)
    end
}
```

## Troubleshooting

First, please make sure you are running the latest version of this plugin and
its dependencies.

Second, please check your configuration and make sure it's in line with the
latest version of this document.

Third, please try setting `debug = true` in `setup` and inspecting the output in
`:messages`. null-ls has a related [`debug`
option](https://github.com/jose-elias-alvarez/null-ls.nvim#how-to-enable-and-use-debug-mode)
that you can use to help figure out issues related to null-ls features.

If your issue relates to `eslint_d`, please try exiting Neovim, running
`eslint_d stop` from your command line, then restarting Neovim. `eslint_d` can
get "stuck" on a particular configuration when switching between projects, so
this step can resolve a lot of issues.

If those options don't help, please open up an issue and provide the requested
information.

## Tests

Clone the repository, run `npm install` in the `test` directory, then run `make test` in the root of the project to run the test suite. The suite has the same
requirements as the plugin.

## Recommended Plugins / Servers

- [JoosepAlviste/nvim-ts-context-commentstring](https://github.com/JoosepAlviste/nvim-ts-context-commentstring):
  Sets `commentstring` intelligently based on the cursor's position in the file,
  meaning JSX comments work as you'd expect.

- [windwp/nvim-ts-autotag](https://github.com/windwp/nvim-ts-autotag): Uses
  Treesitter to automatically close and rename JSX tags.

- [RRethy/nvim-treesitter-textsubjects](https://github.com/RRethy/nvim-treesitter-textsubjects):
  Adds useful "smart" text objects that adapt to the current context.

- The [ESLint language
  server](https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#eslint):
  Provides ESLint code actions, diagnostics, and formatting. Requires more setup
  (and installing another executable), but it uses the ESLint Node API, which is
  better about resolving executables and configuration files in complex project
  structures.
