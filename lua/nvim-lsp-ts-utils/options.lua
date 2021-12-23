local defaults = {
    debug = false,
    disable_commands = false,

    -- import all
    import_all_timeout = 5000,
    import_all_priorities = {
        buffers = 4,
        buffer_content = 3,
        local_files = 2,
        same_file = 1,
    },
    import_all_select_source = false,
    import_all_scan_buffers = 100,

    -- completion
    enable_import_on_completion = false,

    -- watcher
    update_imports_on_move = false,
    watch_dir = nil,
    require_confirmation_on_move = false,

    -- diagnostic filtering
    filter_out_diagnostics_by_severity = {},
    filter_out_diagnostics_by_code = {},

    -- inlay hints
    auto_inlay_hints = true,
    inlay_hints_highlight = "Comment",
    inlay_hints_priority = 200,
    inlay_hints_throttle = vim.o.updatetime,
    inlay_hints_format = {
        Type = {
            highlight = nil,
            text = function(text)
                return "->" .. text:sub(2)
            end,
        },
        Parameter = { highlight = nil, text = nil },
        Enum = { highlight = nil, text = nil },
    },

    -- internal
    _initialized = false,
}

local options = vim.deepcopy(defaults)

local M = {}

M.setup = function(user_options)
    if options._initialized then
        return
    end

    options = vim.tbl_extend("force", options, user_options)
    options._initialized = true
end

M.get = function()
    return options
end

M.reset = function()
    options = vim.deepcopy(defaults)
end

return M
