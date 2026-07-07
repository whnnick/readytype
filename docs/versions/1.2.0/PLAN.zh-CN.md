# ReadyType 1.2.0 计划：热门词包

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

## 技术架构

```text
ReadyType 内置词库
+ 用户常用词
+ 确认式学习词
+ 热门词包本地缓存
        ↓
SmartTermDictionary 合并
        ↓
ContextualVocabularyProvider 排序和裁剪
        ↓
Apple Speech contextualStrings / 后处理 / DeepSeek 术语提示
```

## 新增模块

- `HotVocabularyTerm`：热门词条模型。
- `HotVocabularyManifest`：词包清单，包含版本、生成时间、分类、hash。
- `HotVocabularyStore`：本地读写、过期清理、删除词包。
- `HotVocabularyUpdater`：后台下载、ETag/hash 校验、失败状态。
- `HotVocabularyProvider`：根据 App、场景和词条权重选出 Top N。
- `HotVocabularySettingsViewModel`：设置页状态、开关、手动更新。

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
- 后续如有服务端，服务端负责聚合 TMDb、Wikidata、公开榜单或人工整理，客户端不直接抓第三方 API。

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
- 聊天场景保守上限更低，避免误伤。

## 实施步骤

1. 增加 1.2.0 文档和需求边界。
2. 增加本地数据模型和 store 测试，不接网络。
3. 将热门词包作为新的 `SmartTermSource` 低优先级合并。
4. 扩展 `ContextualVocabularyProvider`，验证排序和裁剪。
5. 增加设置页开关、状态、删除入口。
6. 增加后台 updater，先支持本地或 GitHub-hosted manifest。
7. 增加样例词包和性能测试。
8. 做真实语音回归：有热词、无热词、过期热词、聊天误伤场景。

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
