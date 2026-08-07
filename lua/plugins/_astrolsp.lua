local ts_definition_filetypes = {
  "javascript",
  "typescript",
}

local ts_source_definition_filetypes = {
  "javascriptreact",
  "typescriptreact",
}

local ts_reference_filetypes = {
  javascript = true,
  javascriptreact = true,
  typescript = true,
  typescriptreact = true,
}

local ts_client_attach_time = {}
local ts_root_reference_ready = {}
local ts_warmup_threshold_ms = 15000

local function get_workspace_root(bufnr)
  for _, client in ipairs(vim.lsp.get_clients { bufnr = bufnr }) do
    local root_dir = client.config and client.config.root_dir
    if type(root_dir) == "string" and root_dir ~= "" then return root_dir end
  end

  local current_file = vim.api.nvim_buf_get_name(bufnr)
  return vim.fs.root(current_file, { "tsconfig.json", "jsconfig.json", "package.json", ".git" })
    or vim.fn.getcwd()
end

local function is_typescript_client(client)
  return client and (client.name == "vtsls" or client.name == "ts_ls" or client.name == "tsserver")
end

local function get_typescript_client(bufnr)
  for _, client in ipairs(vim.lsp.get_clients { bufnr = bufnr }) do
    if is_typescript_client(client) then return client end
  end
end

local function mark_ts_client_attach(client)
  if not is_typescript_client(client) or ts_client_attach_time[client.id] then return end
  ts_client_attach_time[client.id] = vim.uv.now()
end

local function get_ts_root_key(bufnr, client)
  client = client or get_typescript_client(bufnr)
  if not client then return nil end
  return (client.config and client.config.root_dir) or get_workspace_root(bufnr)
end

local function mark_ts_root_ready(bufnr, client)
  local root_key = get_ts_root_key(bufnr, client)
  if root_key and root_key ~= "" then ts_root_reference_ready[root_key] = true end
end

local function is_ts_root_ready(bufnr, client)
  local root_key = get_ts_root_key(bufnr, client)
  return root_key and ts_root_reference_ready[root_key] == true or false
end

local function is_ts_client_in_warmup(bufnr)
  local client = get_typescript_client(bufnr)
  if not client then return false end
  mark_ts_client_attach(client)
  if is_ts_root_ready(bufnr, client) then return false end
  local attached_at = ts_client_attach_time[client.id]
  if not attached_at then return false end
  return (vim.uv.now() - attached_at) < ts_warmup_threshold_ms
end

local function open_items_in_quickfix(title, items)
  if vim.tbl_isempty(items) then return end
  vim.fn.setqflist({}, "r", {
    title = title,
    items = items,
  })
  vim.cmd "copen"
end

