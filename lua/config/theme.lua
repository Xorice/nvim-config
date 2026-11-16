require("dark-2026").setup({
    -- 编辑区透出终端背景，浮窗和补全菜单保留底色。
    transparent = true,
    on_highlights = function(hl, p)
        hl.LineNr = { fg = "#858889" }
        hl.CursorLineNr = { fg = p.fg, bold = true }
        hl.CodeiumSuggestion = { fg = p.fg_disabled, italic = true }
        hl.SnacksIndent = { fg = '#30343b' }
        hl.SnacksIndentScope = { fg = '#515965' }
    end,
})

vim.cmd.colorscheme "dark-2026"
