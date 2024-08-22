local utils = require "utils"
local system = vim.loop.os_uname().sysname

return {
  "AstroNvim/astrocore",
  ---@param opts AstroCoreOpts
  opts = function(_, opts)
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

      maps.n["<Leader>wo"] = { "<C-w>o", desc = "Close other screen" }
      maps.v["p"] = { "pgvy", desc = "Paste" }

      if vim.fn.executable "btm" == 1 then
        maps.n["<Leader>tT"] = { function() utils.toggle_term_cmd "btm" end, desc = "ToggleTerm btm" }
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

      -- lsp restart
      maps.n["<Leader>lm"] = { "<Cmd>LspRestart<CR>", desc = "Lsp restart" }
      maps.n["<Leader>lg"] = { "<Cmd>LspLog<CR>", desc = "Show lsp log" }


      maps.n["}"] = {"%"}
      maps.n["J"] = {'5j'}
      maps.n["K"] = {'5k'}
      maps.n["<leader>a"] = {function ()
        vim.cmd.Neotree "focus"
      end}

      maps.n["<leader>n"] = {"*"}

      maps.n["<leader>h"] = {"^"}
      maps.n["<leader>l"] = {"$"}
      maps.n["<leader>L"] = {"$"}
      maps.n["<leader>j"] = {function() vim.diagnostic.goto_next() end}
      maps.n["<leader>k"] = {function() vim.diagnostic.goto_prev() end}
      maps.n["gj"] = {function() require('gitsigns').next_hunk() end}
      maps.n["gk"] = {function() require('gitsigns').prev_hunk() end}
      maps.n["gh"] = {function() vim.lsp.buf.hover() end}
      maps.n["gr"] = {function() require("gitsigns").reset_hunk() end}
      -- 来预览当前光标所在的更改块。
      maps.n["gp"] = {function() require("gitsigns").preview_hunk() end}
      maps.n["<C-m>"] = {function() vim.lsp.buf.code_action() end}

      maps.n["zm"] = {"zM"}
      maps.n["zr"] = {"zR"}
      maps.n["zo"] = {"zO"}
      maps.n["zc"] = {"zC"}
      maps.n["s"] = {'\"_s'}
      maps.n["c"] = {'\"_c'}

      maps.v["J"] = {'5j'}
      maps.v["K"] = {'5k'}
      maps.v["<leader>h"] = {"^"}
      maps.v["<leader>l"] = {"$"}
      maps.v["log"] = {function() require('utils').log_variable() end}

      maps.i["jj"] = {'<Esc>'}
      maps.n["f"] = {function() require('hop').hint_char1() end}

    end

    opts.mappings = maps
  end,
}
