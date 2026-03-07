# M6 — Deploy, Polish & Demo — Implementation Report

**Status:** ✅ Complete (code & scripts)  
**Date:** March 8, 2026  
**Milestone:** [M6-deploy-polish.md](../M6-deploy-polish.md)  
**Depends on:** M2 (Resume Generator), M3 (Skill Gap), M4 (Job Scout), M5 (Tailored Apply)  
**Unlocks:** Hackathon submission

---

## Summary

Implemented all code-level changes for M6: UI polish with loading skeletons, error boundaries, "Powered by Amazon Bedrock" badges across all AI-powered pages, mobile-responsive sidebar, and deployment automation scripts for EC2 + Amplify + DynamoDB. Infrastructure deployment (EC2 launch, Amplify connect, IAM roles) remains manual as those require AWS Console actions.

---

## Tasks Completed

### 6.0 — Pre-flight: Configuration for Production

| Item | File | Status |
|------|------|--------|
| CORS dynamic origins | `app/main.py` | ✅ (pre-existing) |
| `ALLOWED_ORIGINS` in config | `app/core/config.py` | ✅ (pre-existing) |
| LaTeX timeout 60s | `app/core/config.py` | ✅ (pre-existing) |
| DEBUG guards for /docs | `app/main.py` | ✅ (pre-existing) |
| DynamoDB preflight script | `scripts/deploy/preflight-dynamo.sh` | ✅ New |
| Production .env template | `scripts/deploy/.env.production.template` | ✅ New |

### 6.1 — Backend Deployment (EC2)

| Item | File | Status |
|------|------|--------|
| EC2 setup script (apt, venv, systemd, nginx) | `scripts/deploy/setup-ec2.sh` | ✅ New |
| Systemd service file (embedded in script) | `scripts/deploy/setup-ec2.sh` | ✅ New |
| Nginx reverse proxy config (120s timeout) | `scripts/deploy/setup-ec2.sh` | ✅ New |

### 6.2 — Frontend Deployment (Amplify)

| Item | File | Status |
|------|------|--------|
| Amplify build spec | `amplify.yml` | ✅ New |
| Next.js standalone build config | `project/frontend/next.config.js` | ✅ (pre-existing) |

### 6.4 — UI Polish

| Item | File | Status |
|------|------|--------|
| `Skeleton` base component | `components/ui/skeleton.tsx` | ✅ New |
| `CardSkeleton` placeholder | `components/ui/skeleton.tsx` | ✅ New |
| `TableRowSkeleton` for list views | `components/ui/skeleton.tsx` | ✅ New |
| `ResumeListSkeleton` | `components/ui/skeleton.tsx` | ✅ New |
| `SkillGapSkeleton` | `components/ui/skeleton.tsx` | ✅ New |
| `KanbanSkeleton` | `components/ui/skeleton.tsx` | ✅ New |
| `BedrockLoadingSkeleton` (AI operations) | `components/ui/skeleton.tsx` | ✅ New |
| `ErrorBoundary` class component | `components/ui/error-boundary.tsx` | ✅ New |
| `ErrorState` inline error display | `components/ui/error-boundary.tsx` | ✅ New |
| `EmptyState` zero-data placeholder | `components/ui/error-boundary.tsx` | ✅ New |
| `BedrockBadge` (inline/footer/compact) | `components/ui/bedrock-badge.tsx` | ✅ New |
| Bedrock badge on Skill Gap page | `components/dashboard/skill-gap-shell.tsx` | ✅ Modified |
| Bedrock loading in Skill Gap analysis | `components/dashboard/skill-gap-shell.tsx` | ✅ Modified |
| Bedrock badge on Resumes page | `components/dashboard/resumes-list.tsx` | ✅ Modified |
| Bedrock loading in Resume generator | `components/dashboard/resumes-list.tsx` | ✅ Modified |
| Bedrock badge on Apply & Track panel | `components/dashboard/apply-shell.tsx` | ✅ Modified |
| Bedrock loading in Tailored Resume | `components/dashboard/apply-shell.tsx` | ✅ Modified |
| Bedrock badge on Job Scout page | `components/dashboard/job-scout-shell.tsx` | ✅ Modified |
| ErrorBoundary wrapping dashboard content | `app/dashboard/page.tsx` | ✅ Modified |
| Mobile sidebar overlay (responsive) | `app/dashboard/page.tsx` | ✅ Modified |
| Responsive content padding (p-4 sm:p-6) | `app/dashboard/page.tsx` | ✅ Modified |

### 6.5 — Demo Data Population

| Item | File | Status |
|------|------|--------|
| Demo data population script | `scripts/deploy/populate-demo.sh` | ✅ New |

### 6.6 — Architecture & Submission

| Item | Status |
|------|--------|
| AWS cost breakdown | ✅ See below |
| Amplify build configuration | ✅ `amplify.yml` |

---

## New Files Created

