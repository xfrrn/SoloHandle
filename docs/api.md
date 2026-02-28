# API 文档

基础说明
- Base URL: 由部署环境决定
- Content-Type: `application/json`
- 所有时间字段必须是带时区偏移的 ISO8601（例如 `2026-02-28T10:30:00+08:00`）
- 默认时区为 `Asia/Shanghai`

## POST /chat

用途
- 统一入口：创建草稿、确认提交、撤销

请求体
- 参考 `packages/schemas/chat_request.schema.json`
- 互斥逻辑
  - 当 `undo_token` 存在时执行撤销
  - 否则当 `confirm_draft_ids` 存在时执行确认提交
  - 否则必须提供 `text` 执行意图识别并生成草稿

字段
- `text` string: 用户输入文本
- `confirm_draft_ids` string[]: 需要确认的草稿 ID 列表
- `undo_token` string: 撤销 token
- `request_id` string: 可选。用于关联一次草稿生成请求

响应
- 参考 `packages/schemas/chat_response.schema.json`
- 可能是以下四种之一：澄清、草稿、提交结果、撤销结果

示例: 生成草稿
```json
{
  "text": "我今天花了25元买咖啡"
}
```

示例: 生成草稿响应
```json
{
  "drafts": [
    {
      "draft_id": "uuid",
      "tool_name": "create_expense",
      "payload": {"amount": 25, "category": "food", "idempotency_key": "uuid"},
      "confidence": 0.8,
      "status": "draft"
    }
  ],
  "cards": [
    {
      "card_id": "uuid",
      "type": "expense",
      "status": "draft",
      "title": "支出",
      "subtitle": "25 CNY",
      "data": {"amount": 25, "category": "food"},
      "actions": []
    }
  ],
  "request_id": "uuid"
}
```

示例: 确认提交
```json
{
  "confirm_draft_ids": ["uuid-1", "uuid-2"]
}
```

示例: 撤销
```json
{
  "undo_token": "uuid"
}
```

错误
- `400 invalid_json`: 请求体不是 JSON
- `400 invalid_param`: 参数类型或范围错误
- `400 not_found`: 草稿或撤销 token 不存在

## GET /router/health

用途
- 检查 LLM Router 是否已配置

响应
- 参考 `packages/schemas/router_health.schema.json`

示例响应
```json
{
  "llm_configured": true,
  "model": "gpt-4o-mini",
  "base_url": "https://api.openai.com/v1"
}
```
