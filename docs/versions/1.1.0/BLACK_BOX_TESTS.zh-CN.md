# ReadyType 1.1.0 黑盒功能检查

最后更新：2026-07-10。当前构建：`1.0.0 (67)`；`1.1.0` 尚未发布。

## 需求对应与证据

| 产品项 | 当前状态 | 验证证据 |
| --- | --- | --- |
| 常用词与确认式建议 | 已完成 | `UserVocabularyStoreTests`、`UserVocabularyLearningServiceTests` 通过；设置页仅保留用户明确添加的内容。 |
| 聊天、邮件与英文输出 | 已完成自动化验证 | 真实 DeepSeek 验收 4/4 通过：英文聊天、英文邮件、个人聊天自然语气、工作聊天简洁输出。 |
| 自定义快捷键与 Esc | 已完成自动化验证 | `GlobalShortcutServiceTests` 17/17 通过；真实纯修饰键按压仍需人工复核。 |
| 自动粘贴与复制降级 | 已完成自动化验证 | `scripts/verify-1.2-textedit-paste.sh` 通过。 |
| 高精度语音包状态 | 已完成 | build 67 设置页验证“已准备好”和“当前推荐版本”独立显示。 |
| 高精度语音包更新 | 已完成自动化与在线检查 | GitHub Raw 清单可访问；在线检查成功；更新事务单测覆盖新包持久化、旧包保留和失败回退。 |

## 已执行验证

- `swift test`：328 通过，13 条件跳过，0 失败。
- `scripts/build-app.sh`：通过，产物版本为 `1.0.0 (67)`。
- `scripts/package-app.sh`、`scripts/package-dmg.sh`、`hdiutil verify dist/ReadyType.dmg`：通过。
- `scripts/verify-1.0.0-ui.sh`：build 66 通过；build 67 的高精度语音包在线检查已在真实界面复测。
- `scripts/verify-1.2-textedit-paste.sh`：通过。
- `scripts/verify-1.2-real-ai-output.sh`：通过。
- `scripts/verify-1.2-api-error-paths.sh`：通过。
- 敏感信息扫描：通过；项目 `AGENTS.md` 未被 Git 跟踪。

## 真实环境待验收

- 在微信、备忘录、浏览器、邮件或文档工具中，以真实麦克风完成双击 `Option` 开始/结束、`Esc` 取消和自动粘贴抽测。
- 在微信聊天场景中确认输出自然、简洁，不无根据添加“谢谢”“麻烦你了”等礼貌结尾。
- 用真实高精度语音包完成一次长句和中英混说验证，并记录首次使用与预热后的等待差异。
- 当 ReadyType 远程清单未来推荐新模型时，执行一次真实约 626 MiB 的下载更新验收；当前远程推荐版本与已安装版本一致，因此未人为触发大文件更新。

## 发布前阻塞项

1. 完成上述真实麦克风、多 App 抽测并记录无阻塞结果。
2. 将短版本从 `1.0.0` 升级为 `1.1.0`，重新构建 DMG/ZIP。
3. 完成最终敏感信息、远端 Release 产物与下载链接检查。
