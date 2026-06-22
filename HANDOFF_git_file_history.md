# Git File History Handoff

## Current Status

当前没完成的是 `Task 3` 的质量修复，`Task 4/5` 还没开始。

### Done

- `Task 1` 已完成
  - 新增入口：[lua/utils.lua](/Users/chenhb/.config/nvim/lua/utils.lua:3)
  - 新增快捷键：[lua/plugins/_astrocore_mappings.lua](/Users/chenhb/.config/nvim/lua/plugins/_astrocore_mappings.lua:184)
  - 当前快捷键是 `<leader>gh`
- `Task 2` 已完成
  - 当前文件 Git 上下文解析已就位
  - 错误消息已处理：
    - `Current buffer is not a file`
    - `Not in a git repository`
    - `File is not tracked by git`
- `Task 3` 已有第一版实现
  - 文件：[lua/utils/git_file_history.lua](/Users/chenhb/.config/nvim/lua/utils/git_file_history.lua:1)
  - 当前可输出 `git history entries: N`
  - 但代码质量 review 发现算法需要继续修

## Unfinished Work

### Task 3 Issues To Fix

`lua/utils/git_file_history.lua` 当前实现有 3 个未修复问题：

1. `historical_paths` 只保存了旧路径名，没有限定“这个旧路径属于当前文件的哪一段历史”。
   - 风险：如果旧路径后来被别的文件复用，merge 收集会误把无关历史算进当前文件。

2. 返回的 `entries` 结构不统一，不适合下一步 Telescope UI。
   - 下个实现需要统一至少包含：
     - `sha`
     - `short_sha`
     - `date`
     - `author`
     - `subject`
     - `timestamp`
     - `path`

3. `entries` 顺序不对。
   - 现在是普通提交先放，merge 再 append 到末尾。
   - 应改成统一按时间倒序排序。

## Recommended Fix Direction

下一个 AI 可以直接按这个方向修：

- 非 merge 历史继续用 `git log --follow`
  - 用来拿 rename 链和普通提交
- merge 候选不要再按所有 `historical_paths` 从 `HEAD` 全量扫
  - 要按 path segment 限制范围
- 一个可行做法：
  - 当前路径段从 `HEAD` 开始
  - 遇到 rename commit 后，旧路径段的查询 tip 用该 rename commit 的父提交
  - 然后对每个 segment 跑：

```bash
git rev-list --full-history --parents <tip> -- <path>
```

- merge 是否是“手工冲突解决”建议用：

```bash
git diff-tree -c --name-status <sha> -- <path>
```

- 已验证规律：
  - 纯自动 merge：只有 sha 行，没有文件改动行
  - 手工冲突 merge：会出现类似 `MM\tdemo.txt`

- 最终把所有 entries 补齐 metadata，再按 `timestamp` 倒序排序

## Verified Git Behavior

这些结论已经实测过：

- `git log --follow` / `git log --follow --full-history`
  - 拿不到想保留的手工 merge 记录
- `git rev-list --full-history --parents HEAD -- <file>`
  - 会把相关 merge 带出来
- 但它也会带出纯自动 merge
  - 所以还要结合 `git diff-tree -c --name-status`
- `git diff-tree -c --name-status <merge-sha> -- <file>`
  - 自动 merge：无文件改动行
  - 手工冲突 merge：有 `MM\t<file>`

## Validation Still Required After Fix

修完 `Task 3` 后，需要重新跑这 4 组验证：

1. 当前仓库文件
   - 例如 `init.lua`
2. 自动 merge 场景
   - merge 存在，但必须被过滤
3. 手工冲突 merge 场景
   - merge 必须被保留
4. `rename + old path reused`
   - 确保不会误收别的文件历史

## Next Steps

1. 修 [lua/utils/git_file_history.lua](/Users/chenhb/.config/nvim/lua/utils/git_file_history.lua:1) 的 `Task 3` 算法
2. 重新跑 4 组验证
3. 继续实现 `Task 4`
   - Telescope picker
   - 选中提交后只看当前文件 diff
4. 继续实现 `Task 5`
   - `stylua`
   - headless 验证
   - 最终 commit

## Related Files

- 已修改：
  - [lua/utils.lua](/Users/chenhb/.config/nvim/lua/utils.lua:1)
  - [lua/plugins/_astrocore_mappings.lua](/Users/chenhb/.config/nvim/lua/plugins/_astrocore_mappings.lua:1)
  - [lua/utils/git_file_history.lua](/Users/chenhb/.config/nvim/lua/utils/git_file_history.lua:1)
- 设计与计划：
  - [2026-06-18-git-file-history-design.md](/Users/chenhb/.config/nvim/docs/superpowers/specs/2026-06-18-git-file-history-design.md:1)
  - [2026-06-18-git-file-history.md](/Users/chenhb/.config/nvim/docs/superpowers/plans/2026-06-18-git-file-history.md:1)

## Note

- 中断前，已有一个子代理被要求修 `Task 3` 的质量问题，但没有返回完成结果。
- 如果下一个 AI 不继续用子代理，直接本地修也可以。
