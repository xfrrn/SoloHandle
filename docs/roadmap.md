# AI Companion Roadmap

> 说明：这是一个“分阶段、可验证”的实施计划，尽量与现有 `docs/mindmap.txt` 和 `docs/architecture.txt` 保持一致。
> 每一阶段都要能“单独跑通、可演示”。

---

## Stage 0 — 基础结构与开发环境

**目标**：仓库结构清晰，能启动后端。

- [x] 建立 monorepo 目录结构（apps/api, apps/web, packages/schemas, docs）
- [x] 初始化 API 工程骨架（FastAPI + uv）
- [x] SQLite 连接与 schema 初始化（events/tasks/notifications）
- [x] `.gitignore` 和基础脚本

**验证**

- `uv run uvicorn api.main:app --app-dir src --reload` 能启动

---

## Stage 1 — Tools 层 MVP（事件/任务/提醒）

**目标**：可写入/查询事件与任务，带幂等、软删除。

- [x] Tools 函数（events/tasks/notifications）
- [x] Repository + Service 分层
- [x] 参数校验、JSON helpers、时间处理
- [x] 幂等 `idempotency_key`
- [x] Soft delete + undo

**验证**

- `pytest apps/api/src/api/tests/test_tools.py`

---

## Stage 2 — 最小 Orchestrator（Draft/Confirm/Undo）

**目标**：有 `/chat` 入口，能生成草稿、确认提交、撤销。

- [x] Orchestrator log 表
- [x] Draft -> Commit -> Undo
- [x] `/chat` 路由

**验证**

- `python scripts/debug_request.py chat "我今天花了25元买咖啡"`
- `python scripts/debug_request.py confirm <draft_id>`
- `python scripts/debug_request.py undo <undo_token>`

---

## Stage 3 — LLM Router（可插拔 Provider）

**目标**：用 LLM 来做意图识别，替代关键词。

- [x] Router Prompt + JSON Schema
- [x] OpenAI-compatible Provider
- [x] 自动重试（输出非法 JSON 时）
- [x] `/router/health`
- [x] config.toml 配置方式
- [x] Router 输出质量优化（细化 prompt / few-shot）
- [ ] 多事件拆分策略（multi_event）

**验证**

- `GET /router/health` 返回模型信息
- `/chat` 正常生成 draft

---

## Stage 4 — API 文档与 Schema 固化

**目标**：固定协议，方便前端和外部集成。

- [x] `docs/api.md`：接口说明
- [x] `docs/schemas.md`：工具/卡片 schema
- [x] `packages/schemas` 下输出 JSON Schema

**验证**

- Schema 可被前端/SDK 使用

---

## Stage 5 — Scheduler（提醒调度）

**目标**：任务提醒能真正触发通知。

- [x] scheduler 轮询 `tasks.remind_at`
- [x] 写入 `notifications`
- [x] 状态字段（reminded_at / notification_id）

---

## Stage 6 — Web/PWA 前端（最小卡片 UI）

**目标**：能在网页上完成记录、确认、撤销。

- [ ] 简单卡片 UI + 表单
- [ ] Draft/Confirm/Undo 流程

---

## Stage 7 — 可扩展能力（可选）

- [ ] 运动/位置等更多事件
- [ ] Memory 模块
- [ ] 向量检索 / 全文检索
- [ ] 多端同步 / Auth

---

## 当前建议顺序

1. 稳定 LLM Router 输出质量（Stage 3）
2. API 文档与 schema（Stage 4）
3. Scheduler（Stage 5）
4. Web UI（Stage 6）

---

## 注意事项

- 所有写入必须使用幂等键
- 所有时间必须 ISO8601 + offset
- 默认时区 Asia/Shanghai
- 软删除为主，保证可撤销
