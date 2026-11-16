require("mason").setup()
require("mason-lspconfig").setup {
    -- Installation is managed centrally by dependencies.lua.
    ensure_installed = {},
    automatic_enable = false,
}

local caps = require("blink.cmp").get_lsp_capabilities()

require('project_lsp').setup(caps)

vim.lsp.config("clangd", { capabilities = caps })
vim.lsp.config("pyright", { capabilities = caps })
vim.lsp.enable({ "clangd", "pyright" })

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
