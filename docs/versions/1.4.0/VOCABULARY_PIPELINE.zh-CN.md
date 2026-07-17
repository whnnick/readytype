# ReadyType 1.4.0 词包生成与 AI 整理方案

## 目标

生成来源明确、可复现、可回滚的公共热门词包。AI 可以提高维护效率，但不能成为实时输入依赖，也不能绕过确定性校验直接发布词条。

## 确定数据源

### Wikimedia Analytics API

- 用途：取得中文和英文 Wikipedia 的热门页面及页面访问量。
- 项目：`zh.wikipedia.org`、`en.wikipedia.org`。
- 时间：每天读取上一完整自然日，同时保留最近 7 天和过去 28 天聚合值。
- 官方文档：[Wikimedia Analytics API](https://doc.wikimedia.org/generated-data-platform/aqs/analytics-api/) 和[页面访问量接口](https://doc.wikimedia.org/generated-data-platform/aqs/analytics-api/reference/page-views.html)。

### Wikidata

- 用途：把热门页面映射为实体，并取得简体中文、繁体中文、英文名称、别名、实体类型和日期。
- 许可：结构化数据采用 CC0，可用于商业产品和重新分发。
- 官方说明：[Wikidata Licensing](https://www.wikidata.org/wiki/Wikidata:Licensing) 和[数据访问方式](https://www.wikidata.org/wiki/Help:Data_access)。

### 首版明确排除

- TMDB：开发者接口免费范围限于非商业用途，未取得商业许可前不接入。参考 [TMDB FAQ](https://developer.themoviedb.org/docs/faq)。
- 微博、百度热搜及非官方抓取接口：缺少稳定公开接口或明确再分发授权。
- 用户输入、个人常用词和窗口内容：不作为公共热门词来源。

## 每日生成流程

```text
读取上一完整日 Pageviews
        ↓
合并 7 天热度和 28 天基线
        ↓
过滤主页、日期页、列表页、消歧义页和无实体页面
        ↓
关联 Wikidata 名称、别名、类型和日期
        ↓
按允许类别筛选并计算趋势分
        ↓
AI 分类复核与歧义标记（可选）
        ↓
确定性校验、去重、有效期和负样本测试
        ↓
生成 hash、签名并发布
```

候选必须满足：

- 能映射到 Wikidata 实体。
- 属于允许类别，例如影视作品、科技产品、人物、体育赛事或组织。
- 至少在最近 7 天中具有持续热度，或相对 28 天基线出现明确增长。
- 有可用于当前输出语言的规范名称。
- 未命中敏感词、广告词、歧义冲突和人工阻止列表。

趋势排序使用成熟的高频项与时间衰减思路。首版采用可解释的计数、7 天窗口和 28 天基线，不在发布前引入不可解释的在线模型。高频项算法参考 [Space-Saving](https://www.cs.ucsb.edu/research/tech-reports/2005-23)。

## AI 整理边界

AI 可以：

- 复核实体类别。
- 标记名称歧义、广告倾向和不适合输入法的候选。
- 给人工审核提供别名建议和原因。

AI 不可以：

- 创建没有 Wikidata 实体的自动发布词条。
- 直接修改权重、有效期或签名产物。
- 把生成的新别名跳过人工审核后发布。
- 读取用户语音、转写、窗口内容或个人常用词。
- 在用户开始语音输入时被调用。

生成脚本必须支持关闭 AI 后完成抓取、映射、过滤、打包和验证。AI 失败只减少辅助信息，不能阻塞基础词包生成。

## 发布与安全

- 产物发布到同一仓库的 `gh-pages` 分支，与应用源码提交历史分离。
- 计划入口：`https://whnnick.github.io/readytype/vocabulary/v1/manifest.json`。
- manifest 包含 schema 版本、词包版本、生成时间、内容 hash、签名和最低兼容 App 版本。
- 使用 Ed25519 签名；App 只内置公钥。
- 下载到临时文件，校验全部通过后原子替换；失败时保留上一份有效词包。
- 私钥和 DeepSeek Key 只保存在维护者控制的加密发布环境中，不写入仓库、日志或发布产物。

## App 运行时边界

- App 每天最多检查一次更新，只在空闲时执行。
- 录音热路径只读取已解析的内存快照。
- 每次最多选择 10-20 个热门词，全部上下文候选不超过 Apple 建议的 100 个上限。参考 [Apple contextualStrings](https://developer.apple.com/documentation/speech/analysiscontext/contextualstrings)。
- 热门词优先级低于用户常用词和确认式学习词。
- 直接转文字不做基于热门词的激进强制替换。

## 发布门槛

- 数据源和许可检查通过。
- 同一输入生成相同的确定性结果。
- AI 关闭或失败时仍能生成有效基础词包。
- 损坏、过期、签名错误和旧 schema 词包均被 App 拒绝。
- 通用负样本准确率不因热门词明显下降。
- 微信聊天、邮件、文档和技术内容分别完成误触发复测。

## 个人学习边界

个人纠正记忆不属于公共热门词包。它需要跨 App 修改检测、冲突处理、撤销和隐私控制，作为 1.5.0 独立设计；1.4.0 继续使用已有的用户确认式常用词机制。
