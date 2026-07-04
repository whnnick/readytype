<p align="center">
  简体中文 | <a href="./README.md">English</a>
</p>

<h1 align="center">ReadyType</h1>

<p align="center">
  中文优先的 macOS 语音输入工具：直接转文字、整理成文、翻译成英文，或整理成适合发给 AI 的任务说明。
</p>

<p align="center">
  AI 输出默认调用 DeepSeek V4 Flash；按当前官方 API 价格和日常语音输入用量估算，通常爽用一天不到 1 毛钱。
</p>

<p align="center">
  <img alt="Platform" src="https://img.shields.io/badge/platform-macOS%2014%2B-blue">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-6.0-orange">
  <img alt="Version" src="https://img.shields.io/badge/version-1.0.0-green">
  <img alt="License" src="https://img.shields.io/badge/license-MIT-lightgrey">
</p>

## 它能做什么

ReadyType 让你双击 `Option`，自然说话，然后把结果输出到当前输入框。

- `直接转文字`：按你说的直接变成文字，不调用 DeepSeek。
- `整理成文`：把口语、停顿和零散表达整理成更适合发送或保存的文本。
- `翻译成英文`：把中文口述输出成自然英文。
- `写给 AI`：把口述意图整理成清楚的任务说明，适合发给 AI 工具。
- `自动选择`：短句优先速度，高精度语音包准备好且适合当前内容时自动提高准确率。

## 成本很低

ReadyType 的 AI 输出默认调用 `deepseek-v4-flash`。DeepSeek 当前官方价格为输入 $0.14 / 100 万 tokens、输出 $0.28 / 100 万 tokens；按日常语音整理、翻译和写给 AI 的轻量用量估算，通常一天不到 1 毛钱。实际费用取决于你的使用量和 DeepSeek 官方价格变化。

## 下载

从 GitHub Releases 下载最新版 `ReadyType.dmg`。

当前版本未签名、未公证。首次打开时，macOS 可能提示无法验证开发者。请在 Applications 中右键 `ReadyType.app`，选择“打开”，再确认“打开”。

不要关闭 macOS 系统安全设置。

## 反馈问题

安装、权限、快捷键、粘贴、识别准确率和输出语气问题，请通过 [GitHub Issues](https://github.com/whnnick/readytype/issues) 反馈。提交前请删除 API Key、私人聊天、私人邮件和敏感业务内容。

如果 ReadyType 无法打开、无法开始听写、无法粘贴或无法连接 DeepSeek，请先查看 [故障排查](./docs/TROUBLESHOOTING.zh-CN.md)。

第一次试用可以参考 [测试说明](./docs/TESTING.zh-CN.md)，也可以直接使用 [测试邀请文案](./docs/TESTER_INVITE.zh-CN.md)。后续功能计划见 [Roadmap](./docs/ROADMAP.zh-CN.md) 和 [ReadyType 1.1.0](./docs/versions/1.1.0/README.zh-CN.md)。

## 使用要求

- macOS 14 或更高版本
- 本地构建需要 Xcode command line tools
- 整理成文、翻译成英文和写给 AI 需要 DeepSeek 密钥
- 需要授权麦克风、语音识别和辅助功能

语音识别本身不需要额外填写云端语音 API 密钥。

## 使用方式

1. 打开 ReadyType。
2. 在设置中填写 DeepSeek 密钥。密钥会存入 macOS 钥匙串。
3. 选择输出方式。
4. 把光标放到任意输入框。
5. 双击 `Option` 开始说话。
6. 再次双击 `Option` 完成并输出。
7. 语音输入中按 `Esc` 取消。

如果无法自动粘贴，ReadyType 会把结果复制到剪贴板。

## 从源码构建

运行测试：

```bash
swift test
```

构建应用：

```bash
./scripts/build-app.sh
```

打包 zip：

```bash
./scripts/package-app.sh
```

打包 DMG：

```bash
./scripts/package-dmg.sh
```

生成的文件会放在 `dist/`。

## 隐私说明

- DeepSeek 密钥存储在 macOS 钥匙串。
- 不保存完整转写历史。
- `直接转文字` 不调用 DeepSeek。
- AI 输出方式会把当前文本发送给 DeepSeek 处理。
- 高精度语音包保存在 `~/Library/Application Support/ReadyType/Models/`。

## 开源协议

ReadyType 使用 MIT License 开源，详见 [LICENSE](./LICENSE)。
