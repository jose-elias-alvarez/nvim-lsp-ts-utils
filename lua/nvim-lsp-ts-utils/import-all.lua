local a = require("plenary.async_lib")
local u = require("nvim-lsp-ts-utils.utils")
local organize_imports = require("nvim-lsp-ts-utils.organize-imports")

local lsp = vim.lsp

local CODE_ACTION = "textDocument/codeAction"
local APPLY_EDIT = "_typescript.applyWorkspaceEdit"

local get_diagnostics = function(bufnr)
	local diagnostics = lsp.diagnostic.get(bufnr)

	if vim.tbl_isempty(diagnostics) then
		u.print_no_actions_message()
		return nil
	end

	local filtered = {}
	for _, diagnostic in pairs(diagnostics) do
		if diagnostic.source == "typescript" then
			table.insert(filtered, diagnostic)
		end
	end
	return filtered
end

local make_params = function(entry)
	local params = lsp.util.make_range_params()
	params.range = entry.range
	params.context = { diagnostics = { entry } }

	-- caught by null-ls
	params._null_ls_ignore = true

	return params
end

local create_response_handler = function(edits, imports)
	return function(responses)
		if not responses then
			return
		end
		for _, response in ipairs(responses) do
			for _, result in pairs(response) do
				for _, action in pairs(result) do
					-- keep only edits
					if action.command ~= APPLY_EDIT then
						break
					end
					-- keep only actions that look like imports
					if
						not (
							(string.match(action.title, "Add") and string.match(action.title, "existing import"))
							or string.match(action.title, "Import")
						)
					then
						break
					end

					local arguments = action.arguments
					if not arguments or not arguments[1] then
						break
					end

					local changes = arguments[1].documentChanges
					if not changes or not changes[1] then
						break
					end

					-- capture variable name, which should be surrounded by single quotes
					local import = string.match(action.title, "%b''")
					-- avoid importing same variable twice
					if import and not vim.tbl_contains(imports, import) then
						for _, edit in ipairs(changes[1].edits) do
							table.insert(edits, edit)
						end
						table.insert(imports, import)
					end
				end
			end
		end
	end
end

local apply_edits = function(edits, bufnr)
	lsp.util.apply_text_edits(edits, bufnr)

	-- organize imports afterwards to merge separate import statements from the same file
	organize_imports.async()
end

return a.async_void(function(bufnr)
	local diagnostics = get_diagnostics(bufnr)
	if not diagnostics then
		return
	end

	local buf_request_all = a.wrap(vim.lsp.buf_request_all, 4)
	local edits, imports, messages = {}, {}, {}
	local response_handler = create_response_handler(edits, imports)

	local get_responses = function(diagnostic)
		return a.await(buf_request_all(bufnr, CODE_ACTION, make_params(diagnostic)))
	end

	local futures = {}
	local future_factory = function(diagnostic)
		return a.future(function()
			response_handler(get_responses(diagnostic))
		end)
	end

	for _, diagnostic in pairs(diagnostics) do
		if not vim.tbl_contains(messages, diagnostic.message) then
			table.insert(messages, diagnostic.message)
			table.insert(futures, future_factory(diagnostic))
		end
	end

	a.await_all(futures)
	apply_edits(edits, bufnr)
end)
