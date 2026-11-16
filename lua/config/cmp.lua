local sources = { "lsp", "path", "snippets", "buffer" }
-- Codeium uses gzip even on Windows. Basic completion remains available without it.
vim.g.bread_codeium_enabled = vim.env.NVIM_NO_AI ~= '1'
    and vim.fn.executable('gzip') == 1 and vim.fn.executable('curl') == 1
if vim.g.bread_codeium_enabled then
    require('blink.compat').setup({})
    require("codeium").setup {
        enable_cmp_source = true,
        virtual_text = {
            enabled = true,
            key_bindings = {
                accept = "<C-f>",
                next   = "<A-n>",
                prev   = "<A-p>",
            },
        },
    }
    table.insert(sources, 'codeium')
end

require("blink.cmp").setup {
    keymap  = {
        preset = "super-tab",
        ["<CR>"] = { "select_and_accept", "fallback" },
    },
    sources = {
        default = sources,
        providers = {
            codeium = {
                name   = "codeium",
                module = "blink.compat.source",
                score_offset = 100,
                async  = true,
            },
        },
    },
    fuzzy = { implementation = "lua" },
}
