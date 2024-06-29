#!/bin/bash

cd /usr/local/src/k8s/k8s/manifests || exit
git pull
kubectl kustomize --enable-helm ./growi/ > ../../generated/growi/generated.yaml

cd /usr/local/src/k8s/generated || exit
kubectl delete -f ./growi

kubectl patch pv growi-elasticsearch-data-pv --type json -p '[{"op": "remove", "path": "/spec/claimRef/uid"}]'
kubectl patch pv growi-elasticsearch-master-pv --type json -p '[{"op": "remove", "path": "/spec/claimRef/uid"}]'
kubectl patch pv growi-mongodb-pv --type json -p '[{"op": "remove", "path": "/spec/claimRef/uid"}]'
kubectl patch pv growi-uploads-pv --type json -p '[{"op": "remove", "path": "/spec/claimRef/uid"}]'
