local u = require("nvim-lsp-ts-utils.utils")

local lsp = vim.lsp
local api = vim.api

local M = {}
local get_organize_params = function(bufnr)
	return {
		command = "_typescript.organizeImports",
		arguments = { u.buffer.name(bufnr) },
	}
end

local organize_imports = function(bufnr)
	if not bufnr then
		bufnr = api.nvim_get_current_buf()
	end

	lsp.buf.execute_command(get_organize_params(bufnr))
end
M.async = organize_imports

local organize_imports_sync = function(bufnr)
	if not bufnr then
		bufnr = api.nvim_get_current_buf()
	end

	lsp.buf_request_sync(bufnr, "workspace/executeCommand", get_organize_params(bufnr), 500)
end
M.sync = organize_imports_sync
return M
