return {
  "Exafunction/codeium.vim",
  event = "BufEnter",
  config = function()
    vim.keymap.set('i', '<M-\\>', function() return vim.fn['codeium#Complete']() end, { expr = true, silent = true }) 
  end
}

