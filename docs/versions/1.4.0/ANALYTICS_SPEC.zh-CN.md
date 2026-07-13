# ReadyType 1.4.0 匿名事件规范

## 设计规则

- 所有事件和属性使用封闭枚举；业务代码不能发送自由文本。
- 只记录“发生了什么”，不记录“用户说了什么”。
- 耗时、录音长度和系统信息使用分桶值，避免高基数数据。
- 官方构建配置与管理凭据不进入公开仓库；公开源码构建默认不发送。

## 允许事件

| 事件 | 允许属性 |
| --- | --- |
| `app_launched` | 版本、构建、macOS 主版本、芯片架构 |
| `onboarding_step` | 步骤、结果 |
| `speech_package_action` | 下载/准备/更新/删除、结果、耗时桶 |
| `voice_input_started` | 识别选择、输出方式 |
| `voice_input_finished` | 结果、实际识别引擎、输出方式、场景类别、录音时长桶、耗时桶、交付方式 |
| `voice_input_cancelled` | 阶段 |
| `voice_input_failed` | 阶段、固定错误码 |
| `setting_changed` | 设置名称、枚举值 |

## 允许属性值

- 识别选择：`automatic`、`fast`、`accurate`
- 实际引擎：`apple`、`local`
- 输出方式：`direct`、`polished`、`translate`、`ai`
- 场景类别：`generic`、`chat`、`email`、`note`、`document`、`ai_tool`
- 交付方式：`pasted`、`clipboard`、`failed`
- 录音时长桶：`under_5s`、`5_15s`、`15_30s`、`over_30s`
- 耗时桶：`under_500ms`、`500_1500ms`、`1500_3000ms`、`over_3000ms`

新增事件或属性必须先更新本规范和测试，再进入业务代码。

