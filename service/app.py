"""Optional local content service bootstrap; never needed for gameplay."""
from fastapi import FastAPI

app = FastAPI(title="Evolving Realms Content Service", version="0.1.0")


@app.get("/health")
def health() -> dict:
    return {"status": "ok", "provider": "none", "schema_version": 1}
