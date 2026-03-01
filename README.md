# GrowMate

GrowMate is a scalable platform comprising a dynamic mobile application and a robust orchestration backend. This repository represents the definitive, strictly-separated project structure.

## Repository Structure

- `frontend/`: Contains the complete Flutter codebase, including UI, state management, and API clients. Deployable independently to mobile/web platforms.
- `orchestrator/`: Contains the Python backend (FastAPI), managing services, database connections (Supabase), and external API integrations. Deployable independently via Docker/Render.
- `docs/`: Master integration specifications and cross-platform mobile guides.

See individual `README.md` files in `frontend/` and `orchestrator/` for setup and deployment details.
