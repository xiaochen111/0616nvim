return {
  {
    "nvimtools/none-ls.nvim",
    optional = true,
    init = function()
      if vim.lsp.protocol._request_name_to_capability == nil then
        vim.lsp.protocol._request_name_to_capability = vim.lsp.protocol._request_name_to_server_capability
      end

      if vim.lsp._request_name_to_capability == nil then
        vim.lsp._request_name_to_capability = vim.lsp.protocol._request_name_to_server_capability
      end
    end,
    opts = function(_, opts) return opts end,
  },
}
