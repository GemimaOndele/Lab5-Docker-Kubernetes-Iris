# État final du Lab 5

Les parties Docker, minikube, ACR, AKS et CI/CD ont été exécutées. Le pipeline complet 42339928546 a réussi et a vérifié la version e348d51 sur l’API AKS.

Après sauvegarde du modèle et des preuves, le contrôle du 7 novembre 2026 à 05:12 UTC confirme :
- rg-lab5-go : group_exists = false ;
- MC_rg-lab5-go_aks-lab5-go_spaincentral : managed_group_exists = false ;
- ressources étiquetées lab=lab5 : 0.

Les workflows sont manuels uniquement. Le dépôt est public. L’API Azure n’est plus en service. Le Codespace est conservé inactif avec ses changements non validés.

La requête de coûts a reçu HTTP 429 Too Many Requests. Le coût total définitif reste à vérifier 24 à 48 h après la séance, avec scripts/cout-differe.sh. Aucun coût nul n’est revendiqué.

Le contrôle unique verifier-outils.sh entièrement [OK] dans Codespaces n’a pas été archivé ; les preuves fonctionnelles et versions sont réparties entre les environnements de travail.
