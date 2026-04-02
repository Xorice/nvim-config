local key = vim.keymap.set

-------------------------------------------------------------------------------
-- 文件树 / Markdown / 搜索
-------------------------------------------------------------------------------
key('n', '<leader>e',  ':Neotree toggle<CR>',                                        { desc = '󰙅 Toggle Explorer' })
key('n', '<leader>m',  ':Markview toggle<CR>',                                       { desc = '󰽉 Toggle Markdown' })
key('n', '<C-p>',      function() require('telescope.builtin').find_files() end,      { desc = '󰱼 Find Files' })

-------------------------------------------------------------------------------
-- 折叠
-------------------------------------------------------------------------------
key('n', 'zR', function() require('ufo').openAllFolds()  end, { desc = '󱃄 Open All Folds' })
key('n', 'zM', function() require('ufo').closeAllFolds() end, { desc = '󱃃 Close All Folds' })

-------------------------------------------------------------------------------
-- DAP 调试
-------------------------------------------------------------------------------
key('n', '<leader>r',  function() require('dap').continue()          end, { desc = '󰐊 Debug: Start/Continue' })
key('n', '<leader>b',  function() require('dap').toggle_breakpoint()  end, { desc = '󰃢 Debug: Toggle Breakpoint' })
key('n', '<leader>dq', function() require('dap').terminate()          end, { desc = '󰓛 Debug: Terminate' })
key('n', '<leader>du', function() require('dapui').toggle()           end, { desc = '󱂵 Debug: Toggle UI' })
key('n', '<leader>di', function() require('dap').step_into()          end, { desc = '󰆹 Debug: Step Into' })
key('n', '<leader>do', function() require('dap').step_over()          end, { desc = '󰆸 Debug: Step Over' })

-------------------------------------------------------------------------------
-- 窗口大小调整 (smart-splits)
-------------------------------------------------------------------------------
local ss = require('smart-splits')
key('n', '<A-Left>',  ss.resize_left,  { desc = 'Resize Left' })
key('n', '<A-Down>',  ss.resize_down,  { desc = 'Resize Down' })
key('n', '<A-Up>',    ss.resize_up,    { desc = 'Resize Up' })
key('n', '<A-Right>', ss.resize_right, { desc = 'Resize Right' })

-------------------------------------------------------------------------------
-- Love2D / Git
-------------------------------------------------------------------------------
key('n', '<leader>lr', ':!lovec.exe src<CR>',               { desc = '󰠫 Run LÖVE' })
key('n', '<leader>gs', ':Neotree float git_status<CR>',     { desc = '󰊢 Git Status Float' })

-------------------------------------------------------------------------------
-- 缩进
-------------------------------------------------------------------------------
key('n', '<A-]>', '>>',  { noremap = true, silent = true, desc = ' Indent line' })
key('v', '<A-]>', '>gv', { noremap = true, silent = true, desc = ' Indent selection' })
key('n', '<A-[>', '<<',  { noremap = true, silent = true, desc = ' Unindent line' })
key('v', '<A-[>', '<gv', { noremap = true, silent = true, desc = ' Unindent selection' })

-------------------------------------------------------------------------------
-- 行移动 (Alt+J/K)
-------------------------------------------------------------------------------
key('n', '<A-k>', ':m .-2<CR>==',         { noremap = true, silent = true })
key('n', '<A-j>', ':m .+1<CR>==',         { noremap = true, silent = true })
key('v', '<A-k>', ":m '<-2<CR>gv=gv",    { noremap = true, silent = true })
key('v', '<A-j>', ":m '>+1<CR>gv=gv",    { noremap = true, silent = true })

-------------------------------------------------------------------------------
-- 按单词跳转
-------------------------------------------------------------------------------
key({ 'n', 'v', 'i' }, '<C-h>', '<C-Left>',  { noremap = true })
key({ 'n', 'v', 'i' }, '<C-l>', '<C-Right>', { noremap = true })

-------------------------------------------------------------------------------
-- 保存 / 高亮清除
-------------------------------------------------------------------------------
key({ 'n', 'i', 'v' }, '<C-s>', '<Esc>:w<CR>', { noremap = true, silent = true })
key('n', '<Esc>', ':nohlsearch<CR>',            { noremap = true, silent = true })

-------------------------------------------------------------------------------
-- Shift+方向键 选区（Insert / Normal / Visual）
-------------------------------------------------------------------------------
key('i', '<S-Left>',  '<Esc>vh',  { noremap = true, silent = true })
key('i', '<S-Right>', '<Esc>lvl', { noremap = true, silent = true })
key('i', '<S-Up>',   '<Esc>vk',  { noremap = true, silent = true })
key('i', '<S-Down>', '<Esc>vj',  { noremap = true, silent = true })

key('n', '<S-Left>',  'vh', { noremap = true, silent = true })
key('n', '<S-Right>', 'vl', { noremap = true, silent = true })
key('n', '<S-Up>',   'vk', { noremap = true, silent = true })
key('n', '<S-Down>', 'vj', { noremap = true, silent = true })

key('v', '<S-Left>',  'h', { noremap = true, silent = true })
key('v', '<S-Right>', 'l', { noremap = true, silent = true })
key('v', '<S-Up>',   'k', { noremap = true, silent = true })
key('v', '<S-Down>', 'j', { noremap = true, silent = true })

-------------------------------------------------------------------------------
-- 编译运行 C/C++
-------------------------------------------------------------------------------
local function get_extra_flags(file)
    local flags = {}
    local content = vim.fn.readfile(file)
    local link_map = {
        ['math.h']       = '-lm',
        ['pthread.h']    = '-lpthread',
        ['GL/gl.h']      = '-lGL',
        ['GLFW/glfw3.h'] = '-lglfw',
        ['GL/glew.h']    = '-lGLEW',
    }
    for _, line in ipairs(content) do
        for header, flag in pairs(link_map) do
            if line:match('#include') and line:match(header) then
                if not vim.tbl_contains(flags, flag) then
                    table.insert(flags, flag)
                end
            end
        end
    end
    return table.concat(flags, ' ')
end

local function compile_and_run()
    local file = vim.fn.expand('%:p')
    local name = vim.fn.expand('%:t:r')
    local dir  = vim.fn.expand('%:p:h')
    local ext  = vim.fn.expand('%:e')

    local compiler
    if ext == 'c' then
        compiler = 'gcc'
    elseif ext == 'cpp' or ext == 'cc' or ext == 'cxx' then
        compiler = 'g++'
    else
        vim.notify("不是 C/C++ 文件", vim.log.levels.WARN)
        return
    end

    vim.cmd('write')

    local debug_dir = dir .. '/__debug__'
    local out       = debug_dir .. '/' .. name
    vim.fn.mkdir(debug_dir, 'p')

    -- 自动生成 .gitignore
    local gitignore = debug_dir .. '/.gitignore'
    if vim.fn.filereadable(gitignore) == 0 then
        vim.fn.writefile({ '*' }, gitignore)
    end

    local extra = get_extra_flags(file)
    local cmd   = string.format('%s "%s" -o "%s" -g %s && "%s"', compiler, file, out, extra, out)

    -- 关闭已有终端窗口
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.bo[buf].buftype == 'terminal' then
            vim.api.nvim_win_close(win, true)
            break
        end
    end

    vim.cmd('botright vsplit')
    vim.cmd('vertical resize 40')
    vim.cmd('terminal ' .. cmd)
    vim.cmd('startinsert')
end

key('n', '<leader>rc', compile_and_run, { desc = '󰑮 Compile & Run C/C++' })
