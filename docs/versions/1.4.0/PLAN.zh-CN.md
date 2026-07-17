# ReadyType 1.4.0 计划：热门词包

## 设计原则

1. 用户无感：后台更新、失败静默、输入不等待。
2. 用户可控：设置中可关闭、手动更新、删除词包。
3. 本地优先：无网络也能正常输入。
4. 分层词库：用户词永远优先，热门词只做低优先级补充。
5. 小候选集：每次只选相关 Top N，不把整包塞进识别器。
6. 可过期：热门词必须有有效期，避免长期污染候选。

## 参考成熟输入法模式

- Fcitx CloudPinyin 的公开说明是为拼音输入提供 Web 额外候选，适合作为“云候选补充”参考。
- Fcitx5 中文输入使用 libime 一类本地输入法后端，说明稳定输入体验依赖本地模型/词典，而不是每次联网。
- Rime/librime 的核心思路是本地词典、用户数据和可配置方案，适合作为“本地优先 + 用户词库”参考。

ReadyType 应吸收这些模式，但不照搬拼音输入法实现。ReadyType 的输入源是语音，因此热词主要用于：

- Apple Speech `contextualStrings`。
- 识别后的保守术语修正。
- DeepSeek 输出模式的术语提示。

## 确定来源

- Wikimedia Analytics API：读取 `zh.wikipedia.org` 和 `en.wikipedia.org` 的热门页面及页面访问量。
- Wikidata：补齐规范名称、语言别名、实体类型和日期字段；结构化数据使用 CC0。
- 第一版不接 TMDB。其开发者接口的免费范围不覆盖商业产品，除非后续取得商业许可。
- 数据源、许可与 API 规范详见[词包生成与 AI 整理方案](./VOCABULARY_PIPELINE.zh-CN.md)。

## 技术架构

```text
ReadyType 内置词库
+ 用户常用词
+ 确认式学习词
+ 热门词包内存快照
        ↓
SmartTermDictionary 合并
        ↓
ContextualVocabularyProvider 排序和裁剪
        ↓
Apple Speech contextualStrings / 后处理 / DeepSeek 术语提示
```

## 新增模块

- `HotVocabularyManifest`：可解码、可签名校验的词包清单。
- `HotVocabularyStore`：原子写入、上一有效版本保留、过期清理和内存快照。
- `HotVocabularyUpdater`：空闲时下载，执行 ETag、hash 和签名校验。
- `SmartTermDictionary.mergingHotVocabulary`：把有效热门词作为低优先级来源并入现有统一词典。
- `HotVocabularySettingsViewModel`：只向「语音识别」页暴露用户可理解的状态和操作。

## 数据格式草案

```json
{
  "schemaVersion": 1,
  "generatedAt": "2026-07-07T00:00:00Z",
  "packs": [
    {
      "id": "entertainment-cn",
      "displayName": "影视娱乐",
      "version": "2026.07.07",
      "terms": [
        {
          "value": "示例电影名",
          "aliases": ["示例电影", "example movie"],
          "category": "movie",
          "scopes": ["chat", "document"],
          "source": "public-curated",
          "weight": 70,
          "expiresAt": "2026-08-07T00:00:00Z"
        }
      ]
    }
  ]
}
```

## 更新策略

- App 启动后延迟检查，不阻塞首屏。
- 仅在空闲、非录音、非输出中更新。
- 默认每日最多检查一次。
- 下载失败保持旧包；没有旧包则显示未更新。
- 网络错误不弹窗；设置页显示“暂时无法更新”。
- 下载到临时文件，全部校验通过后再原子替换当前词包；任何失败都保留上一份有效词包。
- App 启动时从磁盘构建一次不可变内存快照；录音热路径只读取快照，不访问网络和磁盘。
- 维护侧生成任务每天读取上一完整自然日数据，结合最近 7 天热度与过去 28 天基线；客户端不直接抓取第三方 API。

## 发布与可信来源

- 词包由 ReadyType 的独立发布流程生成，不由客户端抓取热榜。
- 生成产物发布到同一 GitHub 仓库的 `gh-pages` 分支，计划入口为 `https://whnnick.github.io/readytype/vocabulary/v1/manifest.json`。
- manifest 和内容文件使用固定私钥签名，App 只内置公钥；仓库和 CI 不保存生产私钥明文。
- 发布流程先做来源许可、去重、敏感词和过期时间检查，再生成 hash、签名与版本。
- 1.4.0 必须先建立可回滚的正式词包地址和发布检查，不能把临时 URL 写进客户端。

## AI 整理

- AI 只运行在维护侧生成流程中，不进入 App 热路径，也不使用用户 API Key。
- 第一版自动发布的词名与别名必须来自 Wikidata；AI 负责分类复核、歧义标记和审核建议。
- AI 提出的新别名只能进入人工审核队列，不能直接进入发布包。
- 发布结果必须可在不启用 AI 的情况下由确定性脚本重建和验证。

## 排序策略

基础分：

- 用户手动词：最高。
- 用户确认建议：高。
- 内置词：中高。
- 场景词：中。
- 热门词：低。

热门词加权：

- 同类场景加分，例如聊天场景可启用影视娱乐。
- 过期词直接过滤。
- 越接近更新时间权重越高。
- 用户如果确认加入常用词，则转入用户词库，脱离热门词包权重。

## 性能预算

- 本地词包解析在后台完成。
- 识别前只做内存筛选，不做网络请求。
- 单次候选选择目标低于现有 `ContextualVocabularyProvider` 预算。
- Apple Speech 总 contextual terms 不超过 100。
- 热门词每次最多 10-20 个，聊天场景使用更低上限，避免误伤。

## 实施步骤

1. 冻结 1.4.0 数据源、AI 边界、发布地址和 UI 方案。
2. 增加 manifest、签名校验和 store 测试，不接网络。
3. 将有效热门词作为新的 `SmartTermSource` 低优先级并入统一词典。
4. 扩展 `ContextualVocabularyProvider`，验证排序、过期过滤和裁剪。
5. 在「语音识别」页增加紧凑状态区，不新增侧栏入口。
6. 建立正式词包发布地址与生成检查，再接入后台 updater。
7. 增加原子替换、回滚、离线和性能测试。
8. 做真实语音回归：有热词、无热词、过期热词、聊天误伤场景。

## 后续版本

- 个人纠正记忆、跨使用次数统计和确认式学习进入 1.5.0 候选。
- 1.4.0 不监听其他 App 中的用户修改，不上传个人纠正数据，不做静默学习。

## 验收命令

- `swift test --filter HotVocabulary`
- `swift test --filter ContextualVocabularyProviderTests`
- `swift test --filter ContextualVocabularyLatencyBudgetTests`
- `swift test`
- `scripts/build-app.sh`

## 真实验收

- 关闭网络后语音输入正常。
- 更新失败不打断输入。
- 添加用户词后，用户词优先于同名或近音热门词。
- 影视娱乐词只在相关场景提高命中，不污染技术文档。
- 热门词包删除后，候选立即移除。
