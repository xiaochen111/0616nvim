# gI Implementation Picker Design

## Goal

增强现有 `gI` 跳转实现体验：当当前位置存在多个 implementation 时，不再直接交给默认 LSP handler，而是打开一个带预览的 Telescope 小弹窗；用户确认某一项后直接跳转到该实现位置。

## Scope

本次只调整 `gI` 的 implementation 多结果交互，不改变其它 LSP 跳转快捷键，不新增插件，不重构整体 LSP 配置。

## User Interaction

### Trigger

- 普通模式按 `gI`
- 保留当前语义：跳转到当前符号的实现或源定义

### Result Handling

- 0 个 implementation：提示 `No implementations found`
- 1 个 implementation：直接跳转到该位置
- 多个 implementation：打开 Telescope 小弹窗
  - 列表显示文件路径、行列号和目标行文本
  - 右侧 preview 展示目标文件内容
  - 按 `<CR>` 后关闭弹窗并跳转到选中位置

### TypeScript / React Behavior

现有 TypeScript 相关特殊逻辑需要保留：

- `javascript` / `typescript` 继续走 definition
- `javascriptreact` / `typescriptreact` 优先调用 TypeScript source definition command
- 只有不属于这些特殊路径的 filetype，才走普通 implementation 查询

## Technical Approach

### Reuse Existing Picker

复用 `lua/plugins/_astrolsp.lua` 中已有的 `open_items_in_picker(title, items)`：

- 该函数已经实现 Telescope 小弹窗
- 已带文件 preview
- `<CR>` 后会打开目标文件并跳到行列位置
- Telescope 不可用时会 fallback 到 quickfix

这能让 `gI` 的多结果体验和现有 `gR` references 弹窗保持一致。

### Implementation Request Flow

为普通 implementation 路径新增异步 request helper：

1. 获取当前 buffer 和 window
2. 对支持 `textDocument/implementation` 的 client 发起请求
3. 将 LSP locations 转为 quickfix items
4. 使用已有 `dedupe_items(items)` 去重并排序
5. 按结果数量执行：提示、直接跳转或打开 picker

### Jump Behavior

单结果和多结果确认后的跳转都使用同一套位置跳转逻辑，避免行为分叉：

- 打开目标文件
- 将光标移动到目标行列
- 行列号使用 LSP 转换后的 quickfix item 字段

## Error Handling

- LSP 请求返回 error：展示错误提示，不打开空 picker
- 没有支持 implementation 的 client：提示没有实现结果
- 返回结果为空：提示 `No implementations found`
- Telescope 模块加载失败：沿用现有 quickfix fallback

## File Boundaries

- `lua/plugins/_astrolsp.lua`
  - 调整 `goto_source_definition_or_implementation()` 的普通 implementation 分支
  - 新增少量 helper，用于请求 implementation、结果分流和单结果跳转
  - 复用现有 `open_items_in_picker()`、`dedupe_items()`

不需要修改 `lua/plugins/_astrolsp_mapping.lua` 或 `_astrocore_mappings.lua`，因为 `gI` 当前绑定已经位于 `_astrolsp.lua`。

## Testing Strategy

### Automated Checks

- 运行 Lua 格式/语法检查或 headless Neovim 加载相关文件，确认配置无语法错误

### Manual Verification

- 在只有一个 implementation 的符号上按 `gI`，确认直接跳转
- 在多个 implementation 的接口/方法上按 `gI`，确认弹出 Telescope 小窗并显示 preview
- 在 picker 中按 `<CR>`，确认跳到选中实现
- 在没有 implementation 的符号上按 `gI`，确认只提示不报错
- 在 TS/TSX 场景确认现有 source definition 行为没有被破坏

## Non-Goals

- 不实现自定义 UI 主题
- 不引入 `trouble.nvim`、`fzf-lua` 或其它新插件
- 不改变 `gd`、`gR`、hover、references 等其它快捷键行为
- 不实现保留 picker 连续浏览多个实现的模式
