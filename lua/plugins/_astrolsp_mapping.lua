return {
  "AstroNvim/astrolsp",
  ---@param opts AstroLSPOpts
  opts = function(_, opts)
    if not opts.mappings then opts.mappings = require("astrocore").empty_map_table() end
    local maps = opts.mappings
    if maps then
      -- === 原有用户自定义映射 ===
      maps.n["gl"] = { function() vim.diagnostic.open_float() end, desc = "Hover diagnostics" }
      maps.i["<C-l>"] = {
        function() vim.lsp.buf.signature_help() end,
        desc = "Signature help",
        cond = "textDocument/signatureHelp",
      }

      -- === 禁用 AstroLSP 默认的 <Leader>l 前缀映射（改用 <Leader>s） ===
      -- 关键：必须清除 astrolsp 默认的 <Leader>l 父级前缀，否则会覆盖 astrocore 的 $
      maps.n["<Leader>l"] = false
      maps.v["<Leader>l"] = false
      maps.n["<Leader>la"] = false
      maps.x["<Leader>la"] = false
      maps.n["<Leader>lA"] = false
      maps.n["<Leader>ll"] = false
      maps.n["<Leader>lL"] = false
      maps.n["<Leader>lf"] = false
      maps.v["<Leader>lf"] = false
      maps.n["<Leader>lR"] = false
      maps.n["<Leader>lr"] = false
      maps.n["<Leader>lh"] = false
      maps.n["<Leader>lG"] = false
      maps.n["<Leader>ld"] = false
      maps.n["<Leader>li"] = false
      maps.n["<Leader>lI"] = false
      maps.n["<Leader>uL"] = false

      -- === 重新映射到 <Leader>s 前缀 ===
      maps.n["<Leader>s"] = { desc = require("astroui").get_icon("ActiveLSP", 1, true) .. "Language Tools" }
      maps.v["<Leader>s"] = { desc = require("astroui").get_icon("ActiveLSP", 1, true) .. "Language Tools" }

      maps.n["<Leader>sI"] = { "<Cmd>LspInfo<CR>", desc = "LSP information" }
      maps.n["<Leader>sn"] = { "<Cmd>NullLsInfo<CR>", desc = "Null-ls information" }

      maps.n["<Leader>sa"] = {
        function() vim.lsp.buf.code_action() end,
        desc = "LSP code action",
        cond = "textDocument/codeAction",
      }
      maps.x["<Leader>sa"] = {
        function() vim.lsp.buf.code_action() end,
        desc = "LSP code action",
        cond = "textDocument/codeAction",
      }
      maps.n["<Leader>sA"] = {
        function()
          vim.lsp.buf.code_action { context = { only = { "source" }, diagnostics = {} } }
        end,
        desc = "LSP source action",
        cond = "textDocument/codeAction",
      }

      maps.n["<Leader>sl"] = {
        function() vim.lsp.codelens.refresh() end,
        desc = "LSP CodeLens refresh",
        cond = "textDocument/codeLens",
      }
      maps.n["<Leader>sL"] = {
        function() vim.lsp.codelens.run() end,
        desc = "LSP CodeLens run",
        cond = "textDocument/codeLens",
      }

      -- 格式化
      maps.n["<Leader>ss"] = {
        function() vim.lsp.buf.format(require("astrolsp").format_opts) end,
        desc = "Format buffer",
        cond = function(client)
          local disabled = opts.formatting and opts.formatting.disabled
          return client.supports_method "textDocument/formatting"
            and disabled ~= true
            and not vim.tbl_contains(disabled or {}, client.name)
        end,
      }
      maps.v["<Leader>ss"] = {
        function() vim.lsp.buf.format(require("astrolsp").format_opts) end,
        desc = "Format buffer",
        cond = function(client)
          local disabled = opts.formatting and opts.formatting.disabled
          return client.supports_method "textDocument/rangeFormatting"
            and disabled ~= true
            and not vim.tbl_contains(disabled or {}, client.name)
        end,
      }

      maps.n["<Leader>sR"] = {
        function() vim.lsp.buf.references() end,
        desc = "Search references",
        cond = "textDocument/references",
      }
      maps.n["<Leader>sr"] = {
        function() vim.lsp.buf.rename() end,
        desc = "Rename current symbol",
        cond = "textDocument/rename",
      }
      maps.n["<Leader>sh"] = {
        function() vim.lsp.buf.signature_help() end,
        desc = "Signature help",
        cond = "textDocument/signatureHelp",
      }
      maps.n["<Leader>sG"] = {
        function() vim.lsp.buf.workspace_symbol() end,
        desc = "Search workspace symbols",
        cond = "workspace/symbol",
      }
    end

    opts.mappings = maps
  end,
}
