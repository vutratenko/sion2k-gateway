#!/usr/bin/env bash
# Roll out sion2k-gateway: TLS secrets in gateway-system, Argo CD Application, sync wait.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GATEWAY_NS="${GATEWAY_NS:-gateway-system}"
ARGO_NS="${ARGO_NS:-shturval-cd}"

kubectl_retry() {
  local n=0 max="${KUBECTL_RETRY_MAX:-30}"
  until kubectl "$@" 2>/dev/null; do
    n=$((n + 1))
    if [ "$n" -ge "$max" ]; then
      kubectl "$@"
      return $?
    fi
    echo "kubectl retry $n/$max: $*" >&2
    sleep 2
  done
}

echo "== Cluster reachability =="
kubectl_retry get ns "$ARGO_NS" >/dev/null
kubectl_retry create namespace "$GATEWAY_NS" 2>/dev/null || true

echo "== TLS secrets → ${GATEWAY_NS} (from Ingress tls.secretName) =="
kubectl get ingress -A -o json | jq -r '
  .items[]
  | .metadata.namespace as $ns
  | (.spec.tls[]? | .secretName) as $secret
  | select($secret != null)
  | "\($ns)\t\($secret)"
' | sort -u | while IFS=$'\t' read -r src_ns secret; do
  if kubectl get secret -n "$GATEWAY_NS" "$secret" &>/dev/null; then
    echo "skip (exists): $secret"
    continue
  fi
  if ! kubectl get secret -n "$src_ns" "$secret" &>/dev/null; then
    echo "warn: no secret $secret in $src_ns"
    continue
  fi
  echo "copy: $src_ns/$secret → $GATEWAY_NS/$secret"
  kubectl get secret -n "$src_ns" "$secret" -o yaml \
    | kubectl neat 2>/dev/null \
    | sed "s/namespace: ${src_ns}/namespace: ${GATEWAY_NS}/" \
    | kubectl apply -f - 2>/dev/null \
    || kubectl get secret -n "$src_ns" "$secret" -o json \
      | jq --arg ns "$GATEWAY_NS" 'del(.metadata.uid,.metadata.resourceVersion,.metadata.creationTimestamp,.metadata.ownerReferences)
         | .metadata.namespace = $ns' \
      | kubectl apply -f -
done

# Gateway listeners expect these names (may differ from Ingress secretName).
copy_alias() {
  local src="$1" dst="$2"
  if kubectl get secret -n "$GATEWAY_NS" "$dst" &>/dev/null; then
    return 0
  fi
  if kubectl get secret -n "$GATEWAY_NS" "$src" &>/dev/null; then
    echo "alias: $src → $dst in $GATEWAY_NS"
    kubectl get secret -n "$GATEWAY_NS" "$src" -o json \
      | jq --arg name "$dst" --arg ns "$GATEWAY_NS" '
          del(.metadata.uid,.metadata.resourceVersion,.metadata.creationTimestamp,.metadata.ownerReferences)
          | .metadata.name = $name | .metadata.namespace = $ns' \
      | kubectl apply -f -
  fi
}
copy_alias authentik-secret-ingress authentik-tls
# Challenger API: reuse one cert for consolidated listener name if present
for s in challenger-api-secret-ingress challenger-prod-api-secret-ingress challenger-api-sion2k-ru-tls; do
  if kubectl get secret -n "$GATEWAY_NS" "$s" &>/dev/null; then
    copy_alias "$s" challenger-api-sion2k-ru-tls
    break
  fi
done
for s in challenger-stage-api-secret-ingress challenger-stage-api-ingress; do
  if kubectl get secret -n "$GATEWAY_NS" "$s" &>/dev/null; then
    copy_alias "$s" challenger-stage-api-tls
    break
  fi
done

echo "== Argo CD Application =="
kubectl_retry apply -f "${ROOT}/argocd/application.yaml"

if command -v argocd &>/dev/null; then
  argocd app sync sion2k-gateway --grpc-web || true
fi

echo "== Wait Gateway public =="
kubectl wait -n "$GATEWAY_NS" --for=condition=Programmed gateway/public --timeout=300s 2>/dev/null || \
  kubectl get gateway -n "$GATEWAY_NS" public -o yaml | tail -30

VIP="$(kubectl get gateway -n "$GATEWAY_NS" public -o jsonpath='{.status.addresses[0].value}' 2>/dev/null || true)"
echo "Gateway VIP: ${VIP:-<pending>}"
echo "Smoke: curl -k --resolve meet.sion2k.ru:443:\${VIP} https://meet.sion2k.ru/"
