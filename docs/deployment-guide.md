# CareerForge — Deployment Guide

> **Stack:** FastAPI (EC2 t3.micro) + Next.js 14 (AWS Amplify) + DynamoDB + S3 + Bedrock  
> **Region:** us-east-1  
> **AWS Account:** 602664593597  
> **Repo:** `codedbykishore/career-forge` → branch `production`

---

## Prerequisites

- AWS CLI configured with profile `careerforge-dev`  
  ```bash
  aws sts get-caller-identity --profile careerforge-dev
  ```
- Git access to the repo
- GitHub App created at [github.com/settings/apps](https://github.com/settings/apps)

---

## Step 1 — DynamoDB Pre-flight

Verify all 9 tables exist (creates `SkillGapReports` if missing):

```bash
bash project/backend/scripts/deploy/preflight-dynamo.sh us-east-1
```

Expected output: `✅ All 9 DynamoDB tables verified!`

Tables: `Users`, `Projects`, `Resumes`, `Jobs`, `Applications`, `Roadmaps`, `SkillGapReports`, `UserJobStatuses`, `BlacklistedCompanies`

> `UserJobStatuses` and `BlacklistedCompanies` are also auto-created on app startup.

---

## Step 2 — EC2 Setup (Backend)

### 2a. Create AWS resources (one-time)

```bash
# SSH key pair
aws ec2 create-key-pair \
  --key-name careerforge-ec2 \
  --region us-east-1 \
  --profile careerforge-dev \
  --query 'KeyMaterial' --output text > ~/.ssh/careerforge-ec2.pem
chmod 600 ~/.ssh/careerforge-ec2.pem

# IAM role
aws iam create-role \
  --role-name careerforge-ec2-role \
  --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}' \
  --profile careerforge-dev

for POLICY in \
  arn:aws:iam::aws:policy/AmazonBedrockFullAccess \
  arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess \
  arn:aws:iam::aws:policy/AmazonS3FullAccess \
  arn:aws:iam::aws:policy/SecretsManagerReadWrite; do
  aws iam attach-role-policy --role-name careerforge-ec2-role --policy-arn "$POLICY" --profile careerforge-dev
done

aws iam create-instance-profile \
  --instance-profile-name careerforge-ec2-profile --profile careerforge-dev
aws iam add-role-to-instance-profile \
  --instance-profile-name careerforge-ec2-profile \
  --role-name careerforge-ec2-role --profile careerforge-dev

# Security group (ports 22 + 80)
SG_ID=$(aws ec2 create-security-group \
  --group-name careerforge-sg \
  --description "CareerForge API" \
  --region us-east-1 --profile careerforge-dev \
  --query 'GroupId' --output text)

aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" --region us-east-1 --profile careerforge-dev \
  --ip-permissions \
    'IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=0.0.0.0/0}]' \
    'IpProtocol=tcp,FromPort=80,ToPort=80,IpRanges=[{CidrIp=0.0.0.0/0}]'
```

### 2b. Launch EC2 instance

```bash
# Get latest Ubuntu 22.04 AMI
AMI=$(aws ec2 describe-images \
  --region us-east-1 --profile careerforge-dev \
  --owners 099720109477 \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
            "Name=state,Values=available" \
  --query 'sort_by(Images, &CreationDate)[-1].ImageId' --output text)

INSTANCE_ID=$(aws ec2 run-instances \
  --image-id "$AMI" \
  --instance-type t3.micro \
  --key-name careerforge-ec2 \
  --security-group-ids "$SG_ID" \
  --iam-instance-profile Name=careerforge-ec2-profile \
  --region us-east-1 --profile careerforge-dev \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=careerforge-api}]' \
  --query 'Instances[0].InstanceId' --output text)

# Wait for running + get IP
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" \
  --region us-east-1 --profile careerforge-dev

EC2_IP=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" --region us-east-1 --profile careerforge-dev \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

echo "EC2 IP: $EC2_IP"
```

### 2c. Install app on EC2

```bash
# Wait ~30s for SSH to be ready, then run setup
sleep 30
ssh -i ~/.ssh/careerforge-ec2.pem -o StrictHostKeyChecking=no ubuntu@$EC2_IP \
  "bash <(curl -s https://raw.githubusercontent.com/codedbykishore/career-forge/production/project/backend/scripts/deploy/setup-ec2.sh) \
   https://github.com/codedbykishore/career-forge.git production"
```

This installs: `python3.11`, `nginx`, `git`, clones the repo, sets up the Python venv, installs all pip packages, creates the systemd service, and configures Nginx.

### 2d. Create `.env` on EC2

Generate secret keys first:
```bash
python3 -c "import secrets; print('SECRET_KEY='+secrets.token_hex(32)); print('JWT_SECRET_KEY='+secrets.token_hex(32))"
```

Then write the `.env` (replace `<AMPLIFY_URL>` after Step 3):
```bash
ssh -i ~/.ssh/careerforge-ec2.pem ubuntu@$EC2_IP "cat > /home/ubuntu/careerforge/project/backend/.env << 'EOF'
APP_ENV=production
DEBUG=False
SECRET_KEY=<generated-above>
JWT_SECRET_KEY=<generated-above>

AWS_REGION=us-east-1

BEDROCK_MODEL_ID=us.meta.llama3-3-70b-instruct-v1:0
BEDROCK_EMBED_MODEL_ID=amazon.titan-embed-text-v2:0

USE_DYNAMO=true
DYNAMO_TABLE_PREFIX=

S3_BUCKET=careerforge-pdfs-602664593597

GITHUB_APP_ID=3017691
GITHUB_APP_SLUG=career-forge-app
GITHUB_APP_CLIENT_ID=Iv23liPtP21luM5Dj6X0
GITHUB_APP_CLIENT_SECRET=<from-github-developer-console>
GITHUB_APP_PRIVATE_KEY_SECRET=careerforge/github-app-private-key
GITHUB_CALLBACK_URL=https://<AMPLIFY_URL>/api/auth/callback/github

ALLOWED_ORIGINS=https://<AMPLIFY_URL>
EOF"
```

### 2e. Start the backend

```bash
ssh -i ~/.ssh/careerforge-ec2.pem ubuntu@$EC2_IP \
  "sudo systemctl start careerforge && sleep 5 && curl -s http://127.0.0.1:8000/health"
```

Expected: `{"status":"healthy","service":"careerforge","environment":"production"}`

---

## Step 3 — Amplify Setup (Frontend)

### 3a. Connect repo (one-time, via AWS Console)

1. Go to [AWS Amplify Console](https://us-east-1.console.aws.amazon.com/amplify) → **New app → Host web app**
2. Connect GitHub → select repo `codedbykishore/career-forge` → branch: **`production`**
3. Framework: **Next.js - SSR**
4. The `amplify.yml` at the repo root is detected automatically — no changes needed

### 3b. Set Amplify environment variables (via CLI)

```bash
AMPLIFY_APP_ID=<your-amplify-app-id>   # from the Amplify URL

aws amplify update-app \
  --app-id "$AMPLIFY_APP_ID" \
  --platform WEB_COMPUTE \
  --region us-east-1 --profile careerforge-dev \
  --environment-variables \
    "API_URL=http://$EC2_IP,\
NEXT_PUBLIC_API_URL=http://$EC2_IP,\
NEXT_PUBLIC_APP_URL=https://production.${AMPLIFY_APP_ID}.amplifyapp.com,\
NEXT_PUBLIC_GITHUB_CLIENT_ID=Iv23liPtP21luM5Dj6X0,\
AMPLIFY_MONOREPO_APP_ROOT=project/frontend"

aws amplify update-branch \
  --app-id "$AMPLIFY_APP_ID" \
  --branch-name production \
  --framework "Next.js - SSR" \
  --region us-east-1 --profile careerforge-dev
```

> **Key:** `API_URL` (no `NEXT_PUBLIC_` prefix) is used server-side only in Next.js rewrites. This prevents the EC2 HTTP URL from leaking into client-side JS and causing Mixed Content errors.

### 3c. Trigger deploy and get Amplify URL

```bash
aws amplify start-job \
  --app-id "$AMPLIFY_APP_ID" \
  --branch-name production \
  --job-type RELEASE \
  --region us-east-1 --profile careerforge-dev

# Monitor build (polls every 30s)
watch -n 30 "aws amplify list-jobs --app-id $AMPLIFY_APP_ID --branch-name production \
  --region us-east-1 --profile careerforge-dev \
  --query 'jobSummaries[0].{ID:jobId,Status:status}' --output table"
```

Amplify URL: `https://production.<AMPLIFY_APP_ID>.amplifyapp.com`

---

## Step 4 — Wire Up Auth (Post-Amplify)

### 4a. Update GitHub App callback URL

Go to [github.com/settings/apps/career-forge-app](https://github.com/settings/apps/career-forge-app) → **Callback URL** → add:
```
https://production.<AMPLIFY_APP_ID>.amplifyapp.com/api/auth/callback/github
```

### 4b. Update EC2 CORS + callback URL

```bash
AMPLIFY_URL="https://production.${AMPLIFY_APP_ID}.amplifyapp.com"

ssh -i ~/.ssh/careerforge-ec2.pem ubuntu@$EC2_IP "
  sed -i 's|ALLOWED_ORIGINS=.*|ALLOWED_ORIGINS=${AMPLIFY_URL}|' /home/ubuntu/careerforge/project/backend/.env
  sed -i 's|GITHUB_CALLBACK_URL=.*|GITHUB_CALLBACK_URL=${AMPLIFY_URL}/api/auth/callback/github|' /home/ubuntu/careerforge/project/backend/.env
  sudo systemctl restart careerforge
  sleep 4 && curl -s http://127.0.0.1:8000/health
"
```

---

## Step 5 — Verify End-to-End

```bash
# Backend health (direct)
curl -s http://$EC2_IP/health

# Backend health (through Amplify proxy)
curl -s https://production.${AMPLIFY_APP_ID}.amplifyapp.com/api/health

# Frontend loads
curl -sI https://production.${AMPLIFY_APP_ID}.amplifyapp.com/ | grep -E "HTTP|x-powered"
# Expected: HTTP/2 200 + x-powered-by: Next.js
```

Then open the app in a browser and test the full login → dashboard flow.

---

## Updating the App

### Backend-only change (no redeploy needed)

```bash
ssh -i ~/.ssh/careerforge-ec2.pem ubuntu@$EC2_IP "
  cd /home/ubuntu/careerforge && git pull origin production
  source project/backend/venv/bin/activate
  pip install -r project/backend/requirements.txt
  sudo systemctl restart careerforge
"
```

### Frontend change

```bash
# Push to production branch → Amplify auto-deploys
git push origin production
```

### Backend `.env` change only (e.g. swap Bedrock model)

```bash
ssh -i ~/.ssh/careerforge-ec2.pem ubuntu@$EC2_IP "
  sed -i 's|BEDROCK_MODEL_ID=.*|BEDROCK_MODEL_ID=us.meta.llama3-3-70b-instruct-v1:0|' \
    /home/ubuntu/careerforge/project/backend/.env
  sudo systemctl restart careerforge
"
```

---

## Useful Commands

```bash
# SSH into EC2
ssh -i ~/.ssh/careerforge-ec2.pem ubuntu@3.229.137.116

# View live backend logs
ssh -i ~/.ssh/careerforge-ec2.pem ubuntu@3.229.137.116 \
  "sudo journalctl -u careerforge -f"

# Backend service status
ssh -i ~/.ssh/careerforge-ec2.pem ubuntu@3.229.137.116 \
  "sudo systemctl status careerforge --no-pager"

# Check what's in .env on EC2 (secrets redacted)
ssh -i ~/.ssh/careerforge-ec2.pem ubuntu@3.229.137.116 \
  "grep -v 'SECRET\|KEY\|CLIENT' /home/ubuntu/careerforge/project/backend/.env"

# Trigger job scrape manually
curl -X POST http://3.229.137.116/api/jobs/scrape \
  -H "Authorization: Bearer <your-jwt>"

# List all Amplify builds
aws amplify list-jobs --app-id da4uq3j68b16w --branch-name production \
  --region us-east-1 --profile careerforge-dev \
  --query 'jobSummaries[*].{ID:jobId,Status:status,Time:startTime}' --output table
```

---

## Architecture

```
Browser (HTTPS)
    │
    ▼
AWS Amplify  ──────── Next.js 14 SSR ──────────────────────────────────┐
https://production.da4uq3j68b16w.amplifyapp.com                        │
    │                                                                    │
    │  /api/* rewrites (server-side, HTTP OK)                           │
    ▼                                                                    │
Nginx (port 80)                                                         │
    │                                                                    │
    ▼  127.0.0.1:8000                                                   │
FastAPI + Uvicorn (2 workers)    EC2 t3.micro  ip: 3.229.137.116       │
    │                                                                    │
    ├── DynamoDB (9 tables, PAY_PER_REQUEST, us-east-1) ────────────────┤
    ├── S3 (careerforge-pdfs-602664593597) ─────────────────────────────┤
    ├── Bedrock (us.meta.llama3-3-70b-instruct-v1:0 + Titan Embed v2) ─┤
    └── Secrets Manager (careerforge/github-app-private-key) ──────────┘
```

---

## Known Gotchas

| Issue | Fix |
|-------|-----|
| `Mixed Content` errors in browser | All API calls must use relative `/api/*` paths — proxied by Next.js rewrites to EC2. Never use `NEXT_PUBLIC_API_URL` directly in client components. |
| GitHub OAuth redirects to `localhost` | `NEXT_PUBLIC_APP_URL` must be set in Amplify. Amplify SSR's `request.url` resolves to an internal hostname — always use `process.env.NEXT_PUBLIC_APP_URL` for redirect targets. |
| Amplify builds as static (404 on all routes) | Platform must be `WEB_COMPUTE` and branch framework `Next.js - SSR`. Set via CLI or Amplify Console. |
| `Cannot read 'next' version` in Amplify build | Set `AMPLIFY_MONOREPO_APP_ROOT=project/frontend` env var in Amplify. |
| `amplify.yml` `cd project/frontend` fails | `appRoot: project/frontend` already sets the working directory — don't `cd` again in `phases`. |
| Backend service fails to start | `.env` file missing at `/home/ubuntu/careerforge/project/backend/.env`. Copy from template and fill values. |
| Bedrock `ValidationException` | Verify model access is enabled in [Bedrock Console → Model access](https://us-east-1.console.aws.amazon.com/bedrock/home?region=us-east-1#/modelaccess). |
| `SkillGapReports` table missing | Run `bash project/backend/scripts/deploy/preflight-dynamo.sh` — it creates it automatically. |
