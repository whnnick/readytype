# ReadyType 1.3.0

ReadyType 1.3.0 建立隐私优先的匿名产品统计，为后续中英双语版本提供可验证的使用、性能和稳定性数据。

## 文档

- [需求说明](./REQUIREMENTS.zh-CN.md)
- [匿名事件规范](./ANALYTICS_SPEC.zh-CN.md)
- [实施计划](./PLAN.zh-CN.md)
- [黑盒功能检查](./BLACK_BOX_TESTS.zh-CN.md)

## 当前边界

- 1.3.0 不上传语音、转写、最终输出、窗口标题、常用词、剪贴板或 API Key。
- 公开源码构建默认使用 `NoopAnalyticsTracker`，不会发送统计。
- 只有官方构建显式注入统计配置后才具备发送能力。
- 用户可以在权限与隐私页面关闭匿名统计。
- 本版本先建立数据基础，不同时实现英文识别和中英混说。

## 当前进度

已完成事件白名单、设置开关、核心输入漏斗、TelemetryDeck Provider、No-op 默认实现和官方服务端验收。Test Mode 已显示真实 `app_launched` 事件，事件详情字段审计未发现任何被禁止的内容字段；未注入配置的源码构建继续保持不发送。`1.3.0 (87)` 的全量测试、正式统计配置构建、ZIP、DMG、八页面 UI、敏感信息检查、GitHub CI 和远端附件验证均已通过，公开 [v1.3.0 Release](https://github.com/whnnick/readytype/releases/tag/v1.3.0) 已可下载。
