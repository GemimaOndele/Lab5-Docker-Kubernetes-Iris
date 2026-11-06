#!/usr/bin/env bash
# Scanner officiel versionné ; aucun montage des identifiants Azure ou GitHub.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p evidence/partie1
exec > >(tee evidence/partie1/securite-cache.log) 2>&1
docker pull aquasec/trivy:0.76.1
SCANNER=$(docker image inspect aquasec/trivy:0.76.1 --format '{{index .RepoDigests 0}}')
printf '%s\n' "$SCANNER" | tee evidence/partie1/trivy-digest.txt
for tag in naive v1; do
    echo "Analyse de iris-api:$tag"
    docker run --rm -v /var/run/docker.sock:/var/run/docker.sock:ro \
        -v lab5-trivy-cache:/root/.cache/ "$SCANNER" image \
        --scanners vuln --severity HIGH,CRITICAL --format json "iris-api:$tag" \
        > "evidence/partie1/trivy-$tag.json" 2> "evidence/partie1/trivy-$tag.log"
done
python3 - <<'PY'
import json
from collections import Counter
from pathlib import Path
summary=[]
for tag in ['naive','v1']:
    d=json.loads(Path(f'evidence/partie1/trivy-{tag}.json').read_text())
    vs=[v for r in d.get('Results',[]) for v in r.get('Vulnerabilities',[])]
    c=Counter(v['Severity'] for v in vs)
    summary.append({'image':'iris-api:'+tag,'HIGH':c['HIGH'],'CRITICAL':c['CRITICAL'],'date_analyse':d.get('CreatedAt'),'unite':'occurrences de vulnérabilités par paquet'})
Path('evidence/partie1/cve-resume.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2))
print(json.dumps(summary,ensure_ascii=False,indent=2))
PY
CTX=$(mktemp -d /tmp/lab5-cache.XXXXXX)
cp Dockerfile requirements.txt train.py "$CTX/"
cp -r app "$CTX/app"
printf '\n# Lab 5 : modification sans effet pour observer le cache Docker.\n' >> "$CTX/app/main.py"
docker build --progress=plain --build-arg APP_VERSION=1.0.0 -t iris-api:cache-demo "$CTX" 2>&1 | tee evidence/partie1/cache-modification-code.log
docker build --progress=plain --build-arg APP_VERSION=2.0.0 -t iris-api:v2 .
docker image inspect iris-api:v1 iris-api:v2 --format '{{json .RepoTags}} {{.Os}}/{{.Architecture}}' | tee evidence/partie1/architecture-versions.txt
echo 'PARTIE1_SECURITE_CACHE_OK'

