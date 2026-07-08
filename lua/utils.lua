local M = {}

function M.open_git_file_history() require("utils.git_file_history").open_file_history() end

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

function M.is_claude_window(win)
  if not (win and vim.api.nvim_win_is_valid(win)) then return false end
  local buf = vim.api.nvim_win_get_buf(win)
  return vim.bo[buf].filetype == "claude"
end

function M.is_neotree_window(win)
  if not (win and vim.api.nvim_win_is_valid(win)) then return false end
  local buf = vim.api.nvim_win_get_buf(win)
  return vim.bo[buf].filetype == "neo-tree"
end

function M.is_editable_window(win)
  if not (win and vim.api.nvim_win_is_valid(win)) then return false end
  local buf = vim.api.nvim_win_get_buf(win)
  if not vim.bo[buf].buflisted then return false end
  if vim.bo[buf].buftype ~= "" then return false end
  local filetype = vim.bo[buf].filetype
  if filetype == "" or filetype == "neo-tree" or filetype == "claude" then return false end
  return vim.bo[buf].modifiable
end

function M.find_left_target_window(from_win)
  if not (from_win and vim.api.nvim_win_is_valid(from_win)) then return nil end
  local from_pos = vim.api.nvim_win_get_position(from_win)
  local left_editable, left_neotree
  local editable_col, neotree_col

  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if win ~= from_win and vim.api.nvim_win_is_valid(win) then
      local pos = vim.api.nvim_win_get_position(win)
      if pos[2] < from_pos[2] then
        if M.is_editable_window(win) and (not editable_col or pos[2] > editable_col) then
          left_editable = win
          editable_col = pos[2]
        elseif M.is_neotree_window(win) and (not neotree_col or pos[2] > neotree_col) then
          left_neotree = win
          neotree_col = pos[2]
        end
      end
    end
  end

  return left_editable or left_neotree
end

function M.find_right_claude_window(from_win)
  if not (from_win and vim.api.nvim_win_is_valid(from_win)) then return nil end
  local from_pos = vim.api.nvim_win_get_position(from_win)
  local right_claude, claude_col

  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if win ~= from_win and vim.api.nvim_win_is_valid(win) and M.is_claude_window(win) then
      local pos = vim.api.nvim_win_get_position(win)
      if pos[2] > from_pos[2] and (not claude_col or pos[2] < claude_col) then
        right_claude = win
        claude_col = pos[2]
      end
    end
  end

  return right_claude
end

function M.find_nearest_right_window(from_win)
  if not (from_win and vim.api.nvim_win_is_valid(from_win)) then return nil end
  local from_pos = vim.api.nvim_win_get_position(from_win)
  local right_win, right_col

  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if win ~= from_win and vim.api.nvim_win_is_valid(win) then
      local pos = vim.api.nvim_win_get_position(win)
      if pos[2] > from_pos[2] and (not right_col or pos[2] < right_col) then
        right_win = win
        right_col = pos[2]
      end
    end
  end

  return right_win
end

function M.focus_right_claude_or_window()
  local target = M.find_nearest_right_window(vim.api.nvim_get_current_win())
  if not target then
    vim.cmd "wincmd l"
    return
  end

  vim.api.nvim_set_current_win(target)
  if M.is_claude_window(target) then
    vim.api.nvim_set_current_win(target)
    vim.cmd "startinsert"
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

function M.toggle_claude_cli()
  local state = {
    buf = nil,
    win = nil,
    job = nil,
  }

  local function restore_terminal_navigation()
    vim.keymap.set("t", "<C-H>", "<cmd>wincmd h<cr>", { silent = true, noremap = true })
    vim.keymap.set("t", "<C-J>", "<cmd>wincmd j<cr>", { silent = true, noremap = true })
    vim.keymap.set("t", "<C-K>", "<cmd>wincmd k<cr>", { silent = true, noremap = true })
    vim.keymap.set("t", "<C-L>", "<cmd>wincmd l<cr>", { silent = true, noremap = true })
  end

  local function clear_state()
    state.buf = nil
    state.win = nil
    state.job = nil
    restore_terminal_navigation()
  end

  -- 关闭 Claude 侧边栏时只隐藏窗口，保留终端会话，便于再次打开继续使用。
  local function hide_window()
    if state.win and vim.api.nvim_win_is_valid(state.win) then vim.api.nvim_win_close(state.win, true) end
    state.win = nil
    restore_terminal_navigation()
  end

  -- 记录 Claude 窗口离开事件，避免下次切换时误判旧窗口仍可用。
  local function track_window_close()
    vim.api.nvim_create_autocmd("BufWinLeave", {
      buffer = state.buf,
      once = true,
      callback = function()
        state.win = nil
        restore_terminal_navigation()
      end,
    })
  end

  return function()
    if state.win and vim.api.nvim_win_is_valid(state.win) then
      hide_window()
      return
    end

    M.remove_keymap("t", "<C-H>")
    M.remove_keymap("t", "<C-J>")
    M.remove_keymap("t", "<C-K>")
    M.remove_keymap("t", "<C-L>")

    vim.cmd "botright vsplit"
    state.win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_width(state.win, math.min(80, math.max(60, vim.o.columns - 20)))

    if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
      vim.api.nvim_win_set_buf(state.win, state.buf)
      track_window_close()
      vim.cmd "startinsert"
      return
    end

    state.buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(state.win, state.buf)
    vim.bo[state.buf].bufhidden = "hide"
    vim.bo[state.buf].filetype = "claude"

    state.job = vim.fn.termopen("claude --continue", {
      on_exit = function()
        vim.schedule(function()
          if state.win and vim.api.nvim_win_is_valid(state.win) then vim.api.nvim_win_close(state.win, true) end
          clear_state()
        end)
      end,
    })

    vim.api.nvim_buf_set_keymap(state.buf, "t", "<Esc><Esc>", "<C-\\><C-n><Cmd>close<CR>", { noremap = true, silent = true })
    vim.keymap.set("t", "<C-H>", function()
      local target = M.find_left_target_window(state.win)
      if not target then return end
      vim.api.nvim_set_current_win(target)
    end, { buffer = state.buf, silent = true, noremap = true, desc = "Focus editable window or Neo-tree" })
    track_window_close()

    vim.cmd "startinsert"
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
  require("vim.ui.clipboard.osc52").copy("+")(type(text) == "table" and text or vim.split(text, "\n", { plain = true }))
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
