local M = {}
local tasks, order = {}, {}

local function refresh()
    vim.schedule(function()
        local lualine = package.loaded.lualine
        if lualine then lualine.refresh({ place = { 'statusline' } }) end
    end)
end

function M.begin(key, label, total)
    if not tasks[key] then order[#order + 1] = key end
    tasks[key] = { label = label, total = total, done = 0, failed = 0, active = true }
    refresh()
end

function M.update(key, done, detail, failed)
    local task = assert(tasks[key])
    task.done, task.detail = done, detail
    if failed ~= nil then task.failed = failed end
    refresh()
end

function M.finish(key, failed)
    local task = assert(tasks[key])
    task.active, task.finished = false, vim.uv.hrtime()
    if failed ~= nil then task.failed = failed end
    refresh()
end

function M.clear(key)
    -- Keep the slot so repeated installs do not grow the display order.
    if tasks[key] then tasks[key] = { failed = 0 } end
end

function M.status()
    local active, failed, finished = {}, 0, 0
    for _, key in ipairs(order) do
        local task = tasks[key]
        failed = failed + task.failed
        finished = math.max(finished, task.finished or 0)
        if task.active then
            active[#active + 1] = ('%s %d/%d%s'):format(task.label, task.done, task.total,
                vim.o.columns >= 100 and task.detail and task.detail ~= '' and ' ' .. task.detail or '')
        end
    end
    local failure = failed > 0 and (' · %d failed'):format(failed) or ''
    if #active > 0 then return table.concat(active, ' · ') .. failure end
    if failed > 0 then return ('Deps: %d failed'):format(failed) end
    if finished > 0 and vim.uv.hrtime() - finished < 3e9 then return 'Deps ready' end
    return ''
end

return M
