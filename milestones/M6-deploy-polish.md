# M6 — Deploy, Polish & Demo

> **Dependencies:** M2 + M3 + M4 + M5 — ✅ All complete (March 7, 2026)
> **Unlocks:** Hackathon submission
> **Estimated effort:** 4–6 hours
> **Target:** March 8, 2026

---

## Actual Stack (as built)

| Layer | Technology | AWS Service |
|-------|-----------|-------------|
| Frontend | Next.js 14 (`output: standalone`) | AWS Amplify |
| Backend API | FastAPI + Uvicorn (Python 3.11) | EC2 t3.micro |
| AI generation | Bedrock Converse API (`us.anthropic.claude-sonnet-4-6`) | Amazon Bedrock |
| Embeddings | Titan Text Embeddings v2 (`amazon.titan-embed-text-v2:0`) | Amazon Bedrock |
| File storage | PDFs + .tex sources, presigned URLs | S3 (`careerforge-pdfs-602664593597`) |
| Data store | 9 tables (PAY_PER_REQUEST) | DynamoDB |
| LaTeX compile | `latex.ytotech.com` free online API (auto-fallback, no install needed) | — |
| GitHub auth | GitHub App (private key in Secrets Manager) | AWS Secrets Manager |
| Job scraping | APScheduler + jobspy, triggered via `POST /api/jobs/scrape` | — (no Lambda) |

**DynamoDB tables (all in us-east-1):**
- From M0: `Users`, `Projects`, `Resumes`, `Jobs`, `Applications`, `Roadmaps`
- From M3: `SkillGapReports` ← **must be created manually before first run**
- Auto-created on startup: `UserJobStatuses`, `BlacklistedCompanies`

---

## ⚠️ Pre-Deploy Manual Checklist  
> These 6 things cannot be done in code. Do them in order before going live.

- [ ] **1. Create `SkillGapReports` DynamoDB table** (one `aws` command — see step 6.0)
- [ ] **2. Create EC2 `.env` file** with real `SECRET_KEY`, `DEBUG=False`, `ALLOWED_ORIGINS`, GitHub App credentials (see step 6.0)
- [ ] **3. EC2 IAM role** — must include `SecretsManagerReadWrite` or GitHub repo ingestion will fail silently (see step 6.1)
- [ ] **4. Add Amplify URL to GitHub App callback URLs** in GitHub Developer Console (see step 6.2)
- [ ] **5. Set Amplify environment variables** — `NEXT_PUBLIC_API_URL`, `NEXT_PUBLIC_APP_URL`, `NEXT_PUBLIC_GITHUB_CLIENT_ID` (see step 6.2)
- [ ] **6. Restart backend after Amplify URL is known** — update `ALLOWED_ORIGINS` in `.env` on EC2, then `sudo systemctl restart careerforge` (see step 6.2)

---

## Tasks

### 6.0 — Pre-flight: Fix Config for Production

> **Code changes already done on the `production` branch** — these are ✅ and don't need to be touched again.

- [x] ~~**CORS dynamic origins** — `main.py` now reads `ALLOWED_ORIGINS` env var~~ ✅ done in code
- [x] ~~**`ALLOWED_ORIGINS` field in `config.py`**~~ ✅ done in code
- [x] ~~**LaTeX timeout bumped** `30s → 60s`~~ ✅ done in code
- [x] ~~**`DEBUG` guards** — `/docs` hidden when `DEBUG=False`, startup warning on default `SECRET_KEY`~~ ✅ done in code

> **Still needs manual action** (part of the 6-item checklist above):

