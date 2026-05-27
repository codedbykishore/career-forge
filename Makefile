.PHONY: help install install-backend install-frontend backend frontend lint lint-frontend clean

help:
	@echo "Usage:"
	@echo "  make install         Install backend & frontend dependencies"
	@echo "  make install-backend Install backend Python deps (via pip)"
	@echo "  make install-frontend Install frontend npm deps"
	@echo "  make backend         Run backend (uvicorn) on :8000"
	@echo "  make frontend        Run frontend (Next.js) on :3000"
	@echo "  make lint            Run frontend linter (next lint)"
	@echo "  make clean           Remove node_modules, venv, caches"

BACKEND_DIR = project/backend
FRONTEND_DIR = project/frontend
VENV_PYTHON = $(BACKEND_DIR)/venv/bin/python

install: install-backend install-frontend

install-backend:
	@echo "==> Installing backend dependencies..."
	$(VENV_PYTHON) -m pip install -q -r $(BACKEND_DIR)/requirements.txt

install-frontend:
	@echo "==> Installing frontend dependencies..."
	npm --prefix $(FRONTEND_DIR) install

backend:
	@echo "==> Starting backend on http://localhost:8000"
	cd $(BACKEND_DIR) && $(VENV_PYTHON) -m uvicorn app.main:app --reload --port 8000

frontend:
	@echo "==> Starting frontend on http://localhost:3000"
	npm --prefix $(FRONTEND_DIR) run dev

lint: lint-frontend

lint-frontend:
	npm --prefix $(FRONTEND_DIR) run lint

clean:
	rm -rf $(FRONTEND_DIR)/node_modules $(FRONTEND_DIR)/.next
	rm -rf $(BACKEND_DIR)/venv
	rm -rf __pycache__ .pytest_cache
	find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
