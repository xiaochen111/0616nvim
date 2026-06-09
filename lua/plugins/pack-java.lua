---@type LazySpec
return {
  {
    "mfussenegger/nvim-jdtls",
    optional = true,
    opts = function(_, opts)
      opts.cmd = opts.cmd or {}
      opts.cmd[1] = vim.fn.expand "~/.sdkman/candidates/java/17.0.19-tem/bin/java"

      opts.settings = opts.settings or {}
      opts.settings.java = opts.settings.java or {}
      opts.settings.java.configuration = opts.settings.java.configuration or {}
      opts.settings.java.configuration.runtimes = {
        {
          name = "JavaSE-1.8",
          path = vim.fn.expand "~/.sdkman/candidates/java/8.0.492-tem",
          default = true,
        },
        {
          name = "JavaSE-17",
          path = vim.fn.expand "~/.sdkman/candidates/java/17.0.19-tem",
        },
      }
    end,
  },
}
