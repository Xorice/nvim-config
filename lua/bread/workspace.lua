local M = {}
local tasks, timer, configured, closing = {}, nil, false, false
local view = {}
local frames = { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' }

local function stop()
    if timer then timer:stop(); timer:close(); timer = nil end
end

local function refresh()
    local lualine = package.loaded.lualine
    if lualine then lualine.refresh({ place = { 'statusline' } }) end
end

local function animate()
    if timer or closing or #vim.api.nvim_list_uis() == 0 then return end
    timer = vim.uv.new_timer()
    timer:start(100, 100, vim.schedule_wrap(function()
        if timer and not closing then refresh() end
    end))
end

local function count(task)
    local done, total = (task.message or ''):match('^%s*(%d+)%s*/%s*(%d+)%s*$')
    if done then return done .. '/' .. total, 2 end
    if type(task.percentage) == 'number' then return string.format('%d%%', task.percentage), 1 end
    return '', 0
end

function M.status()
    -- Progress belongs to a client and token; never combine counts across workspaces.
    local clients = vim.lsp.get_clients({ bufnr = 0, _uninitialized = true })
    local ids = {}
    for _, client in ipairs(clients) do ids[#ids + 1] = client.id end
    table.sort(ids)
    local key = table.concat(ids, ':')
    if view.key ~= key then view = { key = key } end
    local busy, best, rank = false, nil, -1
    for id in pairs(tasks) do
        local client = vim.lsp.get_client_by_id(id)
        if not client or client:is_stopped() then tasks[id] = nil end
    end
    for _, client in ipairs(clients) do
        if not client.initialized then busy = true end
        for _, task in pairs(tasks[client.id] or {}) do
            view.reported = true
            busy = true
            local _, priority = count(task)
            if priority > rank or (priority == rank and task.updated > best.updated) then
                best, rank = task, priority
            end
        end
    end
    if not busy then
        if view.busy and view.reported then
            view.ready_until, view.reported = vim.uv.hrtime() + 1.5e9, nil
        end
        view.busy = false
        if view.ready_until and vim.uv.hrtime() < view.ready_until then
            animate()
            return 'Workspace ready'
        end
        stop()
        return ''
    end
    view.busy, view.ready_until = true, nil
    animate()
    local spinner = frames[math.floor(vim.uv.hrtime() / 1e8) % #frames + 1]
    local detail = best and count(best) or ''
    return spinner .. ' Workspace loading' .. (detail ~= '' and ' ' .. detail or '')
end

function M.setup()
    if configured then return end
    configured = true
    local group = vim.api.nvim_create_augroup('BreadWorkspaceProgress', { clear = true })
    vim.api.nvim_create_autocmd('LspProgress', { group = group, callback = function(event)
        local data = event.data
        local params = data and data.params
        local value = params and params.value
        if type(value) ~= 'table' or not value.kind or params.token == nil then return end
        local id, token = data.client_id, params.token
        if value.kind == 'end' then
            if tasks[id] then
                tasks[id][token] = nil
                if not next(tasks[id]) then tasks[id] = nil end
            end
        elseif value.kind == 'begin' or value.kind == 'report' then
            tasks[id] = tasks[id] or {}
            local task = value.kind == 'begin' and {} or tasks[id][token] or {}
            if value.message ~= nil then task.message = value.message end
            if value.percentage ~= nil then task.percentage = value.percentage end
            task.updated = vim.uv.hrtime()
            tasks[id][token] = task
        end
        -- Keep Neovim's own progress ring buffer intact for other consumers.
        M.status()
        refresh()
    end })
    vim.api.nvim_create_autocmd({ 'LspAttach', 'LspDetach', 'BufEnter' }, {
        group = group, callback = function() vim.schedule(function() if not closing then M.status(); refresh() end end) end,
    })
    vim.api.nvim_create_autocmd('VimLeavePre', { group = group, once = true,
        callback = function() closing = true; stop() end })
end

return M
