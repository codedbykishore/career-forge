#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# CareerForge — Pre-flight DynamoDB Setup (M6 — 6.0)
# Creates the SkillGapReports table that was added in M3 (not in M0 provisioning)
# Also verifies all 9 expected tables exist
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

REGION="${1:-us-east-1}"
PROFILE="${AWS_PROFILE:-careerforge-dev}"

echo "═══════════════════════════════════════════"
echo "  CareerForge DynamoDB Pre-flight Check"
echo "  Region: $REGION | Profile: $PROFILE"
echo "═══════════════════════════════════════════"

# All 9 expected tables
TABLES=(
  "Users"
  "Projects"
  "Resumes"
  "Jobs"
  "Applications"
  "Roadmaps"
  "SkillGapReports"
  "UserJobStatuses"
  "BlacklistedCompanies"
)

# ── Check / create SkillGapReports ───────────────────────────────────────────
echo ""
echo "→ Checking SkillGapReports table..."
if aws dynamodb describe-table \
  --table-name SkillGapReports \
  --region "$REGION" \
  --profile "$PROFILE" > /dev/null 2>&1; then
  echo "  ✅ SkillGapReports already exists"
else
  echo "  ⚠️  SkillGapReports not found — creating..."
  aws dynamodb create-table \
    --table-name SkillGapReports \
    --attribute-definitions \
      AttributeName=userId,AttributeType=S \
      AttributeName=reportId,AttributeType=S \
    --key-schema \
      AttributeName=userId,KeyType=HASH \
      AttributeName=reportId,KeyType=RANGE \
    --billing-mode PAY_PER_REQUEST \
    --region "$REGION" \
    --profile "$PROFILE"
  
  echo "  ⏳ Waiting for table to become ACTIVE..."
  aws dynamodb wait table-exists \
    --table-name SkillGapReports \
    --region "$REGION" \
    --profile "$PROFILE"
  echo "  ✅ SkillGapReports created successfully"
fi

# ── Verify all tables ────────────────────────────────────────────────────────
echo ""
echo "→ Verifying all 9 DynamoDB tables..."
ALL_OK=true
for TABLE in "${TABLES[@]}"; do
  if aws dynamodb describe-table \
    --table-name "$TABLE" \
    --region "$REGION" \
    --profile "$PROFILE" > /dev/null 2>&1; then
    echo "  ✅ $TABLE"
  else
    echo "  ❌ $TABLE — MISSING"
    ALL_OK=false
    # Note: UserJobStatuses and BlacklistedCompanies are auto-created on app startup
    if [[ "$TABLE" == "UserJobStatuses" || "$TABLE" == "BlacklistedCompanies" ]]; then
      echo "     ^ This table is auto-created when the app starts (ensure_job_scout_tables)"
    fi
  fi
done

echo ""
if $ALL_OK; then
  echo "✅ All 9 DynamoDB tables verified!"
else
  echo "⚠️  Some tables are missing. Start the app to auto-create job scout tables, or create manually."
fi
