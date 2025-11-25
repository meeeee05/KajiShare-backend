# KajiShare Backend API エンドポイント

## ベースURL
```
http://localhost:3001
```

## 認証
### Google OAuth認証
```
POST /auth/google
POST /api/v1/auth/google
```

**リクエストヘッダー:**
```
Authorization: Bearer <Google_ID_Token>
Content-Type: application/json
```

**レスポンス例:**
```json
{
  "message": "Login successful",
  "user": {
    "id": 1,
    "name": "山田太郎",
    "email": "yamada@example.com",
    "picture": "https://...",
    "google_sub": "1234567890"
  }
}
```

## API テスト
### 接続テスト
```
GET /api/test
```

**レスポンス例:**
```json
{
  "message": "KajiShare API is working!",
  "timestamp": "2025-11-09T23:25:02.298+09:00",
  "database": "connected"
}
```

## ユーザー管理
### ユーザー一覧取得
```
GET /api/v1/users
```

### ユーザー詳細取得
```
GET /api/v1/users/:id
```

### ユーザー情報更新
```
PUT /api/v1/users/:id
PATCH /api/v1/users/:id
```

**リクエストボディ:**
```json
{
  "user": {
    "name": "新しい名前",
    "email": "new@example.com",
    "picture": "https://new-picture-url"
  }
}
```

## グループ管理
### グループ一覧取得
```
GET /api/v1/groups
```

### グループ作成
```
POST /api/v1/groups
```

### グループ詳細取得
```
GET /api/v1/groups/:id
```

### グループ更新
```
PUT /api/v1/groups/:id
PATCH /api/v1/groups/:id
```

### グループ削除
```
DELETE /api/v1/groups/:id
```

## メンバーシップ管理
### メンバー追加
```
POST /api/v1/groups/:group_id/memberships
```

### メンバー削除
```
DELETE /api/v1/groups/:group_id/memberships/:id
```

## タスク管理
### タスク一覧取得
```
GET /api/v1/groups/:group_id/tasks
```

### タスク作成
```
POST /api/v1/groups/:group_id/tasks
```

### タスク詳細取得
```
GET /api/v1/groups/:group_id/tasks/:id
```

### タスク更新
```
PUT /api/v1/groups/:group_id/tasks/:id
PATCH /api/v1/groups/:group_id/tasks/:id
```

### タスク削除
```
DELETE /api/v1/groups/:group_id/tasks/:id
```

## 割り当て管理
### 割り当て作成
```
POST /api/v1/groups/:group_id/tasks/:task_id/assignments
```

### 割り当て更新
```
PUT /api/v1/groups/:group_id/tasks/:task_id/assignments/:id
PATCH /api/v1/groups/:group_id/tasks/:task_id/assignments/:id
```

### 割り当て削除
```
DELETE /api/v1/groups/:group_id/tasks/:task_id/assignments/:id
```

## 評価管理
### 評価一覧取得
```
GET /api/v1/evaluations
```

### 評価作成
```
POST /api/v1/evaluations
```

### 評価詳細取得
```
GET /api/v1/evaluations/:id
```

### 評価更新
```
PUT /api/v1/evaluations/:id
PATCH /api/v1/evaluations/:id
```

## エラーレスポンス
### 404 Not Found
```json
{
  "error": "Record not found"
}
```

### 422 Unprocessable Entity
```json
{
  "errors": [
    "Name can't be blank",
    "Email has already been taken"
  ]
}
```

### 401 Unauthorized
```json
{
  "error": "Unauthorized"
}
```

## CORS設定
以下のオリジンからのアクセスが許可されています：
- `http://localhost:3000`
- `http://localhost:3001`
- `http://localhost:5173`
- `http://localhost:8080`
