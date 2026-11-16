local M = {}

M.packages = { 'lua-language-server', 'clangd', 'pyright', 'luau-lsp', 'codelldb', 'debugpy', 'tree-sitter-cli' }
M.parsers = { 'lua', 'luau', 'c', 'cpp', 'python', 'markdown', 'markdown_inline', 'vim', 'vimdoc', 'query' }

function M.ensure(callback)
    if M.running then return end
    M.running = true
    local registry = require('mason-registry')
    registry.refresh(vim.schedule_wrap(function(ok)
        if not ok then
            M.running = false
            vim.notify('Mason registry 下载失败，运行 :MasonLog 查看日志；:InstallTools 重试。', vim.log.levels.ERROR)
            return
        end
        local pending = #M.packages
        local function finished()
            pending = pending - 1
            if pending == 0 then
                M.running = false
                if callback then vim.schedule(callback) end
            end
        end
        for _, name in ipairs(M.packages) do
            local found, package = pcall(registry.get_package, name)
            if not found then
                vim.notify('Mason 找不到软件包: ' .. name, vim.log.levels.ERROR)
                finished()
            elseif package:is_installed() then
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

return M
