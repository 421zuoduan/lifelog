#!/bin/bash
# LifeLog Recorder - 实时记录单条消息到 Notion（只记录日常生活）
# 使用 SubAgent 智能判断日期

NOTION_KEY="ntn_u6470328110RTrO6nvdJt5D3YBVYRTkbukysWQUHBGd7JD"
DATABASE_ID="30b181a95f2e80639966c2b9d93b69cb"
API_VERSION="2022-06-28"

# 参数：消息内容
CONTENT="$1"

# 使用 SubAgent 判断日期
decide_date_with_subagent() {
    local content="$1"
    local today=$(date +%Y-%m-%d)
    
    # 调用 subagent 判断日期
    local result=$(curl -s -X POST "http://localhost:421/api/sessions" \
        -H "Content-Type: application/json" \
        -d "{
            \"runtime\": \"subagent\",
            \"model\": \"minimax/MiniMax-M2.5\",
            \"task\": \"你是 LifeLog 系统的日期判断专家。根据以下用户输入的文本，判断这条记录应该属于哪一天。

输入文本：$content

判断规则：
1. 如果文本中明确提到「昨天」「前天」「今天」「明天」等，使用对应的日期
2. 如果没有明确日期，结合当前时间（2026-03-14）和上下文分析
3. 如果仍然无法判断，输出今天的日期（$today）

当前日期是 2026-03-14。

请只输出日期，格式：YYYY-MM-DD，不要输出其他内容。\",
            \"runTimeoutSeconds\": 30
        }")
    
    # 解析返回的日期
    local decided_date=$(echo "$result" | grep -oE "[0-9]{4}-[0-9]{2}-[0-9]{2}" | head -1)
    
    if [ -z "$decided_date" ]; then
        echo "$today"
    else
        echo "$decided_date"
    fi
}

# 备用：简单的日期解析（当 subagent 不可用时）
parse_date_fallback() {
    local content="$1"
    local today=$(date +%Y-%m-%d)
    
    # 昨天
    if echo "$content" | grep -qE "昨天|昨日|昨儿"; then
        date -d "yesterday" +%Y-%m-%d
        return
    fi
    
    # 前天
    if echo "$content" | grep -qE "前天"; then
        date -d "2 days ago" +%Y-%m-%d
        return
    fi
    
    # 明天
    if echo "$content" | grep -qE "明天|明日|明儿"; then
        date -d "tomorrow" +%Y-%m-%d
        return
    fi
    
    # 后天
    if echo "$content" | grep -qE "后天"; then
        date -d "2 days" +%Y-%m-%d
        return
    fi
    
    # 今天
    if echo "$content" | grep -qE "今天|今日|今儿"; then
        echo "$today"
        return
    fi
    
    # 具体日期格式
    if echo "$content" | grep -qE "[0-9]{4}-[0-9]{1,2}-[0-9]{1,2}"; then
        echo "$content" | grep -oE "[0-9]{4}-[0-9]{1,2}-[0-9]{1,2}" | head -1
        return
    fi
    
    # 没识别到，返回今天
    echo "$today"
}

# 尝试用 SubAgent 判断日期，如果失败则用备用方案
echo "🔍 智能判断日期中..."
TARGET_DATE=$(decide_date_with_subagent "$CONTENT" 2>/dev/null)
if [ -z "$TARGET_DATE" ]; then
    echo "⚠️ SubAgent 不可用，使用备用方案"
    TARGET_DATE=$(parse_date_fallback "$CONTENT")
fi

TODAY=$(date +%Y-%m-%d)

# 判断是否为补录
IS_BACKDATE=false
if [ "$TARGET_DATE" != "$TODAY" ]; then
    IS_BACKDATE=true
fi

echo "📅 识别到日期: $TARGET_DATE (今天: $TODAY, 补录: $IS_BACKDATE)"

# 时间戳
if [ "$IS_BACKDATE" = true ]; then
    TIMESTAMP=$(date "+📅 %Y-%m-%d %H:%M 🔁补录")
else
    TIMESTAMP=$(date "+📅 %Y-%m-%d %H:%M")
fi

if [ -z "$CONTENT" ]; then
    echo "❌ 消息内容不能为空"
    exit 1
fi

