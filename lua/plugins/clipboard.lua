return {
  "AstroNvim/astrocore",
  opts = function(_, opts)
    -- 设置系统剪贴板
    vim.opt.clipboard = "unnamed"

    -- 创建 TextYankPost 自动命令
    vim.api.nvim_create_autocmd("TextYankPost", {
      group = vim.api.nvim_create_augroup("Yank", { clear = true }),
      callback = function()
        if vim.v.event.operator == "y" then
          local text = vim.fn.getreg("0")
          local encoded = vim.fn.system("base64 -w0", text)
          encoded = vim.fn.trim(encoded)
          local osc = string.format("\027]52;c;%s\027\\", encoded)
          io.stderr:write(osc)
        end
      end,
    })

    return opts
  end,
} 