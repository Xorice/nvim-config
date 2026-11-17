-- nvim --headless -u NONE -l scripts/plugin-repair-smoke.lua
-- Reproduces an incomplete checkout using isolated data/config directories.
local script = debug.getinfo(1, 'S').source:sub(2)
local root = vim.fs.dirname(vim.fs.dirname(vim.fn.fnamemodify(script, ':p')))
vim.opt.runtimepath:prepend(root)
local stdpath = vim.fn.stdpath
local source = vim.fs.joinpath(stdpath('data'), 'site', 'pack', 'core', 'opt', 'telescope.nvim')
local fixture = vim.fn.tempname()
local parent = vim.fs.dirname(fixture)
local data, config = vim.fs.joinpath(fixture, 'data'), vim.fs.joinpath(fixture, 'config')
local site = vim.fs.joinpath(data, 'site')
local plugin = vim.fs.joinpath(site, 'pack', 'core', 'opt', 'telescope.nvim')
local entry = vim.fs.joinpath(plugin, 'lua', 'telescope', 'builtin', 'init.lua')
vim.fn.mkdir(config, 'p')
vim.fn.mkdir(vim.fs.dirname(plugin), 'p')
vim.fn.stdpath = function(kind)
    if kind == 'data' then return data end
    if kind == 'config' then return config end
    return stdpath(kind)
end
vim.o.packpath = site .. ',' .. vim.env.VIMRUNTIME
if vim.fn.exists('+packlockfile') == 1 then
    vim.o.packlockfile = vim.fs.joinpath(config, 'nvim-pack-lock.json')
end
local function git(args)
    local result = vim.system(vim.list_extend({ 'git' }, args), { text = true }):wait(10000)
    assert(result.code == 0, result.stderr)
    return vim.trim(result.stdout)
end

local function check()
    local bootstrap = require('bootstrap')
    assert(bootstrap.repair_telescope() == nil, 'absent plugin needs no backup')
    git({ 'clone', '--no-hardlinks', '--no-checkout', source, plugin })
    local revision = git({ '-C', source, 'rev-parse', 'HEAD' })
    vim.fn.writefile({ 'preserve this local file' }, vim.fs.joinpath(plugin, 'local-note.txt'))
    vim.fn.writefile({ vim.json.encode({ plugins = {
        ['telescope.nvim'] = { src = source, rev = revision },
    } }) }, vim.fs.joinpath(config, 'nvim-pack-lock.json'))
    assert(vim.fn.isdirectory(plugin) == 1 and vim.fn.filereadable(entry) == 0,
        'fixture did not reproduce the missing builtin file')
    -- A separate session proves native vim.pack accepts this broken checkout.
    local baseline = string.format([[
        local stdpath = vim.fn.stdpath
        vim.fn.stdpath = function(kind)
            if kind == 'data' then return %q end
            if kind == 'config' then return %q end
            return stdpath(kind)
        end
        vim.o.packpath = %q .. ',' .. vim.env.VIMRUNTIME
        if vim.fn.exists('+packlockfile') == 1 then vim.o.packlockfile = %q end
        vim.pack.add({ { src = %q } }, { confirm = false, load = false })
        assert(vim.fn.filereadable(%q) == 0, 'baseline unexpectedly repaired the file')
        assert(not pcall(require, 'telescope.builtin'), 'baseline unexpectedly loaded builtin')
    ]], data, config, site, vim.fs.joinpath(config, 'nvim-pack-lock.json'), source, entry)
    local broken = vim.system({ vim.v.progpath, '--headless', '-u', 'NONE',
        '-c', 'lua ' .. baseline, '-c', 'qa!' }, { text = true }):wait(10000)
    assert(broken.code == 0 and not broken.stderr:find('Error'), broken.stderr)
    local backup = bootstrap.repair_telescope()
    assert(backup and vim.fn.isdirectory(plugin) == 0, 'incomplete installation was not moved')
    assert(vim.fn.readfile(vim.fs.joinpath(backup, 'local-note.txt'))[1] == 'preserve this local file',
        'backup lost local files')
    vim.pack.add({ { src = source } }, { confirm = false, load = false })
    assert(vim.fn.filereadable(entry) == 1, 'native vim.pack did not restore builtin')
    assert(git({ '-C', plugin, 'rev-parse', 'HEAD' }) == revision, 'locked revision changed')
    assert(type(require('telescope.builtin').find_files) == 'function', 'repaired module cannot load')
    local system = vim.system
    vim.system = function() error('healthy installation must not spawn processes') end
    local healthy_ok, healthy_err = pcall(function()
        assert(bootstrap.repair_telescope() == nil, 'healthy installation was moved')
    end)
    vim.system = system
    assert(healthy_ok, healthy_err)
end

local ok, err = xpcall(check, debug.traceback)
vim.fn.stdpath = stdpath
assert(vim.fs.dirname(fixture) == parent and parent == vim.fs.dirname(vim.fn.tempname()))
vim.fn.delete(fixture, 'rf')
if not ok then
    vim.api.nvim_err_writeln(err)
    vim.cmd('cquit 1')
end
print('PASS: incomplete Telescope checkout backed up and reinstalled at locked revision')
vim.cmd('qa!')
