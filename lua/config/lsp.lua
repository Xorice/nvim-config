require("mason").setup()
require("mason-lspconfig").setup {
    ensure_installed = { "lua_ls", "clangd", "pyright" },
}

local caps = require("blink.cmp").get_lsp_capabilities()

vim.lsp.config("lua_ls", {
    capabilities = caps,
    settings = {
        Lua = { diagnostics = { globals = { "vim" } } },
    },
})

require("luau-lsp").setup {
    platform = { type = "roblox" },
}

vim.lsp.config("clangd", { capabilities = caps })
vim.lsp.config("pyright", { capabilities = caps })
vim.lsp.enable({ "lua_ls", "clangd", "pyright" })

-- 诊断显示设置
vim.diagnostic.config({
    signs = {
        text = {
            [vim.diagnostic.severity.ERROR] = "󰅚 ",
            [vim.diagnostic.severity.WARN]  = "󰀪 ",
            [vim.diagnostic.severity.HINT]  = "󰌶 ",
            [vim.diagnostic.severity.INFO]  = "󰋽 ",
        },
    },
    virtual_text      = false,
    update_in_insert  = false,
    severity_sort     = true,
})

vim.api.nvim_set_hl(0, "DiagnosticSignError", { link = "DiagnosticError" })
vim.api.nvim_set_hl(0, "DiagnosticSignWarn",  { link = "DiagnosticWarn" })
vim.api.nvim_set_hl(0, "DiagnosticSignHint",  { link = "DiagnosticHint" })
vim.api.nvim_set_hl(0, "DiagnosticSignInfo",  { link = "DiagnosticInfo" })

require("tiny-inline-diagnostic").setup()
