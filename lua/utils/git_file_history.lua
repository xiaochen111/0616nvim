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

local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local conf = require("telescope.config").values
local actions = require "telescope.actions"
local action_state = require "telescope.actions.state"
local previewers = require "telescope.previewers"
local putils = require "telescope.previewers.utils"

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
    "--full-history",
    "--name-status",
    FOLLOW_LOG_FORMAT,
    "--",
    context.rel_path,
  })
  if not log_output then return nil, "Failed to read git history" end

  local entries = parse_log_entries(log_output)
  if #entries == 0 then return nil, "No git history found for file" end

  local path_at_commit = context.rel_path
  local history_entries = {}
  local order = 0

  for _, entry in ipairs(entries) do
    local entry_path = path_at_commit

    if #entry.parents <= 1 then
      order = order + 1
      table.insert(history_entries, make_entry(entry, entry_path, order))
    else
      local has_patch = false
      for _, change in ipairs(entry.changes) do
        local parts = vim.split(change, "\t", { plain = true })
        if #parts >= 2 and parts[#parts] == entry_path then
          has_patch = true
          break
        end
      end
      if has_patch then
        order = order + 1
        table.insert(history_entries, make_entry(entry, entry_path, order))
      end
    end

    for _, change in ipairs(entry.changes) do
      local parts = vim.split(change, "\t", { plain = true })
      if parts[1] and parts[1]:match "^R" and parts[3] == entry_path then
        local parent = entry.parents[1]
        if parent and parent ~= "" then path_at_commit = parts[2] end
        break
      end
    end
  end

  return history_entries
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

local function make_diff_previewer(context)
  return previewers.new_buffer_previewer {
    title = "Commit Diff",
    get_buffer_by_name = function(_, entry) return entry.value.sha end,
    define_preview = function(self, entry, status)
      local diff_lines = get_commit_file_diff(context, entry.value.sha, entry.value.path)
      if not diff_lines then diff_lines = { "No diff available" } end

      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, diff_lines)
      putils.highlighter(self.state.bufnr, "diff")
    end,
  }
end

local function open_picker(context, entries)
  local function open_full_preview(entry)
    local diff_lines = get_commit_file_diff(context, entry.sha, entry.path)
    if not diff_lines then diff_lines = { "No diff available" } end

    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, diff_lines)
    vim.bo[buf].filetype = "diff"
    vim.bo[buf].modifiable = false
    vim.bo[buf].bufhidden = "wipe"

    local width = vim.o.columns
    local height = vim.o.lines
    local win = vim.api.nvim_open_win(buf, true, {
      relative = "editor",
      width = width - 4,
      height = height - 4,
      row = 2,
      col = 2,
      style = "minimal",
      border = "rounded",
      title = (" Diff: %s - %s "):format(entry.short_sha, entry.subject),
      title_pos = "center",
    })

    vim.keymap.set("n", "<Esc>", function()
      if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
      vim.schedule(function() open_picker(context, entries) end)
    end, { buffer = buf, nowait = true })
  end

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
      previewer = make_diff_previewer(context),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          if selection then
            actions.close(prompt_bufnr)
            vim.schedule(function() open_full_preview(selection.value) end)
          end
        end)

        return true
      end,
    })
    :find()
end

local function get_file_history_entries(context)
  local entries = get_follow_history(context)
  if not entries then return nil, "Failed to read git history" end

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
