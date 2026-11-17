local treesitter = require('nvim-treesitter')
local dependencies = require('dependencies')
local platform = require('platform')
local progress = require('bread.install_progress')

-- Windows CLI builds default to MSVC even when only GCC/Clang is installed.
-- Pass our available compiler to tree-sitter, keeping an explicit user choice.
if platform.windows and (vim.env.CC or '') == '' then
    vim.env.CC = platform.find({ 'gcc', 'clang', 'cc', 'cl' })
end

dependencies.setup()
require('bread.startup').checkpoint()
dependencies.parsers_ready = false
treesitter.setup({})

local function highlight(buf)
    -- Parsers may still be downloading on the first launch; retry after installation.
    pcall(vim.treesitter.start, buf)
end

vim.api.nvim_create_autocmd('FileType', {
    group = vim.api.nvim_create_augroup('BreadTreesitter', { clear = true }),
    callback = function(event) highlight(event.buf) end,
})

local installing = false
local function install_parsers()
    if installing then return end
    dependencies.parsers_ready = false
    local installed = treesitter.get_installed('parsers')
    if vim.iter(dependencies.parsers):all(function(lang) return vim.tbl_contains(installed, lang) end) then
        dependencies.parsers_ready = true
        progress.clear('parsers')
        return
    end
    progress.begin('parsers', 'Parsers', #dependencies.parsers)
    if vim.fn.executable('tree-sitter') == 0 or not platform.find({ 'gcc', 'clang', 'cc', 'cl' }) then
        progress.finish('parsers', 1)
        vim.notify('缺少 Tree-sitter CLI 或 C 编译器；运行 :BootstrapDeps 和 :InstallTools 重试。', vim.log.levels.WARN)
        return
    end
    local function report()
        local available, missing = treesitter.get_installed('parsers'), {}
        for _, lang in ipairs(dependencies.parsers) do
            if not vim.tbl_contains(available, lang) then missing[#missing + 1] = lang end
        end
        local detail = #missing > 0 and 'pending: ' .. table.concat(missing, ', ', 1, math.min(2, #missing)) or ''
        if #missing > 2 then detail = detail .. ' +' .. (#missing - 2) end
        progress.update('parsers', #dependencies.parsers - #missing, detail)
        return missing
    end
    installing = true
    local watching = true
    local function monitor()
        if not watching then return end
        report()
        vim.defer_fn(monitor, 200)
    end
    monitor()
    treesitter.install(dependencies.parsers):await(function(err, success)
        vim.schedule(function()
            watching = false
            installing = false
            local missing = report()
            progress.finish('parsers', (err or success == false) and math.max(1, #missing) or #missing)
            if err or success == false then
                vim.notify('语法解析器安装失败: ' .. tostring(err) .. '\n运行 :InstallTools 重试。', vim.log.levels.ERROR)
                return
            end
            local installed = treesitter.get_installed('parsers')
            for _, lang in ipairs(dependencies.parsers) do
                if not vim.tbl_contains(installed, lang) then
                    vim.notify(lang .. ' 解析器安装未完成；运行 :InstallTools 重试。', vim.log.levels.WARN)
                    return
                end
            end
            dependencies.parsers_ready = true
            for _, buf in ipairs(vim.api.nvim_list_bufs()) do
                if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype ~= '' then highlight(buf) end
            end
        end)
    end)
end

vim.api.nvim_create_user_command('InstallTools', function()
    dependencies.ensure(install_parsers)
end, { desc = '安装缺失的 LSP、调试器、Tree-sitter CLI 和语法解析器' })

if vim.env.NVIM_NO_INSTALL ~= '1' then dependencies.ensure(install_parsers) end

for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype ~= '' then highlight(buf) end
end
