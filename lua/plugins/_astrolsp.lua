local ts_definition_filetypes = {
  "javascript",
  "typescript",
}

local ts_source_definition_filetypes = {
  "javascriptreact",
  "typescriptreact",
}

local function get_workspace_root(bufnr)
  for _, client in ipairs(vim.lsp.get_clients { bufnr = bufnr }) do
    local root_dir = client.config and client.config.root_dir
    if type(root_dir) == "string" and root_dir ~= "" then return root_dir end
  end

  local current_file = vim.api.nvim_buf_get_name(bufnr)
  return vim.fs.root(current_file, { "tsconfig.json", "jsconfig.json", "package.json", ".git" })
    or vim.fn.getcwd()
end

local function open_items_in_quickfix(title, items)
  if vim.tbl_isempty(items) then return end
  vim.fn.setqflist({}, "r", {
    title = title,
    items = items,
  })
  vim.cmd "copen"
end

local function open_items_in_picker(title, items)
  if vim.tbl_isempty(items) then return end

  local ok_pickers, pickers = pcall(require, "telescope.pickers")
  local ok_finders, finders = pcall(require, "telescope.finders")
  local ok_config, telescope_config = pcall(require, "telescope.config")
  local ok_actions, actions = pcall(require, "telescope.actions")
  local ok_state, action_state = pcall(require, "telescope.actions.state")
  local ok_themes, themes = pcall(require, "telescope.themes")
  local ok_previewers, previewers = pcall(require, "telescope.previewers")

  if not (ok_pickers and ok_finders and ok_config and ok_actions and ok_state and ok_themes and ok_previewers) then
    return open_items_in_quickfix(title, items)
  end

  local make_entry = function(item)
    local filename = item.filename or item.bufnr and vim.api.nvim_buf_get_name(item.bufnr) or ""
    local display = string.format("%s:%d:%d  %s", vim.fn.fnamemodify(filename, ":."), item.lnum or 0, item.col or 0, item.text or "")

    return {
      value = item,
      display = display,
      ordinal = table.concat({
        filename,
        tostring(item.lnum or 0),
        tostring(item.col or 0),
        item.text or "",
      }, " "),
      filename = filename,
      lnum = item.lnum,
      col = item.col,
    }
  end

  pickers
    .new(themes.get_dropdown {
      prompt_title = title,
      previewer = true,
      results_title = false,
      layout_strategy = "horizontal",
      layout_config = {
        width = 0.9,
        height = 0.6,
        preview_width = 0.55,
      },
    }, {
      finder = finders.new_table {
        results = items,
        entry_maker = make_entry,
      },
      sorter = telescope_config.values.generic_sorter {},
      previewer = telescope_config.values.grep_previewer {},
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if not selection or not selection.value then return end

          local target = selection.value
          vim.cmd(("edit %s"):format(vim.fn.fnameescape(target.filename)))
          vim.api.nvim_win_set_cursor(0, { target.lnum, math.max((target.col or 1) - 1, 0) })
        end)

        return true
      end,
    })
    :find()
end

local function get_current_symbol()
  local symbol = vim.fn.expand "<cword>"
  if type(symbol) ~= "string" or symbol == "" then return nil end
  return symbol
end

local function get_current_module_stem(bufnr)
  local filename = vim.api.nvim_buf_get_name(bufnr)
  if filename == "" then return nil end
  return vim.fn.fnamemodify(filename, ":t:r")
end

local function buffer_has_default_export_of_symbol(bufnr, symbol)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local escaped = vim.pesc(symbol)
  local pattern = "^%s*export%s+default%s+" .. escaped .. "%s*;?%s*$"

  for _, line in ipairs(lines) do
    if line:match(pattern) then return true end
  end

  return false
end

