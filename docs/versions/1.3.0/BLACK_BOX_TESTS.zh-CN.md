# ReadyType 1.3.0 黑盒功能检查

最后更新：2026-07-16。当前发布候选为 `1.3.0 (87)`。

## 需求对应与状态

| 产品项 | 状态 | 验证证据 |
| --- | --- | --- |
| 匿名事件白名单 | 已完成 | 业务事件先映射为固定事件名和枚举属性；测试覆盖允许字段，不接受转写或输出正文。 |
| 用户开关 | 已完成 | `ConsentAwareAnalyticsTracker` 测试确认关闭后丢弃新事件；Provider 只接收通过该开关放行的固定事件。 |
| 公开源码默认不发送 | 已完成 | 未注入 App ID 时工厂返回 `NoopAnalyticsTracker`；普通构建的 `Info.plist` 不含统计配置。 |
| 官方 Provider | 已完成 | TelemetryDeck Swift SDK 2.14.1 已接入，自动 Session 事件和 Session 统计关闭。 |
| 隐私说明 | 已完成 | 权限与隐私页及中英文 README 说明允许元数据和明确禁止的数据。 |
| Test Mode 隔离 | 已完成 | 内部构建可注入 Test Mode；测试事件不会混入正式数据。 |
| 官方服务连通性 | 已完成 | 使用官方 App ID 的隔离 `app_launched` 事件被 TelemetryDeck 接收端以 `HTTP 200 OK` 接受。 |
| Dashboard 事件展示 | 已完成 | 2026-07-16 在 Test Mode 的 Recent Events 中确认 `app_launched`，Dashboard 显示 1 位测试用户、1 个事件、0 个错误和 SwiftSDK 2.14.1。 |
| 服务端字段审计 | 已完成 | `app_launched` 详情共有 75 个字段；ReadyType 自定义字段仅为事件规范允许的 `type`、`version`、`build`、`os_major` 和 `architecture`，其余为 TelemetryDeck 固有兼容性元数据。字段名扫描未发现语音、转写、输出、窗口标题、常用词、剪贴板、DeepSeek 或 API Key。 |

## 已执行验证

- `ReadyTypeAnalyticsTests`：6 项执行，0 失败。
- 配置构建：App ID 和 Test Mode 均成功注入，App Bundle 严格签名结构验证通过。
- TelemetryDeck 组织和 ReadyType macOS 应用已创建，使用免费套餐。
- 官方接收端返回 `HTTP 200 OK`；发送内容只包含事件规范允许的版本、构建、macOS 主版本和架构。
- 构建 86 再次注入官方 App ID 和 Test Mode 并启动；启动后本机 `telemetrysignalcache` 为空，测试事件没有因网络失败滞留。
- 2026-07-16 在 TelemetryDeck Test Mode 的 Recent Events 中确认 `app_launched` 已完成入库；事件版本为 `1.2.0 (86)`，SDK 为 2.14.1。
- Dashboard 事件详情字段名审计：75 个字段，禁止内容匹配为 0；ReadyType 自定义字段与匿名事件规范一致。
- No-op 验收结束后曾重新执行普通构建，确认未注入配置的源码构建不含 App ID 或 Test Mode。
- 正式候选构建已注入官方 App ID，且明确不含 Test Mode；App 版本为 `1.3.0 (87)`。
- `swift test`：371 项执行，11 项按环境跳过，0 失败；常用词 2,000 词压力测试 P95 为 8.272 ms。
- App Bundle 严格签名结构、ZIP、DMG 和 `hdiutil verify`：通过；ZIP 内版本为 `1.3.0 (87)`。
- `python3 scripts/check-sensitive-info.py`：通过。
- 新增 `scripts/verify-release-local.sh` 和 `scripts/verify-ui.sh`，后续版本复用同一套发布门禁。
- `scripts/verify-ui.sh`：通过；八个主页面均可打开且核心文案可见。
- `scripts/verify-release-local.sh`：完整通过。
- `git diff --check`：通过。

## 真实环境待验收

1. 发布后首批真实使用数据入库时，抽查 `voice_input_started` 和 `voice_input_finished` 的枚举属性分布。

## 发布前阻塞项

- 提交并推送发布候选，创建 `v1.3.0` tag。
- 等待 Release workflow 上传 ZIP、DMG 和 SHA-256 文件，并执行远端发布状态验证。
