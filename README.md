# Llama Stack Showroom

Reference architecture and CI for [Llama Stack](https://github.com/meta-llama/llama-stack) on Red Hat OpenShift AI (RHOAI).

## Purpose

1. **Reference Architecture**: Production-ready deployment of Llama Stack using RHOAI components (VLLM, PostgreSQL, Milvus, Keycloak)
2. **Automated Testing**: CI that validates deployments with example client scripts
3. **Integration Testing**: Test RHOAI/ODH/upstream Llama Stack images through GitHub Actions
4. **Demo Scripts**: Reusable examples (RAG, authentication) for downstream projects

## Architecture

```
┌─────────────────────────────────────────────────────┐
│ Llama Stack Distribution (CRD)                      │
│  ├─ Inference: VLLM (llama-3-2-3b)                  │
│  ├─ Embeddings: VLLM (nomic-embed-text-v1.5)        │
│  ├─ Auth: Keycloak OAuth2 (RBAC + Team-based)       │
│  ├─ Vector Store: Milvus (50Gi)                     │
│  └─ Storage: PostgreSQL (20Gi)                      │
└─────────────────────────────────────────────────────┘
```

**CI/CD**: GitHub Actions workflow tests full deployment lifecycle on ROSA with configurable image overrides for testing ODH/upstream builds.

## Setup

Create environment file (see `config.sh.example` for details):
```bash
cp config.sh.example ~/.lls_showroom
# Edit ~/.lls_showroom and set required values
```

```bash
./setup.sh       # Install RHOAI operator and dependencies
./provision.sh   # Deploy Llama Stack distribution
```

## Run Demo

```bash
./scripts/rag-demo.py $LLAMA_STACK_URL $KEYCLOAK_URL $USERNAME $PASSWORD
```

Example:
```bash
./scripts/rag-demo.py https://llamastack-distribution-redhat-ods-applications.apps.rosa.derekscluster.ij5f.p3.openshiftapps.com https://keycloak-redhat-ods-applications.apps.rosa.derekscluster.ij5f.p3.openshiftapps.com admin admin123
```

## Cleanup

```bash
./unprovision.sh  # Remove Llama Stack distribution
./cleanup.sh      # Remove RHOAI operator and dependencies
```

## Testing

CI workflow (`.github/workflows/provision.yml`) runs on PRs and supports image overrides:
- `catalog_image`: Custom RHOAI catalog source
- `llama_stack_image`: Custom Llama Stack distro image
- `llama_stack_operator_image`: Custom operator image

This enables testing ODH/upstream builds before they're released.

## Contributing

Contributions welcome in:
- Additional demo scripts (reuse from [llama-stack-demos](https://github.com/opendatahub-io/llama-stack-demos))
- Kustomize overlays to work towards a single refarch
- CI/CD improvements and test coverage

See `scripts/README.md` for detailed demo documentation.
