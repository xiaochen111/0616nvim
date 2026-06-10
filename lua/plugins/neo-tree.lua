---@type LazySpec
return {
  "nvim-neo-tree/neo-tree.nvim",
  -- dependencies = { "miversen33/netman.nvim" },
  config = function(_, opts)
    require("neo-tree").setup(opts)

    local filesystem = require "neo-tree.sources.filesystem"
    local filesystem_commands = require "neo-tree.sources.filesystem.commands"
    local filter_external = require "neo-tree.sources.filesystem.lib.filter_external"
    local renderer = require "neo-tree.ui.renderer"
    local utils = require "neo-tree.utils"
    local compat = require "neo-tree.utils._compat"

    local original_reset_search = filesystem.reset_search

    filesystem.reset_search = function(state, refresh, open_current_node)
      if not open_current_node then return original_reset_search(state, refresh, open_current_node) end

      filter_external.cancel()
      state.fuzzy_finder_mode = nil
      state.use_fzy = nil
      state.fzy_sort_result_scores = nil
      state.sort_function_override = nil

      if refresh == nil then refresh = true end
      if state.open_folders_before_search then
        state.force_open_folders = vim.deepcopy(state.open_folders_before_search, compat.noref())
      else
        state.force_open_folders = nil
      end
      state.search_pattern = nil
      state.open_folders_before_search = nil

      local success, node = pcall(state.tree.get_node, state.tree)
      if not (success and node) then return end

      local path = node:get_id()
      renderer.position.set(state, path)
      if node.type == "directory" then
        path = utils.remove_trailing_slash(path)
        filesystem.navigate(state, nil, path, function() pcall(renderer.focus_node, state, path, false) end)
        return
      end

      filesystem_commands.open_drop(state)
      if refresh and state.current_position ~= "current" and state.current_position ~= "float" then
        filesystem.navigate(state, nil, path)
      end
    end
  end,
  opts = function(_, opts)
    return require("astrocore").extend_tbl(opts, {
      close_if_last_window = true,
      enable_diagnostics = true,
      commands = {
        copy_relative_path = function(state)
          local node = state.tree:get_node()
          if not node then return end

          local path = node.path or node:get_id()
          local root = state.path
          local relative_path

          if type(vim.fs) == "table" and vim.fs.relpath then relative_path = vim.fs.relpath(root, path) end
          if not relative_path or relative_path == "" then relative_path = vim.fn.fnamemodify(path, ":.") end

          vim.fn.setreg("+", relative_path)
          vim.fn.setreg('"', relative_path)
          require("utils").copy_to_osc52(relative_path)
          vim.notify("Copied: " .. relative_path, vim.log.levels.INFO)
        end,
      },
      popup_border_style = "rounded",
      sources = {
        "filesystem",
      },
      source_selector = {
        winbar = false,
      },
      filesystem = {
        -- hijack_netrw_behavior = "open_default",
        use_libuv_file_watcher = true,
        bind_to_cwd = false,
        find_args = function(cmd, path, _, args)
          if cmd == "fd" or cmd == "fdfind" then
            vim.list_extend(args, { "--exclude", "dist" })
          elseif cmd == "find" then
            return vim.list_extend({
              path,
              "-path",
              "*/dist",
              "-prune",
              "-o",
            }, vim.list_slice(args, 2))
          end
          return args
        end,
        follow_current_file = {
          enabled = true,
        },
        window = {
          mappings = {
            ["<cr>"] = "open_drop",
            ["y"] = "copy_relative_path",
            ["z"] = { "close_all_nodes", nowait = false },
            ["zz"] = { function() vim.cmd "normal! zz" end, nowait = false },
          },
        },
        filtered_items = {
          always_show = { ".github", ".gitignore" },
          hide_dotfiles = false,
          hide_gitignored = false,
          hide_by_name = {
            ".git",
            -- "node_modules",
          },
          never_show = {
            ".DS_Store",
            "thumbs.db",
          },
        },
      },
      window = {
        position = "left",
      }
    })
  end,
}
