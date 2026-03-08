#!/bin/bash

cd /usr/local/src/k8s/k8s/manifests || exit
git pull
kubectl kustomize --enable-helm ./growi/ > ../../generated/growi/generated.yaml

cd /usr/local/src/k8s/generated || exit
kubectl delete -f ./growi

for pv in $(kubectl get pv -o name | grep growi); do
  kubectl patch "${pv}" --type json -p '[{"op": "remove", "path": "/spec/claimRef/uid"}]'
done