# 检查是否为纯工作指令
is_work_content() {
    local content="$1"
    local emotion_keywords="觉得|感觉|累|烦|开心|有趣|抽象|无语|好玩|难受|爽|想|希望|花了|搞了|折腾"
    if echo "$content" | grep -qE "$emotion_keywords"; then
        return 1
    fi
    
    local work_keywords="帮我写代码|修改代码|部署服务|启动服务器|运行测试|git push|编译"
    if echo "$content" | grep -qE "$work_keywords"; then
        return 0
    fi
    return 1
}

# 检查是否为测试消息
is_test_or_ack() {
    local content="$1"
    if echo "$content" | grep -qE "^测试|^试一下|测试一下|测试测试"; then
        return 0
    fi
    if [ ${#content} -lt 4 ]; then
        return 0
    fi
    return 1
}

# 检查是否为系统消息
is_system_message() {
    local content="$1"
    local sys_keywords="设置记录|配置Notion|修改LifeLog|记录方式|修改偏好"
    if echo "$content" | grep -qE "$sys_keywords"; then
        return 0
    fi
    return 1
}

# 判断是否需要记录
if is_work_content "$CONTENT"; then
    echo "⏭️ 跳过工作内容: ${CONTENT:0:30}..."
    exit 0
fi

if is_system_message "$CONTENT"; then
    echo "⏭️ 跳过系统消息: ${CONTENT:0:30}..."
    exit 0
fi

if is_test_or_ack "$CONTENT"; then
    echo "⏭️ 跳过测试/确认消息: ${CONTENT:0:30}..."
    exit 0
fi

# 检查目标日期是否已有记录
echo "🔍 检查 $TARGET_DATE 是否有记录..."

RESPONSE=$(curl -s -X POST "https://api.notion.com/v1/databases/$DATABASE_ID/query" \
    -H "Authorization: Bearer $NOTION_KEY" \
    -H "Notion-Version: $API_VERSION" \
    -H "Content-Type: application/json" \
    -d "{\"filter\": { \"property\": \"日期\", \"title\": { \"equals\": \"$TARGET_DATE\" } }, \"page_size\": 1}")

COUNT=$(echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('results',[])))")

if [ "$COUNT" -gt 0 ]; then
    # 追加到现有记录
    PAGE_ID=$(echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['results'][0]['id'])")
    EXISTING=$(echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['results'][0]['properties'].get('原文',{}).get('rich_text',[{}])[0].get('plain_text',''))")
    
    NEW_CONTENT="${EXISTING}"$'\n'"${TIMESTAMP} ${CONTENT}"
    
    echo "📝 追加到现有记录 ${PAGE_ID:0:8}"
    echo "   原有: ${EXISTING:0:50}..."
    echo "   新增: ${CONTENT}"
    
    RESULT=$(curl -s -X PATCH "https://api.notion.com/v1/pages/$PAGE_ID" \
        -H "Authorization: Bearer $NOTION_KEY" \
        -H "Notion-Version: $API_VERSION" \
        -H "Content-Type: application/json" \
        -d "{
            \"properties\": {
                \"原文\": { \"rich_text\": [{ \"text\": { \"content\": \"$(echo "$NEW_CONTENT" | head -1000 | tr '\n' ' ' | sed 's/\"/\\\"/g')\" } }] }
            }
        }")
    
    if echo "$RESULT" | python3 -c "import sys,json; d=json.load(sys.stdin); print('OK' if d.get('object')=='page' else 'FAIL')" 2>/dev/null | grep -q "OK"; then
        echo "NOTION_OK"
    else
        echo "NOTION_FAIL: $RESULT"
    fi
else
    # 创建新记录
    FORMATTED="${TIMESTAMP} ${CONTENT}"
    
    echo "🆕 创建新记录"
    echo "   内容: ${FORMATTED}"
    
    RESULT=$(curl -s -X POST "https://api.notion.com/v1/pages" \
        -H "Authorization: Bearer $NOTION_KEY" \
        -H "Notion-Version: $API_VERSION" \
        -H "Content-Type: application/json" \
        -d "{
            \"parent\": { \"database_id\": \"$DATABASE_ID\" },
            \"properties\": {
                \"日期\": { \"title\": [{ \"text\": { \"content\": \"$TARGET_DATE\" } }] },
                \"原文\": { \"rich_text\": [{ \"text\": { \"content\": \"$FORMATTED\" } }] }
            }
        }")
    
    if echo "$RESULT" | python3 -c "import sys,json; d=json.load(sys.stdin); print('OK' if d.get('object')=='page' else 'FAIL')" 2>/dev/null | grep -q "OK"; then
        echo "NOTION_OK"
    else
        echo "NOTION_FAIL"
    fi
fi
