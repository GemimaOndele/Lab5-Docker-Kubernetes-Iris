from fastapi.testclient import TestClient

from app.main import app


def test_health_ready_predict():
    with TestClient(app) as client:          # runs the lifespan: loads the model
        assert client.get("/health").json() == {"status": "ok"}
        assert client.get("/ready").status_code == 200
        r = client.post("/predict", json={"features": [5.1, 3.5, 1.4, 0.2]})
        assert r.status_code == 200
        assert r.json()["class"] == "setosa"


def test_bad_input_is_rejected():
    with TestClient(app) as client:
        r = client.post("/predict", json={"features": [1.0, 2.0]})
        assert r.status_code == 422           # validated by Pydantic
