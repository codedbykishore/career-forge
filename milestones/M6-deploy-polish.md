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
| LaTeX compile | Docker `texlive/texlive:latest` (runs on EC2) | — |
| GitHub auth | GitHub App (private key in Secrets Manager) | AWS Secrets Manager |
| Job scraping | APScheduler + jobspy, triggered via `POST /api/jobs/scrape` | — (no Lambda) |

**DynamoDB tables (all in us-east-1):**
- From M0: `Users`, `Projects`, `Resumes`, `Jobs`, `Applications`, `Roadmaps`
- From M3: `SkillGapReports` ← **must be created manually before first run**
- Auto-created on startup: `UserJobStatuses`, `BlacklistedCompanies`

---

## Tasks

### 6.0 — Pre-flight: Fix Config for Production

Before provisioning EC2, these code/config changes MUST be made:

- [ ] **CORS: make Amplify URL dynamic** — update `project/backend/app/main.py` to read `ALLOWED_ORIGINS` from an env var and append it to the `allow_origins` list:
  ```python
  import os
  extra = [o for o in os.getenv("ALLOWED_ORIGINS", "").split(",") if o]
  allow_origins = ["http://localhost:3000", "http://localhost:3001", ...] + extra
  ```
- [ ] **GitHub callback URL** — update GitHub App settings (GitHub Developer Console) to add the Amplify production callback URL: `https://<amplify-url>/api/auth/callback/github`. Also set env var `GITHUB_CALLBACK_URL=https://<amplify-url>/api/auth/callback/github` on EC2.
- [ ] **Backend `.env` file** — create `project/backend/.env` with:
  ```
  APP_ENV=production
  DEBUG=False
  SECRET_KEY=<generate-64-char-random>
  USE_DYNAMO=True
  AWS_REGION=us-east-1
  S3_BUCKET=careerforge-pdfs-602664593597
  BEDROCK_MODEL_ID=us.anthropic.claude-sonnet-4-6
  GITHUB_APP_ID=<value>
  GITHUB_APP_CLIENT_ID=<value>
  GITHUB_APP_CLIENT_SECRET=<value>
  GITHUB_CALLBACK_URL=https://<amplify-url>/api/auth/callback/github
  ALLOWED_ORIGINS=https://<amplify-url>
  ```
- [ ] **Verify `SkillGapReports` DynamoDB table exists** in AWS console (it was not provisioned in M0, only added in M3):
  ```bash
  aws dynamodb describe-table --table-name SkillGapReports --region us-east-1
  # If missing:
  aws dynamodb create-table \
    --table-name SkillGapReports \
    --attribute-definitions AttributeName=userId,AttributeType=S AttributeName=reportId,AttributeType=S \
    --key-schema AttributeName=userId,KeyType=HASH AttributeName=reportId,KeyType=RANGE \
    --billing-mode PAY_PER_REQUEST \
    --region us-east-1
  ```

### 6.1 — Backend Deployment (EC2)

- [ ] Launch EC2 `t3.micro` in us-east-1 (free tier)
- [ ] Security group: open ports `22` (SSH), `80` (HTTP via Nginx), `8000` (direct API, lock to your IP for safety)
- [ ] **Attach IAM role** with these policies (NO hardcoded keys on EC2):
  - `AmazonBedrockFullAccess`
  - `AmazonS3FullAccess` (scoped to `careerforge-pdfs-602664593597`)
  - `AmazonDynamoDBFullAccess`
  - `SecretsManagerReadWrite` (for GitHub App private key at `careerforge/github-app-private-key`)
- [ ] SSH in and install dependencies — **Docker is required for LaTeX compilation**:
  ```bash
  sudo apt update
  sudo apt install -y python3.11 python3.11-venv nginx git docker.io
  sudo systemctl enable docker && sudo systemctl start docker
  sudo usermod -aG docker ubuntu
  # Pull LaTeX image now (large download, do this early)
  sudo docker pull texlive/texlive:latest
  ```
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
  After=network.target docker.service
  Requires=docker.service

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
- [ ] Set environment variables in Amplify console:
  - `NEXT_PUBLIC_API_URL=http://<ec2-public-ip>` (no trailing slash)
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

- [ ] Loading skeletons for all Bedrock-backed operations (3–10s latency on Claude Sonnet)
- [ ] Error states: user-friendly messages, not raw `500 Internal Server Error`
- [ ] Add "Powered by Amazon Bedrock" badge on resume generator and skill gap pages
- [ ] Career role selection: 2×4 card grid with icons (already in skill-gap-shell.tsx — verify looks good)
- [ ] Radar chart: 800ms smooth animation on render (already in Recharts config — verify deployed)
- [ ] Mobile responsive check — judges may test on phones
- [ ] Consistent colour scheme and typography across all pages
- [ ] Navigation: Dashboard → Resume → Skill Gap → LearnWeave → Jobs → Applications

### 6.5 — Pre-populate Demo Data

- [ ] Trigger job scrape: `POST http://<ec2-ip>/api/jobs/scrape` — loads 12 mock jobs into DynamoDB (auto-falls back to mock data if `jobspy` fails)
- [ ] Generate 2–3 base resumes for a demo GitHub account
- [ ] Run skill gap analysis for "Backend SDE" and "ML Engineer" roles
- [ ] Generate 1 LearnWeave roadmap
- [ ] Create application records in each Kanban status (saved, applied, interviewing, offered, rejected)
- [ ] **Backup:** Screenshot every page in case live demo fails on stage

### 6.6 — Architecture Diagram & Submission

- [ ] Take screenshots of `docs/career-architecture.html` for presentation slides
- [ ] Prepare AWS cost breakdown slide:
  | Service | What It Does | Estimated Cost |
  |---------|-------------|---------------|
  | Bedrock (`us.anthropic.claude-sonnet-4-6` + Titan) | Resume gen, skill gap, tailoring, job analysis | ~$3.00 |
  | DynamoDB (9 tables, PAY_PER_REQUEST) | All structured data | ~$0 |
  | S3 (`careerforge-pdfs-602664593597`) | PDFs, .tex files, project summaries | ~$0.01 |
  | EC2 t3.micro | API + LaTeX compiler (Docker) | ~$0 (free tier) |
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

1. **Docker is mandatory on EC2** — `latex_service.py` uses `texlive/texlive:latest` Docker container for PDF compilation. Without Docker, resume generation fails. Install Docker and add `ubuntu` user to `docker` group before starting the service.

2. **`SkillGapReports` table was NOT provisioned in M0** — M0 created 6 tables; M3 added a 7th (`SkillGapReports`). Create it manually before deploying (see step 6.0).

3. **CORS is hardcoded** — `app/main.py` has a hardcoded list of allowed origins that doesn't include the Amplify URL. Add `ALLOWED_ORIGINS` env var support before deploying (see step 6.0).

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
- The `texlive/texlive:latest` pull is ~4GB. Do it as the very first step after SSH to EC2, while setting everything else up.
- `UserJobStatuses` and `BlacklistedCompanies` tables are auto-created on app startup via `ensure_job_scout_tables()` — no manual provisioning needed.
