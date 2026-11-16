local M = { windows = vim.fn.has('win32') == 1 }

function M.find(names)
    for _, name in ipairs(names) do
        if vim.fn.executable(name) == 1 then return vim.fn.exepath(name) end
    end
end

function M.add_path(path, prepend)
    if not path or vim.fn.isdirectory(path) == 0 then return end
    local separator = M.windows and ';' or ':'
    local paths = vim.split(vim.env.PATH or '', separator, { plain = true })
    if vim.tbl_contains(paths, path) then return end
    if prepend then table.insert(paths, 1, path) else table.insert(paths, path) end
    vim.env.PATH = table.concat(paths, separator)
end

function M.setup()
    if not M.windows then return end
    -- Git for Windows ships gzip, tar and other tools outside Git/cmd.
    local git = M.find({ 'git' })
    if git then
        local root = vim.fs.dirname(vim.fs.dirname(git))
        M.add_path(vim.fs.joinpath(root, 'usr', 'bin'))
    end
    if vim.env.LOCALAPPDATA then
        M.add_path(vim.fs.joinpath(vim.env.LOCALAPPDATA, 'Programs', 'Git', 'cmd'))
        M.add_path(vim.fs.joinpath(vim.env.LOCALAPPDATA, 'Programs', 'Git', 'usr', 'bin'))
    end
    if vim.env.ProgramFiles then
        M.add_path(vim.fs.joinpath(vim.env.ProgramFiles, 'Git', 'cmd'))
        M.add_path(vim.fs.joinpath(vim.env.ProgramFiles, 'Git', 'usr', 'bin'))
        M.add_path(vim.fs.joinpath(vim.env.ProgramFiles, '7-Zip'))
        M.add_path(vim.fs.joinpath(vim.env.ProgramFiles, 'nodejs'))
    end
    if vim.env.LOCALAPPDATA then
        local winget = vim.fs.joinpath(vim.env.LOCALAPPDATA, 'Microsoft', 'WinGet')
        M.add_path(vim.fs.joinpath(winget, 'Links'))
        for _, bin in ipairs(vim.fn.glob(winget .. '/Packages/BrechtSanders.WinLibs*/mingw64/bin', false, true)) do
            M.add_path(bin)
        end
        local pythons = vim.fn.glob(vim.env.LOCALAPPDATA .. '/Programs/Python/Python3*/python.exe', false, true)
        table.sort(pythons)
        if #pythons > 0 then M.add_path(vim.fs.dirname(pythons[#pythons]), true) end
    end
    -- Prefer native CPython over MSYS Python for Mason's Windows venv layout.
    if M.find({ 'py' }) then
        local result = vim.system({ 'py', '-3', '-c', 'import sys; print(sys.executable)' }, { text = true }):wait(5000)
        if result.code == 0 then M.add_path(vim.fs.dirname(vim.trim(result.stdout)), true) end
    end
end

function M.python()
    local root = vim.env.VIRTUAL_ENV or vim.fs.joinpath(vim.fn.getcwd(), '.venv')
    local executable = vim.fs.joinpath(root, M.windows and 'Scripts/python.exe' or 'bin/python')
    if vim.fn.executable(executable) == 1 then return executable end
    return M.find(M.windows and { 'python', 'python3' } or { 'python3', 'python' })
end

return M
