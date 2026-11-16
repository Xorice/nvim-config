# 🍞 面包 NVIM (Nightly 0.12.x)

面包人专用 nvim 配置文件（大概

## ✨ 特性

- **Core**: Neovim 0.12 Nightly
- **AI**: Codeium (Free & Fast)
- **LSP**: Mason + Blink.cmp 
- **UI**: VS Code Dark 2026（透明背景）+ Lualine + Smear Cursor
- **Debug**: DAP (C++/Python)
- **Bootstrap**: Windows / Linux 系统依赖引导，自动安装语言工具及语法解析器

主题使用 [dark-2026.nvim](https://github.com/boonyarit-iamsaard/dark-2026.nvim)。`lua/config/theme.lua` 中的 `transparent = true` 让编辑区和文件树透出终端背景，浮窗和补全菜单保留底色；改为 `false` 可恢复主题实色背景。窗口是否半透明、是否显示桌面，由终端自身的透明度设置决定。

## 🚀 快速安装

入口要求：**Git、Neovim 0.12+（含 `vim.pack`）和可访问 GitHub 的网络**。目前保留原配置的 Nightly 版本要求，不支持直接使用 0.11。

Windows（PowerShell）：

```powershell
git clone https://github.com/Xorice/nvim-config "$env:LOCALAPPDATA\nvim"
nvim
```

Linux：

```bash
git clone https://github.com/Xorice/nvim-config "${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
nvim
```

已有配置仓库直接 `git pull` 后打开 `nvim`。

首次启动会检查基础工具。缺少时，自动打开安装终端：Windows 使用系统自带的 **WinGet**；Linux 支持 **apt / dnf / pacman**，需要时在终端输入 sudo 密码。安装完成后重新打开 Neovim，继续自动下载插件、LSP、调试器、Tree-sitter CLI 和解析器。等待 `:Mason` 中的安装完成即可；以后启动会跳过已经安装的工具。系统安装只自动尝试一次，失败后修复原因并运行 `:BootstrapDeps` 重试。

自动安装范围：

| 层级 | 内容 |
|------|------|
| 系统工具 | Git / gzip、curl、tar、解压工具、Node.js / npm、Python / venv、C/C++ 编译器、ripgrep、fd |
| 语言工具 | lua-language-server、clangd、pyright、luau-lsp、codelldb、debugpy、Tree-sitter CLI |
| 语法解析器 | Lua、Luau、C、C++、Python、Markdown、Vim、vimdoc、query |

已有工具会优先复用。Windows 自动发现 Git 自带的 gzip、7-Zip 和 WinGet 安装的 WinLibs；如果有 Python Launcher，优先使用标准 CPython，避免 MSYS Python 的 venv 路径差异。Lua 文件运行优先使用 lua/luajit，没有独立解释器时使用 Neovim 自带 LuaJIT（`nvim --clean -l`）。

**仍需自行设置的可选功能**：终端字体选择 Nerd Font；AI 首次使用运行 `:Codeium Auth` 登录；LÖVE 游戏引擎和 Rojo 按项目需要安装并加入 PATH。没有 Rojo 时保留 Luau 语言服务，关闭自动生成 sourcemap。项目自身的第三方库与构建环境仍由项目管理。

### 检查和修复

```vim
:checkhealth bread
:BootstrapDeps
:InstallTools
:Mason
:MasonLog
```

`BootstrapDeps` 补系统工具；`InstallTools` 补语言工具和解析器。网络或权限错误会显示在安装终端 / Mason 日志中，不会标记为安装成功。

也可以先在外部终端执行安装脚本（不需要启动 Neovim）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/bootstrap.ps1
# 仅查看缺失依赖，不安装
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/bootstrap.ps1 -Check
```

```bash
bash scripts/bootstrap.sh
bash scripts/bootstrap.sh --check
```

插件版本由仓库内的 `nvim-pack-lock.json` 固定。主动更新插件使用 `:lua vim.pack.update()`，审阅并保存更新窗口；随后执行 `:TSUpdate` 更新解析器，并一并提交锁文件。

### 无界面验证

已有插件安装完成后，可以禁用后台下载运行冒烟检查（启动、状态栏、调试配置，以及带空格和 `&` 路径的 C/C++/Python/Lua 编译运行）。Windows 无界面 ConPTY 的输出直接写到父终端，因此测试通过管道捕获同一组真实进程。

```powershell
$env:NVIM_NO_INSTALL = '1'
$env:NVIM_NO_BOOTSTRAP = '1'
$env:NVIM_NO_AI = '1'
nvim --headless '+luafile scripts/smoke.lua'
Remove-Item Env:NVIM_NO_INSTALL, Env:NVIM_NO_BOOTSTRAP, Env:NVIM_NO_AI
```

```bash
NVIM_NO_INSTALL=1 NVIM_NO_BOOTSTRAP=1 NVIM_NO_AI=1 nvim --headless '+luafile scripts/smoke.lua'
```

这三个环境变量分别禁用语言工具自动下载、系统依赖自动安装和 AI；正常使用无需设置。Windows 已实际运行验证；Linux 安装脚本仍需要在对应发行版上验证。

## ⌨️ 按键绑定
 
**Leader**: `,`
 
### 文件 & 搜索
 
| 按键 | 功能 |
|------|------|
| `,e` | 切换文件树 (Neo-tree) |
| `Ctrl+P` | 模糊查找文件 (Telescope) |
| `,gs` | 浮动显示 Git 状态 |
| `,m` | 切换 Markdown 预览 |
 
### 编译 & 调试
 
| 按键 | 功能 |
|------|------|
| `,rc` | 编译并运行当前文件 |
| `,r` | DAP 开始 / 继续调试 |
| `,b` | 切换断点 |
| `,di` | Step Into |
| `,do` | Step Over |
| `,du` | 切换调试 UI |
| `,dq` | 终止调试 |
 
### 编辑
 
| 按键 | 功能 |
|------|------|
| `Alt+]` | 增加缩进 |
| `Alt+[` | 减少缩进 |
| `Alt+J` | 当前行下移 |
| `Alt+K` | 当前行上移 |
| `Ctrl+S` | 保存 |
| `Shift+方向键` | 进入 / 扩展 Visual 选区 |
| `Ctrl+H/L` | 按单词跳转 |
| `Ctrl+/` | 注释 / 取消注释 |
 
### 折叠
 
| 按键 | 功能 |
|------|------|
| `zR` | 展开所有折叠 |
| `zM` | 折叠所有 |
 
### AI 补全 (Codeium)
 
| 按键 | 功能 |
|------|------|
| `Ctrl+F` | 接受当前建议 |
| `Alt+n` | 下一条建议 |
| `Alt+p` | 上一条建议 |
 
### Love2D
 
| 按键 | 功能 |
|------|------|
| `,lr` | 运行 LÖVE 项目 |
 
## 🔧 支持的语言
 
| 语言 | LSP | 调试 | 编译运行 |
|------|-----|------| -------|
| C / C++ | clangd | codelldb ✅ | ✅  |
| Python | pyright | debugpy ✅ | ✅  |
| Lua | lua_ls | — | ✅  |
| Luau | luau-lsp | — | ❌ |
