# EvoMap 官方文档待反馈记录

更新时间：2026-04-25 08:34 JST

这个文件记录使用 EvoMap 官方接口时发现的文档/API 不一致点。后续给 EvoMap 官方提交 issue、PR 或邮件时，优先从这里整理。

## 1. `/a2a/hello` 响应结构与文档示例不一致

- 状态：待反馈
- 官方页面：
  - https://evomap.ai/zh/wiki/03-for-ai-agents
  - https://evomap.ai/wiki/03-for-ai-agents
- 影响范围：Mac app 接入官方 `/a2a/hello` 时，按文档字段直接解码会失败。

### 当前文档理解

文档在 `/a2a/hello` 部分列出 `status`、`your_node_id`、`node_secret`、`claim_code`、`claim_url`、`credit_balance` 等字段，容易让接入方理解为这些字段位于 JSON 根对象。

### 实测结果

2026-04-25 08:27 JST 使用 `POST https://evomap.ai/a2a/hello` 实测，HTTP 200 返回的是 A2A envelope。关键字段位于 `payload` 内，而不是根对象：

```json
{
  "protocol": "gep-a2a",
  "protocol_version": "1.0.0",
  "message_type": "hello",
  "sender_id": "hub_...",
  "payload": {
    "status": "acknowledged",
    "your_node_id": "node_...",
    "hub_node_id": "hub_...",
    "credit_balance": 0,
    "survival_status": "alive",
    "referral_code": "node_...",
    "heartbeat_interval_ms": 300000,
    "heartbeat_endpoint": "/a2a/heartbeat",
    "node_secret": "<redacted>",
    "claim_code": "<redacted>",
    "claim_url": "<redacted>"
  }
}
```

### 建议给官方的修复方式

- 在文档中明确：`/a2a/hello` 返回 A2A envelope，业务字段在 `payload.*`。
- 响应示例应展示完整 envelope，而不是只列业务 payload 字段。
- 字段表建议改成 `payload.status`、`payload.your_node_id`、`payload.node_secret` 等。

## 2. `/a2a/hello` 是否立即返回推荐任务和网络 manifest 需要澄清

- 状态：待确认后反馈
- 官方页面：
  - https://evomap.ai/zh/wiki/03-for-ai-agents
  - https://evomap.ai/wiki/03-for-ai-agents
- 影响范围：App 是否应该在 Hello 后立即展示推荐任务、network manifest、starter pack。

### 当前文档理解

文档看起来把 `recommended_tasks`、`network_manifest`、`starter_gene_pack` 等作为 Hello 后可用的数据。

### 实测结果

2026-04-25 08:27 JST 实测 `/a2a/hello` 返回：

```json
{
  "payload": {
    "hello_enrichment_deferred": true,
    "hello_enrichment_note": "Recommendations, tasks, collaboration, network manifest, ecosystem gaps, starter pack, preferences, merge hints, and bundle corrections load in the background. Use POST /a2a/heartbeat for the full discovery payload (cached)."
  }
}
```

即推荐任务、协作、网络 manifest、starter pack 等看起来被延迟到 heartbeat 获取。

### 建议给官方的修复方式

- 如果这是最新行为，文档应写明：Hello 只完成注册和认证材料返回；推荐任务/manifest/starter pack 需要后续 `POST /a2a/heartbeat` 获取。
- 如果文档描述仍然正确，则需要说明什么条件下 Hello 会同步返回这些字段。

## 3. 新节点 starter credits 的入账时机需要澄清

- 状态：待确认后反馈
- 官方页面：
  - https://evomap.ai/zh/wiki/03-for-ai-agents
  - https://evomap.ai/wiki/03-for-ai-agents
- 影响范围：App 首次连接节点后显示多少积分，以及用户如何理解“100 starter credits”。

### 当前文档理解

文档提到新 agent 可获得 starter credits，容易理解为 `/a2a/hello` 成功后 `credit_balance` 立即为 100。

### 实测结果

2026-04-25 08:27 JST 新 sender_id 请求 `/a2a/hello` 成功后，返回 `payload.credit_balance = 0`。

### 建议给官方的修复方式

- 明确 starter credits 是给 Web account、agent node、还是 claim 后绑定账户才入账。
- 明确入账时机：Hello 成功立即入账、claim 后入账、heartbeat 后异步入账，还是人工/任务触发。
- 明确 `credit_balance` 字段代表 node 当前余额、account 余额，还是未 claim 状态下的临时余额。

## 以后新增问题模板

```md
## N. 标题

- 状态：待反馈 / 已反馈 / 官方已确认 / 已修复
- 官方页面：
  - URL
- 影响范围：

### 当前文档理解

### 实测结果

### 建议给官方的修复方式
```
