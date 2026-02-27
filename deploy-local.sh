#!/bin/bash
#
# deploy-local.sh - Deploy Local LlamaStack Changes
#
# This script enables developers to build and deploy their local LlamaStack code
# changes to a remote OpenShift cluster for testing.
#
# Usage:
#   export LLAMA_STACK_SOURCE_PATH=~/projects/llama-stack
#   ./deploy-local.sh
#
# See README.md for documentation.

set -euo pipefail

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source configuration if available
if [ -f ~/.lls_showroom ]; then
  # shellcheck source=/dev/null
  source ~/.lls_showroom
fi

# Default configuration
DEV_IMAGE_NAMESPACE="${DEV_IMAGE_NAMESPACE:-redhat-ods-applications}"
DEV_IMAGE_NAME="${DEV_IMAGE_NAME:-llama-stack-dev}"
DEV_IMAGE_TAG="${DEV_IMAGE_TAG:-dev-$(date +%Y%m%d-%H%M%S)}"
CONTAINER_TOOL="${CONTAINER_TOOL:-podman}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
  echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
  echo -e "${GREEN}✓${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
  echo -e "${RED}✗${NC} $1"
}

# Print banner
print_banner() {
  echo ""
  echo "=========================================="
  echo "  Deploy Local LlamaStack Changes"
  echo "=========================================="
  echo ""
}

# Setup registry configuration
setup_registry() {
  log_info "Setting up in-cluster registry configuration..."

  # Check if internal registry route exists
  if ! oc get route default-route -n openshift-image-registry &>/dev/null; then
    log_warn "Internal registry route not found. Attempting to enable it..."

    if oc patch configs.imageregistry.operator.openshift.io/cluster \
      --type=merge -p '{"spec":{"defaultRoute":true}}' 2>/dev/null; then
      log_info "Waiting for route to be created (up to 3 minutes)..."
      if oc wait --for=condition=Admitted route/default-route \
        -n openshift-image-registry --timeout=180s 2>/dev/null; then
        log_success "Internal registry route enabled"
      else
        log_error "Timeout waiting for registry route"
        log_error "Please enable it manually: oc patch configs.imageregistry.operator.openshift.io/cluster --type=merge -p '{\"spec\":{\"defaultRoute\":true}}'"
        exit 1
      fi
    else
      log_error "Failed to enable internal registry route"
      log_error "You may need cluster-admin permissions or the registry may not be available"
      exit 1
    fi
  fi

  # Get registry route
  REGISTRY_ROUTE=$(oc get route default-route -n openshift-image-registry -o jsonpath='{.spec.host}')
  if [ -z "${REGISTRY_ROUTE}" ]; then
    log_error "Failed to get internal registry route"
    exit 1
  fi

  log_success "Registry route: ${REGISTRY_ROUTE}"

  # Set image URLs
  PUSH_IMAGE="${REGISTRY_ROUTE}/${DEV_IMAGE_NAMESPACE}/${DEV_IMAGE_NAME}:${DEV_IMAGE_TAG}"
  PULL_IMAGE="image-registry.openshift-image-registry.svc:5000/${DEV_IMAGE_NAMESPACE}/${DEV_IMAGE_NAME}:${DEV_IMAGE_TAG}"

  # Test authentication
  log_info "Testing registry authentication..."
  if ! ${CONTAINER_TOOL} login -u "$(oc whoami)" -p "$(oc whoami -t)" \
    --tls-verify=false ${REGISTRY_ROUTE} &>/dev/null; then
    log_error "Failed to authenticate with internal registry"
    log_info "Trying to login again..."
    if ! ${CONTAINER_TOOL} login -u "$(oc whoami)" -p "$(oc whoami -t)" \
      --tls-verify=false ${REGISTRY_ROUTE}; then
      log_error "Registry authentication failed"
      exit 1
    fi
  fi
  log_success "Registry authentication successful"

  export PUSH_IMAGE
  export PULL_IMAGE
}

# Get base image from operator CSV
get_base_image() {
  if [ -n "${DEV_BASE_IMAGE:-}" ]; then
    echo "${DEV_BASE_IMAGE}"
    return
  fi

  log_info "Auto-detecting base image from operator..." >&2

  CSV_NAME=$(oc get csv -n redhat-ods-operator -o json 2>/dev/null | \
    jq -r '.items[] | select(.metadata.name | startswith("rhods-operator")) | .metadata.name' | head -1)

  if [ -n "${CSV_NAME}" ]; then
    BASE_IMAGE=$(oc get csv "${CSV_NAME}" -n redhat-ods-operator \
      -o jsonpath='{.spec.relatedImages[?(@.name=="odh_llama_stack_core_image")].image}' 2>/dev/null)

    if [ -n "${BASE_IMAGE}" ]; then
      # Replace registry.redhat.io with quay.io to match the Kyverno policy in setup.sh
      # The operator CSV references registry.redhat.io (requires auth), but our Kyverno
      # policy rewrites images to use quay.io as images mightn't be available at registry.redhat.io
      BASE_IMAGE="${BASE_IMAGE/registry.redhat.io/quay.io}"
      log_success "Base image: ${BASE_IMAGE}" >&2
      echo "${BASE_IMAGE}"
      return
    fi
  fi

  log_error "Failed to auto-detect base image" >&2
  log_error "Please set DEV_BASE_IMAGE in ~/.lls_showroom" >&2
  exit 1
}

# Validate prerequisites
validate_prerequisites() {
  log_info "Validating prerequisites..."

  # Check for container tool
  if ! command -v ${CONTAINER_TOOL} &>/dev/null; then
    log_error "${CONTAINER_TOOL} not found"
    log_info "Please install podman or docker"
    exit 1
  fi
  log_success "${CONTAINER_TOOL} found"

  # Check for oc
  if ! command -v oc &>/dev/null; then
    log_error "oc command not found"
    log_info "Please install OpenShift CLI: https://docs.openshift.com/container-platform/latest/cli_reference/openshift_cli/getting-started-cli.html"
    exit 1
  fi
  log_success "oc found"

  # Check cluster connectivity
  if ! oc whoami &>/dev/null; then
    log_error "Not logged in to OpenShift cluster"
    log_info "Please login: oc login <cluster-url>"
    exit 1
  fi
  log_success "Connected to cluster as $(oc whoami)"

  # Check LLAMA_STACK_SOURCE_PATH
  if [ -z "${LLAMA_STACK_SOURCE_PATH:-}" ]; then
    log_error "LLAMA_STACK_SOURCE_PATH not set"
    log_error "Please set it in ~/.lls_showroom or as an environment variable"
    log_info "Example: export LLAMA_STACK_SOURCE_PATH=~/projects/llama-stack"
    exit 1
  fi

  if [ ! -d "${LLAMA_STACK_SOURCE_PATH}" ]; then
    log_error "LlamaStack source directory not found: ${LLAMA_STACK_SOURCE_PATH}"
    exit 1
  fi

  if [ ! -f "${LLAMA_STACK_SOURCE_PATH}/setup.py" ] && [ ! -f "${LLAMA_STACK_SOURCE_PATH}/pyproject.toml" ]; then
    log_error "Not a valid LlamaStack source directory (missing setup.py or pyproject.toml)"
    exit 1
  fi

  log_success "LlamaStack source found: ${LLAMA_STACK_SOURCE_PATH}"

  # Setup registry
  setup_registry
}

# Build dev image
build_dev_image() {
  log_info "Building dev image..."

  BASE_IMAGE=$(get_base_image)

  echo ""
  echo "Build configuration:"
  echo "  Base image:   ${BASE_IMAGE}"
  echo "  Source:       ${LLAMA_STACK_SOURCE_PATH}"
  echo "  Target image: ${PUSH_IMAGE}"
  echo ""

  # Build the image
  cd "${LLAMA_STACK_SOURCE_PATH}"

  if ${CONTAINER_TOOL} build \
    -f "${SCRIPT_DIR}/Dockerfile.dev" \
    --build-arg BASE_IMAGE="${BASE_IMAGE}" \
    -t "${PUSH_IMAGE}" \
    .; then
    log_success "Image built successfully"
  else
    log_error "Image build failed"
    exit 1
  fi
}

# Push dev image
push_dev_image() {
  log_info "Pushing image to in-cluster registry..."

  # Push with retry logic
  MAX_RETRIES=3
  RETRY_COUNT=0

  while [ ${RETRY_COUNT} -lt ${MAX_RETRIES} ]; do
    # For internal registry, disable TLS verification
    if ${CONTAINER_TOOL} push --tls-verify=false "${PUSH_IMAGE}"; then
      log_success "Image pushed successfully"
      return 0
    fi

    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ ${RETRY_COUNT} -lt ${MAX_RETRIES} ]; then
      log_warn "Push failed, retrying (${RETRY_COUNT}/${MAX_RETRIES})..."
      sleep 5
    fi
  done

  log_error "Failed to push image after ${MAX_RETRIES} attempts"
  exit 1
}

