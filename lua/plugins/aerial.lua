return {
  {
    "stevearc/aerial.nvim",
    optional = true,
    opts = function(_, opts)
      opts.backends = { "lsp", "markdown", "asciidoc", "man" }
      return opts
    end,
  },
}
