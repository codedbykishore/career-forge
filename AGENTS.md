# CareerForge — Agent Instructions

## Project Structure
```
project/
├── backend/          # FastAPI (Python) - runs on port 8000
└── frontend/         # Next.js 14 (TypeScript) - runs on port 3000
```

## Running the App

**Frontend:**
```bash
cd project/frontend && npm run dev    # http://localhost:3000
```

**Backend:**
```bash
cd project/backend
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

## Key Configuration
- Backend env: `project/backend/.env` (copy from `.env.example`)
- Frontend env: `project/frontend/.env.local` (copy from `.env.local.example`)
- Toggle DynamoDB: `USE_DYNAMO=true/false` in backend env
- **Secrets load order:** AWS Secrets Manager → env vars → hardcoded defaults (only for non-secrets)

## Linting & Typecheck

**Frontend:**
```bash
cd project/frontend && npm run lint
```

**Backend:** No formal test/lint setup; use scripts in `project/backend/scripts/`:
```bash
cd project/backend && python scripts/test_resume_gen.py
python scripts/test_tailor.py
python scripts/test_aws_services.py
python scripts/test_full_stack.py
```

## AWS Services
- **LLM**: Bedrock (Claude 3 Haiku/3 Sonnet, default: `us.anthropic.claude-3-7-sonnet-20250219-v1:0`)
- **Embeddings**: Bedrock Titan Text v2 (`amazon.titan-embed-text-v2:0`)
- **Database**: DynamoDB (preferred) or SQLite (`USE_DYNAMO=true/false`)
- **Storage**: S3 for resumes/PDFs

## API Endpoints
- `/api/auth/*` — Authentication
- `/api/github/*` — GitHub repo ingestion
- `/api/projects/*` — Project management
- `/api/templates/*` — LaTeX templates
- `/api/jobs/*` — Job descriptions
- `/api/resumes/*` — Resume generation
- `/api/skill-gap/*` — Skill gap analysis
- `/api/project-roadmap/*` — Learning roadmaps
- `/api/applications/*` — Application tracking (prefix `/api`)

## Key Services
- `app/services/bedrock_client.py` — Bedrock LLM calls
- `app/services/resume_agent.py` — LaTeX resume generation
- `app/services/resume_tailor.py` — Per-job resume tailoring
- `app/services/github_service.py` — GitHub repo ingestion
- `app/services/job_scraper.py` — LinkedIn/Indeed scraping
- `app/services/naukri_scraper.py` — Naukri/Unstop/Internshala
- `app/services/dynamo_service.py` — DynamoDB operations
- `app/services/scheduler.py` — Hourly job scrape scheduler

## Important Quirks
- **LaTeX compile**: 60s timeout, 256MB memory limit (`app/core/config.py`)
- **Docs disabled** in production: `/docs` and `/redoc` hidden unless `DEBUG=true`
- **Startup**: Backend auto-creates DynamoDB tables and starts scheduler if `USE_DYNAMO=true`
- **Static files**: Mounted at `/uploads` from `settings.UPLOAD_DIR`

## References
- Workflow rules: see `.github/copilot-instructions.md` (plan-first, subagent strategy, self-improvement loop)
- Architecture: see `milestones/PROJECT.md` for full system design