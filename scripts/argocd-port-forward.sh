#!/usr/bin/env bash
set -euo pipefail

CONTEXT="${KUBE_CONTEXT:-kind-seed}"
NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
LOCAL_PORT="${ARGOCD_LOCAL_PORT:-8080}"
LOCAL_ADDRESS="${ARGOCD_LOCAL_ADDRESS:-127.0.0.1}"
SERVICE="service/argocd-server"

command -v kubectl >/dev/null || { echo "kubectl is required" >&2; exit 1; }

if ! kubectl config get-contexts "${CONTEXT}" >/dev/null 2>&1; then
  echo "Kubernetes context '${CONTEXT}' does not exist." >&2
  echo "Available contexts:" >&2
  kubectl config get-contexts -o name >&2
  exit 1
fi

if ! kubectl --context "${CONTEXT}" get namespace "${NAMESPACE}" >/dev/null 2>&1; then
  echo "Namespace '${NAMESPACE}' does not exist in context '${CONTEXT}'." >&2
  echo "Run ./all-local-setup.sh first." >&2
  exit 1
fi

if ! kubectl --context "${CONTEXT}" get "${SERVICE}" -n "${NAMESPACE}" >/dev/null 2>&1; then
  echo "${SERVICE} does not exist in namespace '${NAMESPACE}'." >&2
  echo "Run ./all-local-setup.sh first." >&2
  exit 1
fi

if ! kubectl --context "${CONTEXT}" rollout status deployment/argocd-server \
  -n "${NAMESPACE}" --timeout=60s >/dev/null; then
  echo "argocd-server is not ready." >&2
  kubectl --context "${CONTEXT}" get pods -n "${NAMESPACE}" \
    -l app.kubernetes.io/name=argocd-server >&2
  exit 1
fi

if command -v ss >/dev/null && ss -ltn "sport = :${LOCAL_PORT}" | grep -q LISTEN; then
  echo "Local port ${LOCAL_PORT} is already in use." >&2
  echo "Choose another port, for example:" >&2
  echo "  ARGOCD_LOCAL_PORT=18080 $0" >&2
  exit 1
fi

cat <<EOF
Starting Argo CD port-forward
  context:   ${CONTEXT}
  namespace: ${NAMESPACE}
  service:   ${SERVICE}
  URL:       http://${LOCAL_ADDRESS}:${LOCAL_PORT}

Keep this terminal open. Press Ctrl-C to stop forwarding.
EOF

exec kubectl --context "${CONTEXT}" port-forward \
  --address "${LOCAL_ADDRESS}" \
  -n "${NAMESPACE}" \
  "${SERVICE}" \
  "${LOCAL_PORT}:80"
