local M = {}
local maps = {}
local project = require('project')
local map_dir = vim.fs.joinpath(vim.fn.stdpath('cache'), 'bread', 'sourcemaps')

local function map_path(root)
    return vim.fs.joinpath(map_dir, vim.fn.sha256(root) .. '-' .. vim.fn.getpid() .. '.json')
end

local function enable_sourcemap(client, enabled)
    if not client or client:is_stopped() then return end
    local settings = client.settings['luau-lsp'].sourcemap
    if settings.enabled == enabled then return end
    settings.enabled = enabled
    client:notify('workspace/didChangeConfiguration', { settings = client.settings })
end

local function close_map_handles(map)
    for _, name in ipairs({ 'watcher', 'timer' }) do
        local handle = map[name]
        if handle and not handle:is_closing() then handle:stop(); handle:close() end
    end
end

function M.stop_sourcemap(root, client_id)
    local map = maps[root]
    if not map or (client_id and map.client_id ~= client_id) then return end
    maps[root] = nil
    close_map_handles(map)
    enable_sourcemap(vim.lsp.get_client_by_id(map.client_id), false)
    if not map.job:is_closing() then
        if require('platform').windows then
            -- Rokit is a shim which spawns Rojo; terminate its owned tree too.
            vim.system({ 'taskkill', '/PID', tostring(map.job.pid), '/T', '/F' },
                { stdout = false, stderr = false }):wait(2000)
        else vim.uv.kill(-map.job.pid, 15) end
        map.job:kill(15)
    end
    map.job:wait(2000)
    vim.uv.fs_unlink(map.path)
end

local function watch_sourcemap(client, root, map)
    local function update()
        if maps[root] ~= map or client:is_stopped() then return end
        local stat = vim.uv.fs_stat(map.path)
        if stat and stat.size > 0 then
            -- Rojo may still be writing. Existence alone does not guarantee valid JSON.
            local ok, value, digest = pcall(function()
                local content = table.concat(vim.fn.readfile(map.path), '\n')
                return vim.json.decode(content), vim.fn.sha256(content)
            end)
            if ok and type(value) == 'table' and type(value.name) == 'string' and type(value.className) == 'string' then
                if not client.settings['luau-lsp'].sourcemap.enabled then enable_sourcemap(client, true)
                elseif digest ~= map.digest then
                    -- External cache URIs are routed outside this workspace by the
                    -- server. Reapplying configuration reloads the map for its owner.
                    client:notify('workspace/didChangeConfiguration', { settings = client.settings })
                end
                map.digest = digest
                return true
            end
        end
    end
    map.timer, map.watcher = vim.uv.new_timer(), vim.uv.new_fs_event()
    local scheduled_update = vim.schedule_wrap(update)
    local filename = vim.fs.basename(map.path)
    local started, err = map.watcher:start(map_dir, {}, function(watch_error, name)
        if maps[root] ~= map then return end
        if watch_error then
            vim.schedule(function() vim.notify('无法监听 sourcemap: ' .. watch_error, vim.log.levels.WARN) end)
            return
        end
        if not name or name == filename then
            map.timer:stop()
            map.timer:start(100, 0, scheduled_update)
        end
    end)
    if not started then vim.notify('无法监听 sourcemap: ' .. tostring(err), vim.log.levels.WARN) end
    local attempts = 0
    local function check()
        if maps[root] ~= map or client:is_stopped() or update() then return end
        attempts = attempts + 1
        if attempts < 300 then vim.defer_fn(check, 100)
        else
            M.stop_sourcemap(root, client.id)
            vim.notify('Rojo 在 30 秒内未生成有效 sourcemap；Roblox API 提示保留。修复项目工具后重启语言服务。', vim.log.levels.WARN)
        end
    end
    vim.defer_fn(check, 50)
end

local function start_sourcemap(client)
    local info = project.detect(client.config.root_dir)
    if not info.rojo then return end
    if maps[info.root] then
        if maps[info.root].client_id == client.id then return end
        M.stop_sourcemap(info.root)
    end
    if vim.fn.executable('rojo') ~= 1 then
        vim.notify('未找到 Rojo；Roblox API 提示可用，项目实例路径提示需要安装项目的 Rojo 工具。', vim.log.levels.WARN)
        return
    end
    vim.fn.mkdir(map_dir, 'p')
    local path = map_path(info.root)
    local job, stderr = nil, ''
    local ok, err = pcall(function()
        job = vim.system({ 'rojo', 'sourcemap', info.rojo, '--watch', '--output', path, '--include-non-scripts' }, {
            cwd = info.root, text = true, detach = not require('platform').windows,
            stdout = false,
            stderr = function(_, data)
                if data then stderr = (stderr .. data):sub(-8192) end
            end,
        }, function(result)
            vim.schedule(function()
                if maps[info.root] and maps[info.root].job == job then
                    close_map_handles(maps[info.root])
                    maps[info.root] = nil
                    enable_sourcemap(client, false)
                    vim.uv.fs_unlink(path)
                    if result.code ~= 0 then
                        vim.notify('Rojo sourcemap 已退出: ' .. stderr, vim.log.levels.WARN)
                    end
                end
            end)
        end)
    end)
    if ok then
        local map = { job = job, path = path, client_id = client.id }
        maps[info.root] = map
        watch_sourcemap(client, info.root, map)
    else vim.notify('无法生成 Rojo sourcemap: ' .. tostring(err), vim.log.levels.WARN) end
end

