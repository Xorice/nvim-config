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
    if not link_map then return '' end
    local flags   = {}
    local content = vim.fn.readfile(file)
    for _, line in ipairs(content) do
        for header, flag in pairs(link_map) do
            if line:match('#include') and line:match(header) then
                if not vim.tbl_contains(flags, flag) then
                    table.insert(flags, flag)
                end
            end
        end
    end
    return table.concat(flags, ' ')
end

local function close_terminal()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.bo[buf].buftype == 'terminal' then
            vim.api.nvim_win_close(win, true)
            break
        end
    end
end

local function open_terminal(cmd)
    close_terminal()
    vim.cmd('botright vsplit')
    vim.cmd('vertical resize ' .. M.config.terminal_width)
    vim.cmd('terminal ' .. cmd)
    vim.cmd('startinsert')
end

-------------------------------------------------------------------------------
-- 主入口
-------------------------------------------------------------------------------
function M.run()
    local file = vim.fn.expand('%:p')
    local name = vim.fn.expand('%:t:r')
    local dir  = vim.fn.expand('%:p:h')
    local ext  = vim.fn.expand('%:e')

    local runner = find_runner(ext)
    if not runner then
        vim.notify('不支持的文件类型: .' .. ext, vim.log.levels.WARN)
        return
    end

    vim.cmd('write')

    local debug_dir = dir .. '/' .. M.config.debug_dir
    local out       = debug_dir .. '/' .. name
    vim.fn.mkdir(debug_dir, 'p')

    local gitignore = debug_dir .. '/.gitignore'
    if vim.fn.filereadable(gitignore) == 0 then
        vim.fn.writefile({ '*' }, gitignore)
    end

    local cmd
    if runner.compile then
        local extra   = get_extra_flags(file, runner.link_map)
        local compile = runner.compile(file, out)
        local run     = runner.run(file, out)
        cmd = string.format('%s %s && %s', compile, extra, run)
    else
        cmd = runner.run(file, out)
    end

    open_terminal(cmd)
end

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