local function dedupe_items(items)
  local deduped, seen = {}, {}

  for _, item in ipairs(items) do
    local key = table.concat({
      item.filename or "",
      tostring(item.lnum or 0),
      tostring(item.col or 0),
      item.text or "",
    }, ":")
    if not seen[key] then
      seen[key] = true
      deduped[#deduped + 1] = item
    end
  end

  table.sort(deduped, function(a, b)
    if a.filename == b.filename then
      if a.lnum == b.lnum then return (a.col or 0) < (b.col or 0) end
      return (a.lnum or 0) < (b.lnum or 0)
    end
    return (a.filename or "") < (b.filename or "")
  end)

  return deduped
end

local function collect_text_search_items(root, terms)
  local items = {}

  for _, term in ipairs(terms) do
    if term and term ~= "" then
      local output = vim.fn.systemlist({ "rg", "--vimgrep", "--smart-case", term, root })
      if vim.v.shell_error ~= 0 and vim.v.shell_error ~= 1 then
        vim.notify(("rg search failed for %s"):format(term), vim.log.levels.WARN)
      else
        for _, line in ipairs(output) do
          local filename, lnum, col, text = line:match "^(.-):(%d+):(%d+):(.*)$"
          if filename and lnum and col and text then
            items[#items + 1] = {
              filename = filename,
              lnum = tonumber(lnum),
              col = tonumber(col),
              text = text,
            }
          end
        end
      end
    end
  end

  return items
end

local function show_symbol_references()
  local bufnr = vim.api.nvim_get_current_buf()
  local symbol = get_current_symbol()
  if not symbol then return end
  local root = get_workspace_root(bufnr)
  local items = {}
  local params = vim.lsp.util.make_position_params()
  params.context = { includeDeclaration = false }

  vim.lsp.buf_request_all(bufnr, "textDocument/references", params, function(results)
    local locations = {}

    for _, response in pairs(results or {}) do
      if response and not response.err and response.result then
        if response.result.uri or response.result.targetUri then
          locations[#locations + 1] = response.result
        else
          vim.list_extend(locations, response.result)
        end
      end
    end

    if not vim.tbl_isempty(locations) then
      items = vim.lsp.util.locations_to_items(locations, bufnr)
    end

    local search_terms = { symbol }
    if buffer_has_default_export_of_symbol(bufnr, symbol) then
      local module_stem = get_current_module_stem(bufnr)
      if module_stem and module_stem ~= symbol then search_terms[#search_terms + 1] = module_stem end
    end

    vim.list_extend(items, collect_text_search_items(root, search_terms))
    items = dedupe_items(items)

    if vim.tbl_isempty(items) then
      return vim.notify(("No references for %s"):format(symbol), vim.log.levels.INFO)
    end

    open_items_in_picker(("References: %s"):format(symbol), items)
  end)
end

local function goto_source_definition_or_implementation()
  local bufnr = vim.api.nvim_get_current_buf()
  local filetype = vim.bo[bufnr].filetype

  if vim.tbl_contains(ts_definition_filetypes, filetype) then
    return vim.lsp.buf.definition()
  end

  if not vim.tbl_contains(ts_source_definition_filetypes, filetype) then
    return vim.lsp.buf.implementation()
  end

  local fallback = vim.lsp.buf.definition
  local clients = vim.lsp.get_clients { bufnr = bufnr }
  local source_definition_client, command

  for _, client in ipairs(clients) do
    if client:supports_method "workspace/executeCommand" then
      if client.name == "vtsls" then
        source_definition_client = client
        command = "typescript.goToSourceDefinition"
        break
      elseif client.name == "ts_ls" or client.name == "tsserver" then
        source_definition_client = client
        command = "_typescript.goToSourceDefinition"
      end
    end
  end

  if not source_definition_client or not command then return fallback() end

  local params = vim.lsp.util.make_position_params()
  source_definition_client:request("workspace/executeCommand", {
    command = command,
    arguments = { params.textDocument.uri, params.position },
  }, function(err, result, ctx)
    if err or not result or vim.tbl_isempty(result) then return fallback() end

    local handler = vim.lsp.handlers["textDocument/definition"]
    if handler then return handler(nil, result, ctx) end

    return vim.lsp.util.jump_to_location(result[1], source_definition_client.offset_encoding)
  end, bufnr)
end

---@type LazySpec
return {
  "AstroNvim/astrolsp",
  ---@type AstroLSPOpts
  opts = {
    features = {
      -- Configuration table of features provided by AstroLSP
      autoformat = false, -- enable or disable auto formatting on start
      inlay_hints = false, -- nvim >= 0.10 这个如果开启 方法里的变量会自动给出类型提示 还是关闭了  有点太花了😅
    },
    -- Configuration options for controlling formatting with language servers
    formatting = {
      -- control auto formatting on save
      format_on_save = false,
      -- disable formatting capabilities for specific language servers
      disabled = {},
      -- default format timeout
      timeout_ms = 600000,
    },
    capabilities = {
      workspace = {
        didChangeWatchedFiles = { dynamicRegistration = true },
      },
    },
    mappings = {
      n = {
        -- ["gdd"] = {
        --    require("telescope.builtin").lsp_references
        -- },
        ["gd"] = {
           vim.lsp.buf.definition,
           cond = "textDocument/definition",
        },
        ["gI"] = {
           goto_source_definition_or_implementation,
        },
        ["gR"] = {
           show_symbol_references,
           cond = function(client)
             return client.supports_method "textDocument/references"
               or client.supports_method "textDocument/definition"
           end,
        }
      }
    }
  },
}


-- leader fo 打开最近的文件
-- leader ff 打开文件搜索
-- leader fw 全局搜索文字
