# ReadyType 1.4.0 实施计划：匿名产品统计

## 架构

```text
业务模块
  -> ReadyTypeAnalyticsEvent（封闭枚举）
  -> AnalyticsTracking
       -> NoopAnalyticsTracker（默认）
       -> 官方 Provider Adapter（显式配置）
```

## 实施顺序

1. 增加事件模型、分桶工具、`AnalyticsTracking` 和 No-op 实现。
2. 增加设置持久化和“帮助改进 ReadyType”开关。
3. 在权限与隐私页展示明确的收集与禁止收集说明。
4. 接入启动、首次使用、语音输入、语音包、交付和固定错误事件。
5. 增加官方 Provider Adapter；配置缺失或无效时自动退化为 No-op。
6. 更新中英文 README、CHANGELOG、测试说明和 1.4.0 黑盒检查。

## 验证

- `swift test`
- `scripts/build-app.sh`
- 搜索自由文本、API Key、窗口标题、转写和输出是否进入事件属性
- 使用测试 Tracker 验证开关关闭后不再记录
- 在未注入官方配置的构建中验证无统计网络请求

## 发布门槛

事件规范、隐私文案、实现和测试必须一致；只有官方配置验证完成后才发布启用匿名统计的构建。

官方 Provider 使用 TelemetryDeck Swift SDK 2.14.1；App ID 由 `READYTYPE_TELEMETRYDECK_APP_ID` 在构建时注入 App 的 `Info.plist`。App ID 用于数据路由而非后台管理，但不提交到仓库，以确保普通源码构建保持 No-op。管理 Token 和 Dashboard 凭据不得进入客户端构建。
