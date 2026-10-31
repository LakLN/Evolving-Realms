"""Optional local content service bootstrap; never needed for gameplay."""
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
from service.providers import Settings, GenerationError, generate

app = FastAPI(title="Evolving Realms Content Service", version="0.2.0")


@app.get("/health")
def health() -> dict:
    return {"status": "ok", "provider": "none", "schema_version": 1}


class GenerationRequest(BaseModel):
    request_id: str = Field(min_length=1, max_length=128)
    kind: str
    prompt: str = Field(min_length=1, max_length=4096)
    context: dict
    allow_network: bool = False


@app.post("/generate")
def generate_content(body: GenerationRequest) -> dict:
    # Stateless authoring endpoint. It never opens or writes a game database.
    try:
        return generate(body.model_dump(exclude={"allow_network"}), Settings.from_env(), body.allow_network)
    except (GenerationError, ValueError) as exc:
        raise HTTPException(status_code=422, detail=str(exc) if isinstance(exc, GenerationError) else "Invalid JSON request") from None
