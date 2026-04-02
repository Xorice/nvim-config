local dap    = require("dap")
local dapui  = require("dapui")

dapui.setup()
require("nvim-dap-virtual-text").setup()

require("mason-nvim-dap").setup {
    ensure_installed      = { "codelldb", "python" },
    automatic_installation = true,
    handlers = {
        function(config)
            require('mason-nvim-dap').default_setup(config)
        end,
    },
}

-- 调试 UI 自动开关
dap.listeners.after.event_initialized["dapui_config"]  = function() dapui.open()  end
dap.listeners.before.event_terminated["dapui_config"]  = function() dapui.close() end
dap.listeners.before.event_exited["dapui_config"]      = function() dapui.close() end

-- 断点图标
vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DapBreakpoint", linehl = "", numhl = "" })
vim.api.nvim_set_hl(0, "DapBreakpoint", { fg = "#f38ba8" })
