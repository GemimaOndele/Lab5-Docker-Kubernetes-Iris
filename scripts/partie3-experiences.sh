#!/usr/bin/env bash
# Expériences du sujet limitées au profil minikube lab5-go et au namespace iris.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p evidence/partie3
exec > >(tee evidence/partie3/experiences.log) 2>&1
PROFILE=lab5-go
kc() { kubectl --context="$PROFILE" --namespace=iris "$@"; }
[[ "$(kc get deployment iris-api -o jsonpath='{.metadata.namespace}')" == iris ]]
[[ "$(minikube -p "$PROFILE" status --format='{{.Host}}')" == Running ]]
URL="http://$(minikube -p "$PROFILE" ip):$(kc get svc iris-api -o jsonpath='{.spec.ports[0].nodePort}')"
printf 'URL du service minikube : %s\n' "$URL"
curl --fail --silent --max-time 15 "$URL/"; printf '\n'
kc get pods -o wide

echo 'EXPERIENCE 1a — suppression d’un seul pod de démonstration'
POD=$(kc get pods -l app=iris-api -o jsonpath='{.items[0].metadata.name}')
kc get pod "$POD" -o jsonpath='{.metadata.name} {.metadata.uid}{"\n"}'
kc delete pod "$POD" --wait=false
START=$SECONDS
for ((i=0;i<120;i++)); do
    kc get pods
    READY=$(kc get deployment iris-api -o jsonpath='{.status.readyReplicas}')
    if [[ "$READY" == 2 ]] && ! kc get pod "$POD" >/dev/null 2>&1; then break; fi
    sleep 2
done
[[ "$READY" == 2 ]]
printf 'Réconciliation après suppression : %s secondes\n' "$((SECONDS-START))"

echo 'EXPERIENCE 1b — arrêt du processus du conteneur, même pod'
POD=$(kc get pods -l app=iris-api -o jsonpath='{.items[0].metadata.name}')
BEFORE=$(kc get pod "$POD" -o jsonpath='{.status.containerStatuses[0].restartCount}')
kc get pod "$POD" -o jsonpath='{.metadata.name} {.metadata.uid}{"\n"}'
kc exec "$POD" -- python -c 'import os,signal; os.kill(1,signal.SIGTERM)' || true
START=$SECONDS
AFTER=$BEFORE
for ((i=0;i<120;i++)); do
    kc get pod "$POD"
    AFTER=$(kc get pod "$POD" -o jsonpath='{.status.containerStatuses[0].restartCount}')
    READY=$(kc get pod "$POD" -o jsonpath='{.status.containerStatuses[0].ready}')
    [[ "$AFTER" -gt "$BEFORE" && "$READY" == true ]] && break
    sleep 2
done
[[ "$AFTER" -gt "$BEFORE" && "$READY" == true ]]
printf 'Redémarrages avant=%s après=%s ; retour prêt en %s secondes\n' "$BEFORE" "$AFTER" "$((SECONDS-START))"

echo 'EXPERIENCE 2 — compteurs en mémoire par pod'
: > evidence/partie3/predictions-distribuees.jsonl
for ((i=0;i<12;i++)); do
    curl --fail --silent --max-time 15 -H 'Content-Type: application/json' \
        -d '{"features":[5.1,3.5,1.4,0.2]}' "$URL/predict" | tee -a evidence/partie3/predictions-distribuees.jsonl
    printf '\n' | tee -a evidence/partie3/predictions-distribuees.jsonl
done
: > evidence/partie3/stats.jsonl
for ((i=0;i<8;i++)); do
    curl --fail --silent --max-time 15 "$URL/stats" | tee -a evidence/partie3/stats.jsonl
    printf '\n' | tee -a evidence/partie3/stats.jsonl
done

echo 'EXPERIENCE 3 — ConfigMap et variables d’environnement'
KEY=$(kc get secret iris-secret -o jsonpath='{.data.API_KEY}' | base64 --decode)
curl --fail --silent --max-time 15 -H "X-API-Key: $KEY" "$URL/admin/config" | tee evidence/partie3/config-avant.json; printf '\n'
sed -i 's/LOG_LEVEL: "INFO"/LOG_LEVEL: "DEBUG"/' k8s/configmap.yaml
kc apply -f k8s/configmap.yaml
curl --fail --silent --max-time 15 -H "X-API-Key: $KEY" "$URL/admin/config" | tee evidence/partie3/config-sans-redemarrage.json; printf '\n'
kc rollout restart deployment/iris-api
kc rollout status deployment/iris-api --timeout=240s
curl --fail --silent --max-time 15 -H "X-API-Key: $KEY" "$URL/admin/config" | tee evidence/partie3/config-apres-redemarrage.json; printf '\n'
unset KEY
kc get configmap iris-config -o json > evidence/partie3/configmap-observee.json
# Le fichier de base reste prêt pour le futur déploiement AKS ; la preuve conserve DEBUG observé.
sed -i 's/LOG_LEVEL: "DEBUG"/LOG_LEVEL: "INFO"/' k8s/configmap.yaml
kc apply -f k8s/hpa.yaml
for ((i=0;i<60;i++)); do
    kc get hpa
    CPU=$(kc get hpa iris-api -o jsonpath='{.status.currentMetrics[0].resource.current.averageUtilization}')
    [[ -n "$CPU" ]] && break
    sleep 2
done
kc get hpa -o json > evidence/partie3/hpa-initial.json
kc get pods -o wide | tee evidence/partie3/pods-apres-experiences.txt
echo 'PARTIE3_EXPERIENCES_OK'