# Apply Kyverno policy for image replacement
apply_kyverno_policy() {
  log_info "Applying Kyverno policy for dev image..."

  # Export for envsubst
  export SHOWROOM_LLAMA_STACK_IMAGE="${PULL_IMAGE}"

  # Build the policy YAML from template
  POLICY_YAML="apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: replace-rhoai-llama-stack-images
  annotations:
    policies.kyverno.io/title: Replace RHOAI Llama Stack Images
    policies.kyverno.io/category: Image Management
    policies.kyverno.io/subject: Pod
    policies.kyverno.io/description: >-
      Replaces RHOAI llama-stack images with custom versions for testing/development.
spec:
  background: false
  failurePolicy: Ignore
  rules:
$(envsubst < "${SCRIPT_DIR}/policies/replace-llama-stack-core.yaml.template")"

  # Apply the policy
  if echo "$POLICY_YAML" | oc apply -f - &>/dev/null; then
    log_success "Kyverno policy applied successfully"
  else
    log_error "Failed to apply Kyverno policy"
    log_info "You may need to run ./setup.sh first to install Kyverno"
    exit 1
  fi
}

# Update deployment
update_deployment() {
  log_info "Updating deployment to use dev image..."

  echo ""
  echo "Image configuration:"
  echo "  Push URL:  ${PUSH_IMAGE}"
  echo "  Pull URL:  ${PULL_IMAGE}"
  echo ""

  # Apply Kyverno policy to replace images
  apply_kyverno_policy

  # Delete the pod to force recreation with new image
  log_info "Restarting LlamaStack pod..."

  POD_NAME=$(oc get pods -n ${DEV_IMAGE_NAMESPACE} -l app=llama-stack \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

  if [ -n "${POD_NAME}" ]; then
    if oc delete pod "${POD_NAME}" -n ${DEV_IMAGE_NAMESPACE}; then
      log_success "Pod deleted, operator will recreate it with dev image"
    else
      log_warn "Failed to delete pod, you may need to delete it manually"
    fi
  else
    log_warn "No LlamaStack pod found, it may not be deployed yet"
    log_info "Run ./provision.sh to deploy LlamaStack"
    return
  fi

  # Wait for new pod to be ready
  log_info "Waiting for new pod to be ready..."

  if oc wait --for=condition=Ready pod -l app=llama-stack \
    -n ${DEV_IMAGE_NAMESPACE} --timeout=300s 2>/dev/null; then
    log_success "Pod is ready"
  else
    log_warn "Timeout waiting for pod to be ready"
    log_info "Check pod status with: oc get pods -n ${DEV_IMAGE_NAMESPACE} -l app=llama-stack"
  fi
}

# Follow logs
follow_logs() {
  log_info "Fetching pod logs..."

  # Give old pod time to fully terminate to avoid race condition
  sleep 3

  POD_NAME=$(oc get pods -n ${DEV_IMAGE_NAMESPACE} -l app=llama-stack \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

  if [ -z "${POD_NAME}" ]; then
    log_warn "No pod found"
    return
  fi

  echo ""
  echo "Pod: ${POD_NAME}"
  echo ""

  # Get image to verify it's using our dev image
  CURRENT_IMAGE=$(oc get pod "${POD_NAME}" -n ${DEV_IMAGE_NAMESPACE} \
    -o jsonpath='{.spec.containers[0].image}' 2>/dev/null || true)

  if [ -n "${CURRENT_IMAGE}" ]; then
    echo "Current image: ${CURRENT_IMAGE}"
    echo ""

    if [[ "${CURRENT_IMAGE}" == *"${DEV_IMAGE_NAME}:${DEV_IMAGE_TAG}"* ]]; then
      log_success "Pod is using the dev image!"
    else
      log_warn "Pod may not be using the dev image yet"
      log_warn "Expected: ${PULL_IMAGE}"
      log_warn "Current:  ${CURRENT_IMAGE}"
    fi
  fi

  echo ""
  echo "Streaming logs (Ctrl+C to exit)..."
  echo "=========================================="
  echo ""

  oc logs -f "${POD_NAME}" -n ${DEV_IMAGE_NAMESPACE} 2>/dev/null || \
    log_warn "Failed to stream logs"
}

# Main function
main() {
  print_banner

  validate_prerequisites
  build_dev_image
  push_dev_image
  update_deployment
  follow_logs

  echo ""
  log_success "Local deployment complete!"
  echo ""
  echo "Your local LlamaStack changes are now running on the cluster."
  echo "Route: https://$(oc get route llamastack-distribution -n ${DEV_IMAGE_NAMESPACE} -o jsonpath='{.spec.host}' 2>/dev/null)"
  echo ""
  echo "To revert to the official image, run: ./provision.sh"
  echo ""
}

# Run main function
main "$@"
