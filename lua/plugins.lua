local M = {}
local checkpoint = require('bread.startup').checkpoint
local groups = {
    debugger = { 'nvim-nio', 'nvim-dap', 'nvim-dap-ui', 'nvim-dap-virtual-text', 'mason-nvim-dap.nvim' },
    explorer = { 'neo-tree.nvim' },
    markdown = { 'markview.nvim' },
    telescope = { 'telescope.nvim' },
}
local deferred, loaded, paths = {}, {}, {}
for _, names in pairs(groups) do
    for _, name in ipairs(names) do deferred[name] = true end
end

function M.load(group)
    if loaded[group] then return end
    for _, name in ipairs(groups[group] or {}) do
        -- Register the installed path before loading deferred Lua modules.
        if paths[name] then vim.opt.runtimepath:append(paths[name]) end
        vim.cmd.packadd(name)
        checkpoint()
    end
    if group == 'debugger' or group == 'explorer' or group == 'lsp' then require('config.' .. group) end
    loaded[group] = true
end

vim.pack.add({
    -- 核心：语法、外观、图标
    { src = "https://github.com/nvim-treesitter/nvim-treesitter" },
    { src = "https://github.com/boonyarit-iamsaard/dark-2026.nvim" },
    { src = "https://github.com/nvim-tree/nvim-web-devicons" },
    { src = "https://github.com/sphamba/smear-cursor.nvim" },
    { src = "https://github.com/nvim-lualine/lualine.nvim" },
    { src = "https://github.com/lewis6991/gitsigns.nvim" },

    -- LSP & 补全
    { src = "https://github.com/williamboman/mason.nvim" },
    { src = "https://github.com/neovim/nvim-lspconfig" },
    { src = "https://github.com/saghen/blink.cmp" },
    { src = "https://github.com/rachartier/tiny-inline-diagnostic.nvim" },

    -- UI 组件
    { src = "https://github.com/nvim-neo-tree/neo-tree.nvim" },
    { src = "https://github.com/MunifTanjim/nui.nvim" },
    { src = "https://github.com/nvim-lua/plenary.nvim" },
    { src = "https://github.com/nvim-telescope/telescope.nvim" },
    { src = "https://github.com/folke/which-key.nvim" },
    { src = "https://github.com/folke/snacks.nvim" },

    -- 折叠优化
    { src = "https://github.com/kevinhwang91/nvim-ufo" },
    { src = "https://github.com/kevinhwang91/promise-async" },

    -- DAP (调试)
    { src = "https://github.com/mfussenegger/nvim-dap" },
    { src = "https://github.com/rcarriga/nvim-dap-ui" },
    { src = "https://github.com/nvim-neotest/nvim-nio" },
    { src = "https://github.com/theHamsta/nvim-dap-virtual-text" },
    { src = "https://github.com/jay-babu/mason-nvim-dap.nvim" },

    -- 辅助工具
    { src = "https://github.com/windwp/nvim-autopairs" },
    { src = "https://github.com/OXY2DEV/markview.nvim" },
    { src = "https://github.com/LuaCATS/love2d" },
    { src = "https://github.com/lopi-py/luau-lsp.nvim" },

    -- AI 补全
    { src = "https://github.com/Exafunction/codeium.nvim" },
    { src = "https://github.com/saghen/blink.compat" },
}, { confirm = false, load = function(plugin)
    paths[plugin.spec.name] = plugin.path
    if not deferred[plugin.spec.name] then
        -- After UIEnter, Neovim's automatic plugin/ script pass has already run.
        vim.cmd((vim.v.vim_did_enter == 1 and 'packadd ' or 'packadd! ') .. plugin.spec.name)
    end
    checkpoint()
end })

local function command(name, group)
    vim.api.nvim_create_user_command(name, function(opts)
        M.load(group)
        local cmd = { cmd = name, args = opts.fargs, bang = opts.bang, mods = opts.smods }
        if opts.range > 0 then cmd.range = { opts.line1, opts.line2 } end
        vim.api.nvim_cmd(cmd, {})
    end, { nargs = '*', bang = true, range = true, desc = '首次使用时加载 ' .. group,
        complete = function(_, line, cursor)
            M.load(group)
            return vim.fn.getcompletion(line:sub(1, cursor), 'cmdline')
        end })
end
command('Neotree', 'explorer')
command('Markview', 'markdown')
command('Telescope', 'telescope')
for _, name in ipairs({ 'DapContinue', 'DapToggleBreakpoint', 'DapClearBreakpoints', 'DapToggleRepl',
    'DapStepOver', 'DapStepInto', 'DapStepOut', 'DapPause', 'DapTerminate', 'DapDisconnect',
    'DapSetLogLevel', 'DapShowLog', 'DapRestartFrame', 'DapNew', 'DapEval' }) do
    command(name, 'debugger')
end

local group = vim.api.nvim_create_augroup('BreadLazyPlugins', { clear = true })
function M.activate(buf)
    local ft = vim.bo[buf].filetype
    if vim.tbl_contains({ 'lua', 'luau', 'c', 'cpp', 'python' }, ft) then M.load('lsp') end
    if ft == 'markdown' then M.load('markdown') end
    local path = vim.api.nvim_buf_get_name(buf)
    if buf == vim.api.nvim_get_current_buf() and vim.fn.isdirectory(path) == 1 then
        M.load('explorer')
        require('neo-tree.command').execute({ action = 'show', position = 'current', dir = path })
    end
end
vim.api.nvim_create_autocmd('FileType', { group = group, pattern = { 'lua', 'luau', 'c', 'cpp', 'python' },
    callback = function() M.load('lsp') end })
vim.api.nvim_create_autocmd('FileType', { group = group, pattern = 'markdown',
    callback = function() M.load('markdown') end })
-- Keep directory startup working without loading the explorer for ordinary files.
vim.g.loaded_netrwPlugin = 1
vim.api.nvim_create_autocmd('BufEnter', { group = group, callback = function(event)
    if vim.fn.isdirectory(event.file) ~= 1 then return end
    vim.schedule(function()
        if vim.api.nvim_get_current_buf() ~= event.buf then return end
        M.load('explorer')
        require('neo-tree.command').execute({ action = 'show', position = 'current', dir = event.file })
    end)
end })

return M
