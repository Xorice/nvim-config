local key = vim.keymap.set

-------------------------------------------------------------------------------
-- 文件树 / Markdown / 搜索
-------------------------------------------------------------------------------
key('n', '<leader>e',  ':Neotree toggle<CR>',                                        { desc = '󰙅 Toggle Explorer' })
key('n', '<leader>m',  ':Markview toggle<CR>',                                       { desc = '󰽉 Toggle Markdown' })
local function search(method)
    return function()
        require('plugins').load('telescope')
        require('telescope.builtin')[method]({ cwd = require('project').search_root() })
    end
end
key('n', '<C-p>', search('find_files'), { desc = '󰱼 Find Files' })
key('n', '<leader>fg', search('live_grep'), { desc = 'Search Project Text' })
key('n', '<leader>fw', search('grep_string'), { desc = 'Search Word in Project' })
key('n', '<leader>cf', function()
    local clients = vim.lsp.get_clients({ bufnr = 0, method = 'textDocument/formatting' })
    if #clients == 0 then vim.notify('当前语言服务不支持格式化。'); return end
    vim.lsp.buf.format({ async = true, id = clients[1].id })
end, { desc = 'Format Buffer' })

-------------------------------------------------------------------------------
-- 折叠
-------------------------------------------------------------------------------
key('n', 'zR', function() require('ufo').openAllFolds()  end, { desc = '󱃄 Open All Folds' })
key('n', 'zM', function() require('ufo').closeAllFolds() end, { desc = '󱃃 Close All Folds' })

-------------------------------------------------------------------------------
-- DAP 调试
-------------------------------------------------------------------------------
local function debug_action(method, module)
    return function()
        require('plugins').load('debugger')
        require(module or 'dap')[method]()
    end
end
key('n', '<leader>r',  debug_action('continue'),         { desc = '󰐊 Debug: Start/Continue' })
key('n', '<leader>b',  debug_action('toggle_breakpoint'), { desc = '󰃢 Debug: Toggle Breakpoint' })
key('n', '<leader>dq', debug_action('terminate'),        { desc = '󰓛 Debug: Terminate' })
key('n', '<leader>du', debug_action('toggle', 'dapui'),   { desc = '󱂵 Debug: Toggle UI' })
key('n', '<leader>di', debug_action('step_into'),        { desc = '󰆹 Debug: Step Into' })
key('n', '<leader>do', debug_action('step_over'),        { desc = '󰆸 Debug: Step Over' })

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
key('n', '<leader>lr', function()
    require('compile').run({ love = true })
end, { desc = '󰠫 Run LÖVE' })
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
-- 注释
-------------------------------------------------------------------------------
key('n', '<C-_>',  'gcc', { remap = true, silent = true, desc = '󰆉 Toggle Comment' })
key('v', '<C-_>',  'gcgv',   { remap = true, silent = true, desc = '󰆉 Toggle Comment' })
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
-- 编译运行 
-------------------------------------------------------------------------------
key('n', '<leader>rc', function() require('compile').run() end, { desc = '󰑮 Compile & Run' })
key('n', '<leader>rs', function() require('compile').stop() end, { desc = 'Stop Run' })
key('n', '<leader>ro', function() require('compile').output() end, { desc = 'Show Run Output' })
