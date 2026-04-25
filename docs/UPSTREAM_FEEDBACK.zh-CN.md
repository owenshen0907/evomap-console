# EvoMap 官方文档待反馈记录

更新时间：2026-04-25 11:22 JST

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

## 4. 节点 claim 完成后的状态回读字段需要澄清

- 状态：待确认后反馈
- 官方页面：
  - https://evomap.ai/zh/wiki/03-for-ai-agents
  - https://evomap.ai/wiki/03-for-ai-agents
- 影响范围：第三方客户端在用户通过浏览器完成 claim 后，无法稳定判断本地节点是否已经绑定账号。

### 当前文档理解

文档说明 `/a2a/hello` 会返回 `claim_code` 和 `claim_url`，用户访问 claim URL 后可以把 agent 绑定到 EvoMap 账号。但公开文档未说明 claim 完成后，客户端应该通过哪个接口或字段回读最终状态。

### 实测结果

2026-04-25 09:57 JST 左右，节点已经能完成 Hello 和 authenticated heartbeat，且本地已保存 `node_secret`。但 App 侧只能看到 hello 返回的 `claim_code` / `claim_url`，没有稳定可依赖的 `claimed`、`claim_state`、`claim_status`、`account_claimed` 等字段来判断浏览器 claim 是否已完成。

### 建议给官方的修复方式

- 在 `/a2a/heartbeat` 或专用 status endpoint 中返回稳定字段，例如 `claimed: true` 或 `claim_state: "claimed"`。
- 文档明确推荐客户端如何刷新 claim 状态，以及 claim URL 过期后是否需要重新 `/a2a/hello`。
- 如果当前没有回读接口，文档应说明：第三方客户端只能把 Web account 页面作为最终来源，或需要用户在本地手动标记。

## 5. 悬赏任务认领字段需要明确 `node_id`，公开列表还需要说明 task_id 获取方式

- 状态：待反馈
- 官方页面：
  - https://evomap.ai/zh/bounties
  - https://evomap.ai/zh/wiki/03-for-ai-agents
  - https://evomap.ai/wiki/03-for-ai-agents
- 影响范围：第三方客户端从公开悬赏列表加载任务后，直接调用认领接口容易缺字段。

### 当前文档理解

公开悬赏列表返回的是 bounty/question 维度数据，例如 `bounty_id`、`question_id`、`bounty_amount`。A2A 文档提到可通过 `/a2a/task/claim` 认领任务，但没有足够明确地说明认领请求必须包含 `node_id` 和最终可认领的 `task_id`。

### 实测结果

2026-04-25 10:55 JST 左右，公开接口：

```text
GET https://evomap.ai/api/hub/bounty/questions?limit=2&page=1&has_bounty=true
```

返回条目包含 `bounty_id` 和 `question_id`，但不直接包含 `task_id`。对 bounty 详情接口：

```text
GET https://evomap.ai/api/hub/bounty/{bounty_id}
```

可以拿到用于认领的 `task_id`。认领时如果只发送 `task_id` / `sender_id`，接口返回类似：

```text
HTTP 400: task_id_and_node_id_required
```

说明请求体还需要显式 `node_id`。

### 建议给官方的修复方式

- 在 `/a2a/task/claim` 或 `/api/hub/task/claim` 文档中明确请求体示例：`{ "task_id": "...", "node_id": "node_..." }`。
- 在公开悬赏列表文档中说明：列表行是 bounty/question 维度；客户端需要用 `bounty_id` 查询详情后取得 `task_id`，再调用 claim。
- 如果 `sender_id` 与 `node_id` 都支持或仅兼容其一，文档应明确推荐字段，避免客户端发送错误字段。

## 6. 公开悬赏详情建议暴露最终认领信誉门槛

- 状态：待反馈
- 官方页面：
  - https://evomap.ai/wiki/06-billing-reputation
  - https://evomap.ai/zh/bounties
- 影响范围：第三方客户端可以按文档推断默认门槛，但无法区分 creator 自定义门槛、swarm 门槛或未来规则变更。

### 当前文档理解

`06-billing-reputation` 文档说明 bounty 默认按金额设置信誉要求：1+ credits 需要 reputation >= 20，5+ credits 需要 reputation >= 40，10+ credits 需要 reputation >= 65，同时 creator 可以设置自定义要求。

### 实测结果

2026-04-25 11:21 JST 实测：

```text
GET https://evomap.ai/api/hub/bounty/cmodk1zf20ee7ih01135cwhr6
```

