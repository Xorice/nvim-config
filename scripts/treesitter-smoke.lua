-- nvim --headless -u NONE -l scripts/treesitter-smoke.lua
-- Downloads and builds Luau in a temporary directory; installed parsers stay intact.
local path = debug.getinfo(1, 'S').source:sub(2)
vim.opt.runtimepath:prepend(vim.fs.dirname(vim.fs.dirname(vim.fn.fnamemodify(path, ':p'))))
vim.env.NVIM_NO_INSTALL = '1'
require('platform').setup()
vim.cmd.packadd('nvim-treesitter')
vim.cmd.packadd('mason.nvim')
local original_cc = vim.env.CC
local fixture = vim.fn.tempname()
local fixture_parent = vim.fs.dirname(fixture)

local function check()
    vim.env.CC = nil
    require('config.treesitter')
    if require('platform').windows then
        assert(vim.env.CC and vim.fn.executable(vim.env.CC) == 1, 'no executable compiler selected')
        print('Compiler: ' .. vim.env.CC)
    end
    local treesitter = require('nvim-treesitter')
    treesitter.setup({ install_dir = fixture })
    local dependencies = require('dependencies')
    dependencies.parsers = { 'luau' }
    dependencies.ensure = function(callback) callback() end
    vim.cmd('InstallTools')
    local progress = require('bread.install_progress')
    assert(progress.status():find('Parsers 0/1', 1, true), 'parser installation progress missing')
    assert(vim.wait(120000, function()
        return dependencies.parsers_ready or progress.status():find('failed', 1, true)
    end, 50), 'Luau installation timed out')
    assert(dependencies.parsers_ready, 'Luau installation failed: ' .. progress.status())
    assert(progress.status() == 'Deps ready', 'parser completion was not reported')
    local library = vim.fs.joinpath(fixture, 'parser', 'luau.so')
    assert(vim.fn.filereadable(library) == 1, 'compiled parser missing')
    vim.treesitter.language.add('luau', { path = library })
    local parser = vim.treesitter.get_string_parser('local value: number = 1', 'luau')
    assert(not parser:parse()[1]:root():has_error(), 'built parser could not parse Luau')
    vim.env.CC = 'custom-user-compiler'
    package.loaded['config.treesitter'] = nil
    require('config.treesitter')
    assert(vim.env.CC == 'custom-user-compiler', 'explicit CC was overwritten')
end

local ok, err = xpcall(check, debug.traceback)
vim.env.CC = original_cc
-- Windows keeps the loaded library open until exit; mark it for deletion first.
local library = vim.fs.joinpath(fixture, 'parser', 'luau.so')
if vim.uv.fs_stat(library) then
    local retired = library .. '.delete'
    vim.uv.fs_rename(library, retired)
    vim.uv.fs_unlink(retired)
end
assert(vim.fs.dirname(fixture) == fixture_parent and fixture_parent == vim.fs.dirname(vim.fn.tempname()))
vim.fn.delete(fixture, 'rf')
if not ok then
    vim.api.nvim_err_writeln(err)
    vim.cmd('cquit 1')
end
print('PASS: real Luau download, compilation, parsing and explicit compiler override')
vim.cmd('qa!')
