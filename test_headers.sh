#!/bin/bash

# KajiShare API Headers Test Script
BASE_URL="http://localhost:3000/api/v1"
TOKEN="your-jwt-token-here"

echo "=== KajiShare API Headers Test ==="

# 1. 基本的なユーザー情報取得
echo "1. Basic User Info:"
curl -s "$BASE_URL/users/1" \
  -H "Accept: application/json" \
  -H "User-Agent: KajiShare-Test/1.0" | jq '.data.attributes.name'

# 2. 認証が必要なタスク情報
echo "2. Authenticated Task Request:"
curl -s "$BASE_URL/tasks/1" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/json" \
  -H "User-Agent: KajiShare-Mobile/1.0" \
  -H "Accept-Language: ja-JP" | jq '.data.attributes'

# 3. メンバーシップ情報を含むユーザー取得
echo "3. User with Memberships:"
curl -s "$BASE_URL/users/1?include_memberships=true" \
  -H "Accept: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Requested-With: XMLHttpRequest" | jq '.data.relationships'

# 4. 新しいタスク作成
echo "4. Create New Task:"
curl -s -X POST "$BASE_URL/tasks" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -H "User-Agent: KajiShare-Web/2.0" \
  -H "X-CSRF-Token: csrf-token-example" \
  -d '{
    "task": {
      "name": "新しいタスク",
      "description": "ヘッダーテスト用のタスク",
      "point": 5,
      "group_id": 1
    }
  }' | jq '.data'

echo "=== Test Complete ==="
