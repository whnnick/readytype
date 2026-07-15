# ReadyType 1.3.0 黑盒功能检查

最后更新：2026-07-15。当前验收构建仍标识为 `1.2.0 (86)`，尚未进入 1.3.0 发布阶段。

## 需求对应与状态

| 产品项 | 状态 | 验证证据 |
| --- | --- | --- |
| 匿名事件白名单 | 已完成 | 业务事件先映射为固定事件名和枚举属性；测试覆盖允许字段，不接受转写或输出正文。 |
| 用户开关 | 自动化通过，远程复核待完成 | `ConsentAwareAnalyticsTracker` 测试确认关闭后丢弃新事件；待 Dashboard 完成首次入库后复核事件数量不再增加。 |
| 公开源码默认不发送 | 已完成 | 未注入 App ID 时工厂返回 `NoopAnalyticsTracker`；普通构建的 `Info.plist` 不含统计配置。 |
| 官方 Provider | 已完成 | TelemetryDeck Swift SDK 2.14.1 已接入，自动 Session 事件和 Session 统计关闭。 |
| 隐私说明 | 已完成 | 权限与隐私页及中英文 README 说明允许元数据和明确禁止的数据。 |
| Test Mode 隔离 | 已完成 | 内部构建可注入 Test Mode；测试事件不会混入正式数据。 |
| 官方服务连通性 | 已完成 | 使用官方 App ID 的隔离 `app_launched` 事件被 TelemetryDeck 接收端以 `HTTP 200 OK` 接受。 |
| Dashboard 事件展示 | 部分完成 | 2026-07-15 复核时组织仍显示 `Queued for Data Processing`，Test Mode 下 Users 和 Errors 均为 0；已重新发送隔离的 `app_launched` 事件，等待免费套餐完成批处理。 |

## 已执行验证

- `ReadyTypeAnalyticsTests`：6 项执行，0 失败。
- 配置构建：App ID 和 Test Mode 均成功注入，App Bundle 严格签名结构验证通过。
- TelemetryDeck 组织和 ReadyType macOS 应用已创建，使用免费套餐。
- 官方接收端返回 `HTTP 200 OK`；发送内容只包含事件规范允许的版本、构建、macOS 主版本和架构。
- 构建 86 再次注入官方 App ID 和 Test Mode 并启动；启动后本机 `telemetrysignalcache` 为空，测试事件没有因网络失败滞留。
- 验收结束后已重新执行普通构建，确认当前 `dist/ReadyType.app` 不含 App ID 或 Test Mode 配置。
- `git diff --check`：通过。

## 真实环境待验收

1. 免费套餐完成下一次入库后，在 Test Mode 的 Recent Events 中确认 2026-07-15 重发的 `app_launched`。
2. 完成一次真实语音输入，确认只出现 `voice_input_started` 和 `voice_input_finished` 的允许属性。
3. 关闭“帮助改进 ReadyType”后再次启动和输入，确认不再产生新事件。
4. 检查事件详情不含语音、转写、最终输出、窗口标题、常用词、剪贴板或 DeepSeek 密钥。

## 发布前阻塞项

- 完成 Dashboard 首次入库和开关关闭后的远程复核。
- 将正式构建版本号和构建号更新为 1.3.0 对应值。
- 确认正式发布构建注入 App ID，但不注入 Test Mode。
- 完成全量测试、App/ZIP/DMG 打包、敏感信息检查和 GitHub Release 验证。
