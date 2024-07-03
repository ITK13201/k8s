# Kubernetes

## READMEs per Environment

### Local README

[./README_MINIKUBE](./README_MINIKUBEL.md)

### Production README

[./README_PRODUCTION](./README_PRODUCTION.md)

## Application-specific notes

#### Kubernetes Dashboard

Keep v6 for a while because v6 -> v7 update is not compatible.

#### Growi

Mongo DB error "Authentication Failed" (confirmed in Growi's application log) occurs in the editor screen with v7.0.9 or higher, so the version is left at v7.0.3.
Versions between v7.0.3 and v7.0.9 are unconfirmed.
