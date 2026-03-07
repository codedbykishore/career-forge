#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# CareerForge EC2 Deployment Script (M6 — 6.1)
# Run this on a fresh Ubuntu 22.04 EC2 t3.micro instance
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

REPO_URL="${1:-https://github.com/your-org/career-forge.git}"
BRANCH="${2:-production}"
APP_DIR="/home/ubuntu/careerforge"

echo "═══════════════════════════════════════════"
echo "  CareerForge EC2 Setup — $(date)"
echo "═══════════════════════════════════════════"

# ── 1. System packages ───────────────────────────────────────────────────────
echo "→ Installing system dependencies..."
sudo apt update -y
sudo apt install -y python3.11 python3.11-venv python3-pip nginx git curl

# Optional: Install texlive for local LaTeX compilation (uncomment if needed)
# sudo apt install -y texlive-latex-base texlive-fonts-recommended texlive-latex-extra

# ── 2. Clone repo ───────────────────────────────────────────────────────────
if [ -d "$APP_DIR" ]; then
  echo "→ Repository already exists, pulling latest..."
  cd "$APP_DIR" && git pull origin "$BRANCH"
else
  echo "→ Cloning repository..."
  git clone -b "$BRANCH" "$REPO_URL" "$APP_DIR"
fi

# ── 3. Python virtual environment ────────────────────────────────────────────
echo "→ Setting up Python virtual environment..."
cd "$APP_DIR/project/backend"
python3.11 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# ── 4. .env check ────────────────────────────────────────────────────────────
if [ ! -f "$APP_DIR/project/backend/.env" ]; then
  echo ""
  echo "⚠️  WARNING: .env file not found at $APP_DIR/project/backend/.env"
  echo "   Copy the template and fill in real values:"
  echo "   cp $APP_DIR/project/backend/scripts/deploy/.env.production.template $APP_DIR/project/backend/.env"
  echo ""
fi

# ── 5. Systemd service ──────────────────────────────────────────────────────
echo "→ Installing systemd service..."
sudo tee /etc/systemd/system/careerforge.service > /dev/null <<EOF
[Unit]
Description=CareerForge API
After=network.target

[Service]
User=ubuntu
WorkingDirectory=$APP_DIR/project/backend
ExecStart=$APP_DIR/project/backend/venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8000 --workers 2
Restart=always
RestartSec=5
EnvironmentFile=$APP_DIR/project/backend/.env

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable careerforge
sudo systemctl start careerforge

# ── 6. Nginx reverse proxy ──────────────────────────────────────────────────
echo "→ Configuring Nginx reverse proxy..."
sudo tee /etc/nginx/sites-available/careerforge > /dev/null <<'NGINX'
server {
    listen 80;
    server_name _;

    client_max_body_size 20M;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 120s;
        proxy_connect_timeout 10s;
    }

    # Health check endpoint (no auth needed)
    location /api/health {
        proxy_pass http://127.0.0.1:8000;
        proxy_read_timeout 5s;
    }
}
NGINX

sudo ln -sf /etc/nginx/sites-available/careerforge /etc/nginx/sites-enabled/careerforge
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl restart nginx

# ── 7. Verify ────────────────────────────────────────────────────────────────
echo ""
echo "→ Waiting for service to start..."
sleep 3

if curl -sf http://127.0.0.1:8000/api/health > /dev/null 2>&1; then
  echo "✅ CareerForge API is running!"
  echo "   Health check: curl http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)/api/health"
else
  echo "⚠️  API not responding yet. Check logs:"
  echo "   sudo journalctl -u careerforge -f"
fi

echo ""
echo "═══════════════════════════════════════════"
echo "  Setup complete!"
echo "  Next steps:"
echo "    1. Create .env file if not done"  
echo "    2. sudo systemctl restart careerforge"
echo "    3. Verify: curl http://localhost/api/health"
echo "═══════════════════════════════════════════"
