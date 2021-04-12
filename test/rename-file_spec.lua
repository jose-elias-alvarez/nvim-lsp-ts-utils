local ts_utils = require("nvim-lsp-ts-utils")

local pwd = vim.api.nvim_exec("pwd", true)
local base_path = "test/typescript/"

local get_file_content = function()
    local end_line = tonumber(vim.api.nvim_exec("echo line('$')", true))
    return vim.api.nvim_buf_get_lines(0, 0, end_line, false)
end

local setup = function()
    local copy_test_file = function(original, target)
        os.execute(
            "cp " .. pwd .. "/test/typescript/" .. original .. " " .. pwd ..
                "/test/typescript/" .. target)
    end

    copy_test_file("file-to-be-moved.orig.ts", "file-to-be-moved.ts")
    copy_test_file("linked-file.orig.ts", "linked-file.ts")
    copy_test_file("existing-file.orig.ts", "existing-file.ts")
end

local breakdown = function()
    vim.cmd("bufdo! bwipeout!")
    local delete_test_file = function(target)
        os.execute("rm " .. pwd .. "/test/typescript/" .. target ..
                       " 2> /dev/null")
    end

    delete_test_file("new-path.ts")
    delete_test_file("linked-file.ts")
    delete_test_file("file-to-be-moved.ts")
    delete_test_file("existing-file.ts")
end

describe("rename_file", function()
    before_each(function() setup() end)
    after_each(function() breakdown() end)
    it("should throw error on invalid filetype", function()
        vim.cmd("e " .. base_path .. "invalid_file.txt")

        vim.wait(1000)

        assert.has_errors(function() ts_utils.rename_file() end)
    end)

    it("should move file to specified path", function()
        vim.cmd("e " .. base_path .. "file-to-be-moved.ts")
        local original_content = get_file_content()
        vim.wait(1000)

        local new_path = pwd .. "/" .. base_path .. "new-path.ts"
        ts_utils.rename_file(new_path)
        vim.wait(200)

        local new_content = get_file_content()
        assert.equals(vim.fn.bufname(vim.fn.bufnr()), new_path)
        assert.same(original_content, new_content)
    end)

    it("should update imports in linked file", function()
        setup()
        vim.cmd("e " .. base_path .. "file-to-be-moved.ts")
        vim.wait(1000)

        local new_path = pwd .. "/" .. base_path .. "new-path.ts"
        ts_utils.rename_file(new_path)
        vim.wait(200)

        vim.cmd("e " .. base_path .. "linked-file.ts")
        assert.equals(vim.fn.search("new-path", "nw"), 1)
    end)

    it("should overwrite existing file", function()
        setup()
        vim.cmd("e " .. base_path .. "existing-file.ts")
        local original_content = get_file_content()

        vim.cmd("e " .. base_path .. "file-to-be-moved.ts")
        vim.wait(1000)
        local new_path = pwd .. "/" .. base_path .. "existing-file.ts"
        ts_utils.rename_file(new_path) -- prompt will be automatically accepted, it seems
        vim.wait(200)

        local new_content = get_file_content()
        assert.is.Not.same(original_content, new_content)
    end)
end)

