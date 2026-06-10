local M = {}

-- This file is automatically ran last in the setup process and is a good place to configure
-- augroups/autocommands and custom filetypes also this just pure lua so
-- anything that doesn't fit in the normal config locations above can go here
function M.yaml_ft(path, bufnr)
  local buf_text = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
  if
    -- check if file is in roles, tasks, or handlers folder
    vim.regex("(tasks\\|roles\\|handlers)/"):match_str(path)
    -- check for known ansible playbook text and if found, return yaml.ansible
    or vim.regex("hosts:\\|tasks:"):match_str(buf_text)
  then
    return "yaml.ansible"
  elseif vim.regex("AWSTemplateFormatVersion:"):match_str(buf_text) then
    return "yaml.cfn"
  else -- return yaml if nothing else
    return "yaml"
  end
end

function M.write_to_file(content, file_path)
  local file = io.open(file_path, "a")
  if not file then
    print("Unable to open file: " .. file_path)
    return
  end
  file:write(vim.inspect(content))
  file:write "\n"
  file:close()
end

function M.check_json_key_exists(filename, key)
  -- Open the file in read mode
  local file = io.open(filename, "r")
  if not file then
    return false -- File doesn't exist or cannot be opened
  end

  -- Read the contents of the file
  local content = file:read "*all"
  file:close()

  -- Parse the JSON content
  local json_parsed, json = pcall(vim.fn.json_decode, content)
  if not json_parsed or type(json) ~= "table" then
    return false -- Invalid JSON format
  end

  -- Check if the key exists in the JSON object
  return json[key] ~= nil
end

function M.better_search(key)
  return function()
    local searched, error =
      pcall(vim.cmd.normal, { args = { (vim.v.count > 0 and vim.v.count or "") .. key }, bang = true })
    if not searched and type(error) == "string" then require("astrocore").notify(error, vim.log.levels.ERROR) end
  end
end

function M.remove_keymap(mode, key)
  for _, map in pairs(vim.api.nvim_get_keymap(mode)) do
    if map.lhs == key then vim.api.nvim_del_keymap(mode, key) end
  end
end

function M.toggle_lazy_docker()
  return function()
    require("astrocore").toggle_term_cmd {
      cmd = "lazydocker",
      hidden = true,
      on_open = function()
        M.remove_keymap("t", "<C-H>")
        M.remove_keymap("t", "<C-J>")
        M.remove_keymap("t", "<C-K>")
        M.remove_keymap("t", "<C-L>")
      end,
      on_close = function()
        vim.api.nvim_set_keymap("t", "<C-H>", "<cmd>wincmd h<cr>", { silent = true, noremap = true })
        vim.api.nvim_set_keymap("t", "<C-J>", "<cmd>wincmd j<cr>", { silent = true, noremap = true })
        vim.api.nvim_set_keymap("t", "<C-K>", "<cmd>wincmd k<cr>", { silent = true, noremap = true })
        vim.api.nvim_set_keymap("t", "<C-L>", "<cmd>wincmd l<cr>", { silent = true, noremap = true })
      end,
      on_exit = function(t, job, code, event)
        -- For Stop Term Mode
        vim.cmd [[stopinsert]]
      end,
    }
  end
end

-- function M.toggle_lazy_git()
--   return function()
--     local worktree = require("astrocore").file_worktree()
--     local flags = worktree and (" --work-tree=%s --git-dir=%s"):format(worktree.toplevel, worktree.gitdir) or ""
--     require("astrocore").toggle_term_cmd {
--       cmd = "lazygit " .. flags,
--       hidden = true,
--       on_open = function()
--         M.remove_keymap("t", "<C-H>")
--         M.remove_keymap("t", "<C-J>")
--         M.remove_keymap("t", "<C-K>")
--         M.remove_keymap("t", "<C-L>")
--       end,
--       on_close = function()
--         vim.api.nvim_set_keymap("t", "<C-H>", "<cmd>wincmd h<cr>", { silent = true, noremap = true })
--         vim.api.nvim_set_keymap("t", "<C-J>", "<cmd>wincmd j<cr>", { silent = true, noremap = true })
--         vim.api.nvim_set_keymap("t", "<C-K>", "<cmd>wincmd k<cr>", { silent = true, noremap = true })
--         vim.api.nvim_set_keymap("t", "<C-L>", "<cmd>wincmd l<cr>", { silent = true, noremap = true })
--       end,
--       on_exit = function(t, job, code, event)
--         -- For Stop Term Mode
--         vim.cmd [[stopinsert]]
--       end,
--     }
--   end
-- end
--
--

