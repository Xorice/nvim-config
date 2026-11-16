local M = {}
local overrides = {} -- Session only; project configuration remains the source of truth.
local rojo_choices, rojo_pending = {}, {}
local refresh_id = 0
local config_root

local function normalize(path)
    return vim.fs.normalize(vim.uv.fs_realpath(path) or path)
end

local function same(a, b)
    if require('platform').windows then return a:lower() == b:lower() end
    return a == b
end

local function within(path, root)
    return same(path, root) or same(path:sub(1, #root + 1), root .. '/')
end

local function read(path)
    if vim.fn.filereadable(path) ~= 1 then return '' end
    return table.concat(vim.fn.readfile(path, '', 2000), '\n')
end

-- LuaLS supports JSONC. Strip comments outside strings before decoding it.
local function json_config(path)
    local source, result, i = read(path), {}, 1
    local function next_token(pos)
        while pos <= #source do
            local pair = source:sub(pos, pos + 1)
            if source:sub(pos, pos):match('%s') then pos = pos + 1
            elseif pair == '//' then pos = source:find('\n', pos + 2, true) or #source + 1
            elseif pair == '/*' then
                local finish = source:find('*/', pos + 2, true)
                pos = finish and finish + 2 or #source + 1
            else break end
        end
        return source:sub(pos, pos)
    end
    while i <= #source do
        local char, pair = source:sub(i, i), source:sub(i, i + 1)
        if char == '"' then
            local start = i
            i = i + 1
            while i <= #source do
                local c = source:sub(i, i)
                i = i + (c == '\\' and 2 or 1)
                if c == '"' then break end
            end
            result[#result + 1] = source:sub(start, i - 1)
        elseif pair == '//' then
            i = source:find('\n', i + 2, true) or (#source + 1)
        elseif pair == '/*' then
            local finish = source:find('*/', i + 2, true)
            i = finish and finish + 2 or #source + 1
            result[#result + 1] = ' '
        elseif char == ',' and next_token(i + 1):match('[}%]]') then
            i = i + 1
        else
            result[#result + 1] = char
            i = i + 1
        end
    end
    local ok, value = pcall(vim.json.decode, table.concat(result))
    return ok and type(value) == 'table' and value or {}
end

local function love_config(path)
    local config = json_config(path)
    local special = config['runtime.special'] or (config.runtime or {}).special or {}
    if special['love.filesystem.load'] then return true end
    local library = config['workspace.library'] or (config.workspace or {}).library or {}
    for _, item in ipairs(library) do
        if type(item) == 'string' and item:lower():find('love2d', 1, true) then return true end
    end
    return false
end

local function love_entry(root)
    for _, dir in ipairs({ root, vim.fs.joinpath(root, 'src') }) do
        if vim.fn.filereadable(vim.fs.joinpath(dir, 'main.lua')) == 1 then return dir end
    end
end

local function love_source(root)
    local entry = love_entry(root)
    if not entry then return false end
    local conf = read(vim.fs.joinpath(entry, 'conf.lua'))
    local main = read(vim.fs.joinpath(entry, 'main.lua'))
    return conf:match('love%s*%.%s*conf') ~= nil
        or main:match('function%s+love%s*%.%s*[%w_]+%s*%(') ~= nil
        or main:match('love%s*%.%s*[%w_]+%s*=%s*function') ~= nil
end

function M.detect(path)
    path = path or vim.api.nvim_buf_get_name(0)
    if path == '' then path = vim.fn.getcwd() end
    path = normalize(vim.fn.fnamemodify(path, ':p'))
    local dir = vim.fn.isdirectory(path) == 1 and path or vim.fs.dirname(path)
    config_root = config_root or normalize(vim.fn.stdpath('config'))
    if within(path, config_root) then return { kind = 'nvim', root = config_root } end
    local fallback = within(dir, normalize(vim.fn.getcwd())) and normalize(vim.fn.getcwd()) or dir
    local love_root
    for root in vim.fs.parents(vim.fs.joinpath(dir, '_')) do
        local project_files = vim.tbl_map(vim.fs.normalize, vim.fn.globpath(vim.fn.fnameescape(root), '*.project.json', false, true))
        table.sort(project_files)
        local rojo = project_files[1]
        local default = vim.fs.joinpath(root, 'default.project.json')
        if vim.fn.filereadable(default) == 1 then rojo = default end
        if vim.tbl_contains(project_files, rojo_choices[root]) then rojo = rojo_choices[root] end
        local luarc = vim.fs.joinpath(root, '.luarc.json')
        if vim.fn.filereadable(luarc) ~= 1 then luarc = vim.fs.joinpath(root, '.luarc.jsonc') end
        local kind = overrides[root]
        if not kind then
            if rojo then kind = 'roblox'
            elseif vim.fn.filereadable(vim.fs.joinpath(root, '.luaurc')) == 1 then kind = 'luau'
            elseif vim.fn.filereadable(luarc) == 1 then kind = love_config(luarc) and 'love' or 'lua' end
        end
        if kind then
            return { kind = kind, root = root, rojo = rojo, project_files = project_files, entry = love_entry(root),
                config = vim.fn.filereadable(luarc) == 1 and luarc
                    or (vim.fn.filereadable(vim.fs.joinpath(root, '.luaurc')) == 1 and vim.fs.joinpath(root, '.luaurc') or nil) }
        end
        if love_source(root) then love_root = root end
        if vim.uv.fs_stat(vim.fs.joinpath(root, '.git')) then fallback = root; break end
    end
    if love_root then return { kind = 'love', root = love_root, entry = love_entry(love_root) } end
    return { kind = path:match('%.luau$') and 'luau' or 'lua', root = fallback }
end

-- Buffer-owned data is released on deletion. Arbitrary path queries stay uncached.
function M.for_buffer(buf, force)
    buf = (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf
    local path, cwd = vim.api.nvim_buf_get_name(buf), vim.fn.getcwd()
    local cached = vim.b[buf].bread_project_cache
    if force or not cached or cached.path ~= path or cached.cwd ~= cwd then
        cached = { path = path, cwd = cwd, info = M.detect(path) }
        vim.b[buf].bread_project_cache = cached
    end
    return cached.info
end

function M.search_root()
    local path = vim.api.nvim_buf_get_name(0)
    if vim.bo.filetype == 'lua' or vim.bo.filetype == 'luau' then return M.for_buffer(0).root end
    return vim.fs.root(path ~= '' and path or vim.fn.getcwd(), { '.git' }) or vim.fn.getcwd()
end

function M.select_rojo(info, callback)
    if #info.project_files < 2 or vim.fs.basename(info.rojo or '') == 'default.project.json' or rojo_choices[info.root] then
        callback()
        return
    end
    if rojo_pending[info.root] then table.insert(rojo_pending[info.root], callback); return end
    rojo_pending[info.root] = { callback }
    vim.ui.select(info.project_files, { prompt = '选择本次会话使用的 Rojo 配置', format_item = vim.fs.basename }, function(choice)
        local callbacks = rojo_pending[info.root]
        rojo_pending[info.root] = nil
        if not choice then return end
        rojo_choices[info.root] = choice
        for _, cb in ipairs(callbacks) do cb() end
    end)
end

function M.filetype(path, buf)
    local kind = (buf and M.for_buffer(buf) or M.detect(path)).kind
    return (kind == 'roblox' or kind == 'luau' or path:match('%.luau$')) and 'luau' or 'lua'
end

function M.refresh(root)
    refresh_id = refresh_id + 1
    local current_refresh = refresh_id
    local buffers, clients = {}, {}
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        local path = vim.api.nvim_buf_get_name(buf)
        if vim.api.nvim_buf_is_loaded(buf) and (path:match('%.lua$') or path:match('%.luau$'))
            and (within(normalize(path), root) or same(M.for_buffer(buf).root, root)) then
            buffers[buf] = true
            for _, client in ipairs(vim.lsp.get_clients({ bufnr = buf, _uninitialized = true })) do
                if client.name == 'lua_ls' or client.name == 'luau-lsp' or client.name == 'luau_standard' then
                    clients[client.id] = client
                end
            end
        end
    end
    -- A newly added nested config can split a shared client. Reattach all its buffers.
    for _, client in pairs(clients) do
        for buf in pairs(client.attached_buffers) do buffers[buf] = true end
        client:stop()
    end
    for buf in pairs(buffers) do
        M.for_buffer(buf, true)
        vim.b[buf].bread_project_refresh = current_refresh
    end
    local lsp = package.loaded['project_lsp']
    if lsp and not next(clients) then lsp.stop_sourcemap(root) end
    local attempts = 0
    local function reattach()
        attempts = attempts + 1
        for _, client in pairs(clients) do
            if not client:is_stopped() then
                if attempts >= 10 then client:stop(true) end
                vim.defer_fn(reattach, 100)
                return
            end
        end
        for buf in pairs(buffers) do
            if vim.api.nvim_buf_is_loaded(buf) and vim.b[buf].bread_project_refresh == current_refresh then
                local info = M.for_buffer(buf)
                local ft = (info.kind == 'roblox' or info.kind == 'luau'
                    or vim.api.nvim_buf_get_name(buf):match('%.luau$')) and 'luau' or 'lua'
                vim.api.nvim_buf_call(buf, function()
                    vim.b.bread_project_kind = info.kind
                    if vim.bo.filetype ~= ft then vim.bo.filetype = ft
                    elseif vim.fn.exists('#nvim.lsp.enable#FileType') == 1 then
                        vim.api.nvim_exec_autocmds('FileType', { group = 'nvim.lsp.enable', buffer = buf, modeline = false })
                    end
                end)
            end
        end
    end
    vim.defer_fn(reattach, 150)
end

local function recheck()
    local changed = {}
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) and (vim.bo[buf].filetype == 'lua' or vim.bo[buf].filetype == 'luau') then
            local cached = vim.b[buf].bread_project_cache
            local old = cached and cached.info or M.for_buffer(buf)
            local new = M.for_buffer(buf, true)
            if old.kind ~= new.kind or old.root ~= new.root or old.rojo ~= new.rojo
                or old.entry ~= new.entry or old.config ~= new.config then changed[new.root] = true end
        end
    end
    for root in pairs(changed) do M.refresh(root) end
end

local kinds = { 'lua', 'love', 'luau', 'roblox' }

function M.init(kind)
    assert(vim.tbl_contains(kinds, kind), '用法: :LuaProjectInit lua|love|luau|roblox')
    local project = M.detect()
    assert(project.kind ~= 'nvim', 'Neovim 配置无需初始化项目类型。')
    assert(kind ~= 'roblox' or project.rojo, '请先使用 Rojo 创建项目；此命令只配置语言检查规则。')
    local name = (kind == 'luau' or kind == 'roblox') and '.luaurc' or '.luarc.json'
    local conflicting = name == '.luaurc' and { '.luarc.json', '.luarc.jsonc' } or { '.luaurc' }
    for _, config in ipairs(conflicting) do
        assert(vim.fn.filereadable(vim.fs.joinpath(project.root, config)) == 0,
            '已有 ' .. config .. '，请直接编辑已有配置，或使用 :LuaProjectUse 临时切换。')
    end
    local path = vim.fs.joinpath(project.root, name)
    assert(vim.fn.filereadable(path) == 0, '配置已存在，不会覆盖: ' .. path)
    if name == '.luarc.json' then
        assert(vim.fn.filereadable(vim.fs.joinpath(project.root, '.luarc.jsonc')) == 0, '.luarc.jsonc 已存在，不会另建配置。')
    end
    local content
    if name == '.luaurc' then content = { '{', '  "languageMode": "nonstrict"', '}' }
    elseif kind == 'love' then
        content = { '{', '  "runtime.version": "LuaJIT",', '  "runtime.special": {',
            '    "love.filesystem.load": "loadfile"', '  }', '}' }
    else content = { '{}' } end
    assert(vim.fn.writefile(content, path) == 0, '无法创建: ' .. path)
    overrides[project.root] = nil
    M.refresh(project.root)
    vim.notify('已创建 ' .. path)
end

function M.setup()
    vim.filetype.add({ extension = { lua = M.filetype, luau = M.filetype } })
    local group = vim.api.nvim_create_augroup('BreadProjectLabel', { clear = true })
    vim.api.nvim_create_autocmd({ 'FileType', 'BufEnter', 'BufWritePost' }, {
        group = group,
        callback = function(event)
            local path = vim.api.nvim_buf_get_name(event.buf)
            local name = vim.fs.basename(path)
            if event.event == 'BufWritePost' and (name == '.luarc.json' or name == '.luarc.jsonc'
                or name == '.luaurc' or name:match('%.project%.json$')) then
                M.refresh(vim.fs.dirname(path))
                return
            end
            if event.event == 'BufWritePost' and (name == 'main.lua' or name == 'conf.lua') then recheck() end
            local ft = vim.bo[event.buf].filetype
            if ft == 'lua' or ft == 'luau' then
                vim.b[event.buf].bread_project_kind = M.for_buffer(event.buf).kind
            end
        end,
    })
    vim.api.nvim_create_autocmd({ 'FocusGained', 'DirChanged', 'FileChangedShellPost' }, { group = group, callback = recheck })
    vim.api.nvim_create_autocmd({ 'BufDelete', 'BufFilePost' }, { group = group, callback = function(event)
        vim.b[event.buf].bread_project_cache = nil
        vim.b[event.buf].bread_project_kind = nil
    end })
    vim.api.nvim_create_user_command('LuaProjectInit', function(opts) M.init(opts.args) end,
        { nargs = 1, complete = function() return kinds end, desc = '创建标准 Lua/Luau 项目配置（不覆盖）' })
    vim.api.nvim_create_user_command('LuaProjectUse', function(opts)
        assert(opts.args == 'auto' or vim.tbl_contains(kinds, opts.args), '用法: :LuaProjectUse auto|lua|love|luau|roblox')
        local project = M.detect()
        overrides[project.root] = opts.args ~= 'auto' and opts.args or nil
        M.refresh(project.root)
    end, { nargs = 1, complete = function() return { 'auto', 'lua', 'love', 'luau', 'roblox' } end,
        desc = '临时切换当前项目环境（仅本次会话）' })
    vim.api.nvim_create_user_command('LuaProjectInfo', function() vim.notify(vim.inspect(M.detect())) end,
        { desc = '查看 Lua 项目环境、根目录和入口' })
end

return M
