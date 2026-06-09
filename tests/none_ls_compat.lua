local method_to_required_capability_map = vim.lsp.protocol._request_name_to_capability
  or vim.lsp._request_name_to_capability

assert(method_to_required_capability_map == nil)
assert(type(vim.lsp.protocol._request_name_to_server_capability) == "table")
assert(vim.lsp.protocol._request_name_to_server_capability["textDocument/formatting"] ~= nil)

local plugin = dofile "/Users/chenhb/.config/nvim/lua/plugins/none-ls.lua"
plugin[1].init()

local compat_map = vim.lsp.protocol._request_name_to_capability or vim.lsp._request_name_to_capability
assert(type(compat_map) == "table")
assert(compat_map["textDocument/formatting"] ~= nil)
