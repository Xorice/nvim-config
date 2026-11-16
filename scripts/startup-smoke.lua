-- Run in a real terminal: nvim -u NONE -c "luafile scripts/startup-smoke.lua"
-- A PTY runner should send no keys and enforce a timeout to catch hidden prompts.
local api = vim.api
local path = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p')
vim.opt.runtimepath:prepend(vim.fs.dirname(vim.fs.dirname(path)))
local startup = require('bread.startup')
local original_notify = vim.notify
local original_uis = api.nvim_list_uis
local option_methods = getmetatable(vim.opt.messagesopt)
local original_get = option_methods.get
local original_messagesopt = vim.o.messagesopt
-- Allow the same lifecycle assertions in Windows headless checks.
if #original_uis() == 0 then api.nvim_list_uis = function() return { {} } end end
local long_warning = "STARTUP_WARNING\n" .. string.rep("缺少依赖 'quoted' \\ path\n", 80) .. 'WARNING_END'

local function check()
    for _, scenario in ipairs({ 'warnings', 'error', 'fatal', 'stop', 'render', 'open', 'provider', 'option_map', 'option_wait', 'leave' }) do
        if scenario == 'option_map' then
            -- Some nightly builds return keyed flags instead of a string list.
            option_methods.get = function(option)
                if option._name == 'messagesopt' then return { ['hit-enter'] = true, history = 500 } end
                return original_get(option)
            end
        elseif scenario == 'option_wait' then
            vim.o.messagesopt = 'wait:17,history:73'
        end
        local messagesopt, more = vim.o.messagesopt, vim.o.more
        local state, delivered, continued = nil, {}, false
        local provider = function(message, level, opts)
            assert(state.finished, 'notification displayed before startup finished')
            assert(not state.backdrop and not state.timer, 'startup overlay still active')
            delivered[#delivered + 1] = { message, level, opts }
            return original_notify(message, level, opts)
        end
        vim.notify = provider
        local opts = { title = 'Startup regression' }
        local steps = {
            { label = scenario, fatal = scenario == 'fatal', run = function()
                if scenario == 'option_map' or scenario == 'option_wait' then
                    vim.notify('OPTION_COMPATIBILITY_WARNING\nsecond line', vim.log.levels.WARN)
                elseif scenario == 'warnings' then
                    vim.notify(long_warning, vim.log.levels.WARN, opts)
                    assert(#delivered == 0, 'notification was not queued')
                    vim.schedule(function() vim.notify('SCHEDULED_WARNING\nsecond line', vim.log.levels.WARN) end)
                    api.nvim_echo({ { 'DIRECT_ECHO\n' .. string.rep('echo\n', 80) } }, true, {})
                    print('DIRECT_PRINT\nsecond line')
                elseif scenario == 'error' or scenario == 'fatal' then
                    error('EXPECTED_STARTUP_ERROR\nsecond line')
                elseif scenario == 'stop' then
                    return false
                elseif scenario == 'provider' then
                    vim.notify('PROVIDER_WARNING', vim.log.levels.WARN, opts)
                    vim.notify = provider
                elseif scenario == 'leave' then
                    api.nvim_exec_autocmds('VimLeavePre', {})
                end
            end },
            { label = 'Continue', run = function() continued = true end },
        }
        if scenario == 'render' or scenario == 'open' then
            local name = scenario == 'render' and 'nvim_win_set_config' or 'nvim_open_win'
            local original, calls = api[name], 0
            api[name] = function(...)
                calls = calls + 1
                if scenario == 'render' or calls == 2 then
                    api[name] = original
                    error('EXPECTED_DISPLAY_ERROR')
                end
                return original(...)
            end
        end
        state = startup.run(steps)
        assert(vim.wait(5000, function() return state.finished end), scenario .. ' did not finish')
        local flushed = false
        vim.schedule(function() flushed = true end)
        assert(vim.wait(3000, function() return flushed end), scenario .. ': notification replay blocked input')
        assert(vim.notify == provider, scenario .. ': notification provider not restored')
        assert(vim.o.messagesopt == messagesopt and vim.o.more == more, scenario .. ': options not restored')
        assert(not state.timer and not state.group and not state.backdrop and not state.win and not state.logwin,
            scenario .. ': startup resources leaked')
        assert(#api.nvim_list_wins() == 1, scenario .. ': floating window leaked')
        assert(#api.nvim_list_bufs() == 1, scenario .. ': scratch buffer leaked')
        local should_continue = scenario == 'warnings' or scenario == 'error' or scenario == 'provider'
            or scenario == 'option_map' or scenario == 'option_wait'
        assert(continued == should_continue, scenario .. ': wrong continuation behavior')
        if scenario == 'warnings' then
            assert(#delivered == 2 and delivered[1][1] == long_warning and delivered[1][3] == opts)
            local history = api.nvim_exec2('messages', { output = true }).output
            for _, text in ipairs({ 'STARTUP_WARNING', 'WARNING_END', 'SCHEDULED_WARNING', 'DIRECT_ECHO', 'DIRECT_PRINT' }) do
                assert(history:find(text, 1, true), 'message history lost: ' .. text)
            end
        elseif scenario == 'error' or scenario == 'fatal' or scenario == 'render' or scenario == 'open' then
            assert(#delivered == 1 and delivered[1][2] == vim.log.levels.ERROR, 'startup error was lost')
        elseif scenario == 'provider' then
            assert(#delivered == 1 and delivered[1][3] == opts, 'new notification provider was not retained')
        end
        vim.notify = original_notify
        option_methods.get = original_get
        vim.o.messagesopt = original_messagesopt
    end
end

local ok, err = xpcall(check, debug.traceback)
api.nvim_list_uis = original_uis
vim.notify = original_notify
option_methods.get = original_get
vim.o.messagesopt = original_messagesopt
if vim.env.BREAD_STARTUP_RESULT then
    vim.fn.writefile({ ok and 'PASS: startup notifications, prompts, errors and cleanup' or err }, vim.env.BREAD_STARTUP_RESULT)
end
if ok then
    print('PASS: startup notifications, prompts, errors and cleanup')
    vim.cmd('qa!')
else
    api.nvim_err_writeln(err)
    vim.cmd('cquit 1')
end
