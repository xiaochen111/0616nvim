local ts_definition_filetypes = {
  "javascript",
  "typescript",
}

local ts_source_definition_filetypes = {
  "javascriptreact",
  "typescriptreact",
}

local function goto_source_definition_or_implementation()
  local bufnr = vim.api.nvim_get_current_buf()
  local filetype = vim.bo[bufnr].filetype

  if vim.tbl_contains(ts_definition_filetypes, filetype) then
    return vim.lsp.buf.definition()
  end

  if not vim.tbl_contains(ts_source_definition_filetypes, filetype) then
    return vim.lsp.buf.implementation()
  end

  local fallback = vim.lsp.buf.definition
  local clients = vim.lsp.get_clients { bufnr = bufnr }
  local source_definition_client, command

  for _, client in ipairs(clients) do
    if client:supports_method "workspace/executeCommand" then
      if client.name == "vtsls" then
        source_definition_client = client
        command = "typescript.goToSourceDefinition"
        break
      elseif client.name == "ts_ls" or client.name == "tsserver" then
        source_definition_client = client
        command = "_typescript.goToSourceDefinition"
      end
    end
  end

  if not source_definition_client or not command then return fallback() end

  local params = vim.lsp.util.make_position_params()
  source_definition_client:request("workspace/executeCommand", {
    command = command,
    arguments = { params.textDocument.uri, params.position },
  }, function(err, result, ctx)
    if err or not result or vim.tbl_isempty(result) then return fallback() end

    local handler = vim.lsp.handlers["textDocument/definition"]
    if handler then return handler(nil, result, ctx) end

    return vim.lsp.util.jump_to_location(result[1], source_definition_client.offset_encoding)
  end, bufnr)
end

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
        -- ["gdd"] = {
        --    require("telescope.builtin").lsp_references
        -- },
        ["gd"] = {
           vim.lsp.buf.definition,
           cond = "textDocument/definition",
        },
        ["gI"] = {
           goto_source_definition_or_implementation,
        }
      }
    }
  },
}


-- leader fo 打开最近的文件
-- leader ff 打开文件搜索
-- leader fw 全局搜索文字
