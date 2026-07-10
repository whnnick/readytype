# ReadyType 1.1.0

ReadyType 1.1.0 聚焦真实输入体验的产品化收口：常用词、确认式学习建议、App 场景语气、快捷键自定义和高精度语音包状态。

## 文档

- [需求说明](./REQUIREMENTS.zh-CN.md)
- [实施计划](./PLAN.zh-CN.md)
- [高精度语音包更新设计](./SPEECH_MODEL_UPDATES.zh-CN.md)

## 当前判断

1.0.0 已经包含一部分底层能力，例如常用词存储、常用词导入、确认式建议、快捷键配置和高精度语音包状态展示。1.1.0 不应重复造这些底层能力，而应把它们整理成更清楚、更稳定、更适合普通用户理解的产品体验。

## 当前进展

- 常用词分类已补齐“公司/组织”。
- 默认分类文案已从“通用”调整为“其他”。
- 常用词建议文案已改为“常用词建议 / 加入常用词”，避免暗示静默学习。
- 常用词建议已过滤过长候选和口头结束词，避免把完整句子、私人正文或“OK / 好了 / 完成”等口头噪声加入建议。
- App 场景语气已补充个人聊天和工作聊天规则，微信/聊天场景不再无根据添加过度礼貌结尾。
- 英文邮件输出已加强收件人、编号列表和主题行约束：用户说“给某人发邮件”时必须在问候语中保留收件人，未要求主题时不主动添加主题。
- 快捷键自定义体验已复核：默认双击 `Option`，自定义后即时生效，`Esc` 取消保持独立。
- 高精度语音包已接入 ReadyType 公共远程清单，可区分尚未检查、检查中、未安装、当前推荐版本、发现新版和暂时无法检查。
- 发现新版后可按清单安装 WhisperKit 官方模型；新版验证成功后才清理旧包，失败时保留当前可用版本。
- `dist/ReadyType.dmg` 已可生成并通过 `hdiutil verify` 校验；`hdiutil create` 需要在非沙箱环境运行。

验证记录：
- `swift test --filter UserVocabularyStoreTests`：11 个测试通过。
- `swift test --filter UserVocabularyLearningServiceTests`：5 个测试通过。
- `swift test --filter PromptTemplatesTests`：15 个测试通过。
- `swift test --filter OutputScenarioTests`：11 个测试通过。
- `swift test --filter GlobalShortcutServiceTests`：17 个测试通过。
- `swift test --filter SettingsViewModelTests`：21 个测试通过。
- `swift test --filter LocalSpeechModelUpdateCheckerTests`：7 个测试通过。
- `swift test --filter LocalSpeechModelDownloadServiceTests`：5 个测试通过。
- `swift test --filter LocalSpeechModelManagerTests`：8 个测试通过。
- `swift test`：328 个测试通过，13 个测试跳过。
- `scripts/build-app.sh`：通过。
- `scripts/package-dmg.sh`：通过，生成 `dist/ReadyType.dmg`。
- `scripts/verify-1.0.0-release-local.sh`：通过；包含单元测试、上下文词汇性能、构建、zip、DMG、`plutil`、`git diff --check`、用户可见识别文案扫描和敏感信息扫描。
- `scripts/verify-1.0.0-ui.sh`：通过。
- `scripts/verify-1.2-textedit-paste.sh`：通过。
- `scripts/verify-1.0.0-common-words-ui.sh`：通过。
- 远程清单端到端验收：GitHub Raw 清单可访问；build 67 在设置页从“正在检查”切换为“当前推荐版本（2024-09-30）”，且不覆盖“高精度识别已准备好”。
- `scripts/verify-1.0.0-visual-acceptance.sh`：通过；截图输出到 `tmp/readytype-1.0.0-visual-acceptance/20260704-170909`。
- `scripts/verify-1.2-real-ai-output.sh`：通过；覆盖真实 DeepSeek 输出，包括英文邮件、英文聊天、个人聊天和工作聊天。
- `scripts/verify-1.2-api-error-paths.sh`：通过；覆盖无效密钥、无效模型、超时和不可达地址。
- 修复英文邮件 prompt 后重新执行 `swift test`：320 个测试通过，10 个测试跳过。
- 修复英文邮件 prompt 后重新执行 `scripts/build-app.sh`、`scripts/package-app.sh`、`scripts/package-dmg.sh` 和 `hdiutil verify dist/ReadyType.dmg`：通过。

未覆盖的真实环境门禁：
- `RUN_LOCAL_SPEECH_MODEL=1 scripts/verify-1.0.0-release-local.sh`：需下载或复用真实高精度语音包。
- `RUN_ASR_METRICS=1 scripts/verify-1.0.0-release-local.sh`：需填写真实麦克风 ASR 指标文件。
- 微信、浏览器、邮件/文档和 AI 工具中的真实 App 回归仍需在发布前按测试说明抽测。

## 开发顺序

1. 常用词库产品化收口：已完成。
2. 确认式学习建议收口：已完成。
3. App 场景语气优化：已完成自动化覆盖，待真实 App 回归。
4. 快捷键自定义体验复核：已完成自动化覆盖，待真实 App 回归。
5. 高精度语音包状态和更新提示：已完成自动化覆盖，待真实 App 回归。
6. 文档、测试和发布准备：本地发布门禁已通过，待真实环境门禁和最终 release 决策。
