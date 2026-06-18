local M = {}
local RECORD_SEP = string.char(30)
local FIELD_SEP = string.char(31)
local FOLLOW_LOG_FORMAT = ("--format=%s%%H%s%%P%s%%ct%s%%cs%s%%an%s%%s"):format(
  RECORD_SEP,
  FIELD_SEP,
  FIELD_SEP,
  FIELD_SEP,
  FIELD_SEP,
  FIELD_SEP
)
local COMMIT_META_FORMAT = ("--format=%%H%s%%ct%s%%cs%s%%an%s%%s"):format(
  FIELD_SEP,
  FIELD_SEP,
  FIELD_SEP,
  FIELD_SEP
)

local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local conf = require("telescope.config").values
local actions = require "telescope.actions"
local action_state = require "telescope.actions.state"

local function run_git(args)
  local cmd = { "git" }
  vim.list_extend(cmd, args)

  local output = vim.fn.systemlist(cmd)
  if vim.v.shell_error ~= 0 then return nil end

  return output
end

local function make_entry(meta, path, order)
  return {
    sha = meta.sha,
    short_sha = meta.sha:sub(1, 7),
    date = meta.date,
    author = meta.author,
    subject = meta.subject,
    timestamp = meta.timestamp,
    path = path,
    order = order,
  }
end

local function parse_log_entries(lines)
  local entries = {}
  local current

  for _, line in ipairs(lines) do
    if vim.startswith(line, RECORD_SEP) then
      local meta = line:sub(2)
      local parts = vim.split(meta, FIELD_SEP, { plain = true })
      current = {
        sha = parts[1] or "",
        parents = parts[2] ~= "" and vim.split(parts[2], " ", { trimempty = true }) or {},
        timestamp = tonumber(parts[3]) or 0,
        date = parts[4] or "",
        author = parts[5] or "",
        subject = parts[6] or "",
        changes = {},
      }
      table.insert(entries, current)
    elseif line ~= "" and current then
      table.insert(current.changes, line)
    end
  end

  return entries
end

local function get_commit_metadata(git_root, sha)
  local output = run_git({ "-C", git_root, "show", "-s", COMMIT_META_FORMAT, sha })
  if not output or not output[1] then return nil, "Failed to read git history" end

  local parts = vim.split(output[1], FIELD_SEP, { plain = true })
  return {
    sha = parts[1] or sha,
    timestamp = tonumber(parts[2]) or 0,
    date = parts[3] or "",
    author = parts[4] or "",
    subject = parts[5] or "",
  }
end

local function get_current_file_context()
  local abs_path = vim.api.nvim_buf_get_name(0)
  if abs_path == "" or vim.bo.buftype ~= "" or vim.fn.filereadable(abs_path) ~= 1 then
    return nil, "Current buffer is not a file"
  end

  abs_path = vim.fs.normalize(abs_path)
  local file_dir = vim.fs.dirname(abs_path)
  local git_root_output = run_git({ "-C", file_dir, "rev-parse", "--show-toplevel" })
  if not git_root_output or not git_root_output[1] or git_root_output[1] == "" then
    return nil, "Not in a git repository"
  end

  local git_root = vim.fs.normalize(git_root_output[1])
  local rel_path = vim.fs.relpath(git_root, abs_path)
  if not rel_path or rel_path == "" then return nil, "Not in a git repository" end

  local tracked = run_git({ "-C", git_root, "ls-files", "--error-unmatch", "--", rel_path })
  if not tracked then return nil, "File is not tracked by git" end

  return {
    abs_path = abs_path,
    git_root = git_root,
    rel_path = rel_path,
    file_name = vim.fs.basename(abs_path),
  }
end

local function get_follow_history(context)
  local log_output = run_git({
    "-C",
    context.git_root,
    "log",
    "--follow",
    "--name-status",
    FOLLOW_LOG_FORMAT,
    "--",
    context.rel_path,
  })
  if not log_output then return nil, "Failed to read git history" end

  local entries = parse_log_entries(log_output)
  if #entries == 0 then return nil, "No git history found for file" end

  local segments = { { path = context.rel_path, tip = "HEAD" } }
  local path_at_commit = context.rel_path
  local history_entries = {}
  local order = 0

  for _, entry in ipairs(entries) do
    local entry_path = path_at_commit

    if #entry.parents <= 1 then
      order = order + 1
      table.insert(history_entries, make_entry(entry, entry_path, order))
    end

    for _, change in ipairs(entry.changes) do
      local parts = vim.split(change, "\t", { plain = true })
      if parts[1] and parts[1]:match "^R" and parts[3] == entry_path then
        local parent = entry.parents[1]
        if parent and parent ~= "" then
          path_at_commit = parts[2]
          table.insert(segments, { path = path_at_commit, tip = parent })
        end
        break
      end
    end
  end

  return history_entries, segments, order
