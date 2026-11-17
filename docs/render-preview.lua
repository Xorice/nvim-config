-- The exporter runs this scene in a separate `nvim -u NONE` process.
local M = {}
local api = vim.api

function M.setup(root, fixture)
    vim.opt.runtimepath:prepend(root)
    vim.o.more = false
    vim.o.shortmess = vim.o.shortmess .. 'I'
    if vim.fn.exists('+messagesopt') == 1 then
        local options = vim.split(vim.o.messagesopt, ',')
        options = vim.tbl_filter(function(value) return value ~= 'hit-enter' and not value:match('^wait:') end, options)
        options[#options + 1] = 'wait:0'
        vim.o.messagesopt = table.concat(options, ',')
    end
    for _, name in ipairs({ 'dark-2026.nvim', 'nvim-web-devicons', 'plenary.nvim', 'nui.nvim',
        'neo-tree.nvim', 'lualine.nvim', 'gitsigns.nvim' }) do
        local ok = pcall(vim.cmd, 'packadd! ' .. name)
        assert(ok, 'Missing plugin ' .. name .. '; install this configuration before exporting')
    end
    require('dark-2026').setup({ transparent = false })
    vim.cmd.colorscheme('dark-2026')
    require('project').setup()
    require('gitsigns').setup({})
    require('neo-tree').setup({ window = { width = 30 }, filesystem = { follow_current_file = { enabled = true } } })
    vim.cmd('filetype plugin indent on')
    vim.cmd('cd ' .. vim.fn.fnameescape(fixture))
    vim.cmd('edit ' .. vim.fn.fnameescape(fixture .. '/src/main.luau'))
    local editor, codebuf = api.nvim_get_current_win(), api.nvim_get_current_buf()
    vim.bo[codebuf].filetype = 'luau'
    local ok, err = pcall(vim.treesitter.start, codebuf, 'luau')
    assert(ok, 'Luau parser is not available; finish :InstallTools first. ' .. tostring(err))
    require('neo-tree.command').execute({ action = 'show', source = 'filesystem', dir = fixture,
        reveal_file = fixture .. '/src/main.luau' })
    api.nvim_set_current_win(editor)
    assert(vim.wait(5000, function()
        local status = vim.b[codebuf].gitsigns_status_dict
        return status and status.head == 'main' and ((status.added or 0) + (status.changed or 0) > 0)
    end), 'Git decorations did not become ready')
    vim.wait(200)
    local treebuf
    for _, buf in ipairs(api.nvim_list_bufs()) do
        if vim.bo[buf].filetype == 'neo-tree' then treebuf = buf; break end
    end
    assert(treebuf, 'Neo-tree buffer was not created')
    local palette = require('dark-2026.palette')
    for _, name in ipairs({ 'Normal', 'NormalNC', 'NeoTreeNormal', 'NeoTreeNormalNC' }) do
        local hl = api.nvim_get_hl(0, { name = name, link = false })
        hl.bg = palette.bg
        api.nvim_set_hl(0, name, hl)
    end

    -- Reuse the actual startup renderer. Only the export's pitch ratio changes:
    -- two yaw revolutions and one pitch revolution close the 2.4-second loop.
    local source = table.concat(vim.fn.readfile(root .. '/lua/bread/startup.lua'), '\n')
    local replacements
    source, replacements = source:gsub('state.angle %* %.55', 'state.angle * .5')
    assert(replacements == 2, 'Startup rotation changed; update the export loop in docs/render-preview.lua')
    local startup = assert(loadstring(source, '@readme-export'))()
    local draw, highlights
    for i = 1, 100 do
        local name, value = debug.getupvalue(startup.run, i)
        if not name then break end
        if name == 'draw' then draw = value end
        if name == 'highlights' then highlights = value end
    end
    assert(draw and highlights, 'Startup renderer changed; update docs/render-preview.lua')
    highlights()
    M.draw = draw

    local function window(width, height, row, col, zindex, existing)
        local buf = existing or api.nvim_create_buf(false, true)
        local win = api.nvim_open_win(buf, false, { relative = 'editor', row = row, col = col,
            width = width, height = height, focusable = false, noautocmd = true,
            border = 'none', style = 'minimal', zindex = zindex })
        vim.wo[win].winhighlight = 'Normal:BreadBootNormal,NormalNC:BreadBootNormal,EndOfBuffer:BreadBootNormal'
        return buf, win
    end
    local _, backdrop = window(vim.o.columns, vim.o.lines - vim.o.cmdheight - 1, 0, 0, 300)
    local buf, win = window(52, 17, math.floor((vim.o.lines - vim.o.cmdheight - 18) / 2),
        math.floor((vim.o.columns - 52) / 2), 310)
    local _, treewin = window(32, 5, 3, 2, 320, treebuf)
    vim.wo[treewin].scrolloff = 0
    api.nvim_win_call(treewin, function() vim.fn.winrestview({ topline = 2, lnum = 2, col = 0 }) end)
    local _, codewin = window(37, 8, 10, 2, 320, codebuf)
    for name, value in pairs({ number = true, relativenumber = false, numberwidth = 3,
        signcolumn = 'no', foldcolumn = '0', cursorline = false, wrap = false }) do vim.wo[codewin][name] = value end
    vim.wo[codewin].winhighlight = 'Normal:Normal,NormalNC:Normal,EndOfBuffer:BreadBootNormal'
    local ns = api.nvim_create_namespace('ReadmePreview')
    local heading = window(24, 1, 1, 2, 320)
    api.nvim_buf_set_lines(heading, 0, -1, false, { 'BREAD NVIM' })
    api.nvim_set_hl(0, 'ReadmeHeading', { fg = palette.fg, bold = true, bg = 'NONE' })
    api.nvim_buf_set_extmark(heading, ns, 0, 0, { end_col = 10, hl_group = 'ReadmeHeading' })
    local theme = window(12, 1, 1, vim.o.columns - 14, 320)
    api.nvim_buf_set_lines(theme, 0, -1, false, { vim.g.colors_name })
    api.nvim_buf_set_extmark(theme, ns, 0, 0, { end_col = #vim.g.colors_name, hl_group = 'Comment' })
    M.state = { buf = buf, win = win, backdrop = backdrop, started = vim.uv.hrtime(),
        layout = table.concat({ vim.o.columns, vim.o.lines, vim.o.cmdheight }, ':') }
    assert(vim.b[codebuf].bread_project_kind == 'roblox', 'Example project was not identified as Roblox')
    local head = vim.b[codebuf].gitsigns_head or vim.b[codebuf].gitsigns_status_dict.head
    assert(head and head ~= '', 'Git branch is not available')
    local spinner = { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' }
    M.index = 0
    -- The spinner is an explicit showcase state, not a real server being kept busy.
    require('lualine').setup({
        options = { section_separators = { left = '', right = '' }, component_separators = '',
            globalstatus = true, theme = 'auto' },
        sections = {
            lualine_a = { { 'mode', fmt = function(value) return value:sub(1, 1) end, separator = { left = '' } } },
            lualine_b = { { function() return head end, icon = '' }, 'diff' },
            lualine_c = { { 'filename', path = 0 }, { function()
                return spinner[math.floor(M.index / 4) % #spinner + 1] .. ' Workspace loading'
            end } },
            lualine_x = { { function() return vim.b[codebuf].bread_project_kind end }, 'encoding', 'filetype' },
            lualine_y = {}, lualine_z = { { 'location', separator = { right = '' } } },
        },
    })
    require('lualine').refresh({ place = { 'statusline' }, force = true })
    vim.wait(200)
    vim.cmd('echo ""')
end

function M.frame(index, count)
    M.index = index
    M.state.angle, M.state.drawn = math.pi * 4 * index / count, math.huge
    M.draw(M.state)
    require('lualine').refresh({ place = { 'statusline' }, force = true })
    vim.cmd.redrawstatus()
    vim.cmd.redraw()
end

return M
