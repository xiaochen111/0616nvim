package.path = "/Users/chenhb/.config/nvim/lua/?.lua;" .. package.path

local captured_cmd
local termopen_count = 0
local original_termopen = vim.fn.termopen
local original_create_autocmd = vim.api.nvim_create_autocmd

vim.fn.termopen = function(cmd, _)
  termopen_count = termopen_count + 1
  captured_cmd = cmd
  return 123
end

vim.api.nvim_create_autocmd = function(_, _)
  return 456
end

local toggle = require("utils").toggle_claude_cli()
toggle()
toggle()
toggle()

vim.fn.termopen = original_termopen
vim.api.nvim_create_autocmd = original_create_autocmd

assert(captured_cmd == "claude --continue", "Claude CLI should continue the latest cwd conversation")
assert(termopen_count == 1, "Claude CLI should reuse the hidden terminal session when reopened")
