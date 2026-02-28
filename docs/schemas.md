# Schema 文档

本项目的协议与模型以 JSON Schema 固化，位于 `packages/schemas`。

## 入口与基础对象

- `packages/schemas/chat_request.schema.json`: `/chat` 请求体
- `packages/schemas/chat_response.schema.json`: `/chat` 响应体
- `packages/schemas/router_health.schema.json`: `/router/health` 响应体
- `packages/schemas/router_decision.schema.json`: LLM Router 输出协议
- `packages/schemas/tool_call.schema.json`: ToolCall 结构
- `packages/schemas/card.schema.json`: 卡片结构
- `packages/schemas/draft.schema.json`: 草稿结构

## 领域对象

- `packages/schemas/event.schema.json`: 事件对象
- `packages/schemas/task.schema.json`: 任务对象
- `packages/schemas/notification.schema.json`: 通知对象

## Tools 入参

LLM Router 及外部集成应遵守以下 tool 入参 schema：

- `packages/schemas/tools/create_expense.schema.json`
- `packages/schemas/tools/create_lifelog.schema.json`
- `packages/schemas/tools/create_meal.schema.json`
- `packages/schemas/tools/create_mood.schema.json`
- `packages/schemas/tools/create_task.schema.json`
- `packages/schemas/tools/update_task.schema.json`
- `packages/schemas/tools/complete_task.schema.json`
- `packages/schemas/tools/postpone_task.schema.json`
- `packages/schemas/tools/search_events.schema.json`
- `packages/schemas/tools/search_tasks.schema.json`
- `packages/schemas/tools/list_tasks_today.schema.json`
- `packages/schemas/tools/list_tasks_overdue.schema.json`
- `packages/schemas/tools/soft_delete_event.schema.json`
- `packages/schemas/tools/undo_event.schema.json`
- `packages/schemas/tools/soft_delete_task.schema.json`
- `packages/schemas/tools/undo_task.schema.json`
- `packages/schemas/tools/create_notification_for_task.schema.json`
- `packages/schemas/tools/list_notifications.schema.json`
- `packages/schemas/tools/mark_notification_read.schema.json`

## 枚举值

事件类型
- `expense`, `lifelog`, `meal`, `mood`

支出分类
- `food`, `transport`, `shopping`, `entertainment`, `housing`, `medical`, `education`, `other`, `unknown`

餐食类型
- `breakfast`, `lunch`, `dinner`, `snack`, `unknown`

任务状态
- `todo`, `doing`, `done`, `canceled`

任务优先级
- `low`, `medium`, `high`

数据来源
- `chat_text`, `chat_image`, `chat_voice`, `import`

## 时间与时区

- 所有时间字段必须是带时区偏移的 ISO8601 字符串
- 默认时区为 `Asia/Shanghai`
