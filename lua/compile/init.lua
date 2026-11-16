-- lua/compile/init.lua
-- 自动加载 compile/ 目录下所有语言模块

local M = {}

-------------------------------------------------------------------------------
-- 全局配置
-------------------------------------------------------------------------------
M.config = {
    debug_dir      = '__debug__',
    terminal_width = 40,
}

-------------------------------------------------------------------------------
-- 自动扫描并加载语言模块
-------------------------------------------------------------------------------
M.runners = {}

local compile_dir = vim.fn.stdpath('config') .. '/lua/compile'
local files = vim.fn.glob(compile_dir .. '/*.lua', false, true)

for _, path in ipairs(files) do
    local name = vim.fn.fnamemodify(path, ':t:r')
    if name ~= 'init' then
        local ok, runner = pcall(require, 'compile.' .. name)
        if ok and runner then
            M.runners[name] = runner
        end
    end
end

-------------------------------------------------------------------------------
-- 内部工具函数
-------------------------------------------------------------------------------
local function find_runner(ext)
    for _, runner in pairs(M.runners) do
        if runner.enabled ~= false then
            for _, e in ipairs(runner.ext) do
                if e == ext then return runner end
            end
        end
    end
    return nil
end

local function get_extra_flags(file, link_map)
    if not link_map then return {} end
    local flags   = {}
    local content = vim.fn.readfile(file)
    for _, line in ipairs(content) do
        for header, flag in pairs(link_map) do
            if line:match('#%s*include') and line:find(header, 1, true) then
                if not vim.tbl_contains(flags, flag) then
                    table.insert(flags, flag)
                end
            end
        end
    end
    return flags
end

local function close_terminal()
    if M.terminal_window and vim.api.nvim_win_is_valid(M.terminal_window)
        and vim.api.nvim_win_get_buf(M.terminal_window) == M.terminal_buffer then
        pcall(vim.api.nvim_win_close, M.terminal_window, true)
    end
    if M.terminal_buffer and vim.api.nvim_buf_is_valid(M.terminal_buffer) then
        vim.api.nvim_buf_delete(M.terminal_buffer, { force = true })
    end
    M.terminal_window, M.terminal_buffer = nil, nil
end

function M.stop()
    M.run_id = (M.run_id or 0) + 1
    if M.job then vim.fn.jobstop(M.job); M.job = nil end
end

function M.output()
    if not M.terminal_buffer or not vim.api.nvim_buf_is_valid(M.terminal_buffer) then
        vim.notify('还没有运行输出。')
        return
    end
    if M.terminal_window and vim.api.nvim_win_is_valid(M.terminal_window)
        and vim.api.nvim_win_get_buf(M.terminal_window) == M.terminal_buffer then
        vim.api.nvim_set_current_win(M.terminal_window)
        return
    end
    vim.cmd('botright vsplit')
    M.terminal_window = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(M.terminal_window, M.terminal_buffer)
    vim.cmd('vertical resize ' .. M.config.terminal_width)
end

local function open_terminal(cmd, dir, on_exit)
    if vim.fn.executable(cmd[1]) == 0 then
        vim.notify('找不到可执行文件: ' .. cmd[1] .. '\n运行 :BootstrapDeps 检查系统依赖。', vim.log.levels.ERROR)
        return
    end
    close_terminal()
    vim.cmd('botright vnew')
    M.terminal_window = vim.api.nvim_get_current_win()
    M.terminal_buffer = vim.api.nvim_get_current_buf()
    vim.cmd('vertical resize ' .. M.config.terminal_width)
    local run_id = M.run_id
    local job
    job = vim.fn.jobstart(cmd, { term = true, cwd = dir, on_exit = function(id, code, event)
        if M.job == id then M.job = nil end
        if run_id ~= M.run_id then return end
        if on_exit then on_exit(id, code, event)
        elseif code ~= 0 then
            vim.schedule(function() vim.notify('程序已退出，退出码 ' .. code .. '；详情见运行终端。', vim.log.levels.WARN) end)
        end
    end })
    if job <= 0 then
        vim.notify('无法启动: ' .. cmd[1], vim.log.levels.ERROR)
        return
    end
    M.job = job
    vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { buffer = M.terminal_buffer, desc = '退出终端输入模式' })
    vim.cmd('startinsert')
end

-------------------------------------------------------------------------------
-- 主入口
-------------------------------------------------------------------------------
function M.run(opts)
    opts = opts or {}
    local file = vim.fn.expand('%:p')
    local name = vim.fn.expand('%:t:r')
    local dir  = vim.fn.expand('%:p:h')
    local ext  = vim.fn.expand('%:e')

    local info = require('project').detect(file)
    if info.kind == 'roblox' then
        vim.notify('Roblox 脚本请在 Studio 中运行；Rojo serve/build 继续使用外部终端。', vim.log.levels.INFO)
        return
    end
    local runner
    if info.kind == 'love' or opts.love then
        if not info.entry then
            vim.notify('未找到 LÖVE 入口：项目根目录或 src/ 中需要有 main.lua。', vim.log.levels.WARN)
            return
        end
        local love = require('platform').find({ 'lovec', 'love' })
        if not love then vim.notify('请先安装 LÖVE，并把它加入 PATH。', vim.log.levels.WARN); return end
        runner = { run = function() return { love, info.entry } end }
        dir = info.entry
        vim.cmd('wall')
    else runner = find_runner(ext) end
    if not runner then
        vim.notify('不支持的文件类型: .' .. ext, vim.log.levels.WARN)
        return
    end

    if vim.bo.modified then vim.cmd('write') end
    M.stop()
    local run_id = M.run_id

    if runner.compile then
        local debug_dir = dir .. '/' .. M.config.debug_dir
        local out = debug_dir .. '/' .. name .. (require('platform').windows and '.exe' or '')
        vim.fn.mkdir(debug_dir, 'p')
        local gitignore = debug_dir .. '/.gitignore'
        if vim.fn.filereadable(gitignore) == 0 then vim.fn.writefile({ '*' }, gitignore) end
        local extra   = get_extra_flags(file, runner.link_map)
        local compile = runner.compile(file, out)
        local run     = runner.run(file, out)
        vim.list_extend(compile, extra)
        open_terminal(compile, dir, function(_, code)
            vim.schedule(function()
                if run_id ~= M.run_id then return end
                if code == 0 then open_terminal(run, dir)
                else vim.notify('编译失败，退出码 ' .. code .. '，详情见编译终端。', vim.log.levels.ERROR) end
            end)
        end)
    else
        open_terminal(runner.run(file), dir)
    end
end

vim.api.nvim_create_autocmd('VimLeavePre', {
    group = vim.api.nvim_create_augroup('BreadRunner', { clear = true }),
    callback = M.stop,
})

-- 手动注册语言（在语言文件之外临时添加用）
function M.add(name, runner)
    M.runners[name] = runner
end

-- 开关某个语言
function M.toggle(name)
    local r = M.runners[name]
    if not r then
        vim.notify('compile: 未找到语言 ' .. name, vim.log.levels.WARN)
        return
    end
    r.enabled = r.enabled == false and true or false
    vim.notify('compile[' .. name .. ']: ' .. (r.enabled == false and 'disabled' or 'enabled'))
end

return M
