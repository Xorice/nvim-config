-- Neovim 0.12+ (Nightly)
-- * 面包 NVIM

vim.opt.runtimepath:prepend(vim.fn.stdpath('config'))

require('platform').setup()
require('options')
require('project').setup()
if not require('bootstrap').setup() then return end
local installed, install_error = pcall(require, 'plugins')
if not installed then
    vim.notify('插件安装/加载失败，请检查网络后重启:\n' .. tostring(install_error), vim.log.levels.ERROR)
    return
end

vim.schedule(function()
    for _, name in ipairs({ 'theme', 'cmp', 'lsp', 'debugger', 'treesitter', 'ui', 'tools' }) do
        local ok, err = xpcall(function() require('config.' .. name) end, debug.traceback)
        if not ok then
            vim.notify('配置模块 ' .. name .. ' 加载失败:\n' .. err, vim.log.levels.ERROR)
        end
    end
end)

require('keymaps')
