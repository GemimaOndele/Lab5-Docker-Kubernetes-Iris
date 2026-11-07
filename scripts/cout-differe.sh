#!/usr/bin/env bash
# Lecture uniquement. A lancer 24 a 48 h apres la seance, dans Cloud Shell authentifie.
set -euo pipefail
subscription=$(az account show --query id -o tsv)
body=$(mktemp)
trap 'rm -f "$body"' EXIT
cat > "$body" <<'JSON'
{"type":"ActualCost","timeframe":"MonthToDate","dataset":{"granularity":"None","aggregation":{"totalCost":{"name":"PreTaxCost","function":"Sum"}},"filter":{"dimensions":{"name":"ResourceGroupName","operator":"In","values":["rg-lab5-go","MC_rg-lab5-go_aks-lab5-go_spaincentral"]}},"grouping":[{"type":"Dimension","name":"ResourceGroupName"}]}}
JSON
az rest --method post --url "https://management.azure.com/subscriptions/$subscription/providers/Microsoft.CostManagement/query?api-version=2025-03-01" --body "@$body" -o json
