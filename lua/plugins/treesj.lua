---@type LazySpec
return {
  "Wansmer/treesj",
  cmd = { "TSJToggle", "TSJSplit", "TSJJoin" },
  dependencies = {
    {
      "AstroNvim/astrocore",
      opts = {
        mappings = {
          n = {
            ["<Leader>st"] = { "<Cmd>TSJToggle<CR>", desc = "Toggle Treesitter Join" },
          },
        },
      },
    },
  },
  opts = { use_default_keymaps = false },
}
