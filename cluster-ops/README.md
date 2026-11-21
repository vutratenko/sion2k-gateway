# sion2k-cluster operations manifests

Declarative patches and configs applied to the `sion2k-cluster` client cluster (Alertmanager, descheduler, monitoring spread, vmagent labels).

Apply order (after review):

```bash
kubectl apply -f vmalertmanagerconfig-0.yaml
kubectl apply -f vmagent-client-cluster-labels.yaml
kubectl apply -f vmcluster-metering-pod-spread.yaml
kubectl apply -f shturval-descheduler-policy.yaml
kubectl apply -f shturval-monitoring-pod-spread.yaml
kubectl apply -f shturval-rollouts-pod-spread.yaml
kubectl apply -f shturval-metrics-collector-noise.yaml
kubectl apply -f shturval-cd-application-controller-memory.yaml
kubectl patch -n sion2k-cluster vmrule vmrule-system-0 --type json --patch-file vmrule-system-0-apiserver-sli.patch.json
```

See `descheduler-policy-direct-patch.md` if Helm re-enables `RemovePodsHavingTooManyRestarts`.
