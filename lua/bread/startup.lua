local M = {}
local api, uv = vim.api, vim.uv
local ns = api.nvim_create_namespace('BreadStartup')
local active
local spinners = { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' }
local chars = {}
for mask = 1, 255 do chars[mask] = vim.fn.nr2char(0x2800 + mask) end
local bits = { { 1, 8 }, { 2, 16 }, { 4, 32 }, { 64, 128 } }
local vertices = {
    { -1, -1, -1 }, { 1, -1, -1 }, { 1, 1, -1 }, { -1, 1, -1 },
    { -1, -1, 1 }, { 1, -1, 1 }, { 1, 1, 1 }, { -1, 1, 1 },
}
local faces = {
    { { 1, 4, 3, 2 }, { 0, 0, -1 } }, { { 5, 6, 7, 8 }, { 0, 0, 1 } },
    { { 1, 5, 8, 4 }, { -1, 0, 0 } }, { { 2, 3, 7, 6 }, { 1, 0, 0 } },
    { { 1, 2, 6, 5 }, { 0, -1, 0 } }, { { 4, 8, 7, 3 }, { 0, 1, 0 } },
}

local function highlights()
    api.nvim_set_hl(0, 'BreadBootNormal', { bg = 'NONE', fg = '#8a8a8a' })
    api.nvim_set_hl(0, 'BreadBootText', { fg = '#8a8a8a', bg = 'NONE' })
    api.nvim_set_hl(0, 'BreadBootActive', { fg = '#b2b2b2', bg = 'NONE' })
    api.nvim_set_hl(0, 'BreadBootLoading', { fg = '#8ab4f8', bg = 'NONE' })
    api.nvim_set_hl(0, 'BreadBootDone', { fg = '#81c995', bg = 'NONE' })
    api.nvim_set_hl(0, 'BreadBootError', { fg = '#e78284', bg = 'NONE' })
    api.nvim_set_hl(0, 'BreadBootEdge', { fg = '#929292', bg = 'NONE' })
    for i, color in ipairs({ '#454545', '#565656', '#707070' }) do
        api.nvim_set_hl(0, 'BreadBootFace' .. i, { fg = color, bg = 'NONE' })
    end
end

local function draw_log(state)
    if not state.logwin or not api.nvim_win_is_valid(state.logwin) then return end
    local revision = table.concat({ state.current, vim.o.columns, vim.o.lines, vim.o.cmdheight }, ':')
    local tick = math.floor(uv.hrtime() / 8e7)
    if state.log_revision == revision and state.log_tick == tick then return end
    state.log_revision, state.log_tick = revision, tick
    local compact = vim.o.columns < 76 or vim.o.lines < 20
    local count = math.min(state.current, compact and 1 or math.max(1, vim.o.lines - vim.o.cmdheight - 4))
    local width = math.max(1, math.min(24, vim.o.columns - 4))
    api.nvim_win_set_config(state.logwin, {
        relative = 'editor', row = compact and 0 or 1, col = math.min(2, vim.o.columns - 1),
        width = width, height = count + 2,
    })
    local lines, marks = {}, {}
    for i = state.current - count + 1, state.current do
        local step = state.steps[i]
        local mark = step.status == 'done' and '√' or step.status == 'error' and '×' or spinners[tick % #spinners + 1]
        local group = step.status == 'done' and 'BreadBootDone' or step.status == 'error' and 'BreadBootError' or 'BreadBootLoading'
        lines[#lines + 1] = vim.fn.strcharpart(mark .. ' ' .. step.label, 0, width)
        marks[#marks + 1] = { marker = mark, group = group }
    end
    local done, total = state.current - 1, #state.steps
    local size = math.min(14, math.max(1, width - 7))
    local filled = math.floor(size * done / total)
    lines[#lines + 1] = ''
    lines[#lines + 1] = vim.fn.strcharpart(string.rep('━', filled) .. string.rep('─', size - filled)
        .. string.format(' %d/%d', done, total), 0, width)
    api.nvim_buf_set_lines(state.logbuf, 0, -1, false, lines)
    api.nvim_buf_clear_namespace(state.logbuf, ns, 0, -1)
    for row, mark in ipairs(marks) do
        api.nvim_buf_set_extmark(state.logbuf, ns, row - 1, 0, {
            end_col = #mark.marker, hl_group = mark.group,
        })
    end
    if filled > 0 then
        api.nvim_buf_set_extmark(state.logbuf, ns, #lines - 1, 0, {
            end_col = math.min(filled * #'━', #lines[#lines]), hl_group = 'BreadBootLoading',
        })
    end
end

local function draw(state)
    if state.painting or not state.win or not api.nvim_win_is_valid(state.win) then return end
    state.painting = true
    local width = math.max(1, math.min(52, vim.o.columns - 4))
    local height = math.max(1, math.min(17, vim.o.lines - vim.o.cmdheight - 3))
    local layout = table.concat({ vim.o.columns, vim.o.lines, vim.o.cmdheight }, ':')
    if state.layout ~= layout then
        state.layout = layout
        api.nvim_win_set_config(state.backdrop, {
            relative = 'editor', row = 0, col = 0, width = math.max(1, vim.o.columns), height = math.max(1, vim.o.lines),
        })
        api.nvim_win_set_config(state.win, {
            relative = 'editor', width = width, height = height,
            row = math.max(0, math.floor((vim.o.lines - vim.o.cmdheight - height) / 2)),
            col = math.max(0, math.floor((vim.o.columns - width) / 2)),
        })
    end
    local t = (uv.hrtime() - state.started) / 1e9
    local dt = math.min(.05, math.max(0, t - (state.drawn or t)))
    state.angle = state.angle + dt * 5.4
    state.drawn = t
    local lines, spans = {}, {}

    if width >= 24 and height >= 8 then
        local cols, rows = width - 4, height - 2
        local pw, ph = cols * 2, rows * 4
        local cyaw, syaw = math.cos(.65 + state.angle), math.sin(.65 + state.angle)
        local cpitch, spitch = math.cos(.48 + state.angle * .55), math.sin(.48 + state.angle * .55)
        local function rotate(v)
            local x, z = v[1] * cyaw + v[3] * syaw, -v[1] * syaw + v[3] * cyaw
            return { x, v[2] * cpitch - z * spitch, v[2] * spitch + z * cpitch }
        end
        local projected, cells = {}, {}
        for i, vertex in ipairs(vertices) do
            local v = rotate(vertex)
            local scale = ph * 1.05 / (5 - v[3])
            projected[i] = { x = pw / 2 + v[1] * scale, y = ph / 2 + v[2] * scale }
        end
        local function plot(x, y, group, priority)
            x, y = math.floor(x), math.floor(y)
            if x < 0 or x >= pw or y < 0 or y >= ph then return end
            local row, col = math.floor(y / 4) + 1, math.floor(x / 2) + 1
            cells[row] = cells[row] or {}
            local cell = cells[row][col] or { mask = 0, priority = -1 }
            cell.mask = bit.bor(cell.mask, bits[y % 4 + 1][x % 2 + 1])
            if priority >= cell.priority then cell.group, cell.priority = group, priority end
            cells[row][col] = cell
        end
        -- Perspective projection and visible faces give a real three-dimensional rotation.
        for _, face in ipairs(faces) do
            local normal = rotate(face[2])
            if normal[3] > 1 / 5 then
                local polygon, miny, maxy = {}, ph, 0
                for _, index in ipairs(face[1]) do
                    local point = projected[index]
                    polygon[#polygon + 1] = point
                    miny, maxy = math.min(miny, point.y), math.max(maxy, point.y)
                end
                local light = -.32 * normal[1] - .48 * normal[2] + .81 * normal[3]
                local shade = light > .72 and 3 or light > .35 and 2 or 1
                -- Find the span once per scanline instead of testing four edges per dot.
                for y = math.floor(miny), math.ceil(maxy) do
                    local first, last, scan = math.huge, -math.huge, y + .5
                    for i, a in ipairs(polygon) do
                        local b = polygon[i % 4 + 1]
                        if (a.y <= scan and b.y > scan) or (b.y <= scan and a.y > scan) then
                            local x = a.x + (scan - a.y) * (b.x - a.x) / (b.y - a.y)
                            first, last = math.min(first, x), math.max(last, x)
                        end
                    end
                    for x = math.ceil(first - .5), math.floor(last - .5) do
                        local stipple = shade == 3 or (shade == 2 and (x + y) % 2 == 0) or (x + y * 3) % 4 == 0
                        if stipple then plot(x, y, 'BreadBootFace' .. shade, 1) end
                    end
                end
                for i, a in ipairs(polygon) do
                    local b = polygon[i % 4 + 1]
                    local samples = math.ceil(math.max(math.abs(b.x - a.x), math.abs(b.y - a.y)) * 2)
                    for j = 0, samples do
                        local u = j / samples
                        plot(a.x + (b.x - a.x) * u, a.y + (b.y - a.y) * u, 'BreadBootEdge', 2)
                    end
                end
            end
        end
        lines[1] = ''
        for row = 1, rows do
            local line, run = '  ', nil
            for col = 1, cols do
                local cell = cells[row] and cells[row][col]
                local char = cell and chars[cell.mask] or ' '
                local group = cell and cell.group
                if run and run.group ~= group then
                    run.finish = #line
                    spans[#spans + 1], run = run, nil
                end
                if group and not run then run = { row = row, start = #line, group = group } end
                line = line .. char
            end
            if run then run.finish = #line; spans[#spans + 1] = run end
            lines[#lines + 1] = line
        end
        lines[#lines + 1] = ''
    else
        lines[1] = string.rep(' ', math.max(0, math.floor((width - 1) / 2))) .. '⠿'
    end
    api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
    api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)
    for _, span in ipairs(spans) do
        api.nvim_buf_set_extmark(state.buf, ns, span.row, span.start, {
            end_col = span.finish, hl_group = span.group,
        })
    end
    draw_log(state)
    vim.cmd.redraw()
    state.painting = false
end

-- Paint at safe boundaries inside synchronous initialization without processing
-- unrelated callbacks or delaying startup to wait for the next timer tick.
function M.checkpoint()
    if active and not active.finished and not active.painting and not vim.in_fast_event()
        and (uv.hrtime() - active.started) / 1e9 - (active.drawn or 0) >= .016 then
        draw(active)
    end
end

local function nonblocking_messages()
    -- Nightly builds expose this option as either a list or a key/value table
    -- through vim.opt:get(). The raw comma-separated value is stable across both.
    local options = vim.split(vim.o.messagesopt, ',', { plain = true, trimempty = true })
    options = vim.tbl_filter(function(option)
        return option ~= 'hit-enter' and not option:match('^wait:')
    end, options)
    options[#options + 1] = 'wait:0'
    vim.o.messagesopt = table.concat(options, ',')
    vim.o.more = false
end

-- Yield between stages instead of holding the main loop in one scheduled callback.
-- Individual synchronous plugin setup functions can still briefly stop UI updates.
function M.run(steps)
    local state = { steps = steps, current = 0, angle = 0, started = uv.hrtime(), errors = {}, notifications = {} }
    for _, step in ipairs(steps) do step.status = 'pending' end
    local function close()
        if active == state then active = nil end
        if state.notify then
            if vim.notify == state.notify.wrapper then vim.notify = state.notify.original end
            vim.o.messagesopt, vim.o.more = state.messagesopt, state.more
        end
        for name, lookup in pairs(state.lookups or {}) do
            if vim.fn[name] == lookup.wrapper then vim.fn[name] = lookup.original end
        end
        if state.timer then state.timer:stop(); state.timer:close(); state.timer = nil end
        if state.group then api.nvim_del_augroup_by_id(state.group); state.group = nil end
        for _, field in ipairs({ 'logwin', 'win', 'backdrop' }) do
            if state[field] and api.nvim_win_is_valid(state[field]) then api.nvim_win_close(state[field], true) end
            state[field] = nil
        end
        for _, field in ipairs({ 'logbuf', 'buf', 'backdropbuf' }) do
            if state[field] and api.nvim_buf_is_valid(state[field]) then api.nvim_buf_delete(state[field], { force = true }) end
            state[field] = nil
        end
    end
    local function finish()
        if state.finished then return end
        state.finished = true
        close()
        if #state.notifications == 0 and #state.errors == 0 then return end
        vim.schedule(function()
            local messagesopt, more = vim.o.messagesopt, vim.o.more
            local ok, err = xpcall(function()
                if state.notify then nonblocking_messages(); vim.cmd.redraw() end
                local level = vim.log.levels.INFO
                for _, notification in ipairs(state.notifications) do
                    level = math.max(level, notification.level or vim.log.levels.INFO)
                    vim.notify(notification.message, notification.level, notification.opts)
                end
                for _, message in ipairs(state.errors) do
                    level = vim.log.levels.ERROR
                    vim.notify(message, level)
                end
                if state.notify then
                    -- Full messages stay in :messages; even a narrow terminal must not wait for input.
                    vim.cmd.redraw()
                    local summary = ('Startup: %d message(s), :messages'):format(#state.notifications + #state.errors)
                    local width = math.max(0, math.min(vim.o.columns - 1, vim.v.echospace))
                    local highlight = level >= vim.log.levels.ERROR and 'ErrorMsg'
                        or level >= vim.log.levels.WARN and 'WarningMsg' or 'None'
                    api.nvim_echo({ { summary:sub(1, width), highlight } }, false, {})
                end
            end, debug.traceback)
            if state.notify then vim.o.messagesopt, vim.o.more = messagesopt, more end
            if not ok then error(err) end
        end)
    end
    local function render(callback)
        local ok, err = xpcall(callback, debug.traceback)
        if not ok then
            state.errors[#state.errors + 1] = 'Startup display failed:\n' .. err
            finish()
        end
        return ok
    end
    local function execute(step)
        local started = uv.hrtime()
        local ok, result = xpcall(step.run, debug.traceback)
        step.elapsed = (uv.hrtime() - started) / 1e6
        step.status = ok and 'done' or 'error'
        if not ok then state.errors[#state.errors + 1] = step.label .. ' failed to load:\n' .. result end
        return result ~= false and (ok or not step.fatal)
    end
    local function advance()
        if state.finished then return end
        state.current = state.current + 1
        local step = steps[state.current]
        if not step then finish(); return end
        step.status = 'running'
        if not render(function() draw(state) end) then return end
        vim.defer_fn(function()
            if state.finished then return end
            if execute(step) then advance() else finish() end
        end, 0)
    end
    local function start()
        active = state
        state.messagesopt, state.more = vim.o.messagesopt, vim.o.more
        state.notify = { original = vim.notify }
        state.notify.wrapper = function(message, level, opts)
            if state.finished then return state.notify.original(message, level, opts) end
            state.notifications[#state.notifications + 1] = { message = message, level = level, opts = opts }
        end
        vim.notify = state.notify.wrapper
        -- Also cover direct :echo/print output, which does not pass through vim.notify.
        nonblocking_messages()
        -- Keep the first frames transparent too, before the actual theme loads.
        vim.cmd('highlight Normal guibg=NONE ctermbg=NONE')
        vim.cmd('highlight NormalNC guibg=NONE ctermbg=NONE')
        highlights()
        state.group = api.nvim_create_augroup('BreadStartup', { clear = true })
        local function window(zindex, buffer_field, window_field)
            local buf = api.nvim_create_buf(false, true)
            state[buffer_field] = buf
            vim.bo[buf].bufhidden = 'wipe'
            local win = api.nvim_open_win(buf, false, {
                relative = 'editor', row = 0, col = 0, width = 1, height = 1,
                style = 'minimal', border = 'none', focusable = false, mouse = false,
                noautocmd = true, zindex = zindex,
            })
            state[window_field] = win
            vim.wo[win].winhighlight = 'Normal:BreadBootNormal,NormalNC:BreadBootNormal,EndOfBuffer:BreadBootNormal'
            vim.wo[win].winblend = 0
            return buf, win
        end
        -- Opaque cells with the terminal's default background hide all unfinished UI text.
        window(300, 'backdropbuf', 'backdrop')
        window(310, 'buf', 'win')
        window(311, 'logbuf', 'logwin')
        -- These lookups can stall on Windows PATH entries. Refresh immediately
        -- after they return, including calls made inside third-party plugins.
        -- Restore every wrapper when the startup overlay closes.
        state.lookups = {}
        for _, name in ipairs({ 'executable', 'exepath', 'glob' }) do
            local original = vim.fn[name]
            local wrapper = function(...)
                local result = original(...)
                M.checkpoint()
                return result
            end
            state.lookups[name] = { original = original, wrapper = wrapper }
            vim.fn[name] = wrapper
        end
        api.nvim_create_autocmd('ColorScheme', { group = state.group, callback = highlights })
        api.nvim_create_autocmd('VimResized', { group = state.group, callback = function() draw(state) end })
        api.nvim_create_autocmd('VimLeavePre', { group = state.group, once = true,
            callback = function() state.finished = true; close() end })
        state.timer = uv.new_timer()
        local next_frame = uv.hrtime()
        -- Poll before the 60 Hz deadline: Windows can round a 16 ms timer up
        -- to two system ticks. Keep deadlines cumulative instead of drifting.
        state.timer:start(8, 8, vim.schedule_wrap(function()
            local now = uv.hrtime()
            if not state.finished and now + 2e6 >= next_frame
                and (now - state.started) / 1e9 - (state.drawn or 0) >= .008 then
                if not render(function() draw(state) end) then return end
                next_frame = math.max(next_frame + 1e9 / 60, now + 8e6)
            end
        end))
        advance()
    end
    local batch = false
    for _, arg in ipairs(vim.v.argv) do
        if arg == '--headless' or arg:match('^%-[eEs]+$') or arg == '-l' then batch = true end
    end
    if #api.nvim_list_uis() > 0 then
        render(start)
    elseif not batch then
        api.nvim_create_autocmd('UIEnter', { once = true, callback = function() render(start) end })
    else
        for i, step in ipairs(steps) do
            state.current = i
            if not execute(step) then break end
        end
        finish()
    end
    return state
end

return M
