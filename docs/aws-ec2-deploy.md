# AWS EC2 deployment

This application is deployed as two Docker Compose services on one EC2
instance:

- `caddy`: terminates HTTPS on ports 80/443
- `web`: runs Puma on the private Docker network

PostgreSQL runs on a private RDS instance. Solid Queue uses the same database,
so Redis and a second RDS database are not required.

## AWS resources

- Region: `ap-northeast-1`
- EC2: Amazon Linux 2023, initially `t3.micro`
- RDS: PostgreSQL 15, initially `db.t4g.micro`, Single-AZ, 20 GiB
- ECR repository: `kajishare-backend`
- EC2 security group: public TCP 80/443 only
- RDS security group: TCP 5432 from the EC2 security group only
- RDS public access: disabled

Do not create a NAT Gateway or load balancer for this single-server setup.

## Build and push the image

The recommended path is `.github/workflows/build-backend-image.yml`. It uses
GitHub OIDC to assume a narrowly scoped AWS IAM role, so no long-lived AWS
access key is stored in GitHub.

Before running the workflow:

1. create the `kajishare-backend` ECR repository
2. create an AWS IAM OIDC provider and ECR push role restricted to this repo
   and the `main` branch
3. add the role ARN as the GitHub Actions variable `AWS_ROLE_ARN`

Every push to `main` then publishes an image tagged with the immutable Git
commit SHA.

### Manual alternative

The EC2 instance is x86_64. On an Apple Silicon Mac, explicitly build the
`linux/amd64` image and push it directly to ECR:

```sh
aws ecr get-login-password --region ap-northeast-1 | \
  docker login --username AWS --password-stdin ACCOUNT_ID.dkr.ecr.ap-northeast-1.amazonaws.com

docker buildx build \
  --platform linux/amd64 \
  --tag ACCOUNT_ID.dkr.ecr.ap-northeast-1.amazonaws.com/kajishare-backend:GIT_SHA \
  --push .
```

Use an immutable Git commit SHA for `GIT_SHA`. Avoid relying on `latest` for
rollback-sensitive deployments.

## EC2 files

Place the repository or these deployment files under `/opt/kajishare`:

- `compose.production.yml`
- `Caddyfile`
- `bin/deploy-aws`
- `.env.production` (created on EC2, never committed)

Create the environment file from the example and restrict its permissions:

```sh
cp .env.production.example .env.production
chmod 600 .env.production
```

Required values are:

- `IMAGE_URI`
- `API_DOMAIN`
- `CORS_ORIGINS`
- `RAILS_MASTER_KEY`
- `GOOGLE_CLIENT_ID`
- `FRONTEND_API_SECRET`
- `DATABASE_URL`

The RDS URL format is:

```text
postgresql://DB_USER:DB_PASSWORD@RDS_ENDPOINT:5432/kajishare_production
```

URL-encode reserved characters in the database password. Never paste real
secrets into GitHub, documentation, or chat.

## Deploy

Authenticate Docker to ECR using the EC2 IAM role, then run:

```sh
bin/deploy-aws
```

The script performs these steps in order:

1. validates the Compose configuration
2. pulls the requested immutable image
3. runs `db:prepare` as a one-off container
4. replaces the web and Caddy containers
5. prints container status

Database preparation is intentionally separate from web startup. A broken
migration therefore fails the deployment instead of putting the web container
into a restart loop.

## DNS and verification

Point an `A` record for `api.example.com` to the EC2 Elastic IP. Caddy obtains
and renews the TLS certificate automatically after DNS resolves and ports 80
and 443 are reachable.

Verify the deployment:

```sh
curl --fail https://api.example.com/up
docker compose --env-file .env.production -f compose.production.yml ps
docker compose --env-file .env.production -f compose.production.yml logs --tail=100 web caddy
```

Finally update Vercel's production API URL, Rails `CORS_ORIGINS`, and the
Google OAuth authorized origins to use the production domains.
