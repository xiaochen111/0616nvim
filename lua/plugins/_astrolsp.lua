---@type LazySpec
return {
  "AstroNvim/astrolsp",
  ---@type AstroLSPOpts
  opts = {
    features = {
      -- Configuration table of features provided by AstroLSP
      autoformat = false, -- enable or disable auto formatting on start
      inlay_hints = true, -- nvim >= 0.10
    },
    -- Configuration options for controlling formatting with language servers
    formatting = {
      -- control auto formatting on save
      format_on_save = false,
      -- disable formatting capabilities for specific language servers
      disabled = {},
      -- default format timeout
      timeout_ms = 600000,
    },
    capabilities = {
      workspace = {
        didChangeWatchedFiles = { dynamicRegistration = true },
      },
    },
    mappings = {
      n = {
        ["gdd"] = {
           require("telescope.builtin").lsp_references
        }
      }
    }
  },
}


-- leader fo 打开最近的文件
-- leader ff 打开文件搜索
-- leader fw 全局搜索文字
