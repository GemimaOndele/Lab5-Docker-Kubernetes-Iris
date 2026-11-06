#!/usr/bin/env bash
# Exécuter depuis la racine du dépôt dans Codespaces.
# Aucune création de ressource Azure, aucun nettoyage global de Docker.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p evidence/partie1
exec > >(tee evidence/partie1/execution.log) 2>&1
date -u +'%FT%TZ'
docker version
docker info --format 'Architecture={{.Architecture}} OS={{.OSType}}'
df -h .
docker run --rm hello-world
docker build --progress=plain -f Dockerfile.naive -t iris-api:naive .
docker build --progress=plain --build-arg APP_VERSION=1.0.0 -t iris-api:v1 .
docker image inspect iris-api:naive iris-api:v1 --format '{{json .RepoTags}} bytes={{.Size}} id={{.Id}}' | tee evidence/partie1/images.txt
if docker container inspect iris-lab5-go >/dev/null 2>&1; then
    echo 'Arrêt : iris-lab5-go existe déjà. Examiner ce conteneur avant de relancer.'
    exit 1
fi
docker run -d --name iris-lab5-go -p 127.0.0.1:8000:8000 iris-api:v1
for ((i=0;i<60;i++)); do
    health=$(docker inspect --format '{{.State.Health.Status}}' iris-lab5-go)
    [[ "$health" == healthy ]] && break
    [[ "$health" == unhealthy ]] && { docker logs iris-lab5-go; exit 1; }
    sleep 2
done
[[ "$health" == healthy ]]
docker ps --filter name=iris-lab5-go | tee evidence/partie1/conteneur.txt
docker exec iris-lab5-go whoami | tee evidence/partie1/utilisateur.txt
curl --fail --silent http://127.0.0.1:8000/health | tee evidence/partie1/health.json
printf '\n'
curl --fail --silent http://127.0.0.1:8000/ready | tee evidence/partie1/ready.json
printf '\n'
curl --fail --silent -H 'Content-Type: application/json' -d '{"features":[5.1,3.5,1.4,0.2]}' http://127.0.0.1:8000/predict | tee evidence/partie1/prediction.json
printf '\n'
docker run --rm -e PYTHONPATH=/app -v "$PWD/tests:/tests:ro" -v "$PWD/requirements-dev.txt:/tmp/requirements-dev.txt:ro" --entrypoint sh iris-api:v1 -c 'python -m venv --system-site-packages /tmp/testenv && /tmp/testenv/bin/pip install --no-cache-dir -r /tmp/requirements-dev.txt && /tmp/testenv/bin/python -m pytest -q -p no:cacheprovider /tests'
echo 'PARTIE1_TESTS_OK — analyse de vulnérabilités et expérience du cache encore à effectuer.'

