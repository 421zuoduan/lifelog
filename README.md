# LifeLog 生活记录系统

自动将日常生活记录到 Notion，支持智能日期识别和自动汇总分析。

## 功能特点

- 🤖 **智能日期识别** - 自动识别"昨天"、"前天"等日期，记录到对应日期
- 🔁 **补录标记** - 非当天记录的内容会标记为"🔁补录"
- 📝 **实时记录** - 随时记录生活点滴，自动保存到 Notion
- 🌙 **自动汇总** - 每天凌晨自动运行 LLM 分析，生成情绪状态、主要事件、位置、人员

## 快速开始

### 1. 安装

通过 ClawHub 安装：
```bash
clawhub install lifelog
```

或手动下载：
```bash
git clone https://github.com/421zuoduan/lifelog.git
```

### 2. 配置 Notion

1. **创建 Integration**
   - 访问 https://www.notion.so/my-integrations
   - 点击 **New integration**
   - 复制 Token

2. **创建 Database**
   - 新建 Database，添加字段（全部 rich_text 类型）：
     - 日期（title）
     - 原文
     - 情绪状态
     - 主要事件
     - 位置
     - 人员
   - 右上角 **...** → **Connect to** → 选择你的 Integration

3. **获取 Database ID**
   - URL 中提取：`notion.so/{workspace}/{database_id}?v=...`

4. **修改脚本配置**
   - 编辑 `scripts/` 下的脚本，替换：
     ```bash
     NOTION_KEY="你的Token"
     DATABASE_ID="你的Database_ID"
     ```

### 3. 使用

```bash
# 记录今天的事情
bash scripts/lifelog-append.sh "今天早上吃了油条"

# 记录昨天的事情（自动识别日期）
bash scripts/lifelog-append.sh "昨天去超市买菜了"

# 记录前天的事情
bash scripts/lifelog-append.sh "前天和朋友吃饭了"
```

### 4. 设置定时汇总（可选）

```bash
openclaw cron add \
  --name "LifeLog-每日汇总" \
  --cron "0 5 * * *" \
  --tz "Asia/Shanghai" \
  --session isolated \
  --message "运行 LifeLog 每日汇总"
```

## 脚本说明

| 脚本 | 功能 |
|------|------|
| `lifelog-append.sh` | 实时记录用户消息 |
| `lifelog-daily-summary-v5.sh` | 拉取指定日期原文 |
| `lifelog-update.sh` | 写回分析结果 |

## 支持的日期表达

- 今天/今日/今儿 → 当天
- 昨天/昨日/昨儿 → 前一天
- 前天 → 前两天
- 明天/明儿 → 后一天
- 后天 → 后两天
- 具体日期：2026-02-22、2月22日

## ClawHub

本技能已发布到 ClawHub：https://clawhub.com/s/lifelog

## License

MIT
