"""Iris prediction API (FastAPI) - Lab 5 DSCC, ECE Paris."""
import asyncio
import logging
import os
import secrets
import socket
from contextlib import asynccontextmanager
from pathlib import Path

import joblib
import numpy as np
from fastapi import FastAPI, Header, HTTPException
from pydantic import BaseModel, Field

# --- Configuration: read from environment variables (12-factor app) ---
APP_VERSION = os.getenv("APP_VERSION", "dev")        # set at build time
ENVIRONMENT = os.getenv("ENVIRONMENT", "local")      # from a ConfigMap
MODEL_PATH = Path(os.getenv("MODEL_PATH", "model/model.joblib"))
STARTUP_DELAY = float(os.getenv("STARTUP_DELAY", "0"))  # simulates a big model
API_KEY = os.getenv("API_KEY", "")                   # from a Secret
REDIS_HOST = os.getenv("REDIS_HOST", "")             # optional shared counter
POD = socket.gethostname()                           # = pod name in Kubernetes

logging.basicConfig(level=os.getenv("LOG_LEVEL", "INFO"),
                    format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("iris-api")
state = {"model": None, "classes": [], "meta": {}, "count": 0}


def counter(increment: bool) -> int:
    """Prediction counter: shared in Redis if configured, else per process."""
    if REDIS_HOST:
        import redis
        r = redis.Redis(host=REDIS_HOST, socket_timeout=1)
        return int(r.incr("predictions") if increment
                   else r.get("predictions") or 0)
    state["count"] += int(increment)
    return state["count"]


@asynccontextmanager
async def lifespan(app: FastAPI):
    await asyncio.sleep(STARTUP_DELAY)              # e.g. downloading weights
    bundle = joblib.load(MODEL_PATH)
    state.update(model=bundle["model"], classes=bundle["classes"],
                 meta=bundle["meta"])
    log.info("Model loaded (version=%s, accuracy=%s)",
             APP_VERSION, bundle["meta"]["accuracy"])
    yield
    state["model"] = None


app = FastAPI(title="Iris API", version=APP_VERSION, lifespan=lifespan)


class Features(BaseModel):
    features: list[float] = Field(min_length=4, max_length=4,
                                  examples=[[5.1, 3.5, 1.4, 0.2]])


@app.get("/")
def root():
    return {"service": "iris-api", "version": APP_VERSION,
            "environment": ENVIRONMENT, "pod": POD}


@app.get("/health")                  # liveness: the process answers
def health():
    return {"status": "ok"}


@app.get("/ready")                   # readiness: the model is loaded
def ready():
    if state["model"] is None:
        raise HTTPException(status_code=503, detail="model not loaded")
    return {"status": "ready", "model": state["meta"]}


@app.post("/predict")
def predict(item: Features):
    if state["model"] is None:
        raise HTTPException(status_code=503, detail="model not loaded")
    X = np.array(item.features, dtype=float).reshape(1, -1)
    proba = state["model"].predict_proba(X)[0]
    best = int(np.argmax(proba))
    n = counter(increment=True)
    log.info("prediction #%d: %s (%.2f)", n, state["classes"][best], proba[best])
    return {"class": state["classes"][best],
            "confidence": round(float(proba[best]), 3),
            "probabilities": {c: round(float(p), 3)
                              for c, p in zip(state["classes"], proba)},
            "version": APP_VERSION, "pod": POD}


@app.get("/stats")
def stats():
    return {"predictions": counter(increment=False),
            "backend": "redis" if REDIS_HOST else "memory", "pod": POD}


@app.get("/admin/config")
def admin_config(x_api_key: str = Header(default="")):
    if not API_KEY:
        raise HTTPException(status_code=503, detail="admin disabled (no API_KEY)")
    if not secrets.compare_digest(x_api_key, API_KEY):
        raise HTTPException(status_code=401, detail="invalid API key")
    return {"version": APP_VERSION, "environment": ENVIRONMENT,
            "log_level": os.getenv("LOG_LEVEL", "INFO"),
            "model": state["meta"], "pod": POD}