local function lua_settings(info)
    local settings = { workspace = { checkThirdParty = false } }
    if info.kind == 'nvim' then
        settings.runtime = { version = 'LuaJIT', path = { '?.lua', '?/init.lua', 'lua/?.lua', 'lua/?/init.lua' } }
        settings.workspace.library = { vim.fs.joinpath(vim.env.VIMRUNTIME, 'lua') }
        settings.diagnostics = { globals = { 'vim' } }
    elseif info.kind == 'love' then
        local definition = vim.api.nvim_get_runtime_file('library/love.lua', false)[1]
        settings.runtime = { version = 'LuaJIT', special = { ['love.filesystem.load'] = 'loadfile' } }
        if definition then settings.workspace.library = { vim.fs.dirname(definition) }
        else vim.notify('LÖVE 类型库未安装，请重启 Neovim 完成插件安装。', vim.log.levels.WARN) end
    end
    return settings
end

function M.setup(caps)
    -- Reclaim only our own mappings whose owning process no longer exists.
    -- Signal 0 checks liveness; EPERM/other errors leave the file untouched.
    if vim.fn.isdirectory(map_dir) == 1 then
        for name, kind in vim.fs.dir(map_dir) do
            local hash, pid = name:match('^(%x+)%-(%d+)%.json$')
            if kind == 'file' and hash and #hash == 64 then
                local _, _, code = vim.uv.kill(tonumber(pid), 0)
                if code == 'ESRCH' then vim.uv.fs_unlink(vim.fs.joinpath(map_dir, name)) end
            end
        end
    end
    vim.lsp.config('lua_ls', {
        capabilities = caps,
        root_dir = function(buf, on_dir)
            local info = project.for_buffer(buf)
            if info.kind ~= 'roblox' and info.kind ~= 'luau' then on_dir(info.root) end
        end,
        before_init = function(_, config)
            config.settings.Lua = vim.tbl_deep_extend('force', config.settings.Lua or {}, lua_settings(project.detect(config.root_dir)))
        end,
    })
    vim.lsp.enable('lua_ls')

    local group = vim.api.nvim_create_augroup('BreadProjectLsp', { clear = true })
    vim.api.nvim_create_autocmd({ 'BufDelete', 'BufWipeout', 'LspDetach' }, {
        group = group,
        callback = function(event)
            local clients = event.event == 'LspDetach'
                and { vim.lsp.get_client_by_id(event.data.client_id) }
                or vim.lsp.get_clients({ bufnr = event.buf, _uninitialized = true })
            vim.defer_fn(function()
                for _, client in ipairs(clients) do
                    if not client:is_stopped() and (client.name == 'lua_ls' or client.name == 'luau-lsp' or client.name == 'luau_standard') then
                        local used = false
                        for buf in pairs(client.attached_buffers) do
                            if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buflisted then used = true; break end
                        end
                        if not used then client:stop() end
                    end
                end
            end, 300)
        end,
    })
    vim.api.nvim_create_autocmd('VimLeavePre', { group = group, callback = function()
        for root in pairs(maps) do M.stop_sourcemap(root) end
    end })
    vim.api.nvim_create_autocmd('FileType', { group = group, pattern = 'luau', once = true,
        callback = function() M.setup_luau(caps) end })
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.bo[buf].filetype == 'luau' then M.setup_luau(caps); break end
    end
end

function M.setup_luau(caps)
    if M.luau_configured then return end
    M.luau_configured = true
    local luau = vim.fs.joinpath(vim.fn.stdpath('data'), 'mason', 'packages', 'luau-lsp',
        require('platform').windows and 'luau-lsp.exe' or 'luau-lsp')
    if vim.fn.executable(luau) ~= 1 then luau = 'luau-lsp' end

    -- The plugin downloads Roblox definitions; we own sourcemap jobs so their
    -- cwd, cache path and lifetime follow the project instead of Neovim's cwd.
    require('luau-lsp').setup({
        platform = { type = 'roblox' },
        sourcemap = { autogenerate = false },
        plugin = { enabled = false },
        server = { path = luau },
        fflags = { enable_new_solver = true, enable_by_default = false, sync = true },
    })
    vim.lsp.config('luau-lsp', {
        capabilities = vim.tbl_deep_extend('force', caps, {
            workspace = { didChangeWatchedFiles = { dynamicRegistration = true } },
            textDocument = { diagnostic = vim.NIL },
        }),
        root_dir = function(buf, on_dir)
            local info = project.for_buffer(buf)
            if info.kind == 'roblox' then project.select_rojo(info, function() on_dir(info.root) end) end
        end,
        settings = { ['luau-lsp'] = {
            diagnostics = { strictDatamodelTypes = false },
            completion = { imports = { stringRequires = { enabled = true }, suggestRequires = false } },
        } },
        before_init = function(_, config)
            local info = project.detect(config.root_dir)
            config.settings['luau-lsp'].sourcemap = {
                -- Rojo starts on attach; enable only after its first valid output.
                enabled = false,
                autogenerate = false,
                sourcemapFile = map_path(info.root),
            }
        end,
        on_attach = start_sourcemap,
        on_exit = function(_, _, id)
            vim.schedule(function()
                for root, map in pairs(maps) do
                    if map.client_id == id then M.stop_sourcemap(root, id) end
                end
            end)
        end,
    })

    -- A .luaurc also occurs in standalone Luau projects. Keep Roblox globals
    -- out of these clients by starting the server without Roblox definitions.
    vim.lsp.config('luau_standard', {
        cmd = { luau, 'lsp', '--no-flags-enabled' },
        filetypes = { 'luau' }, capabilities = caps,
        init_options = { fflags = { LuauSolverV2 = 'true' } },
        settings = { ['luau-lsp'] = { platform = { type = 'standard' } } },
        root_dir = function(buf, on_dir)
            local info = project.for_buffer(buf)
            if info.kind ~= 'roblox' then on_dir(info.root) end
        end,
    })
    vim.lsp.enable('luau_standard')
end

return M
