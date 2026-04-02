local opt = vim.opt

vim.g.mapleader      = ","
vim.g.maplocalleader = ","

opt.number         = true
opt.relativenumber = false
opt.tabstop        = 4
opt.shiftwidth     = 4
opt.expandtab      = true
opt.termguicolors  = true
opt.signcolumn     = "yes"
opt.cursorline     = true
opt.mouse          = "a"

-- VSCode 风格折叠
opt.foldcolumn    = '1'
opt.fillchars     = [[eob: ,fold: ,foldopen:,foldsep: ,foldclose:]] -- 更加现代的图标
opt.foldlevel     = 99
opt.foldlevelstart = 99
opt.foldenable    = true
