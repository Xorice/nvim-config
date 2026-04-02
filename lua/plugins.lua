vim.pack.add {
    -- 核心：语法、外观、图标
    { src = "https://github.com/nvim-treesitter/nvim-treesitter" },
    { src = "https://github.com/catppuccin/nvim",                name = "catppuccin" },
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
    { src = "https://github.com/mrjones2014/smart-splits.nvim" },

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
    { src = "https://github.com/numtostr/comment.nvim" },

    -- AI 补全
    { src = "https://github.com/Exafunction/codeium.nvim" },
    { src = "https://github.com/saghen/blink.compat" },
}
