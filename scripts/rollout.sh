#!/usr/bin/env bash
# Roll out sion2k-gateway: TLS secrets in gateway-system, Argo CD Application, sync wait.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GATEWAY_NS="${GATEWAY_NS:-gateway-system}"
ARGO_NS="${ARGO_NS:-shturval-cd}"

echo "== TLS secrets → ${GATEWAY_NS} (from Ingress tls.secretName) =="
tmp="$(mktemp)"
kubectl get ingress -A -o json \
  | jq -r '
    .items[]
    | select(.spec.tls != null)
    | .spec.tls[]?
    | .secretName as $s
    | . // empty
    ' 2>/dev/null || true

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

echo "== Argo CD Application =="
kubectl apply -f "${ROOT}/argocd/application.yaml"

if command -v argocd &>/dev/null; then
  argocd app sync sion2k-gateway --grpc-web || true
fi

echo "== Wait Gateway public =="
kubectl wait -n "$GATEWAY_NS" --for=condition=Programmed gateway/public --timeout=300s 2>/dev/null || \
  kubectl get gateway -n "$GATEWAY_NS" public -o yaml | tail -30

VIP="$(kubectl get gateway -n "$GATEWAY_NS" public -o jsonpath='{.status.addresses[0].value}' 2>/dev/null || true)"
echo "Gateway VIP: ${VIP:-<pending>}"
echo "Smoke: curl -k --resolve meet.sion2k.ru:443:\${VIP} https://meet.sion2k.ru/"
