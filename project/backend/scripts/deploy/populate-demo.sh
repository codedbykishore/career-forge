#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# CareerForge — Pre-populate Demo Data (M6 — 6.5)
# Run after backend is deployed to seed demo data
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

API_URL="${1:-http://localhost:8000}"
TOKEN="${2:-}"

echo "═══════════════════════════════════════════"
echo "  CareerForge Demo Data Population"
echo "  API: $API_URL"
echo "═══════════════════════════════════════════"

# Helper function
call_api() {
  local method="$1"
  local endpoint="$2"
  local data="${3:-}"
  local auth_header=""
  
  if [ -n "$TOKEN" ]; then
    auth_header="-H 'Authorization: Bearer $TOKEN'"
  fi
  
  if [ "$method" = "GET" ]; then
    eval curl -sf "$auth_header" "$API_URL$endpoint" 2>/dev/null || echo '{"error": "request failed"}'
  else
    eval curl -sf -X "$method" \
      -H "'Content-Type: application/json'" \
      "$auth_header" \
      -d "'$data'" \
      "$API_URL$endpoint" 2>/dev/null || echo '{"error": "request failed"}'
  fi
}

# ── 1. Trigger Job Scrape ────────────────────────────────────────────────────
echo ""
echo "→ Step 1: Triggering job scrape..."
SCRAPE_RESULT=$(call_api POST "/api/jobs/scrape")
echo "  Result: $SCRAPE_RESULT"

# ── 2. Verify Health ────────────────────────────────────────────────────────
echo ""
echo "→ Step 2: Checking API health..."
HEALTH=$(call_api GET "/api/health")
echo "  Health: $HEALTH"

# ── 3. Check Job Stats ──────────────────────────────────────────────────────
echo ""
echo "→ Step 3: Checking job stats..."
if [ -n "$TOKEN" ]; then
  STATS=$(call_api GET "/api/jobs/stats")
  echo "  Stats: $STATS"
else
  echo "  ⚠️  No auth token provided — skipping authenticated endpoints"
  echo "  Usage: $0 <api_url> <jwt_token>"
fi

# ── 4. Check Available Roles ────────────────────────────────────────────────
echo ""
echo "→ Step 4: Checking skill gap roles..."
if [ -n "$TOKEN" ]; then
  ROLES=$(call_api GET "/api/skill-gap/roles")
  echo "  Roles available: $(echo "$ROLES" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(len(d.get("roles",[])))' 2>/dev/null || echo 'parse error')"
fi

echo ""
echo "═══════════════════════════════════════════"
echo "  Demo data population complete!"
echo ""
echo "  Remaining manual steps:"
echo "    1. Log in via GitHub OAuth"
echo "    2. Import repos → generate base resumes"
echo "    3. Run skill gap for 'Backend SDE' & 'ML Engineer'"
echo "    4. Generate 1 LearnWeave roadmap"
echo "    5. Create applications in each Kanban status"
echo "    6. Screenshot every page as backup"
echo "═══════════════════════════════════════════"
