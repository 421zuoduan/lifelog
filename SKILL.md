---
name: lifelog
description: |
  生活记录自动化系统。自动识别消息中的日期（今天/昨天/前天/具体日期），使用 SubAgent 智能判断，记录到 Notion 对应日期，支持补录标记。
  适用于：(1) 用户分享日常生活点滴时自动记录；(2) 定时自动汇总分析并填充情绪、事件、位置、人员字段
version: 1.2.3
credentials:
  required:
    - NOTION_KEY
    - NOTION_DATABASE_ID
---

# LifeLog 生活记录系统

自动将用户的日常生活记录到 Notion，支持智能日期识别和自动汇总分析。

## ⚠️ 必需凭据

使用本技能前，必须设置以下环境变量：

```bash
export NOTION_KEY="your-notion-integration-token"
export NOTION_DATABASE_ID="your-notion-database-id"
```

获取方式：
1. 访问 https://www.notion.so/my-integrations 创建 Integration
2. 获取 Internal Integration Token
3. 创建 Database 并 Share 给 Integration
4. 从 URL 中提取 Database ID

# LifeLog 生活记录系统

自动将用户的日常生活记录到 Notion，支持智能日期识别和自动汇总分析。

## 核心功能

1. **实时记录** - 用户分享生活点滴时自动记录到 Notion
2. **智能日期识别（SubAgent）** - 使用 AI SubAgent 智能判断日期，优先分析文本中的日期关键词，其次分析上下文
3. **补录标记** - 非当天记录的内容会标记为"🔁补录"
4. **自动汇总** - 每天凌晨自动运行 LLM 分析，生成情绪状态、主要事件、位置、人员

## Notion 数据库要求

创建 Notion Database，需包含以下字段（全部为 rich_text 类型）：

| 字段名 | 类型 | 说明 |
|--------|------|------|
| 日期 | title | 日期，如 2026-02-22 |
| 原文 | rich_text | 原始记录内容 |
| 情绪状态 | rich_text | LLM 分析后的情绪描述 |
| 主要事件 | rich_text | LLM 分析后的事件描述 |
| 位置 | rich_text | 地点列表 |
| 人员 | rich_text | 涉及的人员 |

## 脚本说明

### 1. lifelog-append.sh

实时记录脚本，接收用户消息内容。**日期由 Agent 调用 SubAgent 智能判断**：

```bash
# 基本用法（Agent 会自动判断日期）
bash lifelog-append.sh "今天早上吃了油条"

# Agent 判断后传入日期
bash lifelog-append.sh "前天去打球了" "2026-03-12"
```

**日期判断流程（Agent 侧）**：
1. 用户发送生活记录 → Agent 调用 SubAgent 判断日期
2. SubAgent 分析文本中的日期关键词（前天、昨天等）
3. 如果没有明确日期，SubAgent 根据上下文智能判断
4. Agent 将判断出的日期和内容一起传给脚本

### 2. lifelog-daily-summary-v5.sh

拉取指定日期的原文，用于 LLM 分析：

```bash
# 拉取昨天
bash lifelog-daily-summary-v5.sh

# 拉取指定日期
bash lifelog-daily-summary-v5.sh 2026-02-22
```

输出格式：
```
PAGE_ID=xxx
---原文开始---
原文内容
---原文结束---
```

### 3. lifelog-update.sh

将 LLM 分析结果写回 Notion：

```bash
bash lifelog-update.sh "<page_id>" "<情绪状态>" "<主要事件>" "<位置>" "<人员>"
```

## 配置步骤

1. 创建 Notion Integration 并获取 API Key
2. 创建 Database 并共享给 Integration
3. 获取 Database ID（URL 中提取）
4. 设置环境变量：

```bash
export NOTION_KEY="your-notion-integration-token"
export NOTION_DATABASE_ID="your-database-id"
```

## 定时任务（可选）

每天凌晨 5 点自动汇总昨天数据：

```bash
openclaw cron add \
  --name "LifeLog-每日汇总" \
  --cron "0 5 * * *" \
  --tz "Asia/Shanghai" \
  --session isolated \
  --message "运行 LifeLog 每日汇总" \
  --delivery-mode announce \
  --channel qqbot \
  --to "<用户ID>"
```

## 工作流

1. 用户发送生活记录 → 调用 `lifelog-append.sh` → 写入 Notion
2. 定时任务触发 → 调用 `lifelog-daily-summary-v5.sh` → 拉取原文
3. LLM 分析原文 → 调用 `lifelog-update.sh` → 填充分析字段
