---@type LazySpec
return {
  {
    "HiPhish/rainbow-delimiters.nvim",
    dependencies = "nvim-treesitter/nvim-treesitter",
    event = "User AstroFile",
    config = function(_, opts)
      require("rainbow-delimiters.setup")(opts)
      -- 修复 Neovim 0.12 上 get_parser() 返回 nil 导致崩溃的问题
      -- 用 pcall 包住 attach，避免修改插件源码导致 Lazy 更新被阻塞
      local ok, lib = pcall(require, "rainbow-delimiters.lib")
      if not ok then return end
      local _attach = lib.attach
      lib.attach = function(bufnr)
        local ok, err = pcall(_attach, bufnr)
        if not ok then
          vim.notify("rainbow-delimiters: " .. tostring(err), vim.log.levels.WARN)
        end
      end
    end,
  },
  {
    "catppuccin/nvim",
    optional = true,
    ---@type CatppuccinOptions
    opts = { integrations = { rainbow_delimiters = true } },
  },
  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    dependencies = { "HiPhish/rainbow-delimiters.nvim" },
    opts = function(_, opts)
      if not opts.scope then opts.scope = {} end
      opts.scope.show_start = true
      opts.scope.show_end = true
      opts.scope.highlight = vim.tbl_get(vim.g, "rainbow_delimiters", "highlight")
        or {
          "RainbowDelimiterRed",
          "RainbowDelimiterYellow",
          "RainbowDelimiterBlue",
          "RainbowDelimiterOrange",
          "RainbowDelimiterGreen",
          "RainbowDelimiterViolet",
          "RainbowDelimiterCyan",
        }
    end,

    config = function(plugin, opts)
      require(plugin.main).setup(opts)

      local hooks = require "ibl.hooks"
      hooks.register(hooks.type.SCOPE_HIGHLIGHT, hooks.builtin.scope_highlight_from_extmark)
    end,
  },
}
