# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a Kubernetes configuration repository that manages multiple applications using GitOps with ArgoCD. The repository uses Kustomize for manifest management and supports both Minikube (local) and production environments.

## Architecture

### GitOps with ArgoCD

The repository is structured for GitOps deployment using ArgoCD:
- ArgoCD ApplicationSet (`manifests/argocd/application-set.yaml`) automatically generates Applications for each directory under `manifests/`
- Applications are auto-synced with prune enabled, meaning changes pushed to the repository are automatically deployed
- The main branch is tracked by ArgoCD (configured to watch `HEAD`)

### Manifest Structure

Manifests are organized by application/component under `manifests/`:
- Each application directory contains a `kustomization.yaml` file
- Applications use a mix of:
  - **Helm charts** (via Kustomize helmCharts field) - e.g., minecraft, nextcloud, growi
  - **Remote manifests** (via URL) - e.g., ArgoCD installation
  - **Custom manifests** (local YAML files) - e.g., rss-notifier, growi-converter

Key directories:
- `manifests/namespaces/` - Namespace definitions (referenced by `kustomization.yaml`)
- `manifests/pv/` - PersistentVolume definitions for local storage
- `manifests/ingress/` - Ingress resources for external access
- `manifests/*/cronjob-*/` - CronJob configurations (e.g., automatic restarts, backups)

### Deployed Applications

The cluster hosts several applications:
- **Infrastructure**: cert-manager, ingress-nginx, ArgoCD, kubernetes-dashboard
- **Monitoring**: Prometheus (metrics collection), Grafana (visualization), Alertmanager (alert notifications)
- **Services**: Nextcloud (file sharing), Growi (wiki), Minecraft/Palworld (game servers)
- **Custom apps**: rss-generator, rss-notifier (custom notification system)

## Common Commands

### Minikube Environment

Start cluster:
```bash
minikube start --cpus=4 --memory=8192
```

Create tunnel for LoadBalancer access:
```bash
minikube tunnel
```

Load local images (always use specific tags, not 'latest'):
```bash
minikube image load <IMAGE>:<TAG>
```

Delete cluster:
```bash
minikube delete
```

### Secrets Management

Generate Kubernetes Secret manifests from credential files:
```bash
./bin/create_secrets.sh
```

This script:
- Reads `.env` files from `credentials/<namespace>/` directory
- Generates Secret YAML files in `secrets/<namespace>/` directory
- Uses `kubectl create secret --dry-run=client` to generate manifests

### Applying Manifests

Since this repository uses ArgoCD, typically you should:
1. Make changes to manifests in this repository
2. Commit and push to the main branch
3. ArgoCD will automatically detect and apply changes

For manual application (when not using ArgoCD):
```bash
kubectl apply -k manifests/<application-name>/
```

### Working with Helm-based Applications

Many applications use Helm charts integrated via Kustomize. To modify:
1. Edit the `values-*.yaml` file in the application directory
2. The `kustomization.yaml` references this values file via `valuesFile` field
3. Commit changes - ArgoCD will regenerate and apply the Helm chart

## Important Notes

### Application-Specific Constraints

**Kubernetes Dashboard**: Keep at v6 temporarily - v7 upgrade is not compatible.

**Growi**: Must remain at v7.0.3 due to MongoDB "Authentication Failed" errors in v7.0.9+. The issue manifests in the editor screen.

### Image Version Management

- The repository uses Renovate (`renovate.json`) for automated dependency updates
- Renovate is configured to:
  - Auto-merge minor/patch updates for non-0.x versions
  - Track Helm chart versions in kustomization files
  - Track container image versions in YAML files
  - Track GitHub release URLs and raw.githubusercontent.com references

### Credentials and Secrets

- Never commit actual credentials to the repository
- Use the `credentials/` directory (gitignored) for local credential files
- Use `./bin/create_secrets.sh` to generate Secret manifests
- The `secrets/` directory contains generated YAML files that reference secrets

### PersistentVolumes

PersistentVolumes are pre-created for applications requiring persistent storage. When adding a new application with storage needs:
1. Create PV definition in `manifests/pv/`
2. Create PVC in the application's directory
3. Reference the PVC in the application's deployment/statefulset

### Testing and Deployment Workflow

Before deploying to production, always test in Minikube environment first:

1. **Create feature branch**
   ```bash
   git checkout -b feature/<feature-name>
   ```

2. **Test in Minikube**
   - Start Minikube cluster: `minikube start --cpus=4 --memory=8192`
   - Apply manifests manually: `kubectl apply -k manifests/<application-name>/`
   - Verify functionality using port-forwarding or Minikube tunnel
   - Run validation checks

3. **Deploy to production**
   - Merge to main branch after testing is complete
   - ArgoCD automatically syncs and deploys changes

**Important**: Never skip Minikube testing for infrastructure changes (monitoring, ingress, cert-manager, etc.)

### Design Documents

Detailed design documents are located in `docs/`:
- `docs/prometheus-grafana-design.md` - Prometheus and Grafana monitoring stack design, including:
  - Architecture and component overview
  - Deployment steps (Minikube testing and production)
  - Discord alert notification setup
  - Validation checklist
  - Troubleshooting guide

**Documentation Style**:
- Use Mermaid diagrams for architecture and flow diagrams (architecture diagrams, sequence diagrams, state diagrams, etc.)
- Use ASCII tree format for directory structures
- Store design documents in `docs/` directory
