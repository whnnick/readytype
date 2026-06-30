# 故障排查

## macOS 提示无法验证开发者

ReadyType 1.0.0 目前未签名、未公证。

1. 将 `ReadyType.app` 拖到 Applications。
2. 右键点击 `ReadyType.app`。
3. 选择“打开”。
4. 在 macOS 弹窗里再次确认“打开”。

不要关闭 macOS 系统安全设置。

## ReadyType 已打开，但快捷键没有反应

ReadyType 默认使用双击 `Option`。

请检查：

- ReadyType 正在菜单栏运行。
- 你是在双击 `Option`，不是一直按住。
- 已在 `系统设置 -> 隐私与安全性 -> 辅助功能` 中授权 ReadyType。

如果快捷键在 ReadyType 窗口里有效、但在其他 App 里无效，通常是缺少辅助功能权限。

## 无法开始听写

请检查：

- ReadyType 已获得麦克风权限。
- ReadyType 已获得语音识别权限。
- 没有其他 App 独占麦克风。

可以在 ReadyType 的权限页和 macOS 系统设置中检查这些权限。

## 没有自动粘贴文字

ReadyType 会先尝试把文字写入当前输入框。如果失败，会把结果复制到剪贴板。

请检查：

- 开始说话前，光标已经在输入框里。
- ReadyType 已获得辅助功能权限。
- 如果 macOS 询问是否允许 ReadyType 控制 `System Events`，请选择允许。
- 如果没有出现文字，可以尝试 `Command + V`；结果可能已经复制到剪贴板。

部分 App 的输入机制比较特殊，少数情况下复制降级是预期行为。

## DeepSeek 输出不可用

`直接转文字` 不使用 DeepSeek。`整理成文`、`翻译成英文` 和 `写给 AI` 会使用 DeepSeek。

请检查：

- 已在 ReadyType 设置中保存 DeepSeek 密钥。
- 服务地址可以访问。
- 模型名称适用于你的 DeepSeek 账号。
- 修改密钥、服务地址或模型后，点击设置里的“测试连接”。

ReadyType 会把密钥存储在 macOS 钥匙串。

## 高精度语音包尚未准备好

高精度语音包缺失或尚未准备好时，极速识别仍然可用。

高精度语音包：

- 适合长文本、中英混说和术语较多的内容；
- 下载和准备可能需要一些时间；
- 可以在设置中删除并重新下载；
- 保存在 `~/Library/Application Support/ReadyType/Models/`。

如果它还在准备中，可以继续正常使用 ReadyType。ReadyType 会先使用极速识别，并在高精度语音包准备好且适合当前内容时自动使用。

## 识别或输出效果不对

请通过 GitHub Issues 反馈：

https://github.com/whnnick/readytype/issues

建议提供：

- ReadyType 版本
- macOS 版本
- 使用 ReadyType 的 App
- 输出方式
- 识别方式
- 你说了什么
- ReadyType 输出了什么
- 你期望的结果

提交前请删除 API Key、私人聊天、私人邮件和敏感业务内容。
