#!/usr/bin/env bash
# Merge platform-agnostic-mutli-user exposure → Gateway shturval-gateway; disable chart Ingress.
set -euo pipefail

SSC_NAME="${SSC_NAME:-kubeflow-step-2}"

if ! kubectl get shturvalserviceconfig "$SSC_NAME" &>/dev/null; then
  echo "ShturvalServiceConfig/$SSC_NAME not found" >&2
  exit 1
fi

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

kubectl get shturvalserviceconfig "$SSC_NAME" -o json | jq '
  .spec.customvalues."platform-agnostic-mutli-user" |= (. // {}) |
  .spec.customvalues."platform-agnostic-mutli-user".exposure = "gateway" |
  .spec.customvalues."platform-agnostic-mutli-user".gateway = {
    create: false,
    name: "shturval-gateway",
    namespace: "gateway-system"
  } |
  .spec.customvalues."platform-agnostic-mutli-user".ingress |= (. // {}) |
  .spec.customvalues."platform-agnostic-mutli-user".ingress.enabled = false |
  del(.metadata.resourceVersion, .metadata.uid, .metadata.managedFields, .status)
' >"$tmp"

kubectl apply -f "$tmp"

echo "Patched ShturvalServiceConfig/$SSC_NAME (spec.customvalues)."
echo "Watch: kubectl get ssc $SSC_NAME -o jsonpath='{.status.appliedCustomValues.platform-agnostic-mutli-user.ingress.enabled}{\"\\n\"}'"
echo "Reconcile SSC in platform UI if GitOpsEngineNotReady."
