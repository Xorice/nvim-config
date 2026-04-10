-- lua/compile/python.lua
return {
    enabled = true,
    ext     = { 'py' },
    compile = nil,  -- 解释型，无编译步骤
    run = function(file, _)
        return string.format('python "%s"', file)
    end,
}
