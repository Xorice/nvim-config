-- Run with nvim --headless -u NONE -l scripts/codeium-smoke.lua.
local path = debug.getinfo(1, 'S').source:sub(2)
vim.opt.runtimepath:prepend(vim.fs.dirname(vim.fs.dirname(vim.fn.fnamemodify(path, ':p'))))
require('platform').setup()
for _, name in ipairs({ 'plenary.nvim', 'codeium.nvim', 'blink.cmp', 'blink.compat' }) do
    vim.cmd.packadd(name)
end

local messages, pending, request = {}, {}, nil
vim.notify = function(message) messages[#messages + 1] = message end
local curl = require('plenary.curl')
local get = curl.get
-- Simulate the asynchronous exit-52 path without contacting GitHub.
curl.get = function(url, opts)
    request = opts
    pending[#pending + 1] = function()
        opts.on_error({ exit = 52, message = 'curl: (52) Empty reply from server' })
    end
end
vim.env.NVIM_NO_AI = nil
local config = require('codeium.config')
local defaults = config.defaults
local fixture = vim.fn.tempname()
config.defaults = function()
    local options = defaults()
    options.bin_path = fixture
    return options
end

local function check()
    vim.v.errmsg = ''
    require('config.cmp')
    assert(request and type(request.on_error) == 'function', 'download has no failure handler')
    local exited = false
    vim.schedule(function()
        pending[1]()
        vim.schedule(function() exited = true end)
    end)
    assert(vim.wait(1000, function() return exited end), 'download callback did not finish')
    assert(vim.v.errmsg == '', 'uncaught download callback error: ' .. vim.v.errmsg)
    assert(vim.tbl_contains(messages, 'Codeium.nvim: failed to download server'), 'download failure was lost')
    assert(not require('codeium').s:is_healthy(), 'failed download started the AI server')
    local sources = require('blink.cmp.config').sources.default
    for _, name in ipairs({ 'lsp', 'path', 'snippets', 'buffer' }) do
        assert(vim.tbl_contains(sources, name), 'ordinary completion source missing: ' .. name)
    end
    local download = require('codeium.io').download
    for _, status in ipairs({ 200, 404 }) do
        local done, err = false, nil
        download('https://example.invalid/server.gz', fixture .. '/server.gz', function(_, failure)
            done, err = true, failure
        end)
        request.callback({ status = status, exit = 0 })
        assert(vim.wait(1000, function() return done end))
        assert((err == nil) == (status == 200), 'HTTP result was handled incorrectly')
    end
end

local ok, err = xpcall(check, debug.traceback)
curl.get, config.defaults = get, defaults
vim.fn.delete(fixture, 'rf')
if not ok then
    vim.api.nvim_err_writeln(err)
    vim.cmd('cquit 1')
end
print('PASS: Codeium transport/HTTP failures preserve ordinary completion')
vim.cmd('qa!')
