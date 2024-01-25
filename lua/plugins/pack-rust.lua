local utils = require "astrocore"
local function preview_stack_trace()
  local line = vim.api.nvim_get_current_line()
  local pattern = "--> ([^:]+):(%d+):(%d+)"
  local filepath, line_nr, column_nr = string.match(line, pattern)
  if filepath and line_nr and column_nr then
    vim.cmd ":wincmd k"
    vim.cmd("e " .. filepath)
    vim.api.nvim_win_set_cursor(0, { tonumber(line_nr), tonumber(column_nr) })
  end
end

return {
  {
    "AstroNvim/astrolsp",
    opts = {
      handlers = { rust_analyzer = false },
      config = {
        rust_analyzer = {
          on_attach = function()
            vim.api.nvim_create_autocmd("TermClose", {
              pattern = "*cargo run*",
              desc = "Jump to error line",
              callback = function()
                vim.keymap.set(
                  "n",
                  "gd",
                  preview_stack_trace,
                  { silent = true, noremap = true, buffer = true, desc = "Jump to error line" }
                )
              end,
            })
          end,
          settings = {
            ["rust-analyzer"] = {
              cargo = {
                allFeatures = true,
                loadOutDirsFromCheck = true,
                runBuildScripts = true,
              },
              -- Add clippy lints for Rust.
              checkOnSave = {
                allFeatures = true,
                command = "clippy",
                extraArgs = { "--no-deps" },
              },
              procMacro = {
                enable = true,
                ignored = {
                  ["async-trait"] = { "async_trait" },
                  ["napi-derive"] = { "napi" },
                  ["async-recursion"] = { "async_recursion" },
                },
              },
              inlayHints = {
                lifetimeElisionHints = {
                  enable = true,
                  useParameterNames = true,
                },
              },
            },
          },
        },
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      if opts.ensure_installed ~= "all" then
        opts.ensure_installed = utils.list_insert_unique(opts.ensure_installed, "rust", "toml", "ron")
      end
    end,
  },
  {
    "jay-babu/mason-nvim-dap.nvim",
    optional = true,
    opts = function(_, opts)
      -- dap
      opts.ensure_installed = utils.list_insert_unique(opts.ensure_installed, "codelldb")
    end,
  },
  {
    "williamboman/mason-lspconfig.nvim",
    optional = true,
    opts = function(_, opts)
      -- lsp
      opts.ensure_installed = utils.list_insert_unique(opts.ensure_installed, "rust_analyzer")
    end,
  },
  {
    "mrcjkb/rustaceanvim",
    version = "^3",
    ft = "rust",
    opts = function()
      local adapter
      local success, package = pcall(function() return require("mason-registry").get_package "codelldb" end)
      local cfg = require "rustaceanvim.config"
      if success then
        local package_path = package:get_install_path()
        local codelldb_path = package_path .. "/codelldb"
        local liblldb_path = package_path .. "/extension/lldb/lib/liblldb"
        local this_os = vim.loop.os_uname().sysname

        -- The path in windows is different
        if this_os:find "Windows" then
          codelldb_path = package_path .. "\\extension\\adapter\\codelldb.exe"
          liblldb_path = package_path .. "\\extension\\lldb\\bin\\liblldb.dll"
        else
          -- The liblldb extension is .so for linux and .dylib for macOS
          liblldb_path = liblldb_path .. (this_os == "Linux" and ".so" or ".dylib")
        end
        adapter = cfg.get_codelldb_adapter(codelldb_path, liblldb_path)
      else
        ---@diagnostic disable-next-line: missing-parameter
        adapter = cfg.get_codelldb_adapter()
      end
      return { server = require("astrolsp").lsp_opts "rust_analyzer", dap = { adapter = adapter } }
    end,
    config = function(_, opts) vim.g.rustaceanvim = opts end,
  },
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      {
        "Saecki/crates.nvim",
        event = { "BufRead Cargo.toml" },
        opts = {
          src = {
            cmp = { enabled = true },
          },
        },
      },
    },
    ---@param opts cmp.ConfigSchema
    opts = function(_, opts)
      opts.sources = opts.sources or {}
      table.insert(opts.sources, { name = "crates" })
      return opts
    end,
  },
  {
    "Saecki/crates.nvim",
    lazy = true,
    opts = {
      null_ls = {
        enabled = true,
        name = "crates.nvim",
      },
    },
  },
}
