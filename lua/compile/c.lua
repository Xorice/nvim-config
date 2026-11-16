-- lua/compile/c.lua
return {
    enabled = true,
    ext     = { 'c' },
    compile = function(file, out)
        local compiler = require('platform').find({ 'gcc', 'clang', 'cc' }) or 'gcc'
        return { compiler, file, '-o', out, '-g' }
    end,
    run = function(_, out)
        return { out }
    end,
    link_map = require('platform').windows and {} or {
        ['math.h']       = '-lm',
        ['pthread.h']    = '-lpthread',
        ['GL/gl.h']      = '-lGL',
        ['GLFW/glfw3.h'] = '-lglfw',
        ['GL/glew.h']    = '-lGLEW',
    },
}
