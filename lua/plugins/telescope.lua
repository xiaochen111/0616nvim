local is_available = require("astrocore").is_available

---@type LazySpec
return {
  {
    "AstroNvim/astrocore",
    ---@param opts AstroCoreOpts
    opts = function(_, opts)
      if not opts.mappings then opts.mappings = require("astrocore").empty_map_table() end
      local maps = opts.mappings
      if maps then
        -- telescope plugin mappings
        if is_available "telescope.nvim" then
          maps.v["<Leader>f"] = { desc = "󰍉 Find" }
          maps.n["<Leader>fT"] = { "<cmd>TodoTelescope<cr>", desc = "Find TODOs" }
          -- buffer switching
          maps.n["<Leader>bt"] = {
            function()
              if #vim.t.bufs > 1 then
                require("telescope.builtin").buffers { sort_mru = true, ignore_current_buffer = true }
              else
                require("astrocore").notify "No other buffers open"
              end
            end,
            desc = "Switch Buffers In Telescope",
          }

          if vim.fn.executable "lazygit" == 1 then
            maps.n["<Leader>tl"] = {
              require("utils").toggle_lazy_git(),
              desc = "ToggleTerm lazygit",
            }
            maps.n["<Leader>gg"] = maps.n["<Leader>tl"]
          end

          if vim.fn.executable "lazydocker" == 1 then
            maps.n["<Leader>td"] = {
              require("utils").toggle_lazy_docker(),
              desc = "ToggleTerm lazydocker",
            }
          end
        end
      end
      opts.mappings = maps
    end,
  },
  {
    "nvim-telescope/telescope.nvim", tag = '0.1.6',
    dependencies = {
      "nvim-lua/popup.nvim",
      "nvim-lua/plenary.nvim",
    },
    -- opts = function(_, opts)
    --   local actions = require "telescope.actions"
    --
    --   return require("astrocore").extend_tbl(opts, {
    --     pickers = {
    --       find_files = {
    --         -- dot file
    --         hidden = true,
    --       },
    --       buffers = {
    --         path_display = { "smart" },
    --         mappings = {
    --           i = { ["<c-d>"] = actions.delete_buffer },
    --           n = { ["d"] = actions.delete_buffer },
    --         },
    --       },
    --     },
    --   })
    -- end,
    -- config = function(...)
    --   local telescope = require "telescope"
    --   require "astronvim.plugins.configs.telescope"(...)
    --   telescope.load_extension "goctl"
    -- end,
  },
  {
    "AstroNvim/astroui",
    ---@type AstroUIOpts
    opts = {
      highlights = {
        -- set highlights for all themes
        -- use a function override to let us use lua to retrieve
        -- colors from highlight group there is no default table
        -- so we don't need to put a parameter for this function
        init = function()
          local get_hlgroup = require("astroui").get_hlgroup
          -- get highlights from highlight groups
          local normal = get_hlgroup "Normal"
          local fg, bg = normal.fg, normal.bg
          local bg_alt = get_hlgroup("Visual").bg
          local green = get_hlgroup("String").fg
          local red = get_hlgroup("Error").fg
          -- return a table of highlights for telescope based on
          -- colors gotten from highlight groups
          return {
            TelescopeBorder = { fg = bg_alt, bg = bg },
            TelescopeNormal = { bg = bg },
            TelescopePreviewBorder = { fg = bg, bg = bg },
            TelescopePreviewNormal = { bg = bg },
            TelescopePreviewTitle = { fg = bg, bg = green },
            TelescopePromptBorder = { fg = bg_alt, bg = bg_alt },
            TelescopePromptNormal = { fg = fg, bg = bg_alt },
            TelescopePromptPrefix = { fg = red, bg = bg_alt },
            TelescopePromptTitle = { fg = bg, bg = red },
            TelescopeResultsBorder = { fg = bg, bg = bg },
            TelescopeResultsNormal = { bg = bg },
            TelescopeResultsTitle = { fg = bg, bg = bg },
          }
        end,
      },
    },
  },
}
