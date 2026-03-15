-- Nightly 0.12.x
-- * 面包 NVIM

-------------------------------------------------------------------------------
-- 1. 基础设置 (Options)
-------------------------------------------------------------------------------
vim.g.mapleader = ","
vim.g.maplocalleader = ","

local opt = vim.opt
opt.number = true
opt.relativenumber = false
opt.tabstop = 4
opt.shiftwidth = 4
opt.expandtab = true
opt.termguicolors = true
opt.signcolumn = "yes"
opt.cursorline = true
opt.mouse = "a"

-- VSCode 风格折叠设置
opt.foldcolumn = '1'
opt.foldlevel = 99
opt.foldlevelstart = 99
opt.foldenable = true

-------------------------------------------------------------------------------
-- 2. 插件安装 (原生批量方式)
-------------------------------------------------------------------------------
vim.pack.add {
    -- 核心：语法、外观、图标
    { src = "https://github.com/nvim-treesitter/nvim-treesitter" },
    { src = "https://github.com/catppuccin/nvim", name = "catppuccin" },
    { src = "https://github.com/nvim-tree/nvim-web-devicons" },
    { src = "https://github.com/sphamba/smear-cursor.nvim" },
    { src = "https://github.com/nvim-lualine/lualine.nvim" },
    { src = "https://github.com/lewis6991/gitsigns.nvim" },

    -- LSP & 补全
    { src = "https://github.com/williamboman/mason.nvim" },
    { src = "https://github.com/williamboman/mason-lspconfig.nvim" },
    { src = "https://github.com/neovim/nvim-lspconfig" },
    { src = "https://github.com/saghen/blink.cmp" },
    { src = "https://github.com/rachartier/tiny-inline-diagnostic.nvim" },

    -- UI 组件
    { src = "https://github.com/nvim-neo-tree/neo-tree.nvim" },
    { src = "https://github.com/MunifTanjim/nui.nvim" },
    { src = "https://github.com/nvim-lua/plenary.nvim" },
    { src = "https://github.com/nvim-telescope/telescope.nvim" },
    { src = "https://github.com/folke/which-key.nvim" },
    { src = "https://github.com/mrjones2014/smart-splits.nvim" }, -- 窗口分割

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
    { src = "https://github.com/S1M0N38/love2d.nvim" },
    { src = "https://github.com/lopi-py/luau-lsp.nvim" },

    -- AI 补全
    { src = "https://github.com/Exafunction/codeium.nvim" },
    { src = "https://github.com/nvim-lua/plenary.nvim" }, -- Codeium 的依赖
    { src = "https://github.com/saghen/blink.compat" },
}
-------------------------------------------------------------------------------
-- 3. 主题
-------------------------------------------------------------------------------
require("catppuccin").setup({
    flavour = "mocha",
    transparent_background = true,
    integrations = { blink_cmp = true, native_lsp = { enabled = true } }
})
vim.cmd.colorscheme "catppuccin"

-- 强制刷新行号颜色
vim.api.nvim_set_hl(0, "LineNr", { fg = "#626880" })
vim.api.nvim_set_hl(0, "CursorLineNr", { fg = "#f5c2e7", bold = true })
vim.api.nvim_set_hl(0, "CodeiumSuggestion", { fg = "#6c7086", italic = true })

