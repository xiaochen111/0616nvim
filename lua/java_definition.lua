local M = {}

-- 判断 jdtls 是否返回了可跳转的定义位置。
local function has_definition(result)
  if not result then return false end
  if vim.islist(result) then return #result > 0 end
  return result.uri ~= nil or result.targetUri ~= nil
end

-- 获取当前 Java buffer 对应的 jdtls 客户端。
local function get_jdtls_client(bufnr)
  return vim.lsp.get_clients { bufnr = bufnr, name = "jdtls" }[1]
end

-- 请求 Java 定义；首次失败时刷新项目配置，重试后询问是否重建缓存。
local function request_definition(client, bufnr, params, attempt)
  local settled = false

  -- 统一处理 LSP 空结果、错误和超时，避免同一请求重复触发修复。
  local function finish(err, result)
    if settled then return end
    settled = true

    if has_definition(result) then
      local locations = vim.islist(result) and result or { result }
      if #locations == 1 then
        vim.lsp.util.show_document(locations[1], client.offset_encoding, { focus = true })
      else
        local items = vim.lsp.util.locations_to_items(locations, client.offset_encoding)
        vim.fn.setqflist({}, " ", { title = "Java definitions", items = items })
        vim.cmd.copen()
      end
      return
    end

    if attempt == 0 then
      local detail = err and (": " .. (err.message or tostring(err))) or ""
      vim.notify("Java 定义未找到，正在自动刷新 Maven 项目配置" .. detail, vim.log.levels.WARN)
      vim.api.nvim_buf_call(bufnr, function() require("jdtls").update_project_config() end)
    end

    if attempt < 1 then
      vim.defer_fn(function()
        if not vim.api.nvim_buf_is_valid(bufnr) or client:is_stopped() then return end
        request_definition(client, bufnr, params, attempt + 1)
      end, 3000)
      return
    end

    vim.notify("刷新后仍未找到定义，请确认是否重建 jdtls 缓存", vim.log.levels.WARN)
    vim.api.nvim_buf_call(bufnr, function() require("jdtls.setup").wipe_data_and_restart() end)
  end

  local success, request_id = client:request("textDocument/definition", params, finish, bufnr)
  if not success then
    finish({ message = "请求发送失败" })
    return
  end

  vim.defer_fn(function()
    if settled then return end
    client:cancel_request(request_id)
    finish({ message = "请求超时" })
  end, 5000)
end

-- 跳转到当前 Java 符号定义，并在项目模型失效时自动尝试修复。
function M.goto_definition()
  local bufnr = vim.api.nvim_get_current_buf()
  local client = get_jdtls_client(bufnr)
  if not client then
    vim.notify("jdtls 尚未就绪，请等待 Java Language Server 启动完成", vim.log.levels.WARN)
    return
  end

  local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
  request_definition(client, bufnr, params, 0)
end

return M
