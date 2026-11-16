-- Run with NVIM_NO_INSTALL=1 NVIM_NO_BOOTSTRAP=1 NVIM_NO_AI=1.
-- Exercises real language servers, LÖVE, Rojo/Rokit and process cleanup.
local project = require('project')
local fixture = vim.fn.tempname() .. ' lua-project-check & paths'
local errors, output = {}, ''
local trace = {}
local exit_codes = {}
vim.api.nvim_create_autocmd({ 'LspAttach', 'LspDetach' }, { callback = function(event)
    local client = vim.lsp.get_client_by_id(event.data.client_id)
    trace[#trace + 1] = { event.event, event.buf, client and client.name }
end })
local notify, jobstart = vim.notify, vim.fn.jobstart
vim.notify = function(message, level, ...)
    if level == vim.log.levels.ERROR then errors[#errors + 1] = message end
    return notify(message, level, ...)
end

local function write(path, lines)
    vim.fn.mkdir(vim.fs.dirname(path), 'p')
    assert(vim.fn.writefile(lines, path) == 0)
    return path
end

local function open(path)
    vim.cmd('stopinsert')
    vim.cmd('edit ' .. vim.fn.fnameescape(path))
    return vim.api.nvim_get_current_buf()
end

local function client_for(buf, name)
    local client
    assert(vim.wait(45000, function()
        client = vim.lsp.get_clients({ bufnr = buf, name = name })[1]
        return client and client.initialized
    end, 50), name .. ' did not attach; enabled=' .. tostring(vim.lsp.is_enabled(name)) .. '; events=' .. vim.inspect(trace))
    assert(#vim.lsp.get_clients({ bufnr = buf }) == 1, 'multiple language servers attached')
    return client
end

local function completion(client, buf, line, character, expected, timeout)
    local found = false
    assert(vim.wait(timeout or 20000, function()
        local response = client:request_sync('textDocument/completion', {
            textDocument = { uri = vim.uri_from_bufnr(buf) },
            position = { line = line, character = character },
            context = { triggerKind = 1 },
        }, 3000, buf)
        local result = response and response.result
        for _, item in ipairs(result and (result.items or result) or {}) do
            if item.label:find(expected, 1, true) then found = true end
        end
        return found
    end, 200), 'missing API completion: ' .. expected)
end

local function run_and_wait(path, expected)
    open(path)
    output = ''
    require('compile').run()
    assert(vim.wait(15000, function() return output:find(expected, 1, true) ~= nil end, 50), output)
    assert(vim.wait(5000, function() return require('compile').job == nil end), 'run did not finish')
    vim.cmd('stopinsert')
    vim.cmd('wincmd p')
end

local function check()
    assert(vim.wait(10000, function() return vim.fn.exists(':UpdateTools') == 2 end))
    local on_exit = vim.lsp.config['luau-lsp'].on_exit
    vim.lsp.config('luau-lsp', { on_exit = function(code, signal, id)
        exit_codes[id] = code
        on_exit(code, signal, id)
    end })
    local plain = write(fixture .. '/plain/main.lua', { 'print("PLAIN_OK")', 'love.graphics.print("unknown")', 'vim.api.nvim_get_current_buf()' })
    local love = write(fixture .. '/love/src/main.lua', { 'function love.load()', '  print("LOVE_OK")', '  love.event.quit()', 'end', 'function love.draw() love.graphics.print("ok") end' })
    write(fixture .. '/love/src/conf.lua', { 'function love.conf(t)', '  t.window = false', '  t.modules.audio = false', 'end' })
    write(fixture .. '/love/.luarc.jsonc', { '{', '  // LÖVE settings; no machine paths', '  "runtime.version": "LuaJIT",', '  "runtime.special": { "love.filesystem.load": "loadfile", /* trailing comment */ },', '}' })
    local roblox = write(fixture .. '/roblox/src/init.lua', { 'local part = Instance.new("Part")', 'part.Anchored = true', 'local n: number = 1', 'print(n)', 'local child = require(script.module)', 'print(child.value)' })
    local new_module = write(fixture .. '/roblox/src/module.luau', { 'return { value = 1 }' })
    write(fixture .. '/roblox/default.project.json', { '{"name":"Check","tree":{"$className":"DataModel","ReplicatedStorage":{"$className":"ReplicatedStorage","Shared":{"$path":"src"}}}}' })
    write(fixture .. '/roblox/rokit.toml', { '[tools]', 'rojo = "rojo-rbx/rojo@7.7.1"' })
    local standard = write(fixture .. '/luau/main.luau', { 'local value: number = 1', 'print(value)' })
    write(fixture .. '/luau/.luaurc', { '{"languageMode":"nonstrict"}' })
    local helper = write(fixture .. '/roblox/tools/helper.lua', { 'return math.abs(-1)' })
    write(fixture .. '/roblox/tools/.luarc.json', { '{}' })
    assert(project.detect(plain).kind == 'lua')
    assert(project.detect(love).kind == 'love')
    assert(project.detect(love).root == vim.fs.normalize(fixture .. '/love'), 'workspace must include src/')
    assert(project.detect(roblox).kind == 'roblox' and project.filetype(roblox) == 'luau')
    assert(project.filetype(new_module) == 'luau')
    assert(project.detect(helper).kind == 'lua' and project.filetype(helper) == 'lua')
    assert(project.detect(standard).kind == 'luau')
    assert(project.detect(vim.fn.stdpath('config') .. '/init.lua').kind == 'nvim')
    print('PASS: project detection, JSONC, nested Lua tools and mixed extensions')

    local plain_buf = open(plain)
    local plain_client = client_for(plain_buf, 'lua_ls')
    assert(not (plain_client.config.settings.Lua.diagnostics or {}).globals)
    assert(not plain_client.config.settings.Lua.workspace.library)
    assert(vim.wait(20000, function()
        local globals = {}
        for _, diagnostic in ipairs(vim.diagnostic.get(plain_buf)) do
            if diagnostic.code == 'undefined-global' then globals[diagnostic.message] = true end
        end
        local text = vim.inspect(globals)
        return text:find('love', 1, true) and text:find('vim', 1, true)
    end, 100), 'ordinary Lua must diagnose foreign globals')

    local love_buf = open(love)
    local love_client = client_for(love_buf, 'lua_ls')
    assert(love_client.config.settings.Lua.runtime.version == 'LuaJIT')
    completion(love_client, love_buf, 4, 35, 'print')
    local helper_buf = open(helper)
    client_for(helper_buf, 'lua_ls')
    local standard_buf = open(standard)
    local standard_client = client_for(standard_buf, 'luau_standard')
    assert(standard_client.config.init_options.fflags.LuauSolverV2 == 'true')
    print('PASS: real LuaLS diagnostics, LÖVE API completion and standalone Luau isolation')

    local roblox_buf = open(roblox)
    assert(vim.bo[roblox_buf].filetype == 'luau', 'Roblox .lua filetype is ' .. vim.bo[roblox_buf].filetype)
    local detected_root
    vim.lsp.config['luau-lsp'].root_dir(roblox_buf, function(root) detected_root = root end)
    assert(detected_root == project.detect(roblox).root, 'LSP root callback failed')
    local roblox_client = client_for(roblox_buf, 'luau-lsp')
    assert(roblox_client.config.init_options.fflags.LuauSolverV2 == 'true')
    completion(roblox_client, roblox_buf, 0, 22, 'new')
    local map_path = roblox_client.config.settings['luau-lsp'].sourcemap.sourcemapFile
    assert(map_path:find(vim.fs.normalize(vim.fn.stdpath('cache')), 1, true) == 1)
    assert(vim.wait(15000, function() return vim.fn.filereadable(map_path) == 1 end), 'Rojo did not generate sourcemap')
    local map = vim.json.decode(table.concat(vim.fn.readfile(map_path), '\n'))
    assert(map.className == 'DataModel')
    completion(roblox_client, roblox_buf, 4, #('local child = require(script.'), 'module')
    completion(roblox_client, roblox_buf, 5, #('print(child.'), 'value')
    write(fixture .. '/roblox/src/extra.luau', { 'return {}' })
    assert(vim.wait(5000, function()
        return table.concat(vim.fn.readfile(map_path), '\n'):find('extra', 1, true) ~= nil
    end), 'sourcemap watcher did not update after creating a module')
    local newer_buf = open(new_module)
    assert(client_for(newer_buf, 'luau-lsp').id == roblox_client.id, 'same project should reuse one client')
    local proc_count = #vim.lsp.get_clients({ name = 'luau-lsp' })
    assert(proc_count == 1)
    vim.api.nvim_buf_delete(roblox_buf, { force = true })
    vim.api.nvim_buf_delete(newer_buf, { force = true })
    assert(vim.wait(5000, function() return roblox_client:is_stopped() and vim.fn.filereadable(map_path) == 0 end), 'project did not release LSP/sourcemap')
    assert(exit_codes[roblox_client.id] == 0, 'Roblox LSP did not shut down cleanly: ' .. tostring(exit_codes[roblox_client.id]))
    assert(vim.fn.filereadable(fixture .. '/roblox/sourcemap.json') == 0)
    print('PASS: Roblox API completion, new solver, real Rokit/Rojo sourcemap, reuse and cleanup')

    local nvim_buf = open(vim.fn.stdpath('config') .. '/lua/project.lua')
    local nvim_client = client_for(nvim_buf, 'lua_ls')
    assert(nvim_client.config.settings.Lua.diagnostics.globals[1] == 'vim')
    for index, line in ipairs(vim.api.nvim_buf_get_lines(nvim_buf, 0, -1, false)) do
        local _, last = line:find('vim.api.', 1, true)
        if last then completion(nvim_client, nvim_buf, index - 1, last + #('nvim_buf_'), 'nvim_buf_get_name', 45000); break end
    end
    vim.api.nvim_buf_delete(nvim_buf, { force = true })
    print('PASS: real Neovim API completion stays in the Neovim environment')

    local init_file = write(fixture .. '/init-project/main.lua', { 'print("init")' })
    vim.cmd('cd ' .. vim.fn.fnameescape(fixture .. '/init-project'))
    open(init_file)
    project.init('love')
    assert(project.detect(init_file).kind == 'love')
    assert(vim.wait(1000, function() return vim.b.bread_project_kind == 'love' end))
    local config_path = fixture .. '/init-project/.luarc.json'
    local before = table.concat(vim.fn.readfile(config_path), '\n')
    assert(not pcall(project.init, 'lua'), 'existing config must not be overwritten')
    assert(table.concat(vim.fn.readfile(config_path), '\n') == before)
    vim.cmd('LuaProjectUse lua')
    assert(project.detect(init_file).kind == 'lua')
    vim.cmd('LuaProjectUse auto')
    assert(project.detect(init_file).kind == 'love')
    print('PASS: explicit initialization, no overwrite and session override')

    -- Capture real jobs with pipes; headless Windows ConPTY bypasses buffers.
    vim.fn.jobstart = function(command, options)
        options.term = nil
        options.stdout_buffered, options.stderr_buffered = true, true
        options.on_stdout = function(_, lines) output = output .. table.concat(lines, '\n') end
        options.on_stderr = function(_, lines) output = output .. table.concat(lines, '\n') end
        return jobstart(command, options)
    end
    local runnable = write(fixture .. '/plain/run.lua', { 'print("PLAIN_OK")' })
    run_and_wait(runnable, 'PLAIN_OK')
    assert(vim.fn.isdirectory(fixture .. '/plain/__debug__') == 0)
    assert(vim.fn.filereadable(fixture .. '/plain/.luarc.json') == 0, 'opening/running plain Lua must not create config')
    run_and_wait(love, 'LOVE_OK')
    assert(vim.fn.isdirectory(fixture .. '/love/src/__debug__') == 0)
    local long_file = write(fixture .. '/plain/long.lua', { 'print("RUNNING")', 'while true do vim.wait(1000) end' })
    open(long_file)
    require('compile').run()
    local old_job = require('compile').job
    vim.cmd('stopinsert')
    vim.cmd('wincmd p')
    require('compile').run()
    assert(vim.wait(5000, function() return vim.fn.jobwait({ old_job }, 0)[1] ~= -1 end), 'restart left old process running')
    local current_job = require('compile').job
    require('compile').stop()
    assert(vim.wait(5000, function() return vim.fn.jobwait({ current_job }, 0)[1] ~= -1 end), 'stop left process running')
    print('PASS: real Lua/LÖVE runners, nested entry, restart and stop without debug artifacts')
    assert(#errors == 0, table.concat(errors, '\n'))
    assert(vim.v.errmsg == '', vim.v.errmsg)
end

-- Let VimEnter finish: asynchronously enabled servers attach existing buffers
-- after startup, just as they do in an interactive editing session.
vim.defer_fn(function()
    local ok, err = xpcall(check, debug.traceback)
    vim.fn.jobstart = jobstart
    if package.loaded.compile then require('compile').stop() end
    if not ok then
        vim.api.nvim_err_writeln(err)
        vim.cmd('cquit 1')
    else
        print('PASS: all project development checks')
        vim.cmd('qa!')
    end
end, 100)
