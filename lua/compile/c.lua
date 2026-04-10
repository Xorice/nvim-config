-- lua/compile/c.lua
return {
    enabled = true,
    ext     = { 'c' },
    compile = function(file, out)
        return string.format('gcc "%s" -o "%s" -g', file, out)
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
