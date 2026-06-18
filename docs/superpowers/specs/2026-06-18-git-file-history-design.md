# Git File History Design

## Goal

为当前打开文件提供一个可交互的 Git 历史弹窗。用户可以在弹窗里浏览该文件的提交记录，选择某个提交后查看“这个提交对当前文件的改动”。历史结果需要保留在 merge commit 中对当前文件产生手工改动的提交，同时过滤纯自动合并但未对当前文件形成实际 patch 的 merge 提交。

## Scope

本次只实现当前文件维度的历史浏览，不实现整个仓库的提交浏览，不新增新的大型 Git UI 插件体系。

## User Interaction

### Trigger

- 提供一个新的普通模式快捷键 `<Leader>gh`
- 仅在当前 buffer 对应真实文件且位于 Git 仓库内时可用

### History Picker

- 触发快捷键后，打开 Telescope picker 作为小弹窗
- 列表项至少包含：
  - 短 SHA
  - 相对或绝对时间
  - 作者
  - 提交标题
- 列表内容基于当前文件路径构建，默认启用跨重命名追踪

### Commit Diff View

- 在 picker 中选中某一条提交并确认后，展示“该提交对当前文件的 diff”
- 只展示当前文件，不展示该提交涉及的其他文件
- diff 视图应可读、可滚动，并尽量沿用现有 Neovim 打开浮窗/终端/preview 的习惯

## Merge History Rules

### Included

- 普通非 merge commit，只要属于当前文件历史，就显示
- merge commit 如果对当前文件存在实际 patch，则显示
  - 这覆盖了冲突解决、手工调整等情况

### Excluded

- merge commit 如果只是自动合并，没有对当前文件形成实际 patch，则不显示

### Practical Interpretation

实现上不依赖 Telescope 内置 `git_bcommits` 的默认路径历史推导，而是使用自定义 Git 命令构建候选列表，以便明确控制 merge commit 的保留规则。

## Technical Approach

### Data Source

- 自定义一个 Lua 函数获取当前文件相对仓库根目录的路径
- 使用 Git 命令获取当前文件历史候选
- 默认使用 `--follow` 追踪 rename
- 对 merge commit 做额外判定，仅保留对当前文件存在 patch 的项

### UI Layer

- 复用当前配置中已有的 `telescope.nvim`
- 自定义 picker、entry maker、previewer 和 selection action

### Diff Rendering

- 选中提交后，对该提交与其父提交在“当前文件”维度生成 patch
- patch 内容在 Neovim 中展示为只读 buffer 或等价视图
- buffer 需要设置合适的 filetype / buftype / wrap 配置，保证阅读体验

## Error Handling

- 当前 buffer 没有关联文件：提示并退出
- 当前文件不在 Git 仓库内：提示并退出
- Git 命令失败：展示明确错误，不打开空 picker
- 某个提交无法生成文件级 diff：提示失败原因

## File Boundaries

- `lua/utils/git_file_history.lua`
  - 当前功能的主实现
  - 包含 Git 历史查询、merge 过滤、Telescope picker、diff 打开逻辑
- `lua/plugins/_astrocore_mappings.lua`
  - 注册 `<Leader>gh` 映射

## Testing Strategy

### Manual Verification

- 在普通 tracked 文件上触发历史弹窗，确认能看到列表
- 在存在 rename 历史的文件上确认 `--follow` 生效
- 在包含 merge commit 的样例仓库中确认：
  - 自动 merge 且当前文件无 patch 的 merge 不出现
  - 冲突后手工解决并对当前文件有 patch 的 merge 出现
- 选择某一条提交后，确认只展示当前文件 diff

### Regression Risk

- Git 历史命令参数写错会导致 merge 过滤失真
- Telescope preview/action 绑定不当会导致无法打开 diff 或打开错误文件

## Non-Goals

- 不实现 blame 时间线替代品
- 不实现多文件提交 diff 浏览器
- 不引入 `diffview.nvim`、`fugitive` 等新插件
