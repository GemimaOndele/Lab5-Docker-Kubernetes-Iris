#!/usr/bin/env bash
# Lab 5 - verifie que les outils sont installes et que Docker tourne.
# Usage : bash scripts/verifier-outils.sh
ok()  { printf '  [OK]  %s\n' "$1"; }
ko()  { printf '  [!!]  %s\n' "$1"; ERR=$((ERR+1)); }
ERR=0
echo "== Outils du Lab 5 =="
for t in docker az kubectl minikube git; do
  if command -v "$t" >/dev/null 2>&1; then ok "$t trouve : $(command -v "$t")"; else ko "$t introuvable (voir Partie 0, etape installation)"; fi
done
if docker info >/dev/null 2>&1; then ok "le moteur Docker repond (version $(docker version --format '{{.Server.Version}}' 2>/dev/null))"
else ko "le moteur Docker ne repond pas : lancez Docker Desktop et attendez 'Engine running'"; fi
if command -v az >/dev/null 2>&1; then
  ok "Azure CLI $(az version --query '"azure-cli"' -o tsv 2>/dev/null)"
  SUB=$(az account show --query name -o tsv 2>/dev/null)
  if [ -n "$SUB" ]; then ok "connecte a Azure, abonnement : $SUB"; else ko "pas connecte a Azure : lancez 'az login'"; fi
fi
command -v kubectl >/dev/null 2>&1 && ok "kubectl $(kubectl version --client -o json 2>/dev/null | grep -m1 gitVersion | tr -d ' ",' | cut -d: -f2)"
command -v minikube >/dev/null 2>&1 && ok "$(minikube version --short 2>/dev/null)"
case "$(uname -s)" in
  MINGW*|MSYS*) [ "$MSYS_NO_PATHCONV" = "1" ] && ok "Git Bash : MSYS_NO_PATHCONV=1" || ko "Git Bash : faites 'source ~/lab5.env' (il contient export MSYS_NO_PATHCONV=1)";;
esac
echo
if [ "$ERR" -eq 0 ]; then echo "Tout est pret. Bon lab !"; else echo "$ERR point(s) a corriger avant de continuer."; fi
