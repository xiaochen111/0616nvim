local utils = require "utils"
local system = vim.loop.os_uname().sysname

local function find_gitsigns_blame_win()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == "gitsigns-blame" then return win, buf end
  end
end

local function toggle_gitsigns_blame()
  local blame_win = find_gitsigns_blame_win()
  if blame_win and vim.api.nvim_win_is_valid(blame_win) then
    vim.api.nvim_win_close(blame_win, true)
    return
  end

  require("gitsigns").blame()
end

return {
  "AstroNvim/astrocore",
  ---@param opts AstroCoreOpts
  opts = function(_, opts)
    -- 将 AstroNvim 的 Language Tools 前缀从 l 改为 s，避免与 <leader>l=$ 冲突
    if opts._map_sections then
      opts._map_sections.s = { desc = opts._map_sections.l and opts._map_sections.l.desc or "󰡰 Language Tools" }
      opts._map_sections.l = nil
    end

    if not opts.mappings then opts.mappings = require("astrocore").empty_map_table() end
    local maps = opts.mappings
    if maps then
      maps.n["<Leader>n"] = false

      maps.n.n = { require("utils").better_search "n", desc = "Next search" }
      maps.n.N = { require("utils").better_search "N", desc = "Previous search" }

      maps.v["K"] = { ":move '<-2<CR>gv-gv", desc = "Move line up", silent = true }
      maps.v["J"] = { ":move '>+1<CR>gv-gv", desc = "Move line down", silent = true }

      maps.i["<C-S>"] = { "<esc>:w<cr>a", desc = "Save file", silent = true }
      maps.x["<C-S>"] = { "<esc>:w<cr>a", desc = "Save file", silent = true }
      maps.n["<C-S>"] = { "<Cmd>w<cr>", desc = "Save file", silent = true }
      maps.n["<C-l>"] = { function() require("utils").focus_right_claude_or_window() end, desc = "Focus right Claude or window" }

      maps.n["<Leader>wo"] = { "<C-w>o", desc = "Close other screen" }
      maps.v["p"] = { "pgvy", desc = "Paste" }

      if vim.fn.executable "btm" == 1 then
        maps.n["<Leader>tT"] = { function() utils.toggle_term_cmd "btm" end, desc = "ToggleTerm btm" }
      end
      if vim.fn.executable "claude" == 1 then
        maps.n["<Leader>cc"] = { require("utils").toggle_claude_cli(), desc = "Toggle Claude CLI" }
        maps.n["<Leader>tc"] = { require("utils").toggle_claude_cli(), desc = "Toggle Claude CLI" }
      end

      maps.n["n"] = { "nzz" }
      maps.n["N"] = { "Nzz" }
      maps.v["n"] = { "nzz" }
      maps.v["N"] = { "Nzz" }

      if vim.g.neovide then
        if system == "Darwin" then
          vim.g.neovide_input_use_logo = 1 -- enable use of the logo (cmd) key
          -- Save
          maps.n["<D-s>"] = ":w<CR>"
          -- Paste normal mode
          maps.n["<D-v>"] = '"+P'
          -- Copy
          maps.v["<D-c>"] = '"+y'
          -- Paste visual mode
          maps.v["<D-v>"] = '"+P'
          -- Paste command mode
          maps.c["<D-v>"] = "<C-R>+"
          -- Paste insert mode
          maps.i["<D-v>"] = '<esc>"+pli'

          -- Allow clipboard copy paste in neovim
          vim.api.nvim_set_keymap("", "<D-v>", "+p<CR>", { noremap = true, silent = true })
          vim.api.nvim_set_keymap("!", "<D-v>", "<C-R>+", { noremap = true, silent = true })
          vim.api.nvim_set_keymap("t", "<D-v>", "<C-R>+", { noremap = true, silent = true })
          vim.api.nvim_set_keymap("v", "<D-v>", "<C-R>+", { noremap = true, silent = true })
        end
      end

      -- close search highlight
      maps.n["<Leader>nh"] = { ":nohlsearch<CR>", desc = "Close search highlight" }

      -- maps.n["H"] = { "^", desc = "Go to start without blank" }
      -- maps.n["L"] = { "$", desc = "Go to end without blank" }

      maps.v["<"] = { "<gv", desc = "Unindent line" }
      maps.v[">"] = { ">gv", desc = "Indent line" }

      -- 在visual mode 里粘贴不要复制
      maps.n["x"] = { '"_x', desc = "Cut without copy" }

      -- 分屏快捷键
      maps.n["<Leader>w"] = { desc = "󱂬 Window" }
      maps.n["<Leader>ww"] = { "<cmd><cr>", desc = "Save" }
      maps.n["<Leader>wc"] = { "<C-w>c", desc = "Close current screen" }
      maps.n["<Leader>wo"] = { "<C-w>o", desc = "Close other screen" }
      -- 多个窗口之间跳转
      maps.n["<Leader>we"] = { "<C-w>=", desc = "Make all window equal" }
      -- 上一个标签窗口
      maps.n["R"] =
        { function() require("astrocore.buffer").nav(vim.v.count > 0 and vim.v.count or 1) end, desc = "Next buffer" }
      -- 下一个标签窗口
      maps.n["E"] = {
        function() require("astrocore.buffer").nav(-(vim.v.count > 0 and vim.v.count or 1)) end,
        desc = "Previous buffer",
      }
      -- 删除除去自己的所有窗口
      maps.n["gxx"] =
        { function() require("astrocore.buffer").close_all(true) end, desc = "Close all buffers except current" }
      maps.n["<Leader>ba"] = { function() require("astrocore.buffer").close_all() end, desc = "Close all buffers" }
      -- 删除当前窗口
      maps.n["<C-w>"] = { function() require("astrocore.buffer").close() end, desc = "Close buffer" }
      maps.n["X"] = { function() require("astrocore.buffer").close() end, desc = "Close current buffer" }
      maps.n["<Leader>bC"] = { function() require("astrocore.buffer").close(0, true) end, desc = "Force close buffer" }
      maps.n["<Leader>bn"] = { "<cmd>tabnew<cr>", desc = "New tab" }
      maps.n["<Leader>bD"] = {
        function()
          require("astrocore.status").heirline.buffer_picker(
            function(bufnr) require("astrocore.buffer").close(bufnr) end
          )
        end,
        desc = "Pick to close",
      }

      -- lsp restart (moved to <Leader>s prefix)
      maps.n["<Leader>sm"] = { "<Cmd>LspRestart<CR>", desc = "Lsp restart" }
      maps.n["<Leader>sg"] = { "<Cmd>LspLog<CR>", desc = "Show lsp log" }

      -- 禁用 AstroNvim 默认的 <Leader>ld（已合并到 <Leader>s 前缀）
      maps.n["<Leader>ld"] = false
      -- 禁用 aerial 的 <Leader>lS Symbols outline
      maps.n["<Leader>lS"] = false
      -- 禁用 telescope 的 <Leader>ls/ld（合并到 <Leader>s 前缀）
      maps.n["<Leader>ls"] = false
      maps.n["<Leader>lD"] = false
      -- 禁用用户插件 treesj/treesitter 的 <Leader>l 前缀映射
      maps.n["<Leader>lt"] = false
      maps.n["<Leader>lT"] = false

      -- 重新映射到 <Leader>s 前缀
      maps.n["<Leader>st"] = { "<Cmd>TSJToggle<CR>", desc = "Toggle Treesitter Join" }
      maps.n["<Leader>si"] = { "<cmd>TSInstallInfo<cr>", desc = "Tree sitter Information" }


      maps.n["}"] = {"%"}
      maps.n["J"] = {'5j'}
      maps.n["K"] = {'5k'}
      maps.n["<Leader>a"] = {function ()
        vim.cmd.Neotree "focus"
      end}

      maps.n["<Leader>n"] = {"*"}

      maps.n["<Leader>h"] = { "^", desc = "Go to start of line" }
      maps.n["<Leader>l"] = { "$", desc = "Go to end of line" }
      maps.n["<Leader>L"] = { "$", desc = "Go to end of line" }
      maps.n["<Leader>j"] = {function() vim.diagnostic.goto_next() end}
      maps.n["<Leader>k"] = {function() vim.diagnostic.goto_prev() end}
      maps.n["gj"] = {function() require('gitsigns').next_hunk() end}
      maps.n["gk"] = {function() require('gitsigns').prev_hunk() end}
      maps.n["gh"] = {function() vim.lsp.buf.hover() end}
      maps.n["gra"] = false
      maps.x["gra"] = false
      maps.n["grn"] = false
      maps.n["grr"] = false
      maps.n["gri"] = false
      maps.n["grt"] = false
      maps.n["grx"] = false
      maps.n["gr"] = {
        function()
          local line = vim.api.nvim_win_get_cursor(0)[1]
          require("gitsigns").reset_hunk { line, line }
        end,
        desc = "Reset git change at current line",
        nowait = true,
      }
      maps.n["gb"] = { toggle_gitsigns_blame, desc = "Toggle gitsigns blame", nowait = true }
      -- 来预览当前光标所在的更改块。
      maps.n["gp"] = {function() require("gitsigns").preview_hunk() end}
      maps.n["<C-m>"] = false

      maps.n["zm"] = {"zM"}
      maps.n["zr"] = {"zR"}
      maps.n["zo"] = {"zO"}
      maps.n["zc"] = {"zC"}
      maps.n["s"] = {'\"_s'}
      maps.n["c"] = {'\"_c'}

      maps.v["J"] = {'5j'}
      maps.v["K"] = {'5k'}
      maps.v["<Leader>h"] = { "^", desc = "Go to start of line" }
      maps.v["<Leader>l"] = { "$", desc = "Go to end of line" }
      maps.v["log"] = {function() require('utils').log_variable() end}

      maps.i["jj"] = {'<Esc>'}
      maps.n["f"] = {function() require('hop').hint_char1() end}

    end

    opts.mappings = maps

    vim.schedule(function()
      for _, mode_lhs in ipairs {
        { "n", "gra" },
        { "x", "gra" },
        { "n", "grn" },
        { "n", "grr" },
        { "n", "gri" },
        { "n", "grt" },
        { "n", "grx" },
      } do
        pcall(vim.keymap.del, mode_lhs[1], mode_lhs[2])
      end
    end)

    -- 强制覆盖 timeoutlen，确保不被 AstroNvim 默认值覆盖
    vim.defer_fn(function()
      vim.opt.timeoutlen = 800
      vim.opt.ttimeoutlen = 0
    end, 200)

    vim.api.nvim_create_autocmd("FileType", {
      pattern = "gitsigns-blame",
      callback = function(args)
        vim.keymap.set("n", "<Esc>", "<Cmd>close<CR>", {
          buffer = args.buf,
          silent = true,
          desc = "Close gitsigns blame window",
        })
      end,
    })

    vim.api.nvim_create_autocmd("User", {
      pattern = "VeryLazy",
      once = true,
      callback = function()
        pcall(vim.keymap.del, "n", "gb")
        vim.keymap.set("n", "gb", toggle_gitsigns_blame, {
          desc = "Toggle gitsigns blame",
          nowait = true,
          silent = true,
        })
      end,
    })
  end,
}
