-- lua/compile/cpp.lua
return {
    enabled = true,
    ext     = { 'cpp', 'cc', 'cxx' },
    compile = function(file, out)
        return string.format('g++ "%s" -o "%s" -g', file, out)
    end,
    run = function(_, out)
        return string.format('"%s"', out)
    end,
    link_map = {
        ['math.h']       = '-lm',
        ['pthread.h']    = '-lpthread',
        ['GL/gl.h']      = '-lGL',
        ['GLFW/glfw3.h'] = '-lglfw',
        ['GL/glew.h']    = '-lGLEW',
    },
}
