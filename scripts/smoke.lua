-- Run with NVIM_NO_INSTALL=1 NVIM_NO_BOOTSTRAP=1 NVIM_NO_AI=1.
-- nvim --headless "+luafile scripts/smoke.lua"
local errors = {}
local notify = vim.notify
vim.notify = function(message, level, ...)
    if level == vim.log.levels.ERROR then table.insert(errors, message) end
    return notify(message, level, ...)
end

local function check()
    assert(vim.wait(10000, function() return vim.fn.exists(':InstallTools') == 2 end), 'config did not finish loading')
    assert(#errors == 0, table.concat(errors, '\n'))
    assert(vim.fn.exists(':BootstrapDeps') == 2)
    assert(type(require('codeium.virtual_text').status_string()) == 'string')
    local line = require('lualine').statusline({ focus = true })
    assert(type(line) == 'string', 'statusline did not render')
    assert(#require('dap').configurations.cpp > 0, 'C++ debug configuration missing')
    assert(#require('dap').configurations.python > 0, 'Python debug configuration missing')

    local fixture_dir = vim.fn.tempname() .. ' nvim smoke & paths'
    vim.fn.mkdir(fixture_dir, 'p')
    -- Windows headless ConPTY writes directly to stdout. Capture the same jobs
    -- through pipes here; the compiler, argv, cwd and exit callbacks are real.
    local output = ''
    local jobstart = vim.fn.jobstart
    vim.fn.jobstart = function(command, options)
        options.term = nil
        options.stdout_buffered = true
        options.stderr_buffered = true
        options.on_stdout = function(_, lines) output = output .. table.concat(lines, '\n') end
        options.on_stderr = function(_, lines) output = output .. table.concat(lines, '\n') end
        return jobstart(command, options)
    end
    local fixtures = {
        { 'hello.c', { '#include <stdio.h>', 'int main(void) { puts("C_OK"); return 0; }' }, 'C_OK' },
        { 'hello.cpp', { '#include <iostream>', 'int main() { std::cout << "CPP_OK" << std::endl; }' }, 'CPP_OK' },
        { 'hello.py', { 'print("PYTHON_OK")' }, 'PYTHON_OK' },
        { 'hello.lua', { 'print("LUA_OK")' }, 'LUA_OK' },
    }
    for _, fixture in ipairs(fixtures) do
        output = ''
        local path = vim.fs.joinpath(fixture_dir, fixture[1])
        vim.fn.writefile(fixture[2], path)
        vim.cmd('edit ' .. vim.fn.fnameescape(path))
        require('compile').run()
        local found = vim.wait(30000, function()
            return output:find(fixture[3], 1, true) ~= nil or #errors > 0
        end, 50)
        assert(#errors == 0, table.concat(errors, '\n'))
        assert(found, fixture[1] .. ' did not produce expected output: ' .. output)
        print('PASS: ' .. fixture[1] .. ' compiled/ran in a path containing spaces and &')
        vim.cmd('stopinsert')
        vim.cmd('wincmd p')
    end
    vim.fn.jobstart = jobstart
    print('PASS: startup, statusline, DAP configurations and four language runners')
end

local ok, err = xpcall(check, debug.traceback)
if not ok then
    vim.api.nvim_err_writeln(err)
    vim.cmd('cquit 1')
else
    vim.cmd('qa!')
end
