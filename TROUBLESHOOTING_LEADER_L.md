# `<Leader>l` 键位冲突问题完整报告（已解决）

## 目标

用户希望按下 `<Leader>l`（即 `Space + l`）时**立即执行 `$` 跳转到行尾**，不弹出任何菜单。

## 历史现象

在 Neovim 中打开任意文件（特别是带 LSP 支持的文件），按下 `<Leader>l` 后：
- 按一次 `<Space>l` → 弹出 AstroNvim 的 which-key 菜单。
- 预期行为应该是立即跳转到行尾。

---

## 最终确定的根本原因 (Root Cause)

问题的根源并非仅仅是静态配置文件的合并顺序，而是 **AstroLSP 的懒加载和动态绑定机制**。

在 AstroNvim 的架构中，`AstroLSP` 模块拥有一个特性：**当一个带代码环境的文件被打开，并且 LSP 服务器成功启动（Attach）时，它会在后台动态生成针对该当前文件有效（Buffer-local）的快捷键。**

其中默认包含了以下两个子映射：
- `<Leader>li` -> `LspInfo`（查看 LSP 信息）
- `<Leader>lI` -> `NullLsInfo`（查看 Null-ls 信息）

由于 which-key 插件的机制，只要检测到存在哪怕一个 `<Leader>l...` 开头的子映射，它就会自动生成并拦截一个名为 `<Leader>l` 的前缀组（prefix group）。

因此，即使我们在全局的静态配置中（如 `_astrocore_mappings.lua`）杀死了所有静态的 `<Leader>l` 组合，一旦 LSP 在后台启动完毕并注册了 `<Leader>li`，which-key 就会**立即复活** `<Leader>l` 前缀菜单，导致用户的 `$` 跳转失效。

---

## 成功解决的方案

为了根除这个"幽灵弹窗"，我们在配置中进行了以下几个层面的彻底清理和转移：

### 1. 禁用 AstroLSP 的 Buffer-Local 动态映射

**文件**：`lua/plugins/_astrolsp_mapping.lua`

这是最关键的一步。我们在用户的 AstroLSP 配置中显式声明了对应键位为 `false`，从而在 LSP Attach 阶段阻止了它生成这几个 buffer-local 快捷键：
```lua
      -- 禁用默认动态生成的 LSP Info 快捷键，掐断 which-key 组重建的根源
      maps.n["<Leader>li"] = false
      maps.n["<Leader>lI"] = false
```

### 2. 将遗留的 Language Tools 整体迁移到 `<Leader>s` 前缀

为了保留 LSP 相关功能的可用性，我们将它们集体搬家到了新的前缀 `<Leader>s` 下，包括但不限于：
- `<Leader>sI` 替代了原来的 `<Leader>li` (LSP Info)
- `<Leader>sn` 替代了原来的 `<Leader>lI` (Null-ls Info)
- 其他所有的 `sa`, `sf`, `sr` 同样也配置到了 `s` 下。

### 3. 清理各扩展包中的 `<Leader>l` 子映射

除了核心的 AstroLSP，各个语言特定扩展包中也带有自己的子映射。我们对这些文件进行了全局替换，把 `l` 换成了 `s`：
- `pack-markdown.lua` -> `<Leader>st` 等等
- `pack-proto.lua` -> `<Leader>sc`
- `pack-sql.lua` -> `<Leader>sc`
- `pack-typescript.lua` -> `<Leader>sa`

### 4. 正确注册 `$` 映射

**文件**：`lua/plugins/_astrocore_mappings.lua`

有了上面彻底清理的护航，我们现在可以正常地在 AstroCore 中注册需要的直接跳转了：
```lua
      maps.n["<Leader>l"] = { "$", desc = "Go to end of line" }
      maps.v["<Leader>l"] = { "$", desc = "Go to end of line" }
```

---

## 走过的弯路（已还原的无效调整）

在排查过程中，我们曾怀疑是 Neovim API 与 which-key API 的注册优先级冲突，尝试在 `init.lua` 中强行写入以下代码来暴力压制：
```lua
vim.api.nvim_create_autocmd("VimEnter", { ... wk.add(...) })
vim.api.nvim_create_autocmd("LspAttach", { ... wk.add(...) })
```
由于当时并没有找到 LSP 动态下发 buffer-local 映射的真凶，这种强制压制的方式不仅未能彻底解决问题，还让配置变得丑陋。

**目前状态**：这些针对 `init.lua` 的临时性、无效性 hack 代码**均已被还原删除**。

---

## 结论

冲突已被完美解决：
- `Space + l`：无延迟跳转到行尾。
- `Space + s`：唤出所有的 LSP 工具菜单（Language Tools）。

*解决时间：2026-06-03*
