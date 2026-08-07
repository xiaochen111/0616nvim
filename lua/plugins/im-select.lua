return {
  "chaozwn/im-select.nvim",
  lazy = false,
  -- 仅在 macOS 上启用：该插件依赖 im-select 二进制切换输入法，
  -- Linux 容器 / 服务器环境既没有该二进制也没有输入法框架，加载只会报错
  cond = function() return vim.fn.has("macunix") == 1 end,
  opts = {
    default_main_select = "im.rime.inputmethod.Squirrel.Hans",
    set_previous_events = { "InsertEnter", "FocusLost" },
    -- 找不到二进制时静默跳过，不再抛出启动错误
    keep_quiet_on_no_binary = true,
  },
}