返回了 `amount: 20`、`task_id`、`task_status` 等字段，但没有稳定的 `min_reputation` / `required_reputation` / `claim_requirement` 字段。客户端只能按金额推断默认门槛，因此能解释 `HTTP 403: insufficient_reputation`，但不能准确展示自定义门槛。

### 建议给官方的修复方式

- 在公开 bounty list/detail 响应中增加 `required_reputation` 或 `claim_requirements.reputation`。
- 如果某任务使用 creator 自定义门槛或 swarm 专用门槛，应在字段中体现来源，例如 `requirement_source: "default_amount_tier" | "creator_custom" | "swarm"`。
- 在 claim 失败时，错误响应建议返回 `current_reputation` 和 `required_reputation`，便于客户端直接给用户解释下一步。

## 7. 认领后 `my_submission_id` 会立即出现，提交/完成语义建议补充

- 状态：待反馈
- 官方页面：
  - https://evomap.ai/wiki/05-a2a-protocol
  - https://evomap.ai/zh/wiki/03-for-ai-agents
- 影响范围：第三方客户端可以查到认领后的 submission，但不容易判断 `pending` submission 是占位、草稿、还是可直接补交的正式记录。

### 当前文档理解

文档说明任务流程是：发现任务 -> `/a2a/task/claim` -> `/a2a/publish` 发布 Capsule -> `/a2a/task/complete` 传入 `task_id`、`asset_id`、`node_id`。协议页也列出 `/a2a/task/submit`，并说明支持 `followup_question`。

### 实测结果

2026-04-25 11:39 JST 实测：认领成功后调用：

```text
GET https://evomap.ai/a2a/task/my?node_id=node_e9f02287fb8f
```

返回的任务中已经包含：

```json
{
  "task_id": "cmodpxj5l0e1tcsb9535ws015",
  "bounty_id": "cmodpxj3b0e1qcsb9klpjcnjf",
  "my_submission_id": "cmodq1qon0fmk8pb8l9wj7sk6",
  "my_submission_status": "pending",
  "my_submission_asset": null
}
```

这说明 claim 阶段可能已经创建了一个 pending submission 占位，但文档没有明确说明后续 `/a2a/task/complete` 是否更新该 submission、是否会新建 submission，以及 `/a2a/task/submit` 和 `/a2a/task/complete` 的推荐使用边界。

### 建议给官方的修复方式

- 在 `/a2a/task/my` 文档中说明 `my_submission_id`、`my_submission_status`、`my_submission_asset` 的含义和状态流转。
- 明确推荐客户端完成 bounty 时应使用 `/a2a/task/complete`、`/a2a/task/submit`，还是二者都支持。
- 给出完整请求/响应样例：claim 后 pending submission -> publish Capsule -> complete with `asset_id` -> task owner accept -> credits settle。
- 如果 `/a2a/task/complete` 会更新 claim 时生成的 pending submission，建议在响应里返回稳定的 `submission_id` 和最终 `submission_status`。

## 8. 公开悬赏列表的 `matched` / `pending` 状态需要明确不能直接认领

- 状态：待反馈
- 官方页面：
  - https://evomap.ai/zh/bounties
  - https://evomap.ai/zh/wiki/03-for-ai-agents
  - https://evomap.ai/wiki/05-a2a-protocol
- 影响范围：第三方客户端如果把公开悬赏页的所有有赏金条目都当作可认领任务，会频繁触发 `HTTP 409: task_not_open`。

### 当前文档理解

AI Agent 文档写到可以通过 heartbeat、fetch 或 `GET /a2a/task/list` 发现开放任务，然后调用 `POST /a2a/task/claim`。A2A 协议文档也写到 task list 是 "available tasks"，但公开悬赏页和公开 bounty API 会展示更多状态的条目，例如 `matched`、`pending`。文档没有直接说明这些状态是否可被 `/a2a/task/claim` 接受。

### 实测结果

2026-04-25 18:50 JST 左右，EvomapConsole 中选中公开悬赏列表里的 `matched` 任务时，界面原来误判为可认领；调用认领接口返回：

```text
HTTP 409: task_not_open
```

这说明 `matched` 至少不是安全可认领状态；`pending` 也应按非 open 状态处理，除非官方文档明确它代表可认领。

### 建议给官方的修复方式

- 在公开 bounty list/detail 响应中明确给出 `claimable: true/false` 或 `claim_status` 字段，避免第三方客户端猜状态。
- 在 `/a2a/task/claim` 文档中列出可认领状态，以及 `task_not_open` 的含义。
- 如果公开悬赏页会展示 `matched`、`pending`、`submitted`、`closed` 等不可认领状态，建议文档说明它们只能展示/跟进，不能直接 claim。

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
