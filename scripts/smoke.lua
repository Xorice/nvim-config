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
    assert(not package.loaded.dap, 'debugger loaded before first use')
    assert(not package.loaded['markview.autocmds'], 'Markdown preview loaded before first use')
    assert(not package.loaded['neo-tree'], 'explorer loaded before first use')
    local system = vim.system
    vim.system = function() error('ordinary startup checks must not spawn processes') end
    require('platform').setup()
    assert(#require('bootstrap').missing() == 0)
    vim.system = system
    local dependencies = require('dependencies')
    local registry = require('mason-registry')
    local refresh, checked = registry.refresh, false
    registry.refresh = function() error('installed tools must not need a registry refresh') end
    dependencies.ensure(function() checked = true end)
    assert(vim.wait(1000, function() return checked end))
    registry.refresh = refresh
    assert(vim.o.undofile, 'persistent undo disabled')
    local line = require('lualine').statusline({ focus = true })
    assert(type(line) == 'string', 'statusline did not render')
    vim.cmd('DapToggleBreakpoint')
    assert(#require('dap').configurations.cpp > 0, 'C++ debug configuration missing')
    assert(#require('dap').configurations.python > 0, 'Python debug configuration missing')
    assert(type(require('dap').configurations.python[1].pythonPath) == 'function')

    vim.cmd('Neotree show')
    assert(vim.bo.filetype == 'neo-tree', 'file explorer did not open')
    vim.cmd('Neotree close')
    assert(#errors == 0, table.concat(errors, '\n'))
    print('PASS: file explorer initialized and opened without errors')

    local fixture_dir = vim.fn.tempname() .. ' nvim smoke & paths'
    vim.fn.mkdir(fixture_dir, 'p')
    local stdpath, original_path = vim.fn.stdpath, vim.env.PATH
    vim.fn.stdpath = function(kind)
        return kind == 'state' and vim.fs.joinpath(fixture_dir, 'state') or stdpath(kind)
    end
    assert(#require('bootstrap').missing() == 0)
    local cache_path = vim.fs.joinpath(vim.fn.stdpath('state'), 'bread-system-tools.json')
    local cached = vim.json.decode(table.concat(vim.fn.readfile(cache_path), '\n'))
    local fingerprint = cached.fingerprint
    cached.tools.git = vim.fs.joinpath(fixture_dir, 'removed-git.exe')
    cached.tools.unused = 'stale entry'
    vim.fn.writefile({ vim.json.encode(cached) }, cache_path)
    assert(#require('bootstrap').missing() == 0)
    cached = vim.json.decode(table.concat(vim.fn.readfile(cache_path), '\n'))
    assert(cached.tools.git ~= vim.fs.joinpath(fixture_dir, 'removed-git.exe') and cached.tools.unused == nil,
        'tool cache retained an invalid or obsolete entry')
    vim.env.PATH = original_path .. (require('platform').windows and ';' or ':') .. fixture_dir
    assert(#require('bootstrap').missing() == 0)
    cached = vim.json.decode(table.concat(vim.fn.readfile(cache_path), '\n'))
    assert(cached.fingerprint ~= fingerprint, 'tool cache ignored PATH changes')
    vim.env.PATH, vim.fn.stdpath = original_path, stdpath
    local markdown = vim.fs.joinpath(fixture_dir, 'readme.md')
    vim.fn.writefile({ '# Lazy Markdown', '', 'Preview should load for the first Markdown buffer.' }, markdown)
    vim.cmd.edit(vim.fn.fnameescape(markdown))
    local markdown_buf = vim.api.nvim_get_current_buf()
    assert(package.loaded['markview.autocmds'], 'Markdown preview did not load')
    assert(vim.wait(2000, function() return require('markview.state').buf_attached(markdown_buf) end), 'Markdown preview did not attach')
    vim.fn.maparg('<C-p>', 'n', false, true).callback()
    assert(vim.bo.filetype == 'TelescopePrompt', 'file search did not open')
    require('telescope.actions').close(vim.api.nvim_get_current_buf())
    local python = require('platform').python()
    local environment = vim.fs.joinpath(fixture_dir, '.venv')
    local created = vim.system({ python, '-m', 'venv', '--without-pip', environment }):wait(15000)
    assert(created.code == 0, 'test virtualenv creation failed')
    local expected_python = vim.fs.joinpath(environment, require('platform').windows and 'Scripts/python.exe' or 'bin/python')
    assert(require('platform').python(vim.fs.joinpath(fixture_dir, 'nested', 'main.py')) == expected_python)
    print('PASS: startup checks avoid processes/registry, lazy Markdown/search and nested Python environment')
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
        if fixture[1] == 'hello.py' then
            assert(require('dap').configurations.python[1].pythonPath() == expected_python,
                'debugger and runner selected different Python environments')
        end
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
