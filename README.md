# Lab 5 — Docker et Kubernetes

**Gémima ONDELE POUROU** — MSc2 Artificial Intelligence, ECE Paris, 2026–2027.
Cours : Distributed Systems and Cloud Computing in AI. Enseignante : Dr BENNAI Soufia.

API FastAPI de classification Iris, issue du kit pédagogique. Expériences réelles des 6 et 7 novembre 2026.

## Résultats vérifiés

- Images naïve / multi-étapes : 2 155 485 513 / 585 545 462 octets (−72,83 %).
- Trivy : 277 HIGH et 15 CRITICAL / 54 HIGH et 0 CRITICAL, en occurrences par paquet.
- minikube : remplacement du pod et redémarrage de conteneur en 9 s ; compteurs indépendants 5 et 7 ; ConfigMap prise en compte après redémarrage.
- AKS Free, un nœud Standard_D2s_v4 en Spain Central, Kubernetes 1.36.4.
- AKS : 110 requêtes pendant v1→v2, 183 pendant v9+annulation et 86 pendant l'auto-réparation, sans erreur observée dans ces fenêtres.
- HPA : 2→5→2 ; plafond(2×273/50)=11, limité à 5.
- CI/CD OIDC : tests, image et déploiement du commit `e348d51` validés.

La précision Iris observée est 0,900 sur 30 observations de test. Redis, la panne du nœud et les options KEDA/Ingress n'ont pas été expérimentés. Ces mesures ne garantissent pas une disponibilité en production.

## Sources et preuves

`app/`, `train.py`, `tests/`, les Dockerfiles et `k8s/` contiennent l'application et ses manifestes. Aucun Secret réel n'est versionné. Les scripts d'expérimentation sont dans `scripts/`, les sorties originales dans `evidence/` et les sauvegardes dans `evidence/archives/`.

`evidence/partie5-build/model.joblib` est le modèle extrait de l'image finale ; son SHA-256 est enregistré à côté. Ne charger un fichier joblib que depuis une source de confiance.

| Validation | Run GitHub Actions |
|---|---|
| minikube et expériences 1 à 3 | 42316639553 |
| Rolling update et HPA minikube | 42337318933 |
| ACR | 42338475608 |
| Expériences AKS | 42338824946 |
| CI/CD finale | 42339928546 |

Un premier essai minikube a produit 3 erreurs sur 167 requêtes. Un `preStop` de 5 s et une période de terminaison de 35 s ont corrigé ce scénario lors des essais suivants. Les archives initiales sont conservées.

## Rejouer localement

Prérequis : Docker Linux, Git et Python 3.13. Dans un environnement isolé :

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt -r requirements-dev.txt
python train.py model/model.joblib
python -m pytest -q
docker build --platform linux/amd64 -t iris-api:v1 .
docker run --rm --name iris -p 8000:8000 iris-api:v1
```

Dans un autre terminal, appeler /health puis /predict avec les features [5.1,3.5,1.4,0.2].
Lire les scripts minikube avant exécution : ils modifient les objets du profil `lab5-go` et du namespace `iris`. Ne pas les lancer sur un cluster de production.

## Recréer Azure

Consulter `LAB_STATUS.md` pour l'état de clôture. Les identifiants et noms conservés documentent une séance ; ils ne signifient pas que les ressources existent encore.

1. Se connecter selon les règles de l'établissement. Vérifier Azure Policy, la disponibilité des tailles, les quotas et le budget.
2. Créer ACR Basic sans compte administrateur et AKS Free à un nœud ; attribuer AcrPull au kubelet.
3. Créer une nouvelle identité managée et sa confiance OIDC : émetteur `https://token.actions.githubusercontent.com`, audience `api://AzureADTokenExchange`. Vérifier le subject réellement émis : ce dépôt utilise le format immuable avec les IDs du propriétaire et du dépôt. Un fork doit créer sa propre confiance.
4. Limiter les rôles : Reader sur le groupe, AcrPush sur ACR et AKS Cluster User sur le cluster. Adapter le contrôle d'accès Kubernetes si nécessaire.
5. Actualiser les noms et identifiants non secrets des workflows. Créer le namespace, la ConfigMap et un nouveau Secret `iris-secret` comportant `API_KEY`, sans commiter sa valeur.
6. Les workflows sont désormais **manuels uniquement**. Lancer volontairement `deploy.yml`. Pour refaire la démonstration par push, rétablir explicitement le déclencheur après revue et le retirer à la fin.
7. Sauvegarder les preuves et le modèle, supprimer uniquement le groupe du TP, vérifier le groupe MC associé et les ressources étiquetées lab=lab5.

`partie5/deploy.yml` conserve l'exemple initial du kit ; seul `.github/workflows/deploy.yml` est le pipeline final.
Pour une reproductibilité binaire stricte, verrouiller aussi les dépendances transitives et le digest Python de base.

L'audit de publication inspecte les objets Git et les archives lisibles. Aucun jeton, clé privée, mot de passe, kubeconfig ou fichier d'authentification Docker ne doit être ajouté. Les client/tenant/subscription IDs ne sont pas des mots de passe. L'IA a assisté l'exécution supervisée et la rédaction ; les journaux archivés servent de preuves.
