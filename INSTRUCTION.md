# Deploying ToDo app with PersistentVolume, ConfigMap and Secret mounts

All namespaced resources belong to the `todoapp` namespace. Manifests are stored in `.infrastructure/`.

## Prerequisites

- A running Kubernetes cluster (e.g. minikube) and `kubectl` configured for it
- The application image pushed to Docker Hub and referenced in `deployment.yml`

## Deploy

Run the bootstrap script, which applies all resources in the correct order (namespace, ConfigMap, Secret, PV, PVC, Deployment):

```bash
chmod +x bootstrap.sh
./bootstrap.sh
```

## Validate

### 1. App is running

```bash
kubectl get deployment todoapp -n todoapp
kubectl get pods -n todoapp
kubectl logs -n todoapp deploy/todoapp --tail=20
kubectl port-forward -n todoapp deploy/todoapp 8080:8080
```

In another terminal:

```bash
curl -i http://localhost:8080/api/health
```

Expected: the Deployment is `READY 1/1`, the pod is `Running`, and the request returns HTTP `200`.

### 2. PersistentVolume and PersistentVolumeClaim are bound

```bash
kubectl get pv todoapp-pv
kubectl get pvc todoapp-pvc -n todoapp
```

Expected: both show `STATUS Bound`, capacity `1Gi`, access mode `RWX`, storage class `standard`, reclaim policy `Delete`.

Check that data survives a pod restart:

```bash
kubectl exec -n todoapp deploy/todoapp -- sh -c 'echo persisted > /app/data/test.txt'
kubectl rollout restart deployment/todoapp -n todoapp
kubectl rollout status deployment/todoapp -n todoapp
kubectl exec -n todoapp deploy/todoapp -- cat /app/data/test.txt
```

Expected: `persisted`.

### 3. ConfigMap data is mounted as files

```bash
kubectl get configmap app-config -n todoapp -o yaml
kubectl exec -n todoapp deploy/todoapp -- ls -la /app/configs
kubectl exec -n todoapp deploy/todoapp -- sh -c 'for f in /app/configs/*; do echo "== $f"; cat "$f"; echo; done'
```

Expected: every key of the ConfigMap is present as a file in `/app/configs`, and the content of each file matches the value of its key.

Check that the mount is read-only:

```bash
kubectl exec -n todoapp deploy/todoapp -- touch /app/configs/test
```

Expected: `Read-only file system` error.

### 4. Secret data is mounted as a file

```bash
kubectl exec -n todoapp deploy/todoapp -- ls -la /app/secrets
kubectl exec -n todoapp deploy/todoapp -- cat /app/secrets/SECRET_KEY
```

Expected: the file `SECRET_KEY` exists and contains the decoded secret value, matching:

```bash
kubectl get secret app-secret -n todoapp -o jsonpath='{.data.SECRET_KEY}' | base64 --decode
```

Check that the mount is read-only:

```bash
kubectl exec -n todoapp deploy/todoapp -- touch /app/secrets/test
```

Expected: `Read-only file system` error.

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| PVC stays `Pending` | `storageClassName`, `accessModes` or size in `pvc.yml` do not match `pv.yml` |
| Pod stays `ContainerCreating` | PVC is not bound, or the ConfigMap or Secret name in `volumes` does not exist |
| PV status `Failed` after PVC deletion | The hostPath is outside `/tmp`, so Kubernetes cannot delete the data |

## Cleanup

```bash
kubectl delete -f .infrastructure/deployment.yml
kubectl delete -f .infrastructure/pvc.yml
kubectl delete -f .infrastructure/pv.yml
kubectl delete -f .infrastructure/secret.yml
kubectl delete -f .infrastructure/configMap.yml
```