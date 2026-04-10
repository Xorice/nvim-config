-- lua/compile/lua.lua
return {
    enabled = true,
    ext     = { 'lua' },
    compile = nil,
    run = function(file, _)
        return string.format('lua "%s"', file)
    end,
}