- [ ] **GitHub App callback URL** — in [GitHub Developer Console](https://github.com/settings/apps) → your app → Callback URLs → add `https://<amplify-url>/api/auth/callback/github`
- [x] **Create `SkillGapReports` DynamoDB table** — automated script at `scripts/deploy/preflight-dynamo.sh` ✅
  ```bash
  aws dynamodb describe-table --table-name SkillGapReports --region us-east-1
  # If it says ResourceNotFoundException, create it:
  aws dynamodb create-table \
    --table-name SkillGapReports \
    --attribute-definitions AttributeName=userId,AttributeType=S AttributeName=reportId,AttributeType=S \
    --key-schema AttributeName=userId,KeyType=HASH AttributeName=reportId,KeyType=RANGE \
    --billing-mode PAY_PER_REQUEST \
    --region us-east-1
  ```
- [x] **Create `project/backend/.env`** for EC2 — template at `scripts/deploy/.env.production.template` ✅
  ```
  APP_ENV=production
  DEBUG=False
  SECRET_KEY=<run: python3 -c "import secrets; print(secrets.token_hex(32))">
  JWT_SECRET_KEY=<same command, different value>
  USE_DYNAMO=True
  AWS_REGION=us-east-1
  S3_BUCKET=careerforge-pdfs-602664593597
  BEDROCK_MODEL_ID=us.anthropic.claude-sonnet-4-6
  GITHUB_APP_ID=<from GitHub Developer Console>
  GITHUB_APP_CLIENT_ID=<from GitHub Developer Console>
  GITHUB_APP_CLIENT_SECRET=<from GitHub Developer Console>
  GITHUB_CALLBACK_URL=https://<amplify-url>/api/auth/callback/github
  ALLOWED_ORIGINS=https://<amplify-url>
  ```

### 6.1 — Backend Deployment (EC2)

- [ ] Launch EC2 `t3.micro` in us-east-1 (free tier)
- [ ] Security group: open ports `22` (SSH), `80` (HTTP via Nginx), `8000` (direct API, lock to your IP for safety)
- [ ] **Attach IAM role** with these policies (NO hardcoded keys on EC2):
  - `AmazonBedrockFullAccess`
  - `AmazonS3FullAccess` (scoped to `careerforge-pdfs-602664593597`)
  - `AmazonDynamoDBFullAccess`
  - `SecretsManagerReadWrite` (for GitHub App private key at `careerforge/github-app-private-key`)
- [ ] SSH in and install dependencies — **no Docker needed**, LaTeX compiles via ytotech online API:
  ```bash
  sudo apt update
  sudo apt install -y python3.11 python3.11-venv nginx git
  ```
  > **Optional:** install `texlive-latex-base` (~200 MB) for fully offline compilation. The code auto-falls back: Docker → local `pdflatex` → ytotech online API. You have been running on ytotech online the whole time locally.
- [ ] Clone repo and set up Python env:
  ```bash
  git clone <repo-url> /home/ubuntu/careerforge
  cd /home/ubuntu/careerforge/project/backend
  python3.11 -m venv venv && source venv/bin/activate
  pip install -r requirements.txt
  # Copy .env file (SCP from local or create directly)
  cp /path/to/.env .env
  ```
- [ ] **Run with systemd** (not pm2 — that's Node.js):
  ```bash
  sudo tee /etc/systemd/system/careerforge.service > /dev/null <<EOF
  [Unit]
  Description=CareerForge API
  After=network.target

  [Service]
  User=ubuntu
  WorkingDirectory=/home/ubuntu/careerforge/project/backend
  ExecStart=/home/ubuntu/careerforge/project/backend/venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8000 --workers 2
  Restart=always
  EnvironmentFile=/home/ubuntu/careerforge/project/backend/.env

  [Install]
  WantedBy=multi-user.target
  EOF

  sudo systemctl daemon-reload
  sudo systemctl enable careerforge
  sudo systemctl start careerforge
  ```
- [ ] Configure Nginx reverse proxy:
  ```nginx
  server {
      listen 80;
      client_max_body_size 20M;
      location / {
          proxy_pass http://127.0.0.1:8000;
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_read_timeout 120s;  # Bedrock calls can take ~10s
      }
  }
  ```
- [ ] Verify: `curl http://<ec2-public-ip>/api/health` → `200 OK`
- [ ] Verify Bedrock works: trigger a test resume generation from the API

### 6.2 — Frontend Deployment (Amplify)

- [ ] Push frontend code to GitHub (if not already)
- [ ] Connect repo to AWS Amplify:
  - Framework: **Next.js (SSR / standalone)**
  - Build command: `npm run build`
  - Output dir: `.next`
- [ ] Set **all three** environment variables in Amplify console (App settings → Environment variables):
  - `NEXT_PUBLIC_API_URL=http://<ec2-public-ip>` (no trailing slash)
  - `NEXT_PUBLIC_APP_URL=https://<your-amplify-app-id>.amplifyapp.com` (no trailing slash — must match GitHub App callback URL exactly)
  - `NEXT_PUBLIC_GITHUB_CLIENT_ID=<GitHub App client ID>` (missing this = "Continue with GitHub" button does nothing)
- [ ] Trigger deploy → wait for build (~3–5 min)
- [ ] **Update CORS on backend**: once Amplify URL is known, add it to `ALLOWED_ORIGINS` env var on EC2 and restart: `sudo systemctl restart careerforge`
- [ ] **Update GitHub App callback URL** in GitHub Developer Console to include `https://<amplify-url>/api/auth/callback/github`
- [ ] Verify: open Amplify URL → app loads → GitHub login works
- [ ] Note the Amplify URL for submission

### 6.3 — End-to-End Smoke Test

Run through the complete demo flow on the deployed environment:

- [ ] GitHub OAuth login works on Amplify URL (full callback roundtrip)
- [ ] Repo ingestion → project summaries written to S3 → GitHub tab shows repos
- [ ] Resume generation → PDF loads from S3 presigned URL (not localhost)
- [ ] Skill gap: select "Backend SDE" → radar chart renders with real data
- [ ] LearnWeave: generate roadmap → milestone "Mark Complete" persists to DynamoDB
- [ ] Job Scout: `POST /api/jobs/scrape` → jobs stored → match scores shown
- [ ] Tailored resume: select job → generate → PDF differs from base, diff badges show
- [ ] Application Kanban: drag card between columns → DynamoDB update confirmed

### 6.4 — UI Polish

- [x] Loading skeletons for all Bedrock-backed operations (3–10s latency on Claude Sonnet) ✅ `BedrockLoadingSkeleton` component + integrated in resume gen, skill gap, tailor
- [x] Error states: user-friendly messages, not raw `500 Internal Server Error` ✅ `ErrorBoundary` + `ErrorState` components wrapping dashboard content
- [x] Add "Powered by Amazon Bedrock" badge on resume generator and skill gap pages ✅ `BedrockBadge` component on all AI-powered tabs
- [x] Career role selection: 2×4 card grid with icons (already in skill-gap-shell.tsx — verify looks good) ✅ verified
- [x] Radar chart: 800ms smooth animation on render (already in Recharts config — verify deployed) ✅ `animationDuration={800}` confirmed
- [x] Mobile responsive check — judges may test on phones ✅ Mobile sidebar overlay + responsive padding
- [x] Consistent colour scheme and typography across all pages ✅ Warm Indigo palette via CSS variables
- [x] Navigation: Dashboard → Resume → Skill Gap → LearnWeave → Jobs → Applications ✅ Tab order verified

### 6.5 — Pre-populate Demo Data

- [x] Trigger job scrape: `POST http://<ec2-ip>/api/jobs/scrape` — loads 12 mock jobs into DynamoDB (auto-falls back to mock data if `jobspy` fails) ✅ script at `scripts/deploy/populate-demo.sh`
- [ ] Generate 2–3 base resumes for a demo GitHub account
- [ ] Run skill gap analysis for "Backend SDE" and "ML Engineer" roles
- [ ] Generate 1 LearnWeave roadmap
- [ ] Create application records in each Kanban status (saved, applied, interviewing, offered, rejected)
- [ ] **Backup:** Screenshot every page in case live demo fails on stage

### 6.6 — Architecture Diagram & Submission

- [ ] Take screenshots of `docs/career-architecture.html` for presentation slides
- [x] Prepare AWS cost breakdown slide: ✅ included in m6-report.md
  | Service | What It Does | Estimated Cost |
  |---------|-------------|---------------|
  | Bedrock (`us.anthropic.claude-sonnet-4-6` + Titan) | Resume gen, skill gap, tailoring, job analysis | ~$3.00 |
  | DynamoDB (9 tables, PAY_PER_REQUEST) | All structured data | ~$0 |
  | S3 (`careerforge-pdfs-602664593597`) | PDFs, .tex files, project summaries | ~$0.01 |
  | EC2 t3.micro | API server (LaTeX via ytotech free API) | ~$0 (free tier) |
  | Amplify | Next.js frontend hosting | ~$0 |
  | Secrets Manager | GitHub App private key | ~$0.01 |
  | **Total** | | **~$3–4** |
- [ ] Note: **no Lambda deployed** — job scraping runs inside FastAPI via `POST /api/jobs/scrape`. Mention scheduled scraping via APScheduler.
- [ ] Record 3-minute demo video (backup for submission)
- [ ] File named: `TeamName – UniversityName` (per PS rules)
- [ ] Submission checklist: Amplify URL, GitHub repo, architecture diagram, demo video, cost breakdown

### 6.7 — Demo Script Rehearsal

| Time      | Action                                                | What Judges See                        |
|-----------|-------------------------------------------------------|----------------------------------------|
| 0:00–0:20 | Open Amplify URL → GitHub OAuth login                 | Clean login, "Connecting to GitHub…"   |
| 0:20–0:50 | Repos ingest → skill profile in Projects tab          | Tech stack extracted from real repos   |
| 0:50–1:20 | Select "Backend SDE" → run gap analysis               | Animated radar chart + colour-coded gap table |
| 1:20–1:50 | Generate base resume → PDF opens from S3              | Jake's template, auto-filled with GitHub data |
| 1:50–2:20 | Job Scout tab → trigger scrape → select job → tailored resume | Match scores + new PDF with diff badges |
| 2:20–2:50 | LearnWeave roadmap + drag-drop Kanban                 | 4-week roadmap + application tracker   |
| 2:50–3:00 | Flash AWS console: Bedrock, S3, DynamoDB, Amplify, Secrets Manager | Prove real AWS usage |

- [ ] Rehearse 3 times minimum
- [ ] Time each run — must finish under 3:00
- [ ] Prepare answers for: "What if GitHub is down?", "How does anti-hallucination work?", "What's the cost at scale?", "Why no Lambda?" (answer: scraper runs in-process via APScheduler, Lambda complexity skipped for hackathon timeline)

---

## Verification Checklist

- [ ] App accessible at public Amplify URL
- [ ] GitHub OAuth login + callback works end-to-end (not redirecting to localhost)
- [ ] LaTeX PDF renders and downloads from S3 presigned URL
- [ ] `SkillGapReports` DynamoDB table exists and gap analysis persists to it
- [ ] All 5 AWS services visible in console (Bedrock, S3, DynamoDB, Amplify, Secrets Manager)
- [ ] Demo completes in under 3 minutes
- [ ] Backup screenshots/video ready
- [ ] Submission file correctly named and formatted

---

## Critical Gotchas (found during codebase audit)

> **AWS CLI status:** `aws sts get-caller-identity` is confirmed working with profile `careerforge-dev` (account `602664593597`). All `aws` commands in this file will work as-is.

1. **No Docker needed — LaTeX uses ytotech online API** — `latex_service.py` has a 3-level fallback: Docker → local `pdflatex` → `latex.ytotech.com` free API. Since neither Docker nor `pdflatex` is installed locally or on a fresh EC2, **it has been using ytotech all along**. This will continue to work on EC2 as long as outbound HTTPS is open (it is by default). If you want fully offline compilation, install `texlive-latex-base` (~200 MB): `sudo apt install -y texlive-latex-base texlive-fonts-recommended texlive-latex-extra`. No 4 GB Docker image required.

2. **`SkillGapReports` table was NOT provisioned in M0** — M0 created 6 tables; M3 added a 7th (`SkillGapReports`). Create it manually before deploying (see step 6.0).

3. ~~**CORS is hardcoded**~~ — ✅ Fixed in code on `production` branch. `main.py` now reads `ALLOWED_ORIGINS` env var and merges it into the allowed list at startup. Just set `ALLOWED_ORIGINS=https://<amplify-url>` in the EC2 `.env` and restart.

4. **GitHub callback URL must match** — the GitHub App is currently configured for `http://localhost:3000/api/auth/callback/github`. In production, this MUST be updated to the Amplify URL in both GitHub Developer Console AND the `GITHUB_CALLBACK_URL` env var on EC2.

5. **IAM role needs Secrets Manager** — GitHub App private key is loaded from AWS Secrets Manager at `careerforge/github-app-private-key`. The EC2 IAM role must include `secretsmanager:GetSecretValue` permission.

6. **No Lambda deployed** — M4 deliberately skipped Lambda packaging. Job scraping runs inside FastAPI via `POST /api/jobs/scrape` endpoint. APScheduler handles hourly background scraping.

7. **Bedrock model is Claude Sonnet 4.6** — config uses `us.anthropic.claude-sonnet-4-6` (cross-region inference prefix), not Claude 3 Haiku as originally planned. Verify model access is enabled for this model ID in the Bedrock console.

8. **`proxy_read_timeout` on Nginx** — Bedrock Claude Sonnet calls for resume generation can take 10–20s. Set `proxy_read_timeout 120s` in Nginx or the frontend will show gateway timeout errors.

9. **pm2 is NOT valid here** — pm2 is a Node.js process manager. Use `systemd` to manage the uvicorn process as a system service (see step 6.1).

10. **Frontend already has a Dockerfile** (`project/frontend/Dockerfile`) — if Amplify build fails, you can build and run the frontend in Docker on a second EC2 or use EC2 User Data to run both containers.

---

## Notes

- EC2 IAM role is non-negotiable — never put AWS credentials in `.env` on the server.
- Amplify auto-deploys on push — do not push broken code after the demo URL is shared.
- Pre-populating demo data is non-negotiable. The scraper mock data is already built in — trigger `POST /api/jobs/scrape` once after deployment.
- LaTeX compilation uses `latex.ytotech.com` free online API — no Docker, no local install, no 4 GB download. Just ensure EC2 security group allows outbound HTTPS (port 443), which AWS does by default.
- `UserJobStatuses` and `BlacklistedCompanies` tables are auto-created on app startup via `ensure_job_scout_tables()` — no manual provisioning needed.
