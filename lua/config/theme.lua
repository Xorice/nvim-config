require("catppuccin").setup({
    flavour = "mocha",
    transparent_background = true,
    integrations = {
        blink_cmp  = true,
        native_lsp = { enabled = true },
    },
})

vim.cmd.colorscheme "catppuccin"

vim.api.nvim_set_hl(0, "LineNr",            { fg = "#898fa6" })
vim.api.nvim_set_hl(0, "CursorLineNr",      { fg = "#f5c2e7", bold = true })
vim.api.nvim_set_hl(0, "CodeiumSuggestion", { fg = "#6c7086", italic = true })
