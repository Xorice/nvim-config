local M = {}
local maps = {}
local project = require('project')
local map_dir = vim.fs.joinpath(vim.fn.stdpath('cache'), 'bread', 'sourcemaps')

local function map_path(root)
    return vim.fs.joinpath(map_dir, vim.fn.sha256(root) .. '-' .. vim.fn.getpid() .. '.json')
end

function M.stop_sourcemap(root, client_id)
    local map = maps[root]
    if not map or (client_id and map.client_id ~= client_id) then return end
    maps[root] = nil
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

local function start_sourcemap(client)
    local info = project.detect(client.config.root_dir)
    if not info.rojo or maps[info.root] then return end
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
                    maps[info.root] = nil
                    vim.uv.fs_unlink(path)
                    if result.code ~= 0 then
                        vim.notify('Rojo sourcemap 已退出: ' .. stderr, vim.log.levels.WARN)
                    end
                end
            end)
        end)
    end)
    if ok then maps[info.root] = { job = job, path = path, client_id = client.id }
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
    local luau = vim.fs.joinpath(vim.fn.stdpath('data'), 'mason', 'packages', 'luau-lsp',
        require('platform').windows and 'luau-lsp.exe' or 'luau-lsp')
    if vim.fn.executable(luau) ~= 1 then luau = 'luau-lsp' end
    vim.lsp.config('lua_ls', {
        capabilities = caps,
        root_dir = function(buf, on_dir)
            local info = project.detect(vim.api.nvim_buf_get_name(buf))
            if info.kind ~= 'roblox' and info.kind ~= 'luau' then on_dir(info.root) end
        end,
        before_init = function(_, config)
            config.settings.Lua = vim.tbl_deep_extend('force', config.settings.Lua or {}, lua_settings(project.detect(config.root_dir)))
        end,
    })

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
            local info = project.detect(vim.api.nvim_buf_get_name(buf))
            if info.kind == 'roblox' then project.select_rojo(info, function() on_dir(info.root) end) end
        end,
        settings = { ['luau-lsp'] = {
            diagnostics = { strictDatamodelTypes = false },
            completion = { imports = { stringRequires = { enabled = true }, suggestRequires = false } },
        } },
        before_init = function(_, config)
            local info = project.detect(config.root_dir)
            config.settings['luau-lsp'].sourcemap = {
                enabled = info.rojo ~= nil,
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
            local info = project.detect(vim.api.nvim_buf_get_name(buf))
            if info.kind ~= 'roblox' then on_dir(info.root) end
        end,
    })
    vim.lsp.enable({ 'lua_ls', 'luau_standard' })

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
                        if not used then
                            client:stop()
                        end
                    end
                end
            end, 300)
        end,
    })
    vim.api.nvim_create_autocmd('VimLeavePre', { group = group, callback = function()
        for root in pairs(maps) do M.stop_sourcemap(root) end
    end })
end

return M
