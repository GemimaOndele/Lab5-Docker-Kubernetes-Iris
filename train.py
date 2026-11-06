"""Train the Iris classifier and save it with its metadata.

Run at image build time (Dockerfile, stage 1):  python train.py model/model.joblib
"""
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

import joblib
import sklearn
from sklearn.datasets import load_iris
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score
from sklearn.model_selection import train_test_split

OUT = Path(sys.argv[1] if len(sys.argv) > 1 else "model/model.joblib")


def main() -> None:
    iris = load_iris()                       # dataset shipped with scikit-learn
    X_train, X_test, y_train, y_test = train_test_split(
        iris.data, iris.target, test_size=0.2,
        random_state=42, stratify=iris.target)
    model = RandomForestClassifier(n_estimators=100, random_state=42)
    model.fit(X_train, y_train)
    acc = accuracy_score(y_test, model.predict(X_test))

    meta = {
        "accuracy": round(float(acc), 4),
        "sklearn": sklearn.__version__,
        "trained_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    joblib.dump({"model": model,
                 "classes": [str(c) for c in iris.target_names],
                 "meta": meta}, OUT)
    print(f"Model saved to {OUT} - test accuracy = {acc:.3f}")
    print(json.dumps(meta))


if __name__ == "__main__":
    main()