local function jump_to_item(item)
  local filename = item.filename or item.bufnr and vim.api.nvim_buf_get_name(item.bufnr) or ""
  if filename == "" then return end

  vim.cmd(("edit %s"):format(vim.fn.fnameescape(filename)))
  vim.api.nvim_win_set_cursor(0, { item.lnum, math.max((item.col or 1) - 1, 0) })
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

          jump_to_item(selection.value)
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
  local globs = {
    "*.ts",
    "*.tsx",
    "*.js",
    "*.jsx",
  }

  for _, term in ipairs(terms) do
    if term and term ~= "" then
      local escaped = term:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "\\%1")
      local pattern = ([[\b%s\b]]):format(escaped)
      local command = {
        "rg",
        "--vimgrep",
        "--smart-case",
        "--glob",
        "!node_modules/**",
        "--glob",
        "!.next/**",
        "--glob",
        "!dist/**",
        "--glob",
        "!build/**",
      }

      for _, glob in ipairs(globs) do
        command[#command + 1] = "--glob"
        command[#command + 1] = glob
      end

      command[#command + 1] = pattern
      command[#command + 1] = root

      local output = vim.fn.systemlist(command)
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

local function collect_reference_items(results)
  local items = {}

  for client_id, response in pairs(results or {}) do
    if response and not response.err and response.result then
      local client = vim.lsp.get_client_by_id(client_id)
      local position_encoding = client and client.offset_encoding or "utf-16"
      vim.list_extend(items, vim.lsp.util.locations_to_items(response.result, position_encoding))
    end
  end

  return items
end

local function collect_location_items(results)
  local items = {}

  for client_id, response in pairs(results or {}) do
    if response and response.err then
      local message = response.err.message or tostring(response.err)
      vim.notify(message, vim.log.levels.ERROR)
    elseif response and response.result then
      local client = vim.lsp.get_client_by_id(client_id)
      local position_encoding = client and client.offset_encoding or "utf-16"
      vim.list_extend(items, vim.lsp.util.locations_to_items(response.result, position_encoding))
    end
  end

  return dedupe_items(items)
end

local function handle_location_items(title, empty_message, items)
  if vim.tbl_isempty(items) then
    vim.notify(empty_message, vim.log.levels.INFO)
    return
  end

  if #items == 1 then
    jump_to_item(items[1])
    return
  end

  open_items_in_picker(title, items)
end

local function show_symbol_implementations()
  local bufnr = vim.api.nvim_get_current_buf()
  local win = vim.api.nvim_get_current_win()

  vim.lsp.buf_request_all(bufnr, "textDocument/implementation", function(client)
    return vim.lsp.util.make_position_params(win, client.offset_encoding)
  end, function(results)
    local items = collect_location_items(results)
    handle_location_items("Implementations", "No implementations found", items)
  end)
end

local function get_typescript_progress()
  local ok, astrolsp = pcall(require, "astrolsp")
  if not ok or type(astrolsp.lsp_progress) ~= "table" then return nil end

  for id, progress in pairs(astrolsp.lsp_progress) do
    local client_id = tonumber(type(id) == "string" and id:match "^(%d+)%.")
    local client = client_id and vim.lsp.get_client_by_id(client_id) or nil
    if is_typescript_client(client) then
      return {
        title = progress.title,
        message = progress.message,
        percentage = progress.percentage,
      }
    end
  end

  return nil
end

local function has_cross_file_items(items, current_file)
  local normalized_current = vim.fs.normalize(current_file or "")
  if normalized_current == "" then return false end

  for _, item in ipairs(items or {}) do
    local filename = item.filename and vim.fs.normalize(item.filename) or ""
    if filename ~= "" and filename ~= normalized_current then return true end
  end

  return false
end

local function has_typescript_reference_client(bufnr)
  for _, client in ipairs(vim.lsp.get_clients { bufnr = bufnr }) do
    if is_typescript_client(client) and client.supports_method "textDocument/references" then
      return true
    end
  end

  return false
end

local function request_reference_results(bufnr, callback)
  local win = vim.api.nvim_get_current_win()
  vim.lsp.buf_request_all(bufnr, "textDocument/references", function(client)
    local params = vim.lsp.util.make_position_params(win, client.offset_encoding)
    params.context = { includeDeclaration = false }
    return params
  end, callback)
end

local function resolve_reference_items(bufnr, callback, opts)
  opts = opts or {}

  request_reference_results(bufnr, function(results)
    local items = collect_reference_items(results)
    if not vim.tbl_isempty(items) then return callback(items) end

    if opts.remaining_retries and opts.remaining_retries > 0 and has_typescript_reference_client(bufnr) then
      return vim.defer_fn(function()
        resolve_reference_items(bufnr, callback, {
          remaining_retries = opts.remaining_retries - 1,
          retry_delay = opts.retry_delay,
        })
      end, opts.retry_delay or 400)
    end

    callback(items)
  end)
end

local function show_symbol_references()
  local bufnr = vim.api.nvim_get_current_buf()
  local symbol = get_current_symbol()
  if not symbol then return end
  local root = get_workspace_root(bufnr)
  local is_ts_reference_file = ts_reference_filetypes[vim.bo[bufnr].filetype] == true
  local current_file = vim.api.nvim_buf_get_name(bufnr)
  resolve_reference_items(bufnr, function(items)
    local used_text_fallback = false
    local picker_title = ("References: %s"):format(symbol)
    local only_current_file_references = false
    local ts_progress = is_ts_reference_file and get_typescript_progress() or nil

    if vim.tbl_isempty(items) then
      local search_terms = { symbol }
      if buffer_has_default_export_of_symbol(bufnr, symbol) then
        local module_stem = get_current_module_stem(bufnr)
        if module_stem and module_stem ~= symbol then search_terms[#search_terms + 1] = module_stem end
      end

      items = collect_text_search_items(root, search_terms)
      used_text_fallback = not vim.tbl_isempty(items)
    end

    items = dedupe_items(items)

    if vim.tbl_isempty(items) then
      return vim.notify(("No references for %s"):format(symbol), vim.log.levels.INFO)
    end

    if is_ts_reference_file and not used_text_fallback and not has_cross_file_items(items, current_file) then
      only_current_file_references = true
    elseif is_ts_reference_file and not used_text_fallback then
      mark_ts_root_ready(bufnr)
    end

    if used_text_fallback and ts_progress then
      picker_title = ("TS LSP 索引中，当前为文本匹配: %s"):format(symbol)
      vim.notify(
        ("TS LSP 正在索引%s，当前为 %s 的文本匹配结果"):format(
          ts_progress.message and ("（" .. ts_progress.message .. "）") or "",
          symbol
        ),
        vim.log.levels.WARN
      )
    elseif used_text_fallback and is_ts_reference_file and is_ts_client_in_warmup(bufnr) then
      picker_title = ("TS LSP 预热中，当前为文本匹配: %s"):format(symbol)
      vim.notify(
        ("TS LSP 尚未上报 progress，当前可能仍在预热，先展示 %s 的文本匹配结果"):format(symbol),
        vim.log.levels.WARN
      )
    elseif only_current_file_references and ts_progress then
      picker_title = ("TS LSP 索引中，当前仅文件内引用: %s"):format(symbol)
      vim.notify(
        ("TS LSP 正在索引%s，%s 当前仅显示文件内引用"):format(
          ts_progress.message and ("（" .. ts_progress.message .. "）") or "",
          symbol
        ),
        vim.log.levels.WARN
      )
    elseif only_current_file_references and is_ts_reference_file and is_ts_client_in_warmup(bufnr) then
      picker_title = ("TS LSP 预热中，当前仅文件内引用: %s"):format(symbol)
      vim.notify(
        ("TS LSP 尚未上报 progress，当前可能仍在预热，%s 暂时只显示文件内引用"):format(symbol),
        vim.log.levels.WARN
      )
    end

    open_items_in_picker(picker_title, items)
  end, {
    remaining_retries = 2,
    retry_delay = 300,
  })
end

local function get_code_action_title(action)
  if type(action.title) == "string" and action.title ~= "" then return action.title end
  return "<unnamed code action>"
end

local function is_quick_fix_like_action(action)
  local kind = type(action.kind) == "string" and action.kind or ""
  if kind == "" then return true end
  return kind == "quickfix"
    or vim.startswith(kind, "quickfix.")
    or vim.startswith(kind, "source.addMissingImports")
    or vim.startswith(kind, "source.fixAll")
end

local quick_fix_kinds = {
  "quickfix",
  "source.addMissingImports",
  "source.addMissingImports.ts",
  "source.fixAll",
  "source.fixAll.ts",
}

local function get_lsp_diagnostics_at_cursor(bufnr, lnum)
  local diagnostics = vim.diagnostic.get(bufnr, { lnum = lnum })
  return vim.tbl_map(function(diag) return (diag.user_data and diag.user_data.lsp) or diag end, diagnostics)
end

local function collect_code_actions(bufnr, context, callback)
  local params = vim.lsp.util.make_range_params(0, "utf-16")
  params.context = context or {}

  vim.lsp.buf_request_all(bufnr, "textDocument/codeAction", params, function(results)
    local actions = {}

    for client_id, response in pairs(results or {}) do
      if response and not response.err and response.result then
        local client = vim.lsp.get_client_by_id(client_id)
        for _, action in ipairs(response.result) do
          actions[#actions + 1] = {
            action = action,
            client = client,
            bufnr = bufnr,
          }
        end
      end
    end

    callback(actions, results)
  end)
end

local function apply_code_action(action, client)
  if not action then return end

  if action.edit then
    vim.lsp.util.apply_workspace_edit(action.edit, client and client.offset_encoding or "utf-16")
  end

  local command = action.command
  if type(command) == "table" then
    local command_client = client
    if command_client then
      command_client:exec_cmd(command, { bufnr = vim.api.nvim_get_current_buf() })
    else
      vim.lsp.buf.execute_command(command)
    end
  elseif type(command) == "string" and command ~= "" then
    vim.lsp.buf.execute_command {
      command = command,
      arguments = action.arguments,
    }
  end
end

local function resolve_and_apply_code_action(action, client, bufnr)
  if not client or not client:supports_method "codeAction/resolve" then
    return apply_code_action(action, client)
  end

  if action.edit or action.command then return apply_code_action(action, client) end

  client:request("codeAction/resolve", action, function(err, resolved)
    if err then
      return vim.notify(("Code action resolve failed: %s"):format(err.message), vim.log.levels.WARN)
    end

    apply_code_action(resolved or action, client)
  end, bufnr)
end

local function select_code_action_with_picker(actions)
  local ok_pickers, pickers = pcall(require, "telescope.pickers")
  local ok_finders, finders = pcall(require, "telescope.finders")
  local ok_config, telescope_config = pcall(require, "telescope.config")
  local ok_actions, telescope_actions = pcall(require, "telescope.actions")
  local ok_state, action_state = pcall(require, "telescope.actions.state")
  local ok_themes, themes = pcall(require, "telescope.themes")

  if not (ok_pickers and ok_finders and ok_config and ok_actions and ok_state and ok_themes) then
    return vim.ui.select(actions, {
      prompt = "Quick fix",
      format_item = function(item) return get_code_action_title(item.action) end,
    }, function(choice)
      if choice then resolve_and_apply_code_action(choice.action, choice.client, choice.bufnr) end
    end)
  end

  pickers
    .new(themes.get_dropdown {
      prompt_title = "Quick fix",
      previewer = false,
      results_title = false,
      layout_config = {
        width = 0.6,
        height = 0.4,
      },
    }, {
      finder = finders.new_table {
        results = actions,
        entry_maker = function(item)
          local title = get_code_action_title(item.action)
          return {
            value = item,
            display = title,
            ordinal = title,
          }
        end,
      },
      sorter = telescope_config.values.generic_sorter {},
      attach_mappings = function(prompt_bufnr)
        telescope_actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          telescope_actions.close(prompt_bufnr)
          if selection and selection.value then
            resolve_and_apply_code_action(selection.value.action, selection.value.client, selection.value.bufnr)
          end
        end)

        return true
      end,
    })
    :find()
end

local function quick_fix()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local context = {
    only = quick_fix_kinds,
    diagnostics = get_lsp_diagnostics_at_cursor(bufnr, cursor[1] - 1),
  }

  collect_code_actions(bufnr, context, function(all_actions)
    local actions = vim.tbl_filter(function(item) return is_quick_fix_like_action(item.action) end, all_actions)

    if vim.tbl_isempty(actions) then
      return vim.notify("No quick fixes available", vim.log.levels.INFO)
    end

    table.sort(actions, function(a, b)
      return get_code_action_title(a.action):lower() < get_code_action_title(b.action):lower()
    end)

    if #actions == 1 then return resolve_and_apply_code_action(actions[1].action, actions[1].client, bufnr) end

    select_code_action_with_picker(actions)
  end)
end

local function goto_source_definition_or_implementation()
  local bufnr = vim.api.nvim_get_current_buf()
  local filetype = vim.bo[bufnr].filetype

  if vim.tbl_contains(ts_definition_filetypes, filetype) then
    return vim.lsp.buf.definition()
  end

  if not vim.tbl_contains(ts_source_definition_filetypes, filetype) then
    return show_symbol_implementations()
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
    autocmds = {
      ts_lsp_attach_state = {
        {
          event = "LspAttach",
          desc = "Track TypeScript LSP attach time",
          callback = function(args)
            local client = vim.lsp.get_client_by_id(args.data.client_id)
            if is_typescript_client(client) then mark_ts_client_attach(client) end
          end,
        },
        {
          event = "LspDetach",
          desc = "Clear TypeScript LSP attach time",
          callback = function(args) ts_client_attach_time[args.data.client_id] = nil end,
        },
      },
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
           function()
             if vim.bo.filetype == "java" then return require("java_definition").goto_definition() end
             require("telescope.builtin").lsp_definitions()
           end,
           cond = "textDocument/definition",
        },
        ["<Leader>m"] = {
           quick_fix,
           desc = "Quick fix",
           cond = "textDocument/codeAction",
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
-- leader fw 全局搜索文字(纯文本，特殊字符按字面匹配)
-- leader fW 全局搜索文字(正则)
