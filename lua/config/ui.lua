-- 文件树
require("neo-tree").setup {
    window = { width = 30 },
    filesystem = {
        follow_current_file = { enabled = true },
    },
}

-- 折叠
require('ufo').setup {
    provider_selector = function()
        return { 'treesitter', 'indent' }
    end,
}

-- Git 标记
require('gitsigns').setup {}

-- Which-key
require("which-key").setup { preset = "helix" }

-- 状态栏
local function codeium_status()
    local status = vim.fn['codeium#GetStatusString']()
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
        lualine_b = { 'branch', 'diff', 'diagnostics' },
        lualine_c = { { 'filename', path = 1 } },
        lualine_x = {
            { codeium_status },
            'encoding',
            'filetype'
        },
        lualine_y = { 'progress' },
        -- Z 组：末尾手动加一个右半圆，开头由 options 自动加左半圆
        lualine_z = { { 'location', separator = { right = '' } } }
    }
}
