# Render backend deploy

## 1. Create PostgreSQL

1. Render Dashboard -> New -> PostgreSQL
2. Region: backend Web Serviceと同じregion
3. 作成後、Internal Database URLを控える

## 2. Create Web Service

1. Render Dashboard -> New -> Web Service
2. GitHub repositoryを選択
3. Branch: `feature/deploy`
4. Language: Docker
5. Dockerfile path: `./Dockerfile`

## 3. Environment variables

必須:

```text
RAILS_ENV=production
RAILS_MASTER_KEY=<config/master.key の値>
DATABASE_URL=<Render PostgreSQL の Internal Database URL>
CORS_ORIGINS=https://<your-frontend>.vercel.app
```

任意:

```text
RAILS_LOG_LEVEL=info
RAILS_MAX_THREADS=5
```

Vercel側のURLがまだない場合は、最初は `CORS_ORIGINS` を空で作成して、フロントのデプロイ後に追加する。
APIはproductionでは許可済みOrigin以外を403にするため、Vercelデプロイ後は必ず設定する。

## 4. Migration

このDocker imageはRails server起動時に `bin/docker-entrypoint` から `bin/rails db:prepare` を実行するため、初回deploy時にmigrationも実行される。

手動で実行したい場合:

```sh
bin/rails db:migrate
```

Render Shellから実行する場合も、環境変数はWeb Serviceと同じものを使う。

## 5. API check

Backend URLが `https://kaji-share-backend.onrender.com` の場合:

```sh
curl https://kaji-share-backend.onrender.com/up
curl -X POST https://kaji-share-backend.onrender.com/api/v1/auth/guest \
  -H "Origin: https://<your-frontend>.vercel.app"
```
