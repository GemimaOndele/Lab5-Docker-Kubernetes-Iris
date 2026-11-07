#!/usr/bin/env bash
# Alternative minikube explicitement prévue par le sujet si les tailles AKS sont bloquées.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p evidence/partie4-minikube
exec > >(tee evidence/partie4-minikube/execution.log) 2>&1
kc() { kubectl --context=lab5-go --namespace=iris "$@"; }
echo 'ENVIRONNEMENT MINIKUBE — ces résultats ne constituent pas un déploiement AKS.'
[[ "$(kc get deployment iris-api -o jsonpath='{.metadata.namespace}')" == iris ]]
minikube -p lab5-go image load iris-api:v2
URL="http://$(minikube -p lab5-go ip):$(kc get svc iris-api -o jsonpath='{.spec.ports[0].nodePort}')"
export URL
trace() {
  python3 - "$1" "$2" <<'PY'
import urllib.request,json,time,sys,datetime
end=time.monotonic()+int(sys.argv[2]); lines=[]
while time.monotonic()<end:
    try:
        with urllib.request.urlopen(__import__('os').environ['URL']+'/',timeout=3) as r:
            x={'status':r.status,**json.load(r)}
    except Exception as e:x={'status':0,'error':str(e)}
    x['utc']=datetime.datetime.now(datetime.timezone.utc).isoformat();lines.append(x);time.sleep(.25)
with open(sys.argv[1],'w') as f:
    for x in lines:f.write(json.dumps(x)+'\n')
print(json.dumps({'trace':sys.argv[1],'requests':len(lines),'errors':sum(x['status']!=200 for x in lines),'versions':sorted(set(x.get('version','ERROR') for x in lines))}),flush=True)
assert all(x['status']==200 for x in lines),'HTTP interruption observed'
PY
}
echo 'ROLLING UPDATE V1 V2'
trace evidence/partie4-minikube/rolling-v1-v2.jsonl 45 & TRACER=$!
kc set image deployment/iris-api iris-api=iris-api:v2
kc rollout status deployment/iris-api --timeout=180s
wait "$TRACER"
kc get pods -o wide | tee evidence/partie4-minikube/pods-v2.txt
echo 'IMAGE V9 ABSENTE ET ANNULATION'
trace evidence/partie4-minikube/v9-annulation.jsonl 75 & TRACER=$!
kc set image deployment/iris-api iris-api=iris-api:v9
PULL=''
for ((i=0;i<30;i++)); do
  PULL=$(kc get pods -l app=iris-api -o jsonpath='{.items[*].status.containerStatuses[*].state.waiting.reason}')
  [[ "$PULL" == *ImagePullBackOff* ]] && break
  sleep 2
done
kc get pods -o wide | tee evidence/partie4-minikube/pods-v9.txt
[[ "$PULL" == *ImagePullBackOff* ]]
kc rollout undo deployment/iris-api
kc rollout status deployment/iris-api --timeout=180s
wait "$TRACER"
echo 'HPA SOUS CHARGE'
kc apply -f k8s/hpa.yaml
for ((i=0;i<120;i++)); do
 CPU=$(kc get hpa iris-api -o jsonpath='{.status.currentMetrics[0].resource.current.averageUtilization}')
 [[ -n "$CPU" ]] && break
 sleep 2
done
[[ -n "$CPU" ]]
kc get hpa iris-api -o json > evidence/partie4-minikube/hpa-repos.json
kc run load-gen --restart=Never --image=busybox:1.37 -- /bin/sh -c 'while true; do wget -q -O /dev/null --header "Content-Type: application/json" --post-data '\''{"features":[6.3,3.3,6.0,2.5]}'\'' http://iris-api/predict; done'
kc wait --for=condition=Ready pod/load-gen --timeout=120s
mkdir -p evidence/partie4-minikube/hpa-charge
for ((i=0;i<36;i++)); do
 kc get hpa iris-api -o json > "evidence/partie4-minikube/hpa-charge/$i.json"
 kc get hpa iris-api
 sleep 5
done
kc top pods | tee evidence/partie4-minikube/top-charge.txt
kc get pods -o wide | tee evidence/partie4-minikube/pods-charge.txt
kc delete pod load-gen --wait=true
for ((i=0;i<90;i++)); do
 kc get hpa iris-api -o json > evidence/partie4-minikube/hpa-apres-charge.json
 REPLICAS=$(kc get deployment iris-api -o jsonpath='{.spec.replicas}')
 [[ "$REPLICAS" == 2 ]] && break
 sleep 2
done
python3 - <<'PY'
from pathlib import Path
import json,math
root=Path('evidence/partie4-minikube')
samples=[]
for p in (root/'hpa-charge').glob('*.json'):
 d=json.loads(p.read_text());s=d['status'];m=s.get('currentMetrics',[])
 if m:
  cpu=m[0]['resource']['current']['averageUtilization'];n=s['currentReplicas']
  samples.append({'cpu_percent':cpu,'current_replicas':n,'formula_raw':math.ceil(n*cpu/50),'formula_bounded':min(5,max(2,math.ceil(n*cpu/50))),'desired_replicas':s.get('desiredReplicas')})
summary={'environment':'minikube on GitHub Actions; not AKS','samples':samples,'max_current_replicas':max(x['current_replicas'] for x in samples),'max_desired_replicas':max(x['desired_replicas'] for x in samples)}
(root/'hpa-calculs.json').write_text(json.dumps(summary,indent=2));print(json.dumps(summary))
assert summary['max_current_replicas']>2,'No scale-out observed'
PY
kc get pods,deploy,svc,hpa -o wide | tee evidence/partie4-minikube/etat-final.txt
echo PARTIE4_MINIKUBE_PLAN_B_OK
