# 🌾 GrowMate Orchestrator

The intelligent backend core for the GrowMate Farming Platform. This service orchestrates complex agricultural data streams (Weather, Soil, Market, Pest, and NDVI) to provide actionable, localized advisories for farmers.

---

## 🚀 Key Features

- **Multi-Stream Orchestration**: Fuses data from OGD (India), Agromonitoring, and localized APIs.
- **Bilingual Support**: Full English and Kannada localization for all advisory outputs.
- **Production Hardened**:
  - **Security**: Bcrypt hashing, JWT isolation, and SQL-injection-proof transactions.
  - **Performance**: GZip compression, lazy Redis caching, and circuit-broken parallel execution.
  - **Reliability**: Resilient shutdown hooks and connection pooling.

## 🛠️ Tech Stack

- **Framework**: FastAPI (Python 3.12)
- **Database**: PostgreSQL (via `asyncpg`)
- **Cache**: Redis
- **Deployment**: Docker (Multi-stage)

---

## 📦 Deployment (Render / Docker)

### Local Environment
1. Copy `.env.example` to `.env` and fill in secrets.
2. Run with Docker:
   ```bash
   docker build -t growmate-backend .
   docker run -p 8000:8000 growmate-backend
   ```

### Supabase Setup (Recommended)
1. Your project is already created at: `itssvxmskvwdlxnxurlr.supabase.co`
2. Your **Connection String** (Transaction Pooler - Port 6543) is:
   `postgresql://postgres.itssvxmskvwdlxnxurlr:wPt33MW7Os2UsmwF@aws-1-ap-southeast-2.pooler.supabase.com:6543/postgres`
3. Paste this exact string as the **`DATABASE_URL`** in your Render Dashboard.
   - **Note**: The backend will automatically initialize the schema on the first connection. No manual SQL is needed.

### Render Hosting
This repository is optimized for **Render**.
1. Connect this repo to Render.
2. The `render.yaml` will automatically provision a **Redis Instance** (for caching) and configure the **Web Service**.
3. Set your secret API keys and the Supabase `DATABASE_URL` in the Render Dashboard environment settings.

---

## 🧪 Testing

Run quality checks and unit tests:
```bash
# Style & Type Checking
flake8 app/
mypy app/

# Unit Tests
pytest tests/
```

Developed with ❤️ for the farming community.
