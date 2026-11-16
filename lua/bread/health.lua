local M = {}

function M.check()
    local health = vim.health
    health.start('面包 NVIM')
    if vim.fn.has('nvim-0.12') == 1 then health.ok('Neovim 0.12+')
    else health.error('需要 Neovim 0.12+（vim.pack）') end
    local missing = require('bootstrap').missing(true)
    if #missing == 0 then health.ok('系统依赖齐全')
    else health.error('缺少: ' .. table.concat(missing, ', '), '运行 :BootstrapDeps') end
    local python = require('platform').python()
    if python then health.info('当前 Python: ' .. python) end
    local found, registry = pcall(require, 'mason-registry')
    for _, name in ipairs(require('dependencies').packages) do
        if found and registry.is_installed(name) then health.ok(name .. ' 已安装')
        else health.warn(name .. ' 未安装', '运行 :InstallTools；首次下载请等待 :Mason 完成') end
    end
    for _, lang in ipairs(require('dependencies').parsers) do
        local ok, loaded = pcall(vim.treesitter.language.add, lang)
        if ok and loaded then health.ok(lang .. ' parser 可用')
        else health.warn(lang .. ' parser 不可用', '运行 :InstallTools') end
    end
    if vim.fn.executable('rojo') == 0 then health.info('可选：Rojo 未安装；Luau 保留语言服务，自动 sourcemap 已关闭') end
    if not require('platform').find({ 'lovec', 'love' }) then health.info('可选：LÖVE 未安装；运行游戏需要另行安装') end
    health.info('终端图标需要选择 Nerd Font；AI 首次使用运行 :Codeium Auth')
end

return M
