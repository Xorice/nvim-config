local treesitter = require('nvim-treesitter')
local dependencies = require('dependencies')
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

local function install_parsers()
    dependencies.parsers_ready = false
    if vim.fn.executable('tree-sitter') == 0 then return end
    if not require('platform').find({ 'gcc', 'clang', 'cc', 'cl' }) then return end
    treesitter.install(dependencies.parsers):await(function(err, success)
        vim.schedule(function()
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
