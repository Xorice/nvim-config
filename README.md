# 🍞 面包 NVIM (Nightly 0.12.x)

面包人专用 nvim 配置文件（大概

## ✨ 特性

- **Core**: Neovim 0.12 Nightly
- **AI**: Codeium (Free & Fast)
- **LSP**: Mason + Blink.cmp 
- **UI**: Catppuccin Mocha + Lualine + Smear Cursor
- **Debug**: DAP (C++/Python) ready

## 🚀 快速安装

```bash
git clone https://github.com/Xorice/nvim-config ~/.config/nvim
nvim
```

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
