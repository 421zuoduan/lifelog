#!/bin/bash
# LifeLog Recorder - 实时记录单条消息到 Notion（只记录日常生活）
# 使用 LLM 智能判断日期（当关键词无法判断时）

NOTION_KEY="ntn_u6470328110RTrO6nvdJt5D3YBVYRTkbukysWQUHBGd7JD"
DATABASE_ID="30b181a95f2e80639966c2b9d93b69cb"
API_VERSION="2022-06-28"

# 参数：消息内容
CONTENT="$1"

# 简单的日期关键词解析（主要方式）
parse_date_simple() {
    local content="$1"
    local today=$(date +%Y-%m-%d)
    
    # 明天/明儿
    if echo "$content" | grep -qE "明天|明日|明儿"; then
        date -d "tomorrow" +%Y-%m-%d
        return
    fi
    
    # 后天
    if echo "$content" | grep -qE "后天"; then
        date -d "2 days" +%Y-%m-%d
        return
    fi
    
    # 昨天/昨儿
    if echo "$content" | grep -qE "昨天|昨日|昨儿"; then
        date -d "yesterday" +%Y-%m-%d
        return
    fi
    
    # 前天
    if echo "$content" | grep -qE "前天"; then
        date -d "2 days ago" +%Y-%m-%d
        return
    fi
    
    # 大前天
    if echo "$content" | grep -qE "大前天"; then
        date -d "3 days ago" +%Y-%m-%d
        return
    fi
    
    # 今天/今儿
    if echo "$content" | grep -qE "今天|今日|今儿"; then
        echo "$today"
        return
    fi
    
    # 具体日期格式
    if echo "$content" | grep -qE "[0-9]{4}-[0-9]{1,2}-[0-9]{1,2}"; then
        echo "$content" | grep -oE "[0-9]{4}-[0-9]{1,2}-[0-9]{1,2}" | head -1
        return
    fi
    
    # 匹配 X月X日 格式
    if echo "$content" | grep -qE "[0-9]{1,2}月[0-9]{1,2}日"; then
        local year=$(date +%Y)
        local month=$(echo "$content" | grep -oE "[0-9]{1,2}月" | head -1 | grep -oE "[0-9]{1,2}")
        local day=$(echo "$content" | grep -oE "[0-9]{1,2}日" | head -1 | grep -oE "[0-9]{1,2}")
        echo "$year-$(printf "%02d" $month)-$(printf "%02d" $day)"
        return
    fi
    
    # 无法判断，返回空
    echo ""
}

# 用 LLM 判断日期（当关键词无法判断时）
decide_date_with_llm() {
    local content="$1"
    
    # 调用 OpenRouter API (免费，支持中文)
    local result=$(curl -s -X POST "https://openrouter.ai/api/v1/chat/completions" \
        -H "Authorization: Bearer sk-or-v1-4e70e4a89b10a7bfdf4e39bf4e85bdfb6d8f2d8a4e5b8c9a6d3f5e7b9c2d1f5" \
        -H "Content-Type: application/json" \
        -H "HTTP-Referer: https://openclaw.ai" \
        -d '{
            "model": "google/gemma-3-1b-it:free",
            "messages": [{"role": "system", "content": "你是日期判断专家。当前是2026年3月14日。根据用户输入判断是哪一天。只输出日期YYYY-MM-DD，不要其他。"}, {"role": "user", "content": "'"$content"'"}],
            "max_tokens": 20
        }')
    
    local decided_date=$(echo "$result" | grep -oE "[0-9]{4}-[0-9]{2}-[0-9]{2}" | head -1)
    echo "$decided_date"
}

# 主逻辑
TODAY=$(date +%Y-%m-%d)

# 先用简单关键词判断
TARGET_DATE=$(parse_date_simple "$CONTENT")

# 如果关键词无法判断，使用 LLM
if [ -z "$TARGET_DATE" ]; then
    echo "🔍 关键词无法判断，使用 LLM 智能分析..."
    TARGET_DATE=$(decide_date_with_llm "$CONTENT")
    
    # 如果 LLM 也无法判断，默认今天
    if [ -z "$TARGET_DATE" ]; then
        echo "⚠️ 无法判断日期，默认今天"
        TARGET_DATE="$TODAY"
    fi
fi

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
