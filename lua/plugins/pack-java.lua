local function java_home(version)
  local path = vim.fn.expand("~/.sdkman/candidates/java/" .. version)
  return vim.fn.isdirectory(path) == 1 and path or nil
end

local function find_jdtls_java_home()
  local candidates = {
    "21",
    "21.0.7-tem",
    "21.0.6-tem",
    "21.0.5-tem",
    "21.0.4-tem",
    "21.0.3-tem",
    "22",
    "23",
    "24",
  }

  for _, version in ipairs(candidates) do
    local path = java_home(version)
    if path then return path end
  end

  for _, entry in ipairs(vim.fn.readdir(vim.fn.expand "~/.sdkman/candidates/java")) do
    if entry ~= "current" then
      local major = tonumber(entry:match "^(%d+)")
      local path = java_home(entry)
      if major and major >= 21 and path then return path end
    end
  end
end

local function start_jdtls(opts)
  local root_dir = vim.fs.root(0, {
    ".git",
    "mvnw",
    "gradlew",
    "pom.xml",
    "build.gradle",
    "build.gradle.kts",
    "settings.gradle",
    "settings.gradle.kts",
  })

  if not root_dir or root_dir == "" then
    require("astrocore").notify("jdtls: root_dir not found. Please open the Java project root.", vim.log.levels.ERROR)
    return
  end

  opts.root_dir = root_dir
  require("jdtls").start_or_attach(opts)
end

---@type LazySpec
return {
  {
    "mfussenegger/nvim-jdtls",
    optional = true,
    opts = function(_, opts)
      local jdtls_java_home = find_jdtls_java_home()
      local java_8_home = java_home "8.0.492-tem"
      local java_17_home = java_home "17.0.19-tem"

      opts.cmd = opts.cmd or {}
      if jdtls_java_home then
        opts.cmd[1] = jdtls_java_home .. "/bin/java"
      elseif java_17_home then
        opts.cmd[1] = java_17_home .. "/bin/java"
        vim.schedule(function()
          require("astrocore").notify(
            "jdtls now requires Java 21+ to launch. Install a Java 21 SDK to restore Java LSP.",
            vim.log.levels.WARN
          )
        end)
      end

      opts.settings = opts.settings or {}
      opts.settings.java = opts.settings.java or {}
      opts.settings.java.configuration = opts.settings.java.configuration or {}
      opts.settings.java.configuration.runtimes = vim.tbl_filter(function(runtime) return runtime.path end, {
        {
          name = "JavaSE-1.8",
          path = java_8_home,
          default = true,
        },
        {
          name = "JavaSE-17",
          path = java_17_home,
        },
        {
          name = "JavaSE-21",
          path = jdtls_java_home,
        },
      })
    end,
    config = function(_, opts)
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "java",
        callback = function() start_jdtls(vim.deepcopy(opts)) end,
      })

      if vim.bo.filetype == "java" then start_jdtls(vim.deepcopy(opts)) end
    end,
  },
}
