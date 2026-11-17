# 🍞 面包 NVIM (Nightly)

面向 Lua / LÖVE / Roblox，以及 C/C++、Python 的 Neovim 配置，支持 Windows / Linux。

![面包 NVIM 预览](docs/readme-preview.gif)

## 主要特性

- 自动识别普通 Lua、LÖVE、独立 Luau 和 Roblox 项目，分别提供对应的 API 提示。
- LSP、补全和语法高亮；支持 C/C++、Python 编译运行与调试，以及 Lua / LÖVE 运行。
- Dark 2026 透明主题、文件树、项目搜索、Git 标记和状态栏。
- Mason 自动安装语言工具，状态栏显示后台安装与工作区加载进度。
- 可选 Codeium AI 补全，持久撤销和外部文件修改自动重载。

## 安装

需要 **Git、Neovim 0.12+（含 `vim.pack`）和可访问 GitHub 的网络**。

Windows PowerShell：

```powershell
git clone https://github.com/Xorice/nvim-config "$env:LOCALAPPDATA\nvim"
nvim
```

Linux：

```sh
git clone https://github.com/Xorice/nvim-config "${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
nvim
```

首次启动按提示安装缺失的系统依赖，完成后重启，继续安装插件、语言工具和解析器。`:Mason` 查看语言工具安装状态。已有配置更新后重启 Neovim 即可。

终端请使用 Nerd Font 显示图标。AI 首次使用运行 `:Codeium Auth` 登录；LÖVE 和 Rojo 按项目需要自行安装并加入 PATH。

## 常用操作

**Leader 为 `,`**。

| 按键 | 功能 |
| --- | --- |
| `,e` | 切换文件树 |
| `Ctrl+P` | 查找项目文件 |
| `,fg` / `,fw` | 项目全文搜索 / 搜索当前单词 |
| `Ctrl+S` | 保存 |
| `gcc` / `gc` | 注释当前行 / 选区 |
| `K` | 查看说明，再按一次进入说明窗口 |
| `Tab` / `Enter` | 接受补全；没有候选时使用原按键行为 |
| `Ctrl+F` | 接受 AI 建议 |
| `,cf` | 手动格式化当前文件 |
| `,rc` / `,rs` / `,ro` | 运行 / 停止 / 查看运行输出 |
| `,lr` | 运行 LÖVE 项目 |
| `,r` / `,b` | 开始或继续调试 / 切换断点 |
| `,di` / `,do` | 调试进入 / 步过 |
| `,du` / `,dq` | 切换调试界面 / 结束调试 |
| `,gs` / `,m` | Git 状态 / Markdown 预览 |
| `zR` / `zM` | 展开 / 折叠全部 |

Lua 项目通常自动识别，`:LuaProjectInfo` 查看当前环境。需要初始化时使用 `:LuaProjectInit love` 等命令，支持 `lua`、`love`、`luau`、`roblox`；已有配置不会覆盖。Roblox 代码在 Studio 中运行，编辑器负责提示与 sourcemap。

## 检查与维护

```vim
:checkhealth bread
:BootstrapDeps
:InstallTools
:Mason
:MasonLog
```

`BootstrapDeps` 补系统依赖，`InstallTools` 重试语言工具和解析器安装，`UpdateTools` 主动更新语言工具。插件更新、完整快捷键、项目环境和网络排障见[详细使用说明](docs/usage.md)。

[预览图复现](docs/README.md)
