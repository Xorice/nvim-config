local M = {}
local progress = require('bread.install_progress')

M.packages = { 'lua-language-server', 'clangd', 'pyright', 'luau-lsp', 'codelldb', 'debugpy', 'tree-sitter-cli' }
M.parsers = { 'lua', 'luau', 'c', 'cpp', 'python', 'markdown', 'markdown_inline', 'vim', 'vimdoc', 'query' }

local function outdated_luau()
    local path = vim.fs.joinpath(vim.fn.stdpath('data'), 'mason', 'packages', 'luau-lsp', 'mason-receipt.json')
    local ok, receipt = pcall(function() return vim.json.decode(table.concat(vim.fn.readfile(path), '\n')) end)
    local id = ok and receipt.source and receipt.source.id or ''
    local version = id:match('@v?(%d+%.%d+%.%d+)$')
    return not version or vim.version.lt(version, '1.70.1')
end

function M.ensure(callback, update)
    if M.running then
        if update then vim.notify('工具安装任务正在运行，请完成后再执行 :UpdateTools。') end
        return
    end
    -- Installed tools work offline. Only load/refresh the registry when needed.
    if not update then
        local ready = not outdated_luau()
        for _, name in ipairs(M.packages) do
            ready = ready and vim.fn.filereadable(vim.fs.joinpath(vim.fn.stdpath('data'),
                'mason', 'packages', name, 'mason-receipt.json')) == 1
        end
        if ready then
            progress.clear('tools')
            if callback then vim.schedule(callback) end
            return
        end
    end
    M.running = true
    progress.begin('tools', 'Tools', #M.packages)
    progress.update('tools', 0, 'registry')
    if update then vim.notify('正在更新 Mason 工具；:Mason 查看进度。') end
    local registry = require('mason-registry')
    registry.refresh(vim.schedule_wrap(function(ok)
        if not ok then
            M.running = false
            progress.finish('tools', 1)
            vim.notify('Mason registry 下载失败，运行 :MasonLog 查看日志；:InstallTools 重试。', vim.log.levels.ERROR)
            return
        end
        local pending, failed, active = #M.packages, 0, {}
        local function report()
            local names = vim.tbl_keys(active)
            table.sort(names)
            local detail = table.concat(names, ', ', 1, math.min(2, #names))
            if #names > 2 then detail = detail .. ' +' .. (#names - 2) end
            progress.update('tools', #M.packages - pending, detail, failed)
        end
        local function finished(name, failure)
            active[name] = nil
            if failure then failed = failed + 1 end
            pending = pending - 1
            report()
            if pending == 0 then
                M.running = false
                progress.finish('tools', failed)
                if update and failed == 0 then vim.notify('Mason 工具更新完成，请重启 Neovim。') end
                if callback then vim.schedule(callback) end
            end
        end
        for _, name in ipairs(M.packages) do
            local found, package = pcall(registry.get_package, name)
            if not found then
                vim.notify('Mason 找不到软件包: ' .. name, vim.log.levels.ERROR)
                finished(name, true)
            elseif package:is_installed() and not update and not (name == 'luau-lsp' and outdated_luau()) then
                finished(name)
            else
                local success, failure
                local settled = false
                local function done(failed_install)
                    if settled then return end
                    settled = true
                    package:off('install:success', success)
                    package:off('install:failed', failure)
                    finished(name, failed_install)
                end
                success = vim.schedule_wrap(function() done() end)
                failure = vim.schedule_wrap(function()
                    vim.notify(name .. ' 安装失败；:MasonLog 查看原因，:InstallTools 重试。', vim.log.levels.ERROR)
                    done(true)
                end)
                package:once('install:success', success)
                package:once('install:failed', failure)
                active[name] = true
                report()
                if not package:is_installing() then package:install() end
            end
        end
    end))
end

function M.setup()
    if M.configured then return end
    M.configured = true
    require('mason').setup()
    vim.api.nvim_create_user_command('UpdateTools', function() M.ensure(nil, true) end,
        { desc = '主动更新 Mason 语言服务和调试器到当前稳定版' })
end

return M