end

local function merge_has_file_patch(git_root, sha, path)
  local output = run_git({ "-C", git_root, "diff-tree", "-c", "--name-status", sha, "--", path })
  if not output then return nil, "Failed to read git history" end

  for _, line in ipairs(output) do
    if line:find("\t", 1, true) then
      local parts = vim.split(line, "\t", { plain = true })
      if parts[#parts] == path then return true end
    end
  end

  return false
end

local function get_merge_entries(context, segments, order)
  local merge_entries = {}
  local seen = {}

  for _, segment in ipairs(segments) do
    local lines = run_git({ "-C", context.git_root, "rev-list", "--full-history", "--parents", segment.tip, "--", segment.path })
    if not lines then return nil, "Failed to read git history" end

    for _, line in ipairs(lines) do
      local parts = vim.split(line, " ", { trimempty = true })
      local sha = parts[1]
      if sha and #parts > 2 and not seen[sha] then
        seen[sha] = true
        local has_patch, err = merge_has_file_patch(context.git_root, sha, segment.path)
        if err then return nil, err end
        if has_patch then
          local meta
          meta, err = get_commit_metadata(context.git_root, sha)
          if err then return nil, err end
          order = order + 1
          table.insert(merge_entries, make_entry(meta, segment.path, order))
        end
      end
    end
  end

  return merge_entries
end

local function sort_entries(entries)
  table.sort(entries, function(a, b)
    if a.timestamp ~= b.timestamp then return a.timestamp > b.timestamp end
    return a.order < b.order
  end)

  for _, entry in ipairs(entries) do
    entry.order = nil
  end
end

local function make_display(entry)
  return ("%s  %s  %s  %s"):format(entry.short_sha, entry.date, entry.author, entry.subject)
end

local function get_commit_file_diff(context, sha, path)
  local lines = run_git({
    "-C",
    context.git_root,
    "show",
    "--format=",
    sha,
    "--",
    path,
  })
  if not lines then return nil, "git show failed" end
  if vim.tbl_isempty(lines) then return nil, "No diff for selected commit" end
  return lines
end

local function open_diff_buffer(context, entry)
  local diff_lines, err = get_commit_file_diff(context, entry.sha, entry.path)
  if not diff_lines then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  vim.cmd "botright new"
  local buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_name(buf, ("git://%s/%s"):format(entry.short_sha, context.rel_path))
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, diff_lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].filetype = "diff"
end

local function open_picker(context, entries)
  pickers
    .new({}, {
      prompt_title = ("Git File History: %s"):format(context.file_name),
      finder = finders.new_table {
        results = entries,
        entry_maker = function(entry)
          return {
            value = entry,
            display = make_display(entry),
            ordinal = ("%s %s %s %s"):format(entry.short_sha, entry.author, entry.date, entry.subject),
          }
        end,
      },
      sorter = conf.generic_sorter({}),
      previewer = conf.grep_previewer({}),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if selection then open_diff_buffer(context, selection.value) end
        end)
        return true
      end,
    })
    :find()
end

local function get_file_history_entries(context)
  local entries, segments, order_or_err = get_follow_history(context)
  if not entries then return nil, segments end

  local merge_entries, err = get_merge_entries(context, segments, order_or_err)
  if not merge_entries then return nil, err end

  vim.list_extend(entries, merge_entries)

  if #entries == 0 then return nil, "No git history found for file" end

  sort_entries(entries)

  return entries
end

function M.open_file_history()
  local context, err = get_current_file_context()
  if err then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  local entries
  entries, err = get_file_history_entries(context)
  if err then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  open_picker(context, entries)
end

function M.test_get_entries()
  local context, err = get_current_file_context()
  if err then return nil, err end
  return get_file_history_entries(context), context
end

function M.test_get_diff(sha, path)
  local context, err = get_current_file_context()
  if err then return nil, err end
  return get_commit_file_diff(context, sha, path)
end

return M
