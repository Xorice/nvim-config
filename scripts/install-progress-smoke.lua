-- nvim --headless -u NONE -l scripts/install-progress-smoke.lua
local script = debug.getinfo(1, 'S').source:sub(2)
vim.opt.runtimepath:prepend(vim.fs.dirname(vim.fs.dirname(vim.fn.fnamemodify(script, ':p'))))
vim.env.NVIM_NO_INSTALL = '1'
vim.o.columns = 120
local progress = require('bread.install_progress')
local dependencies = require('dependencies')
local frames, messages, packages, refreshed = {}, {}, {}, nil
package.loaded.lualine = { refresh = function() frames[#frames + 1] = progress.status() end }
vim.notify = function(message) messages[#messages + 1] = message end
local function wait_for(predicate)
    assert(vim.wait(1000, predicate, 10), 'progress transition timed out: ' .. progress.status())
end
for _, name in ipairs({ 'alpha', 'beta', 'gamma' }) do
    local package = { listeners = {}, installing = false, installs = 0 }
    function package:is_installed() return false end
    function package:is_installing() return self.installing end
    function package:install() self.installing = true; self.installs = self.installs + 1 end
    function package:once(event, callback) self.listeners[event] = callback end
    function package:off(event, callback)
        assert(callback == self.listeners[event], 'installation listener was not removed')
        self.listeners[event] = nil
    end
    function package:emit(event)
        self.installing = false
        assert(self.listeners[event], 'missing installation listener')()
    end
    packages[name] = package
end
package.loaded['mason-registry'] = {
    refresh = function(callback) refreshed = callback end,
    get_package = function(name) return assert(packages[name]) end,
}
dependencies.packages = { 'alpha', 'beta', 'gamma' }

local function check()
    -- Animate during an unchanged download, then hide ready and stop refreshing.
    local list_uis = vim.api.nvim_list_uis
    vim.api.nvim_list_uis = function() return { {} } end
    progress.begin('animation', 'Tools', 2)
    local first = progress.status()
    assert(first:match('^%S+ Tools 0/2$'), 'missing braille activity indicator')
    wait_for(function() return #frames > 1 and progress.status() ~= first end)
    progress.finish('animation')
    assert(progress.status() == 'Deps ready')
    assert(vim.wait(3500, function() return progress.status() == '' end, 20), 'ready did not disappear')
    vim.wait(50, function() return false end, 10)
    local idle_frames = #frames
    vim.wait(250, function() return false end, 10)
    assert(#frames == idle_frames, 'idle animation timer kept refreshing')
    progress.clear('animation')
    vim.api.nvim_list_uis = list_uis

    local completed = false
    dependencies.ensure(function() completed = true end, true)
    assert(progress.status():find('Tools 0/3 registry', 1, true))
    refreshed(true)
    wait_for(function() return packages.gamma.installing end)
    packages.alpha:emit('install:success')
    wait_for(function() return progress.status():find('Tools 1/3', 1, true) end)
    packages.beta:emit('install:failed')
    wait_for(function() return progress.status():find('1 failed', 1, true) end)
    packages.gamma:emit('install:success')
    wait_for(function() return completed and not dependencies.running end)
    assert(progress.status() == 'Deps: 1 failed', 'failure was shown as success')
    assert(not vim.tbl_contains(messages, 'Mason 工具更新完成，请重启 Neovim。'))
    dependencies.ensure(nil, true)
    assert(not progress.status():find('failed', 1, true), 'retry retained an old failure')
    refreshed(true)
    wait_for(function() return packages.gamma.installing end)
    for _, name in ipairs(dependencies.packages) do packages[name]:emit('install:success') end
    wait_for(function() return not dependencies.running end)
    assert(progress.status() == 'Deps ready')
    assert(vim.tbl_contains(messages, 'Mason 工具更新完成，请重启 Neovim。'))
    dependencies.ensure(nil, true)
    refreshed(false)
    wait_for(function() return not dependencies.running end)
    assert(progress.status() == 'Deps: 1 failed', 'registry failure was lost')
    progress.clear('tools')

    -- Drive the real parser installation callbacks without network or compilers.
    local installed, parser_done, installs = { 'lua' }, nil, 0
    package.loaded['nvim-treesitter'] = {
        setup = function() end,
        get_installed = function() return installed end,
        install = function()
            installs = installs + 1
            return { await = function(_, callback) parser_done = callback end }
        end,
    }
    dependencies.setup = function() end
    dependencies.ensure = function(callback) callback() end
    dependencies.parsers = { 'lua', 'luau' }
    require('platform').find = function() return 'fixture-cc' end
    local executable = vim.fn.executable
    vim.fn.executable = function(name) return name == 'tree-sitter' and 1 or executable(name) end
    require('config.treesitter')
    vim.cmd('InstallTools')
    assert(progress.status():find('Parsers 1/2 pending: luau', 1, true))
    vim.cmd('InstallTools')
    assert(installs == 1, 'repeated command started overlapping parser jobs')
    parser_done(nil, false)
    wait_for(function() return progress.status() == 'Deps: 1 failed' end)
    assert(not dependencies.parsers_ready)
    vim.cmd('InstallTools')
    assert(progress.status():find('Parsers 1/2 pending: luau', 1, true))
    installed = { 'lua', 'luau' }
    parser_done(nil, true)
    wait_for(function() return dependencies.parsers_ready end)
    assert(progress.status() == 'Deps ready')
    vim.cmd('InstallTools')
    assert(progress.status() == '', 'installed dependencies must not show ongoing work')
    package.loaded['nvim-treesitter'].get_installed = function() error('finished monitor still running') end
    vim.v.errmsg = ''
    vim.wait(300, function() return false end, 10)
    assert(vim.v.errmsg == '', vim.v.errmsg)
    assert(#frames > 0, 'statusline was never refreshed')
end

local ok, err = xpcall(check, debug.traceback)
if not ok then
    vim.api.nvim_err_writeln(err)
    vim.cmd('cquit 1')
end
print('PASS: progress animation, ready expiry, tool/parser progress, failures, retries and cleanup')
vim.cmd('qa!')