| File | Purpose |
|------|---------|
| `project/frontend/src/components/ui/skeleton.tsx` | Loading skeleton components for all views |
| `project/frontend/src/components/ui/error-boundary.tsx` | Error boundary + error/empty states |
| `project/frontend/src/components/ui/bedrock-badge.tsx` | "Powered by Amazon Bedrock" badge |
| `project/backend/scripts/deploy/setup-ec2.sh` | Full EC2 deployment automation |
| `project/backend/scripts/deploy/.env.production.template` | Production env var template |
| `project/backend/scripts/deploy/preflight-dynamo.sh` | DynamoDB table verification/creation |
| `project/backend/scripts/deploy/populate-demo.sh` | Demo data seeding script |
| `amplify.yml` | AWS Amplify build specification |

## Files Modified

| File | Changes |
|------|---------|
| `project/frontend/src/app/dashboard/page.tsx` | ErrorBoundary wrapper, mobile sidebar overlay, responsive padding |
| `project/frontend/src/components/dashboard/skill-gap-shell.tsx` | BedrockBadge, BedrockLoadingSkeleton |
| `project/frontend/src/components/dashboard/resumes-list.tsx` | BedrockBadge, BedrockLoadingSkeleton |
| `project/frontend/src/components/dashboard/apply-shell.tsx` | BedrockBadge, BedrockLoadingSkeleton |
| `project/frontend/src/components/dashboard/job-scout-shell.tsx` | BedrockBadge |
| `milestones/M6-deploy-polish.md` | Checked off completed items |

---

## AWS Cost Breakdown (Estimated for Hackathon Demo)

| Service | What It Does | Estimated Cost |
|---------|-------------|---------------|
| Bedrock (`us.anthropic.claude-sonnet-4-6` + Titan Embeddings v2) | Resume gen, skill gap analysis, tailoring, job analysis | ~$3.00 |
| DynamoDB (9 tables, PAY_PER_REQUEST) | All structured data (users, projects, resumes, jobs, applications, roadmaps, skill gap reports, tracking) | ~$0 |
| S3 (`careerforge-pdfs-602664593597`) | PDFs, .tex files, project summaries | ~$0.01 |
| EC2 t3.micro | FastAPI server (LaTeX via ytotech free API) | ~$0 (free tier) |
| Amplify | Next.js 14 standalone hosting | ~$0 |
| Secrets Manager | GitHub App private key storage | ~$0.01 |
| **Total** | | **~$3–4** |

---

## Deployment Architecture

```
┌──────────────┐     HTTPS      ┌──────────────────────┐
│  Browser      │──────────────▶│  AWS Amplify           │
│  (Next.js)    │               │  (Next.js 14 SSR)      │
└──────┬───────┘               └──────────────────────┘
       │ API calls                        │
       ▼                                  │
┌──────────────┐     HTTP/80    ┌─────────▼────────────┐
│  Nginx        │◀─────────────│  EC2 t3.micro         │
│  (reverse     │               │  (us-east-1)          │
│   proxy)      │──────────────▶│                       │
└──────────────┘  127.0.0.1:8000│  FastAPI + Uvicorn    │
                                │  + APScheduler        │
                                └───────┬──────────────┘
                                        │
                    ┌───────────────────┬┼─────────────────┐
                    │                   ││                  │
              ┌─────▼────┐    ┌────────▼▼──┐    ┌─────────▼────┐
              │ DynamoDB   │    │ S3 Bucket  │    │ Bedrock       │
              │ 9 tables   │    │ PDFs, .tex │    │ Claude 4.6    │
              │ PAY_PER_REQ│    │ summaries  │    │ Titan Embed   │
              └────────────┘    └────────────┘    └───────────────┘
                                                         │
                                              ┌──────────▼──────┐
                                              │ Secrets Manager  │
                                              │ GitHub App key   │
                                              └─────────────────┘
```

---

## Remaining Manual Steps (Infrastructure)

These require AWS Console access and cannot be automated in code:

1. **Launch EC2 t3.micro** in us-east-1 with appropriate security group
2. **Attach IAM role** (Bedrock, S3, DynamoDB, SecretsManager)
3. **Run `setup-ec2.sh`** on the instance
4. **Create `.env`** from template with real secrets
5. **Run `preflight-dynamo.sh`** to verify all tables
6. **Connect repo to AWS Amplify** with env vars
7. **Update GitHub App callback URL** to Amplify domain
8. **Restart backend** after Amplify URL is known
9. **Run `populate-demo.sh`** to seed demo data
10. **Generate sample resumes** and run skill gap analysis manually
11. **Screenshot every page** as backup

---

## Verification

- [x] TypeScript compilation passes (`tsc --noEmit` — 0 errors)
- [x] All new components have no lint errors  
- [x] Loading skeletons display during Bedrock operations
- [x] "Powered by Amazon Bedrock" badge visible on all AI-powered pages
- [x] Error boundary catches and displays friendly error messages
- [x] Mobile sidebar overlays correctly on small screens
- [x] Deployment scripts are executable and self-documenting
- [ ] End-to-end smoke test (requires deployed infrastructure)
- [ ] Demo rehearsal (requires deployed infrastructure)
