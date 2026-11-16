param([switch]$Check)
$ErrorActionPreference = 'Stop'

function Add-ToolPath([string]$ToolPath) {
    if ($ToolPath -and (Test-Path -LiteralPath $ToolPath)) {
        if (($env:Path -split ';') -notcontains $ToolPath) { $env:Path += ';' + $ToolPath }
    }
}

function Refresh-ToolPath {
    foreach ($scope in @('Machine', 'User')) {
        foreach ($entry in ([Environment]::GetEnvironmentVariable('Path', $scope) -split ';')) {
            Add-ToolPath ([Environment]::ExpandEnvironmentVariables($entry))
        }
    }
    Add-ToolPath "$env:LOCALAPPDATA\Microsoft\WinGet\Links"
    Add-ToolPath "$env:ProgramFiles\7-Zip"
    Add-ToolPath "$env:ProgramFiles\nodejs"
    $gitCommand = Get-Command git.exe -ErrorAction SilentlyContinue
    if ($gitCommand) { Add-ToolPath (Join-Path (Split-Path (Split-Path $gitCommand.Source)) 'usr\bin') }
    $packageRoot = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages"
    if (Test-Path -LiteralPath $packageRoot) {
        Get-ChildItem -LiteralPath $packageRoot -Directory -Filter 'BrechtSanders.WinLibs*' |
            ForEach-Object { Add-ToolPath (Join-Path $_.FullName 'mingw64\bin') }
    }
    if (Get-Command py.exe -ErrorAction SilentlyContinue) {
        try {
            $nativePython = & py.exe -3 -c 'import sys; print(sys.executable)' 2>$null
            if ($LASTEXITCODE -eq 0) {
                $pythonDirectory = Split-Path ($nativePython | Select-Object -Last 1)
                $env:Path = $pythonDirectory + ';' + $env:Path
            }
        } catch { Write-Verbose 'Python Launcher has no usable runtime yet.' }
    }
}

function Has-Tool([string[]]$Names) {
    foreach ($toolName in $Names) {
        if (Get-Command $toolName -CommandType Application -ErrorAction SilentlyContinue) { return $true }
    }
    return $false
}

Refresh-ToolPath
$requirements = @(
    @{ Names = @('git.exe'); Id = 'Git.Git' },
    @{ Names = @('gzip.exe'); Id = 'Git.Git' },
    @{ Names = @('curl.exe'); Id = 'cURL.cURL' },
    @{ Names = @('tar.exe'); Id = 'Git.Git' },
    @{ Names = @('node.exe'); Id = 'OpenJS.NodeJS.LTS' },
    @{ Names = @('npm.cmd'); Id = 'OpenJS.NodeJS.LTS' },
    @{ Names = @('python.exe'); Id = 'Python.Python.3.12' },
    @{ Names = @('gcc.exe', 'clang.exe'); Id = 'BrechtSanders.WinLibs.POSIX.UCRT' },
    @{ Names = @('g++.exe', 'clang++.exe'); Id = 'BrechtSanders.WinLibs.POSIX.UCRT' },
    @{ Names = @('rg.exe'); Id = 'BurntSushi.ripgrep.MSVC' },
    @{ Names = @('fd.exe'); Id = 'sharkdp.fd' },
    @{ Names = @('7z.exe', '7za.exe'); Id = '7zip.7zip' }
)
$missing = @($requirements | Where-Object { -not (Has-Tool $_.Names) } | Select-Object -ExpandProperty Id -Unique)
if (Has-Tool @('python.exe')) {
    & python.exe -c "import importlib.util, sys; sys.exit(0 if all(importlib.util.find_spec(m) for m in ('venv', 'ensurepip')) else 1)"
    if ($LASTEXITCODE -ne 0) { $missing += 'Python.Python.3.12' }
}
$missing = @($missing | Select-Object -Unique)
if ($missing.Count -eq 0) { Write-Output 'All system dependencies are available.'; exit 0 }
Write-Output ('Missing dependencies (winget): ' + ($missing -join ', '))
if ($Check) { exit 0 }
if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
    throw 'winget is required. Install Microsoft App Installer, then rerun :BootstrapDeps.'
}
foreach ($packageId in $missing) {
    & winget.exe install --id $packageId --exact --source winget --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
    if ($LASTEXITCODE -ne 0) { throw "winget failed for $packageId (exit $LASTEXITCODE). Fix the error above and rerun :BootstrapDeps." }
    Refresh-ToolPath
}
$unavailable = @($requirements | Where-Object { -not (Has-Tool $_.Names) })
if ($unavailable.Count -gt 0) {
    throw ('Installation completed but tools are still missing from PATH: ' + (($unavailable | ForEach-Object { $_.Names -join '/' }) -join ', ') + '. Open a new terminal and rerun the script.')
}
& python.exe -c 'import venv, ensurepip'
if ($LASTEXITCODE -ne 0) { throw 'Python venv/ensurepip is unavailable. Select a standard CPython installation and rerun the script.' }
Write-Output 'System dependencies installed. Restart Neovim to load the updated PATH and install language tools.'
