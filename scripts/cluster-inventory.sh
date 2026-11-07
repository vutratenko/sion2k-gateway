#!/usr/bin/env bash
# Lists non-platform Ingresses and Gateways for sion2k migration review.
# Requires kubectl context with cluster access.

set -euo pipefail

EX_NS_REGEX='^(shturval-backend|monitoring|postgres-operator)$'

echo "=== GatewayClass / Gateway ==="
kubectl get gatewayclass 2>/dev/null || true
kubectl get gateway -A 2>/dev/null || true

echo
echo "=== Ingress (excluding platform namespaces shturval-backend, monitoring, postgres-operator) ==="
kubectl get ingress -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,CLASS:.spec.ingressClassName,HOSTS:.spec.rules[*].host \
  2>/dev/null | head -1
kubectl get ingress -A -o json 2>/dev/null | jq -r '
  .items[]
  | select(.metadata.namespace | test("'"$EX_NS_REGEX"'") | not)
  | [.metadata.namespace, .metadata.name, (.spec.ingressClassName // "-"), ([.spec.rules[]?.host // empty] | join(","))]
  | @tsv
' | sort

echo
echo "=== HTTPRoute (sample) ==="
kubectl get httproute -A 2>/dev/null | head -40 || true
