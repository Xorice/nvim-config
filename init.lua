-- Neovim 0.12+ (Nightly)
-- * 面包 NVIM

vim.opt.runtimepath:prepend(vim.fn.stdpath('config'))

require('options')
-- Filetype detection must be registered before command-line files are read.
require('project').setup()
-- The explorer is loaded after the UI attaches; prevent netrw taking the directory first.
vim.g.loaded_netrwPlugin = 1

require('bread.startup').run({
    { label = 'Environment', fatal = true, run = function() require('platform').setup() end },
    { label = 'Dependencies', fatal = true, run = function() return require('bootstrap').setup() end },
    { label = 'Plugins', fatal = true, run = function() require('plugins') end },
    { label = 'Theme', run = function() require('config.theme') end },
    { label = 'Completion', run = function() require('config.cmp') end },
    { label = 'Syntax', run = function() require('config.treesitter') end },
    { label = 'Interface', run = function() require('config.ui') end },
    { label = 'Tools', run = function() require('config.tools') end },
    { label = 'Keymaps', run = function() require('keymaps') end },
    { label = 'Workspace', run = function()
        -- UIEnter happens after the initial FileType/BufEnter events.
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buflisted then require('plugins').activate(buf) end
        end
    end },
})
