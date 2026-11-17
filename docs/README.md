# 开场动画与预览 GIF

[返回主 README](../README.md) · [详细使用与排障](usage.md)

## 文件位置

| 文件 | 用途 |
| --- | --- |
| [lua/bread/startup.lua](../lua/bread/startup.lua) | Neovim 实际使用的开场动画与分阶段初始化 |
| [readme-preview.gif](readme-preview.gif) | 主 README 引用的循环预览图 |
| [render-preview.py](render-preview.py) | 字体查找、Neovim 字符网格采集和 GIF 编码 |
| [render-preview.lua](render-preview.lua) | 在独立 Neovim 中搭建文件树、Luau 示例和状态栏 |

运行时动画就绪后立即关闭，LSP 和后台工具安装继续通过状态栏报告进度。动画在初始化步骤之间补帧，空闲时目标约 60 FPS；单个同步系统调用执行期间仍可能短暂停顿。

## 复现预览图

先按主 README 完成配置安装，确认主题、Neo-tree、lualine、gitsigns、图标依赖和 **Luau 解析器** 已安装。导出器只使用已安装的资源，不会自动下载插件、编译解析器或启动语言服务。

需要：

- PATH 中的 Neovim 0.12+、Git。
- Python 3.11+ 和 [uv](https://docs.astral.sh/uv/)。Python 依赖与版本固定在脚本开头，uv 会建立独立环境。
- 本机安装的 **0xProto Nerd Font Mono**，或通过 `--font` 指定其他覆盖所需图标的 Nerd Font。

在仓库根目录运行，Windows PowerShell 和 Linux shell 使用同一条命令：

```sh
uv run docs/render-preview.py
```

默认输出 `docs/readme-preview.gif`。脚本自动查找常见的 Windows 用户/系统字体目录、Linux 字体目录和 macOS 字体目录；也可以手动指定路径：

```sh
uv run docs/render-preview.py --font "/path/to/0xProtoNerdFontMono-Regular.ttf"
uv run docs/render-preview.py --nvim "/path/to/nvim" --output "/path/to/preview.gif"
uv run docs/render-preview.py --help
```

Windows 字体路径含空格时加引号。例如：

```powershell
uv run docs/render-preview.py --font "$env:LOCALAPPDATA\Microsoft\Windows\Fonts\0xProtoNerdFontMono-Regular.ttf"
```

没有 uv 时，可在自己的 Python 虚拟环境中安装以下依赖，再执行脚本：

```sh
python -m pip install pynvim==0.6.0 Pillow==12.2.0 fonttools==4.63.0
python docs/render-preview.py --font "/path/to/YourNerdFont.ttf"
```

## 导出过程

脚本在临时目录创建一个 Roblox/Rojo 示例项目和本地 Git 仓库，用实际改动生成 Git 分支及 diff 状态；不会修改当前仓库的 Git 配置、索引或提交。示例保留 Lua 的表参数调用语法：

```lua
greet { name = "bread" }
```

随后启动独立的 `nvim -u NONE`，复用仓库的立方体绘制代码、已安装的主题、Neo-tree、Tree-sitter 和 lualine，读取 Neovim 合成后的完整字符网格与高亮颜色。文件树只保留局部元素，不显示路径或窗口分割线；预览图不含开场进度条。

底部 `Workspace loading` 是循环展示状态，不表示某个真实语言服务一直在索引。`roblox` 类型来自示例项目识别，Git 分支和改动来自临时仓库。

输出为 **1200 × 672、120 帧、50 FPS、2.4 秒**的无限循环 GIF。只在导出进程内把俯仰转速比例从 `0.55` 调整到 `0.5`，使两次水平旋转与一次俯仰旋转正好闭合；不会修改实际开场动画。脚本验证首尾画面一致、字符覆盖和 GIF 帧数后，才替换输出文件。

## 字体与差异

默认字体使用本机的 0xProto Nerd Font Mono，其许可为 [SIL OFL 1.1](https://github.com/0xType/0xProto/blob/main/LICENSE)；Nerd Fonts 版本的许可信息见[官方字体清单](https://github.com/ryanoasis/nerd-fonts/blob/master/bin/scripts/lib/fonts.json)。脚本不会把字体文件打包进仓库。

可选的 `--bold-font` 指定粗体，`--fallback-font` 指定补字字体。默认会尝试本机的 Source Han Sans SC。旧版 0xProto 缺少盲文字形时，脚本直接绘制 Neovim 输出的 Unicode 八点掩码，不使用系统专有字体补字。

不同字体、Neovim、插件和解析器版本可能使字形、颜色或图标细节有所差异。如果运行时动画的内部接口发生变化，导出器会报错提示更新 Lua 场景脚本，而不是继续生成不完整的图片。

## 常见问题

- **找不到字体**：传入 `--font` 的实际 TTF/OTF 路径；缺字时更换覆盖所需 Nerd 图标的字体，或指定开源补字字体。
- **Missing plugin / Luau parser is not available**：先正常打开本配置并完成安装；解析器安装失败时运行 `:InstallTools`，详细排障见 [usage.md](usage.md)。
- **使用了其他 Neovim 数据目录**：导出时保持正常使用本配置时相同的 `NVIM_APPNAME` 等环境设置，以便找到已安装的插件和解析器。
- **Git decorations did not become ready**：确认 Git 可运行；导出器使用临时仓库和命令级身份设置，不需要配置全局 Git 作者或签名。
