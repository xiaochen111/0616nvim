local utils = require "astrocore"
local is_available = require("astrocore").is_available
local set_mappings = require("astrocore").set_mappings

return {
  { "microsoft/python-type-stubs", ft = "python" },
  {
    "AstroNvim/astrolsp",
    ---@type AstroLSPOpts
    opts = {
      servers = { "pylance" },
      ---@diagnostic disable: missing-fields
      config = {
        pylance = {
          on_attach = function(client, bufnr)
            if is_available "venv-selector.nvim" then
              set_mappings({
                n = {
                  ["<Leader>lv"] = {
                    "<cmd>VenvSelect<CR>",
                    desc = "Select VirtualEnv",
                  },
                  ["<Leader>lV"] = {
                    function()
                      require("astrocore").notify(
                        "Current Env:" .. require("venv-selector").get_active_venv(),
                        vim.log.levels.INFO
                      )
                    end,
                    desc = "Show Current VirtualEnv",
                  },
                },
              }, { buffer = bufnr })
            end
            vim.api.nvim_buf_create_user_command(
              bufnr,
              "PylanceOrganizeImports",
              function()
                vim.lsp.buf.execute_command {
                  command = "pyright.organizeimports",
                  arguments = { vim.uri_from_bufnr(0) },
                }
              end,
              { desc = "Organize Imports" }
            )
          end,
          filetypes = { "python" },
          root_dir = function(...)
            return require("lspconfig.util").root_pattern(unpack {
              "pyproject.toml",
              "setup.py",
              "setup.cfg",
              "requirements.txt",
              "Pipfile",
              "pyrightconfig.json",
            })(...)
          end,
          cmd = { "pylance", "--stdio" },
          single_file_support = true,
          settings = {
            python = {
              pythonPath = vim.env.VIRTUAL_ENV and vim.env.VIRTUAL_ENV .. "/bin/python",
              analysis = {
                autoSearchPaths = true,
                useLibraryCodeForTypes = true,
                diagnosticMode = "workspace",
                typeCheckingMode = "basic",
                autoImportCompletions = true,
                completeFunctionParens = true,
                indexing = true,
                inlayHints = {
                  variableTypes = true,
                  functionReturnTypes = true,
                  callArgumentNames = true,
                  pytestParameters = true,
                },
                stubPath = vim.fn.stdpath "data" .. "/lazy/python-type-stubs",
                diagnosticSeverityOverrides = {
                  reportUnusedImport = "information",
                  reportUnusedFunction = "information",
                  reportUnusedVariable = "information",
                  reportGeneralTypeIssues = "none",
                  reportOptionalMemberAccess = "none",
                  reportOptionalSubscript = "none",
                  reportPrivateImportUsage = "none",
                },
              },
            },
          },
          handlers = {
            ["workspace/executeCommand"] = function(_, result)
              if result and result.label == "Extract Method" then
                vim.ui.input({ prompt = "New name: ", default = result.data.newSymbolName }, function(input)
                  if input and #input > 0 then vim.lsp.buf.rename(input) end
                end)
              else
                print(result.label)
              end
            end,
          },
          commands = {
            PylanceExtractMethod = {
              function()
                local arguments =
                  { vim.uri_from_bufnr(0):gsub("file://", ""), require("vim.lsp.util").make_given_range_params().range }
                vim.lsp.buf.execute_command { command = "pylance.extractMethod", arguments = arguments }
              end,
              description = "Extract Method",
              range = 2,
            },
            PylanceExtractVariable = {
              function()
                local arguments =
                  { vim.uri_from_bufnr(0):gsub("file://", ""), require("vim.lsp.util").make_given_range_params().range }
                vim.lsp.buf.execute_command { command = "pylance.extractVariable", arguments = arguments }
              end,
              description = "Extract Variable",
              range = 2,
            },
          },
          docs = {
            description = "https://github.com/microsoft/pylance-release\n\n`pylance`, Fast, feature-rich language support for Python",
          },
        },
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    optional = true,
    opts = function(_, opts)
      if opts.ensure_installed ~= "all" then
        opts.ensure_installed = utils.list_insert_unique(opts.ensure_installed, "python", "toml")
      end
    end,
  },
  {
    "jay-babu/mason-null-ls.nvim",
    optional = true,
    opts = function(_, opts) opts.ensure_installed = utils.list_insert_unique(opts.ensure_installed, "ruff") end,
  },
  {
    "jay-babu/mason-nvim-dap.nvim",
    optional = true,
    opts = function(_, opts)
      opts.ensure_installed = utils.list_insert_unique(opts.ensure_installed, "python")
      if not opts.handlers then opts.handlers = {} end
      opts.handlers.python = function() end -- make sure python doesn't get set up by mason-nvim-dap, it's being set up by nvim-dap-python
    end,
  },
  {
    "linux-cultist/venv-selector.nvim",
    opts = {
      anaconda_base_path = "~/miniconda3",
      anaconda_envs_path = "~/miniconda3/envs",
    },
  },
  {
    "mfussenegger/nvim-dap-python",
    dependencies = { "mfussenegger/nvim-dap" },
    ft = "python",
    config = function(_, opts)
      local path = require("mason-registry").get_package("debugpy"):get_install_path() .. "/venv/bin/python"
      require("dap-python").setup(path, opts)
    end,
  },
}
