local M = {}
local platform = require('platform')

function M.missing(deep)
    local missing = {}
    local cache_path = vim.fs.joinpath(vim.fn.stdpath('state'), 'bread-system-tools.json')
    local fingerprint = vim.fn.sha256((vim.env.PATH or '') .. '\n' .. (vim.env.PATHEXT or ''))
    local ok, value = pcall(function() return vim.json.decode(table.concat(vim.fn.readfile(cache_path), '\n')) end)
    local cached = ok and type(value) == 'table' and value or {}
    local known = cached.fingerprint == fingerprint and type(cached.tools) == 'table' and cached.tools or {}
    local tools = {}
    local function available(names)
        local key = table.concat(names, '/')
        if not deep and type(known[key]) == 'string' and vim.fn.executable(known[key]) == 1 then
            tools[key] = known[key]
        else tools[key] = platform.find(names) end
        return tools[key] ~= nil
    end
    for _, names in ipairs({ { 'git' }, { 'curl' }, { 'tar' }, { 'gzip' }, { 'node' },
        { 'npm' }, { 'python3', 'python' }, { 'gcc', 'clang', 'cc' },
        { 'g++', 'clang++', 'c++' }, { 'rg' }, { 'fd', 'fdfind' } }) do
        if not available(names) then table.insert(missing, table.concat(names, '/')) end
    end
    if platform.windows then
        if not available({ '7z', '7za' }) then table.insert(missing, '7z') end
    elseif not available({ 'unzip' }) then
        table.insert(missing, 'unzip')
    end
    if cached.fingerprint ~= fingerprint or not vim.deep_equal(cached.tools, tools) then
        -- Caching is optional; an unwritable state directory must not prevent editing.
        pcall(function()
            vim.fn.mkdir(vim.fn.stdpath('state'), 'p')
            vim.fn.writefile({ vim.json.encode({ fingerprint = fingerprint, tools = tools }) }, cache_path)
        end)
    end
    local python = deep and platform.python()
    if python then
        local result = vim.system({ python, '-c', 'import venv, ensurepip' }, { text = true }):wait(5000)
        if result.code ~= 0 then table.insert(missing, 'python-venv/ensurepip') end
    end
    return missing
end

function M.install()
    if M.running then return end
    local script = vim.fs.joinpath(vim.fn.stdpath('config'), 'scripts', platform.windows and 'bootstrap.ps1' or 'bootstrap.sh')
    local command = platform.windows
        and { platform.find({ 'pwsh', 'powershell' }), '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', script }
        or { 'bash', script }
    vim.cmd('botright new')
    M.running = true
    local job = vim.fn.jobstart(command, {
        term = true,
        on_exit = function(_, code)
            M.running = false
            vim.schedule(function()
                vim.notify(code == 0 and '系统依赖安装完成，请重新打开 Neovim，继续自动安装语言工具和语法解析器。'
                    or '依赖安装失败，详情见终端输出。修复后运行 :BootstrapDeps 重试。',
                    code == 0 and vim.log.levels.INFO or vim.log.levels.ERROR)
            end)
        end,
    })
    if job <= 0 then
        M.running = false
        vim.notify('无法启动依赖安装脚本: ' .. script, vim.log.levels.ERROR)
    else
        vim.cmd('startinsert')
    end
end

function M.setup()
    vim.api.nvim_create_user_command('BootstrapDeps', M.install, { desc = '安装缺失的系统依赖' })
    if vim.fn.has('nvim-0.12') == 0 or not vim.pack then
        vim.notify('这份配置需要 Neovim 0.12+（vim.pack）。请先更新 Neovim。', vim.log.levels.ERROR)
        return false
    end
    local missing = M.missing()
    if #missing > 0 and vim.env.NVIM_NO_BOOTSTRAP ~= '1' and #vim.api.nvim_list_uis() > 0 then
        local marker = vim.fs.joinpath(vim.fn.stdpath('state'), 'bread-bootstrap-attempted')
        if vim.fn.filereadable(marker) == 0 then
            vim.fn.mkdir(vim.fn.stdpath('state'), 'p')
            vim.fn.writefile({ os.date() }, marker)
            vim.api.nvim_create_autocmd('VimEnter', { once = true, callback = function()
                vim.notify('首次启动，正在安装系统依赖: ' .. table.concat(missing, ', '))
                M.install()
            end })
            return false
        end
    end
    if #missing > 0 then
        vim.schedule(function()
            vim.notify('缺少系统依赖: ' .. table.concat(missing, ', ')
                .. '\n运行 :BootstrapDeps 安装；:checkhealth bread 查看详情。', vim.log.levels.WARN)
        end)
    end
    return true
end

return M
