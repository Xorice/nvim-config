-- lua/compile/lua.lua
return {
    enabled = true,
    ext     = { 'lua' },
    compile = nil,
    run = function(file, _)
        local lua = require('platform').find({ 'lua', 'luajit' })
        if lua then return { lua, file } end
        return { vim.v.progpath, '--clean', '-l', file }
    end,
}
