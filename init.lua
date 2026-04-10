-- Nightly 0.12.x
-- * 面包 NVIM

vim.opt.runtimepath:prepend(vim.fn.stdpath('config'))

require('options')
require('plugins')

vim.schedule(function()
    require('config.theme')
    require('config.treesitter')
    require('config.cmp')
    require('config.lsp')
    require('config.debugger')
    require('config.ui')
    require('config.tools')
end)

require('keymaps')
