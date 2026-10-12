# AcadNexa Backend (FastAPI + PostgreSQL)

Enterprise Multi-Tenant Campus Management System REST API built with FastAPI, SQLAlchemy, and PostgreSQL.

---

## 🚀 Cloud Deployment Guide

### Deploying on Render (Free Web Service)
1. In Render Dashboard, click **New +** -> **Web Service**.
2. Connect this repository: `AcadNexa-Backend`.
3. Set the following configuration:
   - **Environment**: `Python 3`
   - **Region**: Closest to you (e.g., Singapore or Oregon)
   - **Branch**: `main`
   - **Build Command**: `pip install -r requirements.txt`
   - **Start Command**: `uvicorn app.main:app --host 0.0.0.0 --port $PORT`
4. Add the following **Environment Variables**:
   - `POSTGRES_USER`: (from your Supabase database settings)
   - `POSTGRES_PASSWORD`: (from your Supabase database settings)
   - `POSTGRES_HOST`: (e.g. `db.<project-ref>.supabase.co`)
   - `POSTGRES_PORT`: `5432` or `6543`
   - `POSTGRES_DB`: `postgres`
   - `SECRET_KEY`: `acadnexa-production-secret-jwt-token-key-2026`
   - `ENVIRONMENT`: `production`
   - `DEBUG`: `False`

### Deploying on Railway
1. Click **New Project** -> **Deploy from GitHub repo**.
2. Select `AcadNexa-Backend`.
3. Railway automatically detects Python and uses the `Procfile` or `Dockerfile`.
4. Under **Variables**, add the PostgreSQL credentials from Supabase.

---

## 🛠 Local Setup & Running
```bash
# Install dependencies
pip install -r requirements.txt

# Run migrations / seed database
python seed_db.py

# Run API server
uvicorn app.main:app --reload --port 8000
```
- API Root: `http://localhost:8000`
- Swagger Interactive Docs: `http://localhost:8000/docs`