-------------------------------------------------------------------------------
-- 4. 插件配置
-------------------------------------------------------------------------------
vim.schedule(function()

    -- === 语法与补全 ===
    require 'nvim-treesitter' .setup
    {
        ensure_installed = { "lua", "c", "cpp", "python", "markdown" },
        highlight = { enable = true }
    }
    require "codeium" .setup {
        enable_cmp_source = false,
        virtual_text = {
            enabled = true,
            key_bindings = {
                accept = "<C-f>",
                next = "<A-]>",
                prev = "<A-[>",
            }
        }
    }
    require "blink.cmp" .setup {
        keymap = { preset = "enter" },
        sources = {
            -- 加上 codeium 到列表
            default = { "lsp", "path", "snippets", "buffer", "codeium" },
            providers = {
                codeium = {
                    name = "codeium",
                    module = "blink.compat.source",
                    score_offset = 100,
                    async = true,
                },
            },
        },
        fuzzy = { implementation = "lua" }
    }
    require('gitsigns').setup {} -- git diff显示

    -- === LSP (适配 0.12) ===
    require "mason" .setup()
    require "mason-lspconfig" .setup
    {
        ensure_installed = { "lua_ls", "clangd", "pyright" }
    }
    local caps = require "blink.cmp" .get_lsp_capabilities()
    vim.lsp.config("lua_ls", { capabilities = caps, settings = { Lua = { diagnostics = { globals = { "vim" } } } } })
    require "luau-lsp" .setup {
        platform = {
            type = "roblox", -- 这一行会自动帮你搞定 game, workspace 等所有全局变量
        },
    }

    vim.lsp.config("clangd", { capabilities = caps })
    vim.lsp.config("pyright", { capabilities = caps })
    vim.lsp.enable({"lua_ls", "clangd", "pyright"})

    vim.diagnostic.config({
        signs = {
            text = {
                [vim.diagnostic.severity.ERROR] = "󰅚 ",
                [vim.diagnostic.severity.WARN]  = "󰀪 ",
                [vim.diagnostic.severity.HINT]  = "󰌶 ",
                [vim.diagnostic.severity.INFO]  = "󰋽 ",
            },
        },
        virtual_text = false, -- 禁用原生行内文字，交给 tiny-inline 处理
        update_in_insert = false,
        severity_sort = true,
    })

    vim.api.nvim_set_hl(0, "DiagnosticSignError", { link = "DiagnosticError" })
    vim.api.nvim_set_hl(0, "DiagnosticSignWarn", { link = "DiagnosticWarn" })
    vim.api.nvim_set_hl(0, "DiagnosticSignHint", { link = "DiagnosticHint" })
    vim.api.nvim_set_hl(0, "DiagnosticSignInfo", { link = "DiagnosticInfo" })

    require "tiny-inline-diagnostic" .setup()

    -- === 折叠 (UFO) ===
    require 'ufo' .setup
    {
        provider_selector = function()
            return {'treesitter', 'indent'}
        end
    }

    -- === DAP 调试配置 (C, C++, Python) ===
    local dap, dapui = require "dap", require "dapui"
    dapui.setup()
    require "nvim-dap-virtual-text" .setup()

    -- 使用 Mason 管理调试器安装
    require "mason-nvim-dap" .setup
    {
        ensure_installed = { "codelldb", "python" }, -- python 对应 debugpy
        automatic_installation = true,
        handlers = {
            function(config) require 'mason-nvim-dap' .default_setup(config) end,
        },
    }

    -- 调试 UI 自动交互
    dap.listeners.after.event_initialized["dapui_config"] = function() dapui.open() end
    dap.listeners.before.event_terminated["dapui_config"] = function() dapui.close() end
    dap.listeners.before.event_exited["dapui_config"] = function() dapui.close() end

    -- 视觉符号
    vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DapBreakpoint", linehl = "", numhl = "" })
    vim.api.nvim_set_hl(0, "DapBreakpoint", { fg = "#f38ba8" })

    -- === 其他组件 ===
    require "neo-tree" .setup
    {
        window = { width = 30 },
        filesystem = {
            follow_current_file = { enabled = true }
        }
    }
    require "tiny-inline-diagnostic" .setup()
    require "nvim-autopairs" .setup {}
    require "smear_cursor" .setup()
    require "which-key" .setup { preset = "helix" }
    require 'smart-splits' .setup {}

    -- 状态栏 Lualine
    local function codeium_status()
        local status = vim.fn['codeium#GetStatusString']()
        if status == "" then return "󰚩 Off" end
        -- 移除状态字符串中的空格并加上图标
        return "󰚩 " .. status:gsub("^%s*(.-)%s*$", "%1")
    end

    -- 2. 配置 Lualine
    require('lualine').setup({
        options = {
            component_separators = { left = '󰿟', right = '󰿟' },
            section_separators = { left = '', right = '' },
            globalstatus = true, -- 0.12 推荐开启全局状态栏
        },
        sections = {
            lualine_a = { { 'mode', fmt = function(str) return str:sub(1, 1) end } }, -- 只显示模式首字母
            lualine_b = { 'branch', 'diff', 'diagnostics' },
            lualine_c = { { 'filename', path = 1 } }, -- 显示相对路径
            lualine_x = {
                { codeium_status }, -- 这里加入 AI 状态
                'encoding',
                'filetype'
            },
            lualine_y = { 'progress' },
            lualine_z = { 'location' }
        }
    })
end)

-------------------------------------------------------------------------------
-- 5. 快捷键映射
-------------------------------------------------------------------------------
local key = vim.keymap.set

key('n', '<leader>e', ':Neotree toggle<CR>', { desc = '󰙅 Toggle Explorer' })
key('n', '<leader>m', ':Markview toggle<CR>', { desc = '󰽉 Toggle Markdown' })
key('n', '<C-p>', function() require('telescope.builtin').find_files() end, { desc = '󰱼 Find Files' })
key('n', 'zR', function() require('ufo').openAllFolds() end, { desc = '󱃄 Open All Folds' })
key('n', 'zM', function() require('ufo').closeAllFolds() end, { desc = '󱃃 Close All Folds' })

-- DAP 快捷键
key("n", "<leader>r", function() require('dap').continue() end, { desc = '󰐊 Debug: Start/Continue' })
key("n", "<leader>b", function() require('dap').toggle_breakpoint() end, { desc = '󰃢 Debug: Toggle Breakpoint' })
key("n", "<leader>dq", function() require('dap').terminate() end, { desc = '󰓛 Debug: Terminate' })
key("n", "<leader>du", function() require('dapui').toggle() end, { desc = '󱂵 Debug: Toggle UI' })
key("n", "<leader>di", function() require('dap').step_into() end, { desc = '󰆹 Debug: Step Into' })
key("n", "<leader>do", function() require('dap').step_over() end, { desc = '󰆸 Debug: Step Over' })

-- 窗口快捷键
local ss = require('smart-splits')
key('n', '<A-h>', ss.resize_left, { desc = 'Resize Left' })
key('n', '<A-j>', ss.resize_down, { desc = 'Resize Down' })
key('n', '<A-k>', ss.resize_up, { desc = 'Resize Up' })
key('n', '<A-l>', ss.resize_right, { desc = 'Resize Right' })

-- Love2D 快捷键
key('n', '<leader>lr', ':!lovec.exe src<CR>', { desc = '󰠫 Run LÖVE' })

-- GIT 操作
vim.keymap.set('n', '<leader>gs', ':Neotree float git_status<CR>', { desc = '󰊢 Git Status Float' })
