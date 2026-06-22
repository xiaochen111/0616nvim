# gI Implementation Picker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 当 `gI` 查询到多个 implementation 时，打开带预览的 Telescope 小弹窗，并在确认后跳转到选中实现。

**Architecture:** 保留 `lua/plugins/_astrolsp.lua` 中现有 TypeScript source definition 特殊路径，只替换普通 implementation 分支。新增小型 helper 复用已有 `open_items_in_picker()`，让 0/1/多结果分别走提示、直接跳转和 Telescope picker。

**Tech Stack:** Neovim Lua、Neovim LSP API、Telescope、headless Neovim Lua 测试脚本。

---

## File Structure

- Modify: `lua/plugins/_astrolsp.lua`
  - 复用现有 `open_items_in_picker(title, items)` 和 `dedupe_items(items)`。
  - 新增 `jump_to_item(item)`，统一 picker 确认和单结果跳转行为。
  - 新增 `handle_location_items(title, items)`，实现 0/1/多结果分流。
  - 新增 `show_symbol_implementations()`，异步请求 `textDocument/implementation` 并打开 picker。
  - 修改 `goto_source_definition_or_implementation()` 的普通 implementation 分支，从 `vim.lsp.buf.implementation()` 改为 `show_symbol_implementations()`。
- Create: `tests/astrolsp_implementation_picker.lua`
  - 使用 headless Neovim 加载 `_astrolsp.lua`。
  - 通过 stub LSP/Telescope API 验证：多结果会打开 picker，单结果会直接跳转。

---

### Task 1: 添加 gI implementation 分流测试

**Files:**
- Create: `tests/astrolsp_implementation_picker.lua`

- [ ] **Step 1: 写入失败测试文件**

Create `tests/astrolsp_implementation_picker.lua` with this content:

```lua
local astrolsp = dofile "/Users/chenhb/.config/nvim/lua/plugins/_astrolsp.lua"
local gi_mapping = astrolsp.opts.mappings.n["gI"][1]

local original = {
  notify = vim.notify,
  buf_request_all = vim.lsp.buf_request_all,
  locations_to_items = vim.lsp.util.locations_to_items,
  get_clients = vim.lsp.get_clients,
  cmd = vim.cmd,
}

local function reset_stubs()
  package.loaded["telescope.pickers"] = nil
  package.loaded["telescope.finders"] = nil
  package.loaded["telescope.config"] = nil
  package.loaded["telescope.actions"] = nil
  package.loaded["telescope.actions.state"] = nil
  package.loaded["telescope.themes"] = nil
  package.loaded["telescope.previewers"] = nil

  vim.notify = original.notify
  vim.lsp.buf_request_all = original.buf_request_all
  vim.lsp.util.locations_to_items = original.locations_to_items
  vim.lsp.get_clients = original.get_clients
  vim.cmd = original.cmd
end

local function with_filetype(filetype)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(bufnr)
  vim.bo[bufnr].filetype = filetype
  return bufnr
end

local function stub_clients()
  vim.lsp.get_clients = function()
    return {
      {
        id = 1,
        name = "test-lsp",
        offset_encoding = "utf-16",
        supports_method = function(_, method) return method == "textDocument/implementation" end,
      },
    }
  end
end

local function stub_implementation_items(items)
  vim.lsp.buf_request_all = function(_, method, _, callback)
    assert(method == "textDocument/implementation")
    callback {
      [1] = {
        result = items,
      },
    }
  end

  vim.lsp.util.locations_to_items = function(locations)
    return locations
  end
end

local function stub_telescope(state)
  package.loaded["telescope.pickers"] = {
    new = function(_, opts)
      state.picker_opts = opts
      return {
        find = function()
          state.picker_opened = true
        end,
      }
    end,
  }
  package.loaded["telescope.finders"] = {
    new_table = function(opts)
      state.finder_opts = opts
      return opts
    end,
  }
  package.loaded["telescope.config"] = {
    values = {
      generic_sorter = function() return function() end end,
      grep_previewer = function() return "grep-previewer" end,
    },
  }
  package.loaded["telescope.actions"] = {
    select_default = {
      replace = function() end,
    },
    close = function() end,
  }
  package.loaded["telescope.actions.state"] = {
    get_selected_entry = function() return nil end,
  }
  package.loaded["telescope.themes"] = {
    get_dropdown = function(opts) return opts end,
  }
  package.loaded["telescope.previewers"] = {}
end

local function test_multiple_implementations_open_picker()
  reset_stubs()
  with_filetype "go"
  stub_clients()

  local state = { picker_opened = false }
  stub_telescope(state)
  stub_implementation_items {
    { filename = "/tmp/impl_a.go", lnum = 10, col = 3, text = "func (a A) Run() {}" },
    { filename = "/tmp/impl_b.go", lnum = 20, col = 5, text = "func (b B) Run() {}" },
  }

  gi_mapping()

  assert(state.picker_opened == true)
  assert(state.picker_opts.prompt_title == "Implementations")
  assert(#state.finder_opts.results == 2)
end

local function test_single_implementation_jumps_directly()
  reset_stubs()
  with_filetype "go"
  stub_clients()
  stub_implementation_items {
    { filename = "/tmp/impl_single.go", lnum = 12, col = 4, text = "func (s S) Run() {}" },
  }

  local edited
  vim.cmd = function(command)
    edited = command
  end

  gi_mapping()

  assert(edited == "edit /tmp/impl_single.go")
  local cursor = vim.api.nvim_win_get_cursor(0)
  assert(cursor[1] == 12)
  assert(cursor[2] == 3)
end

local ok, err = pcall(function()
  test_multiple_implementations_open_picker()
  test_single_implementation_jumps_directly()
end)

reset_stubs()

if not ok then error(err) end
```

