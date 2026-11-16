require('dependencies').setup()
local caps = require("blink.cmp").get_lsp_capabilities()

require('project_lsp').setup(caps)

vim.lsp.config("clangd", { capabilities = caps })
vim.lsp.config("pyright", { capabilities = caps })
vim.lsp.enable({ "clangd", "pyright" })

local function hover_window()
    local win = vim.b.lsp_floating_preview
    if win and vim.api.nvim_win_is_valid(win)
        and vim.w[win]['textDocument/hover'] == vim.api.nvim_get_current_buf() then return win end
end

vim.api.nvim_create_autocmd('LspAttach', {
    group = vim.api.nvim_create_augroup('BreadLspDocumentation', { clear = true }),
    callback = function(event)
        local client = vim.lsp.get_client_by_id(event.data.client_id)
        if not client or not client:supports_method('textDocument/hover', event.buf) then return end
        vim.keymap.set('n', 'K', function()
            local win = hover_window()
            if win then vim.api.nvim_set_current_win(win)
            else vim.lsp.buf.hover() end
        end, { buffer = event.buf, desc = 'Show / Focus Documentation' })
        for _, key in ipairs({ '<C-d>', '<C-u>' }) do
            local scroll = vim.api.nvim_replace_termcodes(key, true, false, true)
            vim.keymap.set('n', key, function()
                local count = vim.v.count > 0 and tostring(vim.v.count) or ''
                local command = function() vim.cmd.normal({ args = { count .. scroll }, bang = true }) end
                local win = hover_window()
                if win then vim.api.nvim_win_call(win, command)
                else command() end
            end, { buffer = event.buf, desc = 'Scroll Documentation or Buffer' })
        end
    end,
})

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
