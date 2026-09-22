return {
  "AstroNvim/astrocore",
  opts = function(_, opts)
    --- 判断当前 Neovim 是否运行在 SSH 远程会话中。
    --- @return boolean 是否需要通过终端将复制内容传回本机
    local function is_ssh_session()
      return vim.env.SSH_CONNECTION ~= nil or vim.env.SSH_TTY ~= nil
    end

    if is_ssh_session() then
      -- 远程只通过 OSC 52 向本机写入剪贴板；不读取它，避免终端不支持
      -- OSC 52 查询时，普通 p 会等待最长 10 秒。
      local copy = require("vim.ui.clipboard.osc52").copy "+"
      vim.opt.clipboard = ""
      vim.api.nvim_create_autocmd("TextYankPost", {
        group = vim.api.nvim_create_augroup("RemoteOsc52Yank", { clear = true }),
        callback = function()
          if vim.v.event.operator == "y" then copy(vim.fn.getreg("0", 1, true)) end
        end,
      })
    else
      -- 本机 macOS 使用 Neovim 自动探测到的 pbcopy/pbpaste，读取外部剪贴板不会等待终端响应。
      vim.g.clipboard = nil
      vim.opt.clipboard = "unnamedplus"
    end

    return opts
  end,
}