- [ ] **Step 2: 运行测试并确认失败**

Run:

```bash
nvim --headless -u init.lua -l tests/astrolsp_implementation_picker.lua
```

Expected: FAIL. The failure should show that the multiple implementation case did not open the picker, because `gI` still calls `vim.lsp.buf.implementation()` directly for normal filetypes.

- [ ] **Step 3: 提交失败测试**

Run:

```bash
git add tests/astrolsp_implementation_picker.lua
git commit -m "test: cover gI implementation picker behavior"
```

---

### Task 2: 提取统一跳转 helper 并复用到现有 picker

**Files:**
- Modify: `lua/plugins/_astrolsp.lua:83-150`

- [ ] **Step 1: 在 `open_items_in_picker` 前新增 `jump_to_item`**

In `lua/plugins/_astrolsp.lua`, insert this function immediately before `local function open_items_in_picker(title, items)`:

```lua
local function jump_to_item(item)
  vim.cmd(("edit %s"):format(vim.fn.fnameescape(item.filename)))
  vim.api.nvim_win_set_cursor(0, { item.lnum, math.max((item.col or 1) - 1, 0) })
end
```

- [ ] **Step 2: 更新 picker 的默认选择动作**

In `open_items_in_picker`, replace the existing selection jump block:

```lua
          local target = selection.value
          vim.cmd(("edit %s"):format(vim.fn.fnameescape(target.filename)))
          vim.api.nvim_win_set_cursor(0, { target.lnum, math.max((target.col or 1) - 1, 0) })
```

with:

```lua
          jump_to_item(selection.value)
```

- [ ] **Step 3: 运行现有相关测试确认仍失败在 implementation 分流**

Run:

```bash
nvim --headless -u init.lua -l tests/astrolsp_implementation_picker.lua
```

Expected: FAIL. The multi-result test should still fail because normal `gI` has not yet been routed through the new implementation request flow.

- [ ] **Step 4: 提交跳转 helper**

Run:

```bash
git add lua/plugins/_astrolsp.lua
git commit -m "refactor: share lsp item jump helper"
```

---

### Task 3: 实现 implementation 请求和 0/1/多结果分流

**Files:**
- Modify: `lua/plugins/_astrolsp.lua:260-344`
- Modify: `lua/plugins/_astrolsp.lua:588-598`

- [ ] **Step 1: 新增 implementation 结果收集 helper**

Insert this function after `local function collect_reference_items(results)`:

```lua
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
```

- [ ] **Step 2: 新增 0/1/多结果处理 helper**

Insert this function immediately after `collect_location_items`:

```lua
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
```

- [ ] **Step 3: 新增 implementation request 函数**

Insert this function after `handle_location_items`:

```lua
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
```

