# ARCHIVAL NOTICE

Please check out
[typescript.nvim](https://github.com/jose-elias-alvarez/typescript.nvim), a
minimal `typescript-language-server` integration plugin written in TypeScript.

You are free to use nvim-lsp-ts-utils in its current state (or copy the
functionality you need into your Neovim config) but it will no longer receive
updates or bug fixes.

# nvim-lsp-ts-utils

Utilities to improve the TypeScript development experience for Neovim's
built-in LSP client.

## Requirements

- Neovim 0.6.0+

- [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig), which you are
  (probably) already using to configure `typescript-language-server`

- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)

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

  **Note**: `:TSLspImportAll` depends on `tsserver` diagnostics, meaning that the
  function won't work for JavaScript files unless you set `"checkJs": true` inside
  `tsconfig.json` / `jsconfig.json`.

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

- Import missing import under cursor (exposed as `:TSLspImportCurrent`)

  Adds the missing import under the cursor. Affected by the same options as
  `:TSLspImportAll`.

- Import on completion

  Adds missing imports on completion confirm (`<C-y>`) when using the built-in
  LSP `omnifunc`. Enable by setting `enable_import_on_completion` to `true`
  inside `setup` (see below).

- Avoid organizing imports

  By default `always_organize_imports` is set to `true`, every call to
  `:TSLspImportAll` or `:TSLspImportCurrent` will also run `:TSLspOrganize`
  to fix possible duplicated imports.

  If `always_organize_imports` is set to `false`, it will only run
  `:TSLspOrganize` in situations where is necessary: i.e. two new imports
  from the same module.

- Fix invalid ranges

  `tsserver` uses non-compliant ranges in some code actions (most notably "Move
  to a new file"), which makes them [not work properly in
  Neovim](https://github.com/neovim/neovim/issues/14469). The plugin fixes these
  ranges so that the affected actions work as expected.

  You can enable this feature by calling `setup_client` in your configuration (see
  below).

- Inlay hints (exposed as `:TSLspInlayHints`/`:TSLspDisableInlayHints`/`:TSLspToggleInlayHints`)

  `tsserver` has added experimental support for inlay hints as of Typescript
  v4.4.2. Note that you need to set `init_options` for this feature to work.
  Please see [Setup](#setup) for instructions.

  Supports the following settings:

  - `auto_inlay_hints` (boolean): Set inlay hints on every new buffer visited
    automatically. Note that it would stop doing so if you call
    `:TSDisableInlayHints` and will continue if you call `:TSLspInlayHints`. If
    false, you need to call `:TSInlayHints` for every buffer to see its inlay
    hints. Defaults to `true`.

  - `inlay_hints_highlight` (string): Highlight group used for inlay hints.
    Defaults to "Comment".

  - `inlay_hints_priority` (number): Priority of the hint extmarks. Change
    this value if the inlay hints conflict with other extmarks. Defaults to 200.

  - `inlay_hints_throttle` (number): Throttle time of inlay hints requests in ms.
    Defaults to 150.

  - `inlay_hints_format` (table): Format options for individual kind of inlay
    hints. See [Setup](#setup) section for default settings and example.

- Filter `tsserver` diagnostics

Some `tsserver` diagnostics may be annoying or can result in duplicated
messages when used with a linter. For example, to disable the hint about
RequireJS modules, set `filter_out_diagnostics_by_code` to `{ 80001 }` and to
disable all hints, set `filter_out_diagnostics_by_severity` to `{ "hint" }`.

Like fixing invalid ranges, this function requires calling `setup_client` in
your configuration (see below).

Note: filtering out error code 2304 (unused variables) will break
`:TSLspImportAll` functionality.

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
local lspconfig = require("lspconfig")

lspconfig.tsserver.setup({
    -- Needed for inlayHints. Merge this table with your settings or copy
    -- it from the source if you want to add your own init_options.
    init_options = require("nvim-lsp-ts-utils").init_options,
    --
    on_attach = function(client, bufnr)
        local ts_utils = require("nvim-lsp-ts-utils")

        -- defaults
        ts_utils.setup({
            debug = false,
            disable_commands = false,
            enable_import_on_completion = false,

            -- import all
            import_all_timeout = 5000, -- ms
            -- lower numbers = higher priority
            import_all_priorities = {
                same_file = 1, -- add to existing import statement
                local_files = 2, -- git files or files with relative path markers
                buffer_content = 3, -- loaded buffer content
                buffers = 4, -- loaded buffer names
            },
            import_all_scan_buffers = 100,
            import_all_select_source = false,
            -- if false will avoid organizing imports
            always_organize_imports = true,

            -- filter diagnostics
            filter_out_diagnostics_by_severity = {},
            filter_out_diagnostics_by_code = {},

            -- inlay hints
            auto_inlay_hints = true,
            inlay_hints_highlight = "Comment",
            inlay_hints_priority = 200, -- priority of the hint extmarks
            inlay_hints_throttle = 150, -- throttle the inlay hint request
            inlay_hints_format = { -- format options for individual hint kind
                Type = {},
                Parameter = {},
                Enum = {},
                -- Example format customization for `Type` kind:
                -- Type = {
                --     highlight = "Comment",
                --     text = function(text)
                --         return "->" .. text:sub(2)
                --     end,
                -- },
            },

            -- update imports on file move
            update_imports_on_move = false,
            require_confirmation_on_move = false,
            watch_dir = nil,
        })

        -- required to fix code action ranges and filter diagnostics
        ts_utils.setup_client(client)

        -- no default maps, so you may want to define some here
        local opts = { silent = true }
        vim.api.nvim_buf_set_keymap(bufnr, "n", "gs", ":TSLspOrganize<CR>", opts)
        vim.api.nvim_buf_set_keymap(bufnr, "n", "gr", ":TSLspRenameFile<CR>", opts)
        vim.api.nvim_buf_set_keymap(bufnr, "n", "gi", ":TSLspImportAll<CR>", opts)
    end,
})
```

## Integrations via null-ls

You may want to set up integrations via
[null-ls.nvim](https://github.com/jose-elias-alvarez/null-ls.nvim) to provide
formatting, diagnostics, and code actions.

null-ls includes these integrations out-of-the-box, so they don't depend on this
plugin, but since I consider them an integral part of the TypeScript development
experience, I'm including instructions here for ESLint and Prettier, two common
options.

### Setting up null-ls

To enable null-ls and set up integrations, install it via your plugin manager
and add the following snippet to your LSP configuration:

```lua
local null_ls = require("null-ls")
null_ls.setup({
    sources = {
        null_ls.builtins.diagnostics.eslint, -- eslint or eslint_d
        null_ls.builtins.code_actions.eslint, -- eslint or eslint_d
        null_ls.builtins.formatting.prettier -- prettier, eslint, eslint_d, or prettierd
    },
})
```

null-ls provides other built-in sources for the JavaScript ecosystem. I've
included some alternatives above, and you can see the full list
[here](https://github.com/jose-elias-alvarez/null-ls.nvim/blob/main/doc/BUILTINS.md).
To set up more sources, add them to the `sources` table in `null_ls.setup`.

To learn about formatting files and setting up formatting on save, check out the
[null-ls FAQ](https://github.com/jose-elias-alvarez/null-ls.nvim#faq). To see
the full list of configuration options, see the [config
documentation](https://github.com/jose-elias-alvarez/null-ls.nvim/blob/main/doc/CONFIG.md).

### Configuring sources

null-ls allows configuring built-in sources via the `with` method, which you can
learn about
[here](https://github.com/jose-elias-alvarez/null-ls.nvim/blob/main/doc/BUILTINS.md#configuration).

For example, to configure `eslint` to use a project-local executable from
`node_modules` when available but fall back to a global executable, use this
configuration:

```lua
local null_ls = require("null-ls")
null_ls.setup({
    sources = {
        null_ls.builtins.diagnostics.eslint.with({
            prefer_local = "node_modules/.bin",
        }),
    },
})
```

To configure `eslint` to _only_ run when a project-local executable is available
in `node_modules`, use the following:

```lua
local null_ls = require("null-ls")
null_ls.setup({
    sources = {
        null_ls.builtins.diagnostics.eslint.with({
            only_local = "node_modules/.bin",
        }),
    },
})
```

You can use the same options for `prettier` or any other built-in source.

### ESLint Notes

- Vanilla `eslint` is absurdly slow and you'll see a noticeable delay on each
  action when using it. If possible, I highly, highly recommend using
  [eslint_d](https://github.com/mantoni/eslint_d.js). It works out-of-the-box
  for diagnostics and code actions and can also work as a formatter via
  [eslint-plugin-prettier](https://github.com/prettier/eslint-plugin-prettier#recommended-configuration).

- Since null-ls wraps the ESLint CLI, it may have trouble handling complex
  project structures. For these cases (e.g. monorepos), I recommend the [ESLint
  language
  server](https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#eslint),
  which can also provide diagnostics, code actions, and ESLint formatting.

## Troubleshooting

1. Make sure you are running the latest version of this plugin and its
   dependencies.
2. Check your configuration and make sure it's in line with the latest version
   of this document.
3. Set `debug = true` in your config and inspect the output in `:messages` to
   see if it matches what you expect.

If those options don't help, please open up an issue and provide the requested
information.

If you have a question or issue related to null-ls, please post a discussion
question or open an issue on the [null-ls
repository](https://github.com/jose-elias-alvarez/null-ls.nvim).

## Tests

Clone the repository and run `make test`. The suite has the same requirements as
the plugin.

## Recommended Plugins

- [JoosepAlviste/nvim-ts-context-commentstring](https://github.com/JoosepAlviste/nvim-ts-context-commentstring):
  sets `commentstring` intelligently based on the cursor's position in the file,
  meaning JSX comments work as you'd expect.

- [windwp/nvim-ts-autotag](https://github.com/windwp/nvim-ts-autotag): uses
  Treesitter to automatically close and rename JSX tags.

- [RRethy/nvim-treesitter-textsubjects](https://github.com/RRethy/nvim-treesitter-textsubjects):
  adds useful "smart" text objects that adapt to the current context.

- The [ESLint language
  server](https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#eslint):
  provides ESLint code actions, diagnostics, and formatting.

## Sponsors

Thanks to everyone who sponsors my projects and makes continued development /
maintenance possible!

<!-- sponsors --><a href="https://github.com/yutkat"><img src="https://github.com/yutkat.png" width="60px" alt="" /></a><a href="https://github.com/hituzi-no-sippo"><img src="https://github.com/hituzi-no-sippo.png" width="60px" alt="" /></a><a href="https://github.com/sbc64"><img src="https://github.com/sbc64.png" width="60px" alt="" /></a><a href="https://github.com/milanglacier"><img src="https://github.com/milanglacier.png" width="60px" alt="" /></a><!-- sponsors -->
