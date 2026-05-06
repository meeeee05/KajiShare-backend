# KajiShare Backend API エンドポイント

## ベースURL

```text
http://localhost:3001
```

## 認証

Bearerトークンを利用します。

```text
Authorization: Bearer <token>
Content-Type: application/json
```

### 認証API

```text
POST /auth/google
POST /api/v1/auth/google
POST /api/v1/auth/guest
```

## 共通・確認

```text
GET /api/test
GET /up
```

## ユーザー

```text
GET /api/v1/users/me
GET /api/v1/users
GET /api/v1/users/:id
POST /api/v1/users
PATCH /api/v1/users/:id
DELETE /api/v1/users/:id
```

## グループ

```text
GET /api/v1/groups
POST /api/v1/groups
GET /api/v1/groups/:id
PATCH /api/v1/groups/:id
DELETE /api/v1/groups/:id

POST /api/v1/groups/join
POST /api/v1/groups/:id/leave
DELETE /api/v1/groups/:id/leave
DELETE /api/v1/groups/:id/members/me
```

## メンバーシップ

```text
GET /api/v1/groups/:group_id/memberships
POST /api/v1/groups/:group_id/memberships
DELETE /api/v1/groups/:group_id/memberships/:id

GET /api/v1/memberships
GET /api/v1/memberships/:id
POST /api/v1/memberships
PATCH /api/v1/memberships/:id
PATCH /api/v1/memberships/:id/change_role
DELETE /api/v1/memberships/:id
```

## タスク

```text
GET /api/v1/groups/:group_id/tasks
POST /api/v1/groups/:group_id/tasks
GET /api/v1/groups/:group_id/tasks/:id
PATCH /api/v1/groups/:group_id/tasks/:id
DELETE /api/v1/groups/:group_id/tasks/:id

GET /api/v1/tasks
GET /api/v1/tasks/:id
PATCH /api/v1/tasks/:id
DELETE /api/v1/tasks/:id
```

## アサインメント

```text
GET /api/v1/groups/:group_id/assignments
GET /api/v1/tasks/:task_id/assignments
POST /api/v1/tasks/:task_id/assignments
GET /api/v1/groups/:group_id/tasks/:task_id/assignments
POST /api/v1/groups/:group_id/tasks/:task_id/assignments

GET /api/v1/assignments
GET /api/v1/assignments/:id
PATCH /api/v1/assignments/:id
DELETE /api/v1/assignments/:id
```

## 評価

```text
GET /api/v1/evaluations
GET /api/v1/evaluations/:id
POST /api/v1/evaluations
POST /api/v1/assignments/:assignment_id/evaluations
PATCH /api/v1/evaluations/:id
DELETE /api/v1/evaluations/:id
```

### 評価API入力キー

- 正式キーは `score` / `feedback`
- 旧エイリアス `point` / `comment` は受け付けません

## 定期タスク

```text
GET /api/v1/groups/:group_id/recurring_tasks
POST /api/v1/groups/:group_id/recurring_tasks
GET /api/v1/recurring_tasks/:id
PATCH /api/v1/recurring_tasks/:id
DELETE /api/v1/recurring_tasks/:id
```

## 通知

```text
GET /api/v1/notifications
```

### 通知クエリパラメータ

- `type=task_assigned`: task_assigned通知のみ取得
- `for_records=true`: records向けモード
- `since_id`: 増分取得カーソル（数値 or `task_assigned_123`形式）
- `limit`: 取得件数（`<=0` はデフォルト50、上限1000）

## 代表的なエラーレスポンス

```json
{
  "error": "Unauthorized",
  "message": "認証トークンが提供されていません",
  "status": 401
}
```

```json
{
  "error": "Forbidden",
  "message": "このグループのメンバーではありません",
  "status": 403
}
```

```json
{
  "error": "Unprocessable Entity",
  "message": "入力内容に誤りがあります",
  "errors": ["Score can't be blank"],
  "status": 422
}
```