function M.toggle_lazy_git()
  return function()
    local worktree = require("astrocore").file_worktree()
    local flags = worktree and (" --work-tree=%s --git-dir=%s"):format(worktree.toplevel, worktree.gitdir) or ""
    local lazygit_cmd = "lazygit " .. flags

    -- 计算浮动窗口的尺寸
    local width = math.floor(vim.o.columns * 0.8)
    local height = math.floor(vim.o.lines * 0.8)
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    -- 打开一个新的浮动终端窗口
    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_open_win(buf, true, {
      relative = 'editor',
      width = width,
      height = height,
      row = row,
      col = col,
      style = 'minimal',
      border = 'rounded',
    })

    -- 在浮动窗口中启动 lazygit
    vim.fn.termopen(lazygit_cmd, {
      on_exit = function(t, job, code, event)
        -- 关闭窗口时停止插入模式
        vim.cmd("stopinsert")
        vim.api.nvim_win_close(win, true)
      end,
    })

    -- 关闭插入模式，并设置按键绑定
    -- vim.cmd("stopinsert")
    --
    -- 设置窗口打开时进入插入模式
    vim.cmd("startinsert")

    -- 窗口打开时移除快捷键
    M.remove_keymap("t", "<C-H>")
    M.remove_keymap("t", "<C-J>")
    M.remove_keymap("t", "<C-K>")
    M.remove_keymap("t", "<C-L>")

    -- 窗口关闭时恢复快捷键
    vim.api.nvim_create_autocmd("BufWinLeave", {
      buffer = buf,
      callback = function()
        vim.api.nvim_set_keymap("t", "<C-H>", "<cmd>wincmd h<cr>", { silent = true, noremap = true })
        vim.api.nvim_set_keymap("t", "<C-J>", "<cmd>wincmd j<cr>", { silent = true, noremap = true })
        vim.api.nvim_set_keymap("t", "<C-K>", "<cmd>wincmd k<cr>", { silent = true, noremap = true })
        vim.api.nvim_set_keymap("t", "<C-L>", "<cmd>wincmd l<cr>", { silent = true, noremap = true })
      end,
    })

    -- 设置关闭窗口的快捷键
    vim.api.nvim_buf_set_keymap(buf, "t", "<C-w>", "<cmd>close<CR>", { noremap = true, silent = true })
  end
end
--



function M.removeValueFromTable(tbl, value)
  for i, v in ipairs(tbl) do
    if v == value then
      table.remove(tbl, i)
      return true
    end
  end
  return false
end

function M.list_remove_unique(lst, vals)
  if not lst then lst = {} end
  assert(vim.islist(lst), "Provided table is not a list like table")
  if not vim.islist(vals) then vals = { vals } end
  local added = {}
  vim.tbl_map(function(v) added[v] = true end, lst)
  for _, val in ipairs(vals) do
    if added[val] then
      M.removeValueFromTable(lst, val)
      added[val] = false
    end
  end
  return lst
end


function M.log_variable()
  vim.cmd('normal! "vy')
  local var = vim.fn.getreg('v')
  local line = string.format("console.log('%s: ', %s);", var, var)
  -- Move to the next line and insert the console.log statement
  vim.api.nvim_command('normal! o' .. line)
  -- Move back to the previous line
  vim.api.nvim_command('normal! k')
end

function M.copy_to_osc52(text)
  local encoded = vim.fn.system("base64 -w0", text)
  encoded = vim.fn.trim(encoded)
  io.stderr:write(string.format("\027]52;c;%s\027\\", encoded))
end

function M.lsp_buf_debug()
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = {
    ("bufnr: %d"):format(bufnr),
    ("name: %s"):format(vim.api.nvim_buf_get_name(bufnr)),
    ("filetype: %s"):format(vim.bo[bufnr].filetype),
  }
  local clients = vim.lsp.get_clients { bufnr = bufnr }
  lines[#lines + 1] = ("clients: %d"):format(#clients)

  for _, client in ipairs(clients) do
    local root_dir = client.config.root_dir
    if type(root_dir) == "function" then root_dir = "<function>" end
    lines[#lines + 1] = string.format(
      "- %s | codeAction=%s | root_dir=%s",
      client.name,
      tostring(client:supports_method "textDocument/codeAction"),
      root_dir or "nil"
    )
  end

  if #clients == 0 then lines[#lines + 1] = "- no LSP clients attached" end

  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "LSP Buffer Debug" })
end

return M
