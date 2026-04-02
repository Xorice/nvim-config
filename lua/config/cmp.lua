require("codeium").setup {
    enable_cmp_source = false,
    virtual_text = {
        enabled = true,
        key_bindings = {
            accept = "<C-f>",
            next   = "<A-]>",
            prev   = "<A-[>",
        },
    },
}

require("blink.cmp").setup {
    keymap  = { preset = "enter" },
    sources = {
        default = { "lsp", "path", "snippets", "buffer", "codeium" },
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
