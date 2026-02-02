# KajiShare API

- グループ課題・家事・タスク管理のためのRails製APIサーバです。
- フロントエンド（React / Next.js など）からの利用を想定し、
  認証・権限・バリデーション・テストを重視した設計を行っております。

## 特徴・設計方針

- API専用（Rails API mode）
- JWT（Bearer Token）による認証
- 権限管理（admin / member）
- ワークロード比率による負荷管理
- バリデーションエラーの構造化レスポンス
- RSpecによるテスト（Request Spec中心）

## 主な機能

- Google認証によるユーザー管理- グループ・タスク・アサインメント・評価のRESTful API
- 権限（admin/member）・ワークロード比率管理
- JSONレスポンス / バリデーションエラーの詳細返却

## 技術スタック

- Ruby 3.4.４
- Rails 8.0.4（API mode）
- PostgreSQL 14.19
- RSpec 3.13
- FactoryBot, Shoulda Matchers
- Docker / docker-compose
- Google Auth（IDトークン認証）

## セットアップ手順

### 必要環境

- Ruby 3.4.４
- Rails 8.0.4
- PostgreSQL 14.19
- Node.js（フロント連携時のみ）

### 初期構築

git clone <https://github.com/meeeee05/KajiShare-backend>

cd KajiShare-backend

bundle install

rails db:create db:migrate db:seed

rails s

## 認証について

本APIは JWT（Bearer Token）認証 を採用しています。

Google OAuth 認証に成功すると、バックエンドからJWTトークンを発行します。
JWTトークンをAPIリクエストに付与してください。
Authorization: Bearer <token>

## APIエンドポイント（一部）

- /api/v1/auth/google : Google認証
- /api/v1/users : ユーザー管理
- /api/v1/groups : グループ作成・参加・編集
- /api/v1/groups/:group_id/tasks : タスク一覧・作成
- /api/v1/tasks/:id : タスク詳細・更新・削除
- /api/v1/assignments : タスクの割当
- /api/v1/evaluations : タスクの評価

## タスク作成例 

詳細は API_ENDPOINTS.md を参照

POST /api/v1/groups/:group_id/tasks

{
  "task": {
    "name": "掃除",
    "description": "リビング掃除",
    "point": 5
  }
}

## テスト

RSpecによる自動テストを実装しています。

bundle exec rspec

• Request Specを中心に実施
• 認証（401）
• 権限（403）
• 存在しないリソース（404）
• バリデーションエラー（422）

## ディレクトリ構成

app/

  controllers/
  
  models/
  
  serializers/
  
  ...
  
spec/

  requests/api/v1/
  
  support/
  
  factories/
  
config/

db/

## ER図

```mermaid
erDiagram
    USERS {
        int id
        string name
        string email
    }

    GROUPS {
        int id
        string name
    }

    MEMBERSHIPS {
        int id
        string role
        int workload_ratio
    }

    TASKS {
        int id
        string name
        int point
    }

    ASSIGNMENTS {
        int id
        string status
    }

    EVALUATIONS {
        int id
        int score
    }

    USERS ||--o{ MEMBERSHIPS : has
    GROUPS ||--o{ MEMBERSHIPS : has
    GROUPS ||--o{ TASKS : has
    TASKS ||--o{ ASSIGNMENTS : has
    ASSIGNMENTS ||--o{ EVALUATIONS : has
