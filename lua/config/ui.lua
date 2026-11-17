-- Subtle indent guides; search and explorer keep their existing plugins.
local checkpoint = require('bread.startup').checkpoint
require('snacks').setup({
    indent = {
        enabled = true,
        animate = { enabled = false },
        scope = { enabled = true, underline = false },
    },
})
-- UI configuration runs after the first file's BufReadPost.
require('snacks').indent.enable()
checkpoint()

-- 折叠
require('ufo').setup {
    provider_selector = function()
        return { 'treesitter', 'indent' }
    end,
}
checkpoint()

-- Git 标记
require('gitsigns').setup {}
checkpoint()

-- Which-key
require("which-key").setup { preset = "helix" }
checkpoint()

-- 状态栏
local workspace = require('bread.workspace')
local install_progress = require('bread.install_progress')
workspace.setup()

local function detail_visible()
    return vim.o.columns >= 100 or install_progress.status() == ''
end

local function codeium_status()
    if not vim.g.bread_codeium_enabled then return '󰚩 Off' end
    local status = require('codeium.virtual_text').status_string()
    if status == "" then return "󰚩 Off" end
    return "󰚩 " .. status:gsub("^%s*(.-)%s*$", "%1")
end

require('lualine').setup {
    options = {
        -- 核心修正：左侧 section 结尾用右半圆，右侧 section 开头用左半圆
        section_separators = { left = '', right = '' },
        component_separators = '', 
        globalstatus = true,
        theme = "auto",
    },
    sections = {
        -- A 组：左侧最开头手动加一个左半圆，末尾由 options 自动加右半圆
        lualine_a = { { 'mode', fmt = function(str) return str:sub(1, 1) end, separator = { left = '' } } },
        lualine_b = { 'branch', {
            'diff', cond = function()
                return vim.o.columns >= 100 or (workspace.status() == '' and install_progress.status() == '')
            end,
        }, 'diagnostics' },
        lualine_c = { { 'filename', path = 1, cond = detail_visible }, { install_progress.status }, {
            workspace.status,
            cond = detail_visible,
            fmt = function(text) return (text:gsub('%%', '%%%%')) end,
        } },
        lualine_x = {
            { codeium_status, cond = detail_visible },
            { function()
                return vim.b.bread_project_kind or ''
            end, cond = detail_visible },
            { 'encoding', cond = detail_visible },
            { 'filetype', cond = detail_visible },
        },
        lualine_y = { 'progress' },
        -- Z 组：末尾手动加一个右半圆，开头由 options 自动加左半圆
        lualine_z = { { 'location', separator = { right = '' } } }
    }
}
