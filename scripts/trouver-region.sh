#!/usr/bin/env bash
# Lab 5 - trouve une region autorisee ET une taille de VM utilisable pour le noeud AKS.
# Usage : bash scripts/trouver-region.sh      (apres 'az login')
# Azure for Students : seules ~5 regions sont autorisees et certaines tailles y sont bloquees.
SIZES="Standard_B2als_v2 Standard_B2as_v2 Standard_B2s_v2 Standard_D2as_v5 Standard_D2s_v5"
echo "Lecture de la strategie 'Allowed resource deployment regions'..."
REGIONS=$(az policy assignment list --disable-scope-strict-match \
  --query "[?parameters.listOfAllowedLocations].parameters.listOfAllowedLocations.value[]" -o tsv 2>/dev/null | sort -u)
if [ -z "$REGIONS" ]; then
  echo "Aucune strategie de regions trouvee (abonnement non etudiant ?). Regions testees par defaut."
  REGIONS="francecentral westeurope northeurope swedencentral germanywestcentral"
fi
echo "Regions autorisees : $(echo $REGIONS)"; echo
FOUND=""
for R in $REGIONS; do
  USE=$(az vm list-usage --location "$R" --query "[?name.value=='cores'].[currentValue,limit]" -o tsv 2>/dev/null)
  printf '%-20s vCPU utilises/limite : %s\n' "$R" "${USE:-?}"
  OKS=$(az vm list-skus --location "$R" --resource-type virtualMachines --all \
        --query "[?length(restrictions[?type=='Location'])==\`0\`].name" -o tsv 2>/dev/null)
  for S in $SIZES; do
    if echo "$OKS" | grep -qx "$S"; then
      printf '    %-20s disponible\n' "$S"
      [ -z "$FOUND" ] && FOUND="LOCATION=$R  NODE_SIZE=$S"
    fi
  done
done
echo
if [ -n "$FOUND" ]; then
  echo "Proposition : $FOUND"
  echo "Reportez ces deux valeurs dans ~/lab5.env (LOCATION=... et NODE_SIZE=...)."
else
  echo "Aucune taille disponible : reessayez plus tard ou demandez a l'enseignante."
fi