- [ ] **Step 4: 修改普通 implementation 分支**

In `goto_source_definition_or_implementation()`, replace:

```lua
  if not vim.tbl_contains(ts_source_definition_filetypes, filetype) then
    return vim.lsp.buf.implementation()
  end
```

with:

```lua
  if not vim.tbl_contains(ts_source_definition_filetypes, filetype) then
    return show_symbol_implementations()
  end
```

- [ ] **Step 5: 运行新增测试确认通过**

Run:

```bash
nvim --headless -u init.lua -l tests/astrolsp_implementation_picker.lua
```

Expected: PASS with exit code 0 and no Lua assertion failure.

- [ ] **Step 6: 提交 implementation picker 功能**

Run:

```bash
git add lua/plugins/_astrolsp.lua
git commit -m "feat: show gI implementations in picker"
```

---

### Task 4: 回归检查与手动验证指引

**Files:**
- Modify only if checks reveal a defect: `lua/plugins/_astrolsp.lua`
- Modify only if checks reveal a defect: `tests/astrolsp_implementation_picker.lua`

- [ ] **Step 1: 运行新增测试**

Run:

```bash
nvim --headless -u init.lua -l tests/astrolsp_implementation_picker.lua
```

Expected: PASS with exit code 0.

- [ ] **Step 2: 运行已有 none-ls 兼容测试**

Run:

```bash
nvim --headless -u init.lua -l tests/none_ls_compat.lua
```

Expected: PASS with exit code 0.

- [ ] **Step 3: 检查 Lua 格式**

Run:

```bash
stylua --check lua/plugins/_astrolsp.lua tests/astrolsp_implementation_picker.lua
```

Expected: PASS. If it fails with formatting differences, run:

```bash
stylua lua/plugins/_astrolsp.lua tests/astrolsp_implementation_picker.lua
```

Then rerun the `stylua --check` command and expect PASS.

- [ ] **Step 4: 手动验证多实现弹窗**

Open a project with an LSP server that supports `textDocument/implementation`, place the cursor on a symbol with multiple implementations, and press `gI`.

Expected:

- Telescope dropdown opens with title `Implementations`
- Results show file path, line, column, and target line text
- Preview pane shows the selected target file
- Pressing `<CR>` closes Telescope and jumps to the selected implementation

- [ ] **Step 5: 手动验证单实现直接跳转**

Place the cursor on a symbol with exactly one implementation and press `gI`.

Expected:

- No Telescope window opens
- Current window edits the implementation file
- Cursor lands on the implementation line and column

- [ ] **Step 6: 手动验证 TypeScript source definition 未破坏**

In a `typescriptreact` or `javascriptreact` buffer, press `gI` on a component import or symbol where source definition previously worked.

Expected:

- It still uses the TypeScript source definition command when `vtsls`, `ts_ls`, or `tsserver` supports it
- If the source definition command has no result, it falls back to `vim.lsp.buf.definition()` as before

- [ ] **Step 7: 提交验证修正**

If Step 1-6 required changes, run:

```bash
git add lua/plugins/_astrolsp.lua tests/astrolsp_implementation_picker.lua
git commit -m "fix: stabilize gI implementation picker"
```

If Step 1-6 required no changes, do not create an empty commit.

---

## Self-Review

- Spec coverage:
  - 0 个 implementation 提示：Task 3 Step 2 implements `No implementations found`.
  - 1 个 implementation 直接跳转：Task 3 Step 2 uses `jump_to_item(items[1])`; Task 1 tests it.
  - 多个 implementation 使用 Telescope 小弹窗和 preview：Task 3 Step 2 calls `open_items_in_picker`; Task 1 tests picker opening; existing picker provides preview.
  - `<CR>` 跳转：Task 2 reuses `jump_to_item` in picker selection action.
  - TypeScript / React 特殊逻辑保留：Task 3 only changes the non-TSX implementation branch; Task 4 manually verifies TSX behavior.
  - Telescope 不可用 fallback：existing `open_items_in_picker` fallback remains unchanged.
- Placeholder scan: no placeholder instructions remain; every code step includes concrete code.
- Type consistency: `jump_to_item`, `collect_location_items`, `handle_location_items`, and `show_symbol_implementations` are defined before use and referenced consistently.
