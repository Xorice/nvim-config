local M = {}

M.packages = { 'lua-language-server', 'clangd', 'pyright', 'luau-lsp', 'codelldb', 'debugpy', 'tree-sitter-cli' }
M.parsers = { 'lua', 'luau', 'c', 'cpp', 'python', 'markdown', 'markdown_inline', 'vim', 'vimdoc', 'query' }

local function outdated_luau()
    local path = vim.fs.joinpath(vim.fn.stdpath('data'), 'mason', 'packages', 'luau-lsp',
        require('platform').windows and 'luau-lsp.exe' or 'luau-lsp')
    if vim.fn.executable(path) ~= 1 then return true end
    local result = vim.system({ path, '--version' }, { text = true }):wait(5000)
    local version = result.stdout and result.stdout:match('%d+%.%d+%.%d+')
    return not version or vim.version.lt(version, '1.70.1')
end

function M.ensure(callback, update)
    if M.running then
        if update then vim.notify('工具安装任务正在运行，请完成后再执行 :UpdateTools。') end
        return
    end
    M.running = true
    if update then vim.notify('正在更新 Mason 工具；:Mason 查看进度。') end
    local registry = require('mason-registry')
    registry.refresh(vim.schedule_wrap(function(ok)
        if not ok then
            M.running = false
            vim.notify('Mason registry 下载失败，运行 :MasonLog 查看日志；:InstallTools 重试。', vim.log.levels.ERROR)
            return
        end
        local pending, failed = #M.packages, false
        local function finished()
            pending = pending - 1
            if pending == 0 then
                M.running = false
                if update and not failed then vim.notify('Mason 工具更新完成，请重启 Neovim。') end
                if callback then vim.schedule(callback) end
            end
        end
        for _, name in ipairs(M.packages) do
            local found, package = pcall(registry.get_package, name)
            if not found then
                failed = true
                vim.notify('Mason 找不到软件包: ' .. name, vim.log.levels.ERROR)
                finished()
            elseif package:is_installed() and not update and not (name == 'luau-lsp' and outdated_luau()) then
                finished()
            else
                local success, failure
                local function done()
                    package:off('install:success', success)
                    package:off('install:failed', failure)
                    finished()
                end
                success = vim.schedule_wrap(done)
                failure = vim.schedule_wrap(function()
                    failed = true
                    vim.notify(name .. ' 安装失败；:MasonLog 查看原因，:InstallTools 重试。', vim.log.levels.ERROR)
                    done()
                end)
                package:once('install:success', success)
                package:once('install:failed', failure)
                if not package:is_installing() then package:install() end
            end
        end
    end))
end

function M.setup()
    vim.api.nvim_create_user_command('UpdateTools', function() M.ensure(nil, true) end,
        { desc = '主动更新 Mason 语言服务和调试器到当前稳定版' })
end

return M
