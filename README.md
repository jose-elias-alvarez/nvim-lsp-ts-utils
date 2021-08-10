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

- Fix current problem (exposed as `:TSLspFixCurrent`)

  A simple way to apply the first available code action to the current line
  without confirmation.

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

### null-ls Integrations

The plugin integrates with
[null-ls.nvim](https://github.com/jose-elias-alvarez/null-ls.nvim) to provide
ESLint code actions, diagnostics, and formatting. To enable null-ls itself, you
must install it via your plugin manager and add the following snippet to your
LSP configuration:

```lua
require("null-ls").config {}
require("lspconfig")["null-ls"].setup {}
```

- ESLint code actions

  Adds actions to fix ESLint issues or disable the violated rule for the current
  line / file.

  Supports the following settings:

  - `eslint_enable_code_actions` (boolean): enables ESLint code actions. Set to
    `true` by default.

  - `eslint_enable_disable_comments` (boolean): enables ESLint code actions to
    disable the violated rule for the current line / file. Set to `true` by
    default.

  - `eslint_bin` (string): sets the binary used to get ESLint output. Looks for
    a local executable in `node_modules` and falls back to a system-wide
    executable, which must be available on your `$PATH`.

    Uses `eslint` by default for compatibility, but I highly, highly recommend
    using [eslint_d](https://github.com/mantoni/eslint_d.js). `eslint` will add
    a noticeable delay to each code action.

  - `eslint_config_fallback` (string, function): path to a fallback ESLint
    config file that the plugin will use if it can't find a config file in the
    root directory. Set to `nil` by default.

- ESLint diagnostics

  Shows ESLint diagnostics for the current buffer as LSP diagnostics.

  Supports the following settings:

  - `eslint_enable_diagnostics` (boolean): enables ESLint diagnostics for the
    current buffer on `tsserver` attach. Set to `false` by default.

  - `eslint_bin` and `eslint_config_fallback`: applies the same settings as
    ESLint code actions. Like code actions, using `eslint_d` will improve your
    experience.

  - `eslint_show_rule_id` (boolean): shows the ESLint rule ID in diagnostics.
    Set to `false` by default.

- Formatting

  Provides formatting via null-ls.

  The plugin supports [Prettier](https://github.com/prettier/prettier),
  [prettierd](https://github.com/fsouza/prettierd),
  [prettier_d_slim](https://github.com/mikew/prettier_d_slim) and
  [eslint_d](https://github.com/mantoni/eslint_d.js/) as formatters. Formatting
  via vanilla `eslint` is not supported.

  Supports the following settings:

  - `enable_formatting` (boolean): enables formatting. Set to `false` by
    default.

  - `formatter` (string): sets the executable used for formatting. Set to
    `prettier` by default. Must be one of `prettier`, `prettierd`,
    `prettier_d_slim`, or `eslint_d`.

    Like `eslint_bin`, the plugin will look for a local
    executable in `node_modules` and fall back to a system-wide executable,
    which must be available on your `$PATH`.

  - `formatter_config_fallback` (string, function): path to a fallback formatter
    config file that the plugin will use if it can't find a config file in the
    root directory. Set to `nil` by default.

    Note that if you've set `formatter` to `eslint_d`, the plugin will use
    `eslint_config_fallback` instead.

  Note that once you've enabled formatting, it'll run whenever you call either
  of the following commands:

  ```vim
  " runs asynchronously
  :lua vim.lsp.buf.formatting()

  " blocks until formatting completes
  :lua vim.lsp.buf.formatting_sync()
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
  accordingly. The plugin will attempt to find a `.gitignore` file in the root
  directory and watch all non-ignored directories.

  Supports the following settings:

  - `update_imports_on_move` (boolean): enables this feature. Set to `false` by
    default.

  - `require_confirmation_on_move` (boolean): if `true`, prompts for
    confirmation before updating imports. Set to `false` by default.

  - `watch_dir` (string, nil): sets a fallback directory that the plugin will
    watch for changes if it can't find a `.gitignore` in the root directory.
    Path is relative to the current root directory. Set to `nil` by default.

  Note that if the root directory is not recognized as a Git project and
  `watch_dir` is `nil` or fails to resolve, the plugin will not enable file
  watching.

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
    on_attach = function(client, bufnr)
        -- disable tsserver formatting if you plan on formatting via null-ls
        client.resolved_capabilities.document_formatting = false

        local ts_utils = require("nvim-lsp-ts-utils")

        -- defaults
        ts_utils.setup {
            debug = false,
            disable_commands = false,
            enable_import_on_completion = false,

            -- import all
            import_all_timeout = 5000, -- ms
            import_all_priorities = {
                buffers = 4, -- loaded buffer names
                buffer_content = 3, -- loaded buffer content
                local_files = 2, -- git files or files with relative path markers
                same_file = 1, -- add to existing import statement
            },
            import_all_scan_buffers = 100,
            import_all_select_source = false,

            -- eslint
            eslint_enable_code_actions = true,
            eslint_enable_disable_comments = true,
            eslint_bin = "eslint",
            eslint_config_fallback = nil,
            eslint_enable_diagnostics = false,
            eslint_show_rule_id = false,

            -- formatting
            enable_formatting = false,
            formatter = "prettier",
            formatter_config_fallback = nil,

            -- update imports on file move
            update_imports_on_move = false,
            require_confirmation_on_move = false,
            watch_dir = nil,
        }

        -- required to fix code action ranges
        ts_utils.setup_client(client)

        -- no default maps, so you may want to define some here
        local opts = { silent = true }
        vim.api.nvim_buf_set_keymap(bufnr, "n", "gs", ":TSLspOrganize<CR>", opts)
        vim.api.nvim_buf_set_keymap(bufnr, "n", "qq", ":TSLspFixCurrent<CR>", opts)
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
`:messages`. null-ls has an identical `debug` option that you can use to help
figure out issues related to null-ls features.

If your issue relates to `eslint_d`, please try exiting Neovim, running
`eslint_d stop` from your command line, then restarting Neovim. `eslint_d` can
get "stuck" on a particular configuration when switching between projects, so
this step can resolve a lot of issues.

If those options don't help, please open up an issue and provide the requested
information.

## Tests

Run `make test` in the root of the project to run the test suite. The suite has
the same requirements as the plugin, and running the full suite requires having
`eslint` and `prettier` on your `$PATH`.

## Other Recommended Plugins

- [JoosepAlviste/nvim-ts-context-commentstring](https://github.com/JoosepAlviste/nvim-ts-context-commentstring):
  Sets `commentstring` intelligently based on the cursor's position in the file,
  meaning JSX comments work as you'd expect.

- [windwp/nvim-ts-autotag](https://github.com/windwp/nvim-ts-autotag): Uses
  Treesitter to automatically close and rename JSX tags.

- [RRethy/nvim-treesitter-textsubjects](https://github.com/RRethy/nvim-treesitter-textsubjects):
  Adds useful "smart" text objects that adapt to the current context.
