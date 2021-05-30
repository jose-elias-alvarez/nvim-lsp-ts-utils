local o = require("nvim-lsp-ts-utils.options")
local u = require("nvim-lsp-ts-utils.utils")
local loop = require("nvim-lsp-ts-utils.loop")
local rename_file = require("nvim-lsp-ts-utils.rename-file")

local defer = vim.defer_fn

local s = { watching = false, unwatch = nil, _source = nil }
s.source = {
	get = function()
		return s._source
	end,
	set = function(val)
		s._source = val
	end,
	reset = function()
		s._source = nil
	end,
}

s.reset = function()
	s.watching = false
	s.unwatch = nil
	s._source = nil
end

local should_ignore_file = function(path)
	local extension = u.file.extension(path)
	if vim.tbl_contains(u.tsserver_extensions, extension) then
		return false
	end

	-- the path may be a directory,
	-- but since it could be deleted, we can't check with fs_fstat
	if extension == "" then
		return false
	end

	return true
end

local should_ignore_event = function(source, target)
	-- ignore save
	if source == target then
		return true
	end

	-- ignore non-move events
	local source_exists, target_exists = u.file.stat(source), u.file.stat(target)
	if source_exists then
		return true
	end
	if not target_exists then
		return true
	end

	-- ignore type mismatches
	if u.file.extension(source) == "" and target_exists.type ~= "directory" then
		return true
	end

	return false
end

local handle_event_factory = function(dir)
	return function(filename)
		local path = dir .. "/" .. filename
		if should_ignore_file(path) then
			return
		end

		local source = s.source.get()
		if not source then
			s.source.set(path)
			defer(function()
				s.source.reset()
			end, 50)
			return
		end

		local target = path
		if should_ignore_event(source, target) then
			s.source.reset()
			return
		end

		if source then
			u.debug_log("attempting to update imports")
			u.debug_log("source: " .. source)
			u.debug_log("target: " .. target)

			rename_file.on_move(source, target)
			s.source.reset()
		end
	end
end

local handle_error = function(err)
	u.echo_warning("error in watcher: " .. err)
	s.reset()
end

local M = {}
M.start = function()
	if s.watching then
		return
	end

	local root = u.buffer.root()
	if not root then
		u.debug_log("project root could not be determined; watch aborted")
		return
	end

	local dir = root .. o.get().watch_dir
	assert(u.file.is_dir(dir), "watch_dir is not a directory")

	s.watching = true
	u.debug_log("watching directory " .. dir)

	s.unwatch = loop.watch_dir(dir, {
		on_event = handle_event_factory(dir),
		on_error = handle_error,
	})
end

M.stop = function()
	if not s.unwatch then
		return
	end

	s.unwatch()
	s.reset()
	u.debug_log("watcher stopped")
end

M.restart = function()
	M.stop()
	defer(M.start, 100)
end

return M
