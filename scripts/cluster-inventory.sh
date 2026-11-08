#!/usr/bin/env bash
# Non-platform Ingress vs Gateway public: gap report for sion2k migration.
# Requires kubectl context with cluster access.

set -euo pipefail

EX_NS_REGEX='^(shturval-backend|shturval-cd|monitoring|postgres-operator|victoria-metrics)$'
PLATFORM_INGRESS_NS_REGEX='^(shturval-backend|shturval-cd|monitoring|postgres-operator|victoria-metrics)$'
GATEWAY_NS="${GATEWAY_NS:-gateway-system}"
GATEWAY_NAME="${GATEWAY_NAME:-shturval-gateway}"

echo "=== Gateway ${GATEWAY_NS}/${GATEWAY_NAME} ==="
kubectl get gateway -n "$GATEWAY_NS" "$GATEWAY_NAME" -o wide 2>/dev/null || true

echo
echo "=== Non-platform nginx Ingress hosts (still on cluster) ==="
kubectl get ingress -A -o json 2>/dev/null | jq -r --arg rx "$EX_NS_REGEX" '
  .items[]
  | select(.metadata.namespace | test($rx) | not)
  | select((.spec.ingressClassName // "") == "nginx" or .spec.ingressClassName == null)
  | . as $i
  | (.spec.rules[]?.host // empty) as $h
  | select($h != "")
  | [$h, $i.metadata.namespace, $i.metadata.name]
  | @tsv
' | sort -u | column -t -s $'\t' || true

echo
echo "=== HTTPRoute → public: hosts and backend health ==="
kubectl get httproute -A -o json 2>/dev/null | jq -r --arg gw "$GATEWAY_NAME" --arg gwns "$GATEWAY_NS" '
  .items[]
  | select([.spec.parentRefs[]? | select(.name == $gw and (.namespace // "gateway-system") == $gwns)] | length > 0)
  | . as $r
  | ($r.status.parents[0].conditions // []) as $c
  | ([$c[] | select(.type=="Accepted") | .status] | first // "?") as $acc
  | ([$c[] | select(.type=="ResolvedRefs") | .status] | first // "?") as $refs
  | ([$c[] | select(.type=="ResolvedRefs" and .status=="False") | .message] | first // "") as $err
  | "\($r.metadata.namespace)/\($r.metadata.name)\t\($r.spec.hostnames // [] | join(","))\tacc=\($acc)\trefs=\($refs)\t\($err)"
' | sort || true

echo
echo "=== TLSRoute → public ==="
kubectl get tlsroute -A -o json 2>/dev/null | jq -r --arg gw "$GATEWAY_NAME" --arg gwns "$GATEWAY_NS" '
  .items[]
  | select([.spec.parentRefs[]? | select(.name == $gw and (.namespace // "gateway-system") == $gwns)] | length > 0)
  | "\(.metadata.namespace)/\(.metadata.name)\t\(.spec.hostnames // [] | join(","))"
' | sort 2>/dev/null || echo "(no TLSRoute CRD or routes)"

echo
echo "=== Gap: Ingress host without matching HTTPRoute/TLSRoute host on public ==="
{
  kubectl get ingress -A -o json 2>/dev/null | jq -r --arg rx "$EX_NS_REGEX" '
    .items[]
    | select(.metadata.namespace | test($rx) | not)
    | select((.spec.ingressClassName // "") == "nginx" or .spec.ingressClassName == null)
    | .spec.rules[]?.host // empty
  ' | LC_ALL=C sort -u
} > /tmp/ing-hosts.$$.txt

{
  kubectl get httproute -A -o json 2>/dev/null | jq -r --arg gw "$GATEWAY_NAME" --arg gwns "$GATEWAY_NS" '
    .items[]
    | select([.spec.parentRefs[]? | select(.name == $gw and (.namespace // "gateway-system") == $gwns)] | length > 0)
    | .spec.hostnames[]?
  '
  kubectl get tlsroute -A -o json 2>/dev/null | jq -r --arg gw "$GATEWAY_NAME" --arg gwns "$GATEWAY_NS" '
    .items[]
    | select([.spec.parentRefs[]? | select(.name == $gw and (.namespace // "gateway-system") == $gwns)] | length > 0)
    | .spec.hostnames[]?
  ' 2>/dev/null || true
} | LC_ALL=C sort -u > /tmp/route-hosts.$$.txt

LC_ALL=C sort -u -o /tmp/ing-hosts.$$.txt /tmp/ing-hosts.$$.txt
LC_ALL=C sort -u -o /tmp/route-hosts.$$.txt /tmp/route-hosts.$$.txt
comm -23 /tmp/ing-hosts.$$.txt /tmp/route-hosts.$$.txt | while read -r h; do
  echo "  MISSING_ROUTE  $h"
done
rm -f /tmp/ing-hosts.$$.txt /tmp/route-hosts.$$.txt

echo
echo "=== Broken HTTPRoute (ResolvedRefs=False) ==="
kubectl get httproute -A -o json 2>/dev/null | jq -r --arg gw "$GATEWAY_NAME" --arg gwns "$GATEWAY_NS" '
  .items[]
  | select([.spec.parentRefs[]? | select(.name == $gw and (.namespace // "gateway-system") == $gwns)] | length > 0)
  | . as $r
  | ($r.status.parents[0].conditions // []) as $c
  | ([$c[] | select(.type=="ResolvedRefs" and .status=="False") | .message] | first) as $err
  | select($err != null)
  | "\($r.spec.hostnames // ["-"] | join(","))\t\($r.metadata.namespace)/\($r.metadata.name)\t\($err)"
' || true
