return {
  {
    "nvim-treesitter/nvim-treesitter",
    optional = true,
    opts = function(_, opts)
      require("treesitter_query_compat").apply()
      return opts
    end,
  },
}
