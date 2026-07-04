# ReadyType 1.1.0

ReadyType 1.1.0 聚焦真实输入体验的产品化收口：常用词、确认式学习建议、App 场景语气、快捷键自定义和高精度语音包状态。

## 文档

- [需求说明](./REQUIREMENTS.zh-CN.md)
- [实施计划](./PLAN.zh-CN.md)

## 当前判断

1.0.0 已经包含一部分底层能力，例如常用词存储、常用词导入、确认式建议、快捷键配置和高精度语音包状态展示。1.1.0 不应重复造这些底层能力，而应把它们整理成更清楚、更稳定、更适合普通用户理解的产品体验。

## 当前进展

- 常用词分类已补齐“公司/组织”。
- 默认分类文案已从“通用”调整为“其他”。
- 常用词建议文案已改为“常用词建议 / 加入常用词”，避免暗示静默学习。
- 常用词建议已过滤过长候选和口头结束词，避免把完整句子、私人正文或“OK / 好了 / 完成”等口头噪声加入建议。
- App 场景语气已补充个人聊天和工作聊天规则，微信/聊天场景不再无根据添加过度礼貌结尾。
- 快捷键自定义体验已复核：默认双击 `Option`，自定义后即时生效，`Esc` 取消保持独立。
- 高精度语音包已新增独立更新状态，可区分尚未检查、检查中、未安装、已是最新、发现新版和暂时无法检查。
- `dist/ReadyType.dmg` 已可生成并通过 `hdiutil verify` 校验；`hdiutil create` 需要在非沙箱环境运行。

验证记录：
- `swift test --filter UserVocabularyStoreTests`：11 个测试通过。
- `swift test --filter UserVocabularyLearningServiceTests`：5 个测试通过。
- `swift test --filter PromptTemplatesTests`：15 个测试通过。
- `swift test --filter OutputScenarioTests`：11 个测试通过。
- `swift test --filter GlobalShortcutServiceTests`：17 个测试通过。
- `swift test --filter SettingsViewModelTests`：20 个测试通过。
- `swift test --filter LocalSpeechModelUpdateCheckerTests`：4 个测试通过。
- `swift test`：320 个测试通过，10 个测试跳过。
- `scripts/build-app.sh`：通过。
- `scripts/package-dmg.sh`：通过，生成 `dist/ReadyType.dmg`。

## 开发顺序

1. 常用词库产品化收口：已完成。
2. 确认式学习建议收口：已完成。
3. App 场景语气优化：已完成自动化覆盖，待真实 App 回归。
4. 快捷键自定义体验复核：已完成自动化覆盖，待真实 App 回归。
5. 高精度语音包状态和更新提示：已完成自动化覆盖，待真实 App 回归。
6. 文档、测试和发布准备：进行中。
