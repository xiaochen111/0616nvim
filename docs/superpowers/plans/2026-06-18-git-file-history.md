# Git File History Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为当前打开文件新增一个基于 Telescope 的 Git 历史弹窗，支持跨 rename 浏览历史、过滤纯自动 merge、保留对当前文件有实际 patch 的 merge，并在选中提交后只展示该提交对当前文件的 diff。

**Architecture:** 新功能集中放到 `lua/utils/git_file_history.lua`，把 Git 查询、merge 过滤、Telescope picker 和 diff 打开逻辑封装在一个模块里。`lua/utils.lua` 只暴露加载入口，`lua/plugins/_astrocore_mappings.lua` 只负责绑定 `<Leader>gh`。验证以 headless Neovim 调用 Lua 函数和临时 Git 仓库回归为主。

**Tech Stack:** Lua, Neovim API, telescope.nvim, Git CLI

---

### Task 1: 搭建模块边界和快捷键入口

**Files:**
- Create: `lua/utils/git_file_history.lua`
- Modify: `lua/utils.lua`
- Modify: `lua/plugins/_astrocore_mappings.lua`

- [ ] **Step 1: 新建文件历史模块骨架**

```lua
local M = {}

function M.open_file_history()
  vim.notify("git file history not implemented yet", vim.log.levels.INFO)
end

return M
```

- [ ] **Step 2: 在 `lua/utils.lua` 暴露加载入口**

```lua
function M.open_git_file_history() require("utils.git_file_history").open_file_history() end
```

- [ ] **Step 3: 在 `_astrocore_mappings.lua` 添加快捷键**

```lua
maps.n["<Leader>gh"] = {
  function() require("utils").open_git_file_history() end,
  desc = "Git file history",
}
```

- [ ] **Step 4: 运行 headless 检查模块可加载**

Run:

```bash
nvim --headless "+lua require('utils.git_file_history')" "+quitall"
```

Expected: 退出码 `0`

- [ ] **Step 5: 提交入口骨架**

```bash
git -C /Users/chenhb/.config/nvim add lua/utils.lua lua/utils/git_file_history.lua lua/plugins/_astrocore_mappings.lua
git -C /Users/chenhb/.config/nvim commit -m "feat: add git file history entrypoint"
```

### Task 2: 实现当前文件 Git 上下文解析

**Files:**
- Modify: `lua/utils/git_file_history.lua`

- [ ] **Step 1: 添加当前文件和仓库上下文解析函数**

```lua
local function notify(msg, level) vim.notify(msg, level or vim.log.levels.WARN) end

local function systemlist(cmd, cwd)
  local result = vim.fn.systemlist(cmd)
  local code = vim.v.shell_error
  return result, code
end

local function get_file_context()
  local abs_path = vim.api.nvim_buf_get_name(0)
  if abs_path == "" then return nil, "Current buffer is not a file" end

  local parent = vim.fs.dirname(abs_path)
  local root = vim.fn.systemlist({ "git", "-C", parent, "rev-parse", "--show-toplevel" })[1]
  if vim.v.shell_error ~= 0 or not root or root == "" then return nil, "Not in a git repository" end

  local rel = vim.fn.fnamemodify(abs_path, ":.")
  rel = vim.fn.systemlist({ "git", "-C", root, "ls-files", "--full-name", "--", abs_path })[1]
  if vim.v.shell_error ~= 0 or not rel or rel == "" then return nil, "File is not tracked by git" end

  return {
    abs_path = abs_path,
    git_root = root,
    rel_path = rel,
    file_name = vim.fs.basename(abs_path),
  }
end
```

- [ ] **Step 2: 在入口函数里接入上下文校验**

```lua
function M.open_file_history()
  local ctx, err = get_file_context()
  if not ctx then
    notify(err)
    return
  end

  vim.notify(("git history: %s"):format(ctx.rel_path), vim.log.levels.INFO)
end
```

- [ ] **Step 3: 运行无仓库/普通仓库场景验证**

Run:

```bash
nvim --headless "+enew" "+lua require('utils.git_file_history').open_file_history()" "+quitall"
```

Expected: 提示 `Current buffer is not a file`

Run:

```bash
nvim --headless "+edit /Users/chenhb/.config/nvim/init.lua" "+lua require('utils.git_file_history').open_file_history()" "+quitall"
```

Expected: 提示包含 `lua` 路径，不报错

- [ ] **Step 4: 提交上下文解析**

```bash
git -C /Users/chenhb/.config/nvim add lua/utils/git_file_history.lua
git -C /Users/chenhb/.config/nvim commit -m "feat: resolve git file history context"
```

### Task 3: 实现历史查询和 merge 过滤

**Files:**
- Modify: `lua/utils/git_file_history.lua`

- [ ] **Step 1: 定义提交解析格式和基础查询命令**

```lua
local record_sep = "\31"
local field_sep = "\30"

local function build_history_cmd(ctx)
  return {
    "git",
    "-C",
    ctx.git_root,
    "log",
    "--follow",
    "--date=short",
    ("--pretty=format:%%H%s%%h%s%%ad%s%%an%s%%s"):format(field_sep, field_sep, field_sep, field_sep),
    "--name-only",
    "--",
    ctx.rel_path,
  }
end
```

- [ ] **Step 2: 解析 `git log` 输出为提交记录**

```lua
local function parse_history(lines)
  local records, current = {}, nil
  for _, line in ipairs(lines) do
    if line:find(field_sep, 1, true) then
      local full_sha, short_sha, date, author, subject = unpack(vim.split(line, field_sep, { plain = true }))
      current = {
        sha = full_sha,
        short_sha = short_sha,
        date = date,
        author = author,
        subject = subject,
      }
      table.insert(records, current)
    elseif current and line ~= "" then
      current.path = line
    end
  end
  return records
end
```

- [ ] **Step 3: 增加 merge commit patch 过滤**

```lua
local function commit_parent_count(ctx, sha)
  local parts = vim.fn.systemlist({ "git", "-C", ctx.git_root, "rev-list", "--parents", "-n", "1", sha })[1] or ""
  local items = vim.split(parts, " ", { trimempty = true })
  return math.max(#items - 1, 0)
end

local function commit_touches_file(ctx, sha, path)
  local lines = vim.fn.systemlist({ "git", "-C", ctx.git_root, "show", "--format=", "--numstat", sha, "--", path })
  if vim.v.shell_error ~= 0 then return false end
  for _, line in ipairs(lines) do
    if line ~= "" then return true end
  end
  return false
end

local function filter_records(ctx, records)
  local filtered = {}
  for _, record in ipairs(records) do
    if commit_parent_count(ctx, record.sha) <= 1 or commit_touches_file(ctx, record.sha, ctx.rel_path) then
      table.insert(filtered, record)
    end
  end
  return filtered
end
```

- [ ] **Step 4: 让入口函数先能返回过滤后的数量**

```lua
local function get_history(ctx)
  local lines = vim.fn.systemlist(build_history_cmd(ctx))
  if vim.v.shell_error ~= 0 then return nil, "git log failed" end
  local records = filter_records(ctx, parse_history(lines))
  if #records == 0 then return nil, "No git history found for current file" end
  return records
end

function M.open_file_history()
  local ctx, err = get_file_context()
  if not ctx then
    notify(err)
    return
  end

  local records, history_err = get_history(ctx)
  if not records then
    notify(history_err)
    return
  end

  vim.notify(("git history entries: %d"):format(#records), vim.log.levels.INFO)
end
```

- [ ] **Step 5: 用临时仓库覆盖 merge 规则回归**

Run:

```bash
TMP_REPO="$(mktemp -d)"
git -C "$TMP_REPO" init
printf 'a\n' > "$TMP_REPO/demo.txt"
git -C "$TMP_REPO" add demo.txt
git -C "$TMP_REPO" commit -m "init"
git -C "$TMP_REPO" checkout -b feature
printf 'feature\n' > "$TMP_REPO/demo.txt"
git -C "$TMP_REPO" commit -am "feature change"
git -C "$TMP_REPO" checkout master
git -C "$TMP_REPO" merge --no-ff feature -m "auto merge feature"
```

Expected: 自动 merge 提交不进入过滤后的 `demo.txt` 历史

Run:

```bash
TMP_REPO="$(mktemp -d)"
git -C "$TMP_REPO" init
printf 'base\n' > "$TMP_REPO/demo.txt"
git -C "$TMP_REPO" add demo.txt
git -C "$TMP_REPO" commit -m "init"
git -C "$TMP_REPO" checkout -b left
printf 'left\n' > "$TMP_REPO/demo.txt"
git -C "$TMP_REPO" commit -am "left change"
git -C "$TMP_REPO" checkout master
printf 'right\n' > "$TMP_REPO/demo.txt"
git -C "$TMP_REPO" commit -am "right change"
git -C "$TMP_REPO" merge left || true
printf 'resolved\n' > "$TMP_REPO/demo.txt"
git -C "$TMP_REPO" add demo.txt
git -C "$TMP_REPO" commit -m "manual merge"
```

Expected: `manual merge` 出现在过滤后的 `demo.txt` 历史里

- [ ] **Step 6: 提交历史查询逻辑**

```bash
git -C /Users/chenhb/.config/nvim add lua/utils/git_file_history.lua
git -C /Users/chenhb/.config/nvim commit -m "feat: filter git file history merges"
```

### Task 4: 实现 Telescope picker 和 diff 展示

**Files:**
- Modify: `lua/utils/git_file_history.lua`

- [ ] **Step 1: 引入 Telescope 依赖并定义 entry maker**

```lua
local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local conf = require("telescope.config").values
local actions = require "telescope.actions"
local action_state = require "telescope.actions.state"

local function make_display(record)
  return ("%s  %s  %s  %s"):format(record.short_sha, record.date, record.author, record.subject)
end
```

- [ ] **Step 2: 实现当前文件 diff 内容获取**

```lua
local function get_commit_file_diff(ctx, sha)
  local lines = vim.fn.systemlist({
    "git",
    "-C",
    ctx.git_root,
    "show",
    "--format=",
    sha,
    "--",
    ctx.rel_path,
  })
  if vim.v.shell_error ~= 0 then return nil, "git show failed" end
  if vim.tbl_isempty(lines) then return nil, "No diff for selected commit" end
  return lines
end
```

- [ ] **Step 3: 实现只读 diff buffer 打开逻辑**

```lua
local function open_diff_buffer(ctx, record)
  local diff_lines, err = get_commit_file_diff(ctx, record.sha)
  if not diff_lines then
    notify(err, vim.log.levels.ERROR)
    return
  end

  vim.cmd "botright new"
  local buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_name(buf, ("git://%s/%s"):format(record.short_sha, ctx.rel_path))
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, diff_lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].filetype = "diff"
end
```

- [ ] **Step 4: 实现 picker 打开与回车行为**

```lua
local function open_picker(ctx, records)
  pickers
    .new({}, {
      prompt_title = ("Git File History: %s"):format(ctx.file_name),
      finder = finders.new_table {
        results = records,
        entry_maker = function(record)
          return {
            value = record,
            display = make_display(record),
            ordinal = ("%s %s %s %s"):format(record.short_sha, record.author, record.date, record.subject),
          }
        end,
      },
      sorter = conf.generic_sorter({}),
      previewer = conf.grep_previewer({}),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if selection then open_diff_buffer(ctx, selection.value) end
        end)
        return true
      end,
    })
    :find()
end

function M.open_file_history()
  local ctx, err = get_file_context()
  if not ctx then
    notify(err)
    return
  end

  local records, history_err = get_history(ctx)
  if not records then
    notify(history_err)
    return
  end

  open_picker(ctx, records)
end
```

- [ ] **Step 5: 运行 headless + 真实交互验证**

Run:

```bash
nvim --headless "+edit /Users/chenhb/.config/nvim/init.lua" "+lua require('utils.git_file_history').open_file_history()" "+sleep 1" "+quitall"
```

Expected: 无 Lua 报错，picker 可初始化

Manual:

```text
在仓库内打开一个 tracked 文件，按 <leader>gh，确认弹出历史列表；回车某条记录后，仅打开该文件的 diff。
```

- [ ] **Step 6: 提交交互功能**

```bash
git -C /Users/chenhb/.config/nvim add lua/utils/git_file_history.lua
git -C /Users/chenhb/.config/nvim commit -m "feat: add telescope git file history picker"
```

### Task 5: 最终验证和整理

**Files:**
- Modify: `lua/utils/git_file_history.lua`
- Modify: `lua/plugins/_astrocore_mappings.lua`
- Modify: `lua/utils.lua`

- [ ] **Step 1: 检查格式和静态错误**

Run:

```bash
stylua lua/utils.lua lua/utils/git_file_history.lua lua/plugins/_astrocore_mappings.lua
nvim --headless "+lua require('utils.git_file_history')" "+quitall"
```

Expected: 无格式化错误、无加载错误

- [ ] **Step 2: 重新跑关键回归**

Run:

```bash
nvim --headless "+edit /Users/chenhb/.config/nvim/init.lua" "+lua require('utils.git_file_history').open_file_history()" "+sleep 1" "+quitall"
```

Expected: 无 Lua 报错

Manual:

```text
1. 打开普通 tracked 文件，按 <leader>gh
2. 搜索某条历史并回车
3. 确认 diff buffer 的 filetype 为 diff
4. 确认自动 merge 不出现、手工解决冲突的 merge 出现
```

- [ ] **Step 3: 查看最终 diff**

Run:

```bash
git -C /Users/chenhb/.config/nvim diff -- lua/utils.lua lua/utils/git_file_history.lua lua/plugins/_astrocore_mappings.lua
```

Expected: 只包含本次功能相关改动

- [ ] **Step 4: 最终提交**

```bash
git -C /Users/chenhb/.config/nvim add lua/utils.lua lua/utils/git_file_history.lua lua/plugins/_astrocore_mappings.lua
git -C /Users/chenhb/.config/nvim commit -m "feat: add git file history picker for current file"
```
