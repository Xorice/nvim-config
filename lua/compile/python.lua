-- lua/compile/python.lua
return {
    enabled = true,
    ext     = { 'py' },
    compile = nil,  -- 解释型，无编译步骤
    run = function(file, _)
        return { require('platform').python(file) or 'python3', file }
    end,
}
