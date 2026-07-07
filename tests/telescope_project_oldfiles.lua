local captured_oldfiles_opts

package.loaded.astrocore = nil
package.loaded["telescope.builtin"] = nil

package.preload.astrocore = function()
  return {
    is_available = function(plugin) return plugin == "telescope.nvim" end,
    empty_map_table = function() return { n = {}, v = {} } end,
    extend_tbl = function(_, tbl) return tbl end,
  }
end

package.preload["telescope.builtin"] = function()
  return {
    oldfiles = function(opts) captured_oldfiles_opts = opts end,
    live_grep = function() end,
    buffers = function() end,
  }
end

local specs = dofile "/Users/chenhb/.config/nvim/lua/plugins/telescope.lua"
local astrocore_spec = specs[1]
local opts = { mappings = { n = {}, v = {} } }

astrocore_spec.opts(nil, opts)

local mapping = opts.mappings.n["<Leader>fo"]
assert(type(mapping) == "table", "<Leader>fo mapping should be defined")
assert(type(mapping[1]) == "function", "<Leader>fo should call a Lua function")

mapping[1]()

assert(type(captured_oldfiles_opts) == "table", "<Leader>fo should call telescope oldfiles with opts")
assert(captured_oldfiles_opts.cwd_only == true, "<Leader>fo oldfiles should be limited to cwd")
