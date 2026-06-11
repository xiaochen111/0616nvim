---@type LazySpec
return {
  {
    "olimorris/codecompanion.nvim",
    cmd = {
      "CodeCompanion",
      "CodeCompanionActions",
      "CodeCompanionChat",
      "CodeCompanionCmd",
    },
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    opts = {
      opts = {
        language = "Chinese",
      },
      adapters = {
        http = {
          opts = {
            show_model_choices = false,
            show_presets = false,
          },
          volcengine_ark = function()
            return require("codecompanion.adapters").extend("openai_compatible", {
              env = {
                api_key = function()
                  return vim.env.ARK_API_KEY ~= nil and vim.env.ARK_API_KEY ~= ""
                      and vim.env.ARK_API_KEY
                    or "ark-ef7327c4-c314-4552-8e8b-39c0748550d6-09eb1"
                end,
                url = "https://ark.cn-beijing.volces.com/api/coding",
                chat_url = "/v1/chat/completions",
              },
              schema = {
                model = {
                  default = "ark-code-latest",
                  choices = {
                    "ark-code-latest",
                  },
                },
              },
            })
          end,
        },
      },
      strategies = {
        chat = {
          adapter = "volcengine_ark",
        },
        inline = {
          adapter = "volcengine_ark",
        },
      },
      display = {
        chat = {
          intro_message = "CodeCompanion via Volcengine Ark",
        },
      },
    },
    keys = {
      { "<Leader>cc", "<Cmd>CodeCompanionChat<CR>", desc = "CodeCompanion Chat" },
      { "<Leader>ca", "<Cmd>CodeCompanionActions<CR>", desc = "CodeCompanion Actions" },
      { "<Leader>ci", "<Cmd>CodeCompanion<CR>", mode = { "n", "v" }, desc = "CodeCompanion Inline" },
    },
    init = function()
      if vim.env.ARK_API_KEY and vim.env.ARK_API_KEY ~= "" then return end
    end,
  },
}
