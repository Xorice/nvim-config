local M = { windows = vim.fn.has('win32') == 1 }

function M.find(names)
    for _, name in ipairs(names) do
        local path = vim.fn.exepath(name)
        if path ~= '' then return path end
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
        local pythons = {}
        for _, pattern in ipairs({ vim.env.LOCALAPPDATA .. '/Programs/Python/Python3*/python.exe',
            vim.env.LOCALAPPDATA .. '/Python/pythoncore-3.*/python.exe',
            (vim.env.ProgramFiles or '') .. '/Python3*/python.exe' }) do
            vim.list_extend(pythons, vim.fn.glob(pattern, false, true))
        end
        local function minor(path)
            return tonumber(path:match('pythoncore%-3%.(%d+)') or path:match('Python3(%d+)')) or 0
        end
        table.sort(pythons, function(a, b)
            if minor(a) == minor(b) then return a < b end
            return minor(a) < minor(b)
        end)
        if #pythons > 0 then M.add_path(vim.fs.dirname(pythons[#pythons]), true) end
    end
end

function M.python(file)
    local suffix = M.windows and 'Scripts/python.exe' or 'bin/python'
    for _, root in ipairs({ vim.env.VIRTUAL_ENV or '', vim.env.CONDA_PREFIX or '' }) do
        if root ~= '' then
            local executable = vim.fs.joinpath(root, suffix)
            if vim.fn.executable(executable) == 1 then return executable end
            -- Conda uses python.exe directly on Windows.
            executable = vim.fs.joinpath(root, M.windows and 'python.exe' or 'bin/python')
            if vim.fn.executable(executable) == 1 then return executable end
        end
    end
    local path = file and file ~= '' and vim.fs.dirname(vim.fn.fnamemodify(file, ':p')) or vim.fn.getcwd()
    for root in vim.fs.parents(vim.fs.joinpath(path, '_')) do
        local executable = vim.fs.joinpath(root, '.venv', suffix)
        if vim.fn.executable(executable) == 1 then return executable end
        if vim.uv.fs_stat(vim.fs.joinpath(root, '.git')) then break end
    end
    return M.find(M.windows and { 'python', 'python3' } or { 'python3', 'python' })
end

return M
