---@type LazySpec
return {
  "AstroNvim/astrolsp",
  ---@type AstroLSPOpts
  opts = {
    features = {
      -- Configuration table of features provided by AstroLSP
      autoformat = false, -- enable or disable auto formatting on start
      inlay_hints = false, -- nvim >= 0.10 这个如果开启 方法里的变量会自动给出类型提示 还是关闭了  有点太花了😅
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
