#!/usr/bin/env bash
# Cluster d'apprentissage dédié au Lab 5, aucune action sur AKS.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p evidence/partie3
exec > >(tee evidence/partie3/preparation.log) 2>&1
PROFILE=lab5-go
date -u +'%FT%TZ'
minikube start -p "$PROFILE" --driver=docker --cpus=2 --memory=4096
minikube -p "$PROFILE" addons enable metrics-server
minikube -p "$PROFILE" image load iris-api:v1
kc() { kubectl --context="$PROFILE" --namespace=iris "$@"; }
kc apply -f k8s/namespace.yaml
kc apply -f k8s/configmap.yaml
if ! kc get secret iris-secret >/dev/null 2>&1; then
    kc create secret generic iris-secret --from-literal=API_KEY="$(openssl rand -hex 16)"
fi
kc apply -f k8s/deployment.yaml -f k8s/service.yaml
kc rollout status deployment/iris-api --timeout=240s
kc get pods -o wide | tee evidence/partie3/pods-initial.txt
kc get all | tee evidence/partie3/objets-initial.txt
kc describe deployment iris-api > evidence/partie3/deployment.txt
kc logs -l app=iris-api --tail=10 > evidence/partie3/journaux-initial.txt
kc exec deployment/iris-api -- id | tee evidence/partie3/identite.txt
kc get nodes -o wide
echo 'PARTIE3_DEPLOIEMENT_OK — expériences à exécuter séparément.'

