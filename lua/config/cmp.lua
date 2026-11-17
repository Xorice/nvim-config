local sources = { "lsp", "path", "snippets", "buffer" }
-- Codeium uses gzip even on Windows. Basic completion remains available without it.
vim.g.bread_codeium_enabled = vim.env.NVIM_NO_AI ~= '1'
    and vim.fn.executable('gzip') == 1 and vim.fn.executable('curl') == 1
if vim.g.bread_codeium_enabled then
    -- Plenary's mixed-separator log path can fail to create this on Windows.
    vim.fn.mkdir(vim.fs.joinpath(vim.fn.stdpath('log'), 'codeium'), 'p')
    -- The pinned Codeium downloader omits plenary's on_error handler, so a
    -- failed curl job otherwise throws from an asynchronous Lua callback.
    require('codeium.io').download = function(url, path, callback)
        return require('plenary.curl').get(url, {
            output = path,
            compressed = false,
            raw = { '--retry', '2', '--retry-all-errors', '--connect-timeout', '10', '--max-time', '60' },
            on_error = vim.schedule_wrap(function(err)
                callback(nil, err.message)
            end),
            callback = vim.schedule_wrap(function(out)
                if out.status < 200 or out.status > 399 then
                    callback(out, 'http response ' .. out.status)
                else
                    callback(out, nil)
                end
            end),
        })
    end
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
