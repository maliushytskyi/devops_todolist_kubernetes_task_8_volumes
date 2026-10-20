#!/bin/bash
set -e

# 1. Namespace (idempotent: does not fail if it already exists)
kubectl create namespace todoapp --dry-run=client -o yaml | kubectl apply -f -

# 2. ConfigMap
kubectl apply -f .infrastructure/configMap.yml

# 3. Secret
kubectl apply -f .infrastructure/secret.yml

# 4. PersistentVolume
kubectl apply -f .infrastructure/pv.yml

# 5. PersistentVolumeClaim
kubectl apply -f .infrastructure/pvc.yml

# 6. Deployment
kubectl apply -f .infrastructure/deployment.yml

# Wait until the app is ready and show the result
kubectl rollout status deployment/todoapp -n todoapp
kubectl get pv
kubectl get pvc,configmap,secret,pods -n todoapp