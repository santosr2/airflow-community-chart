# Airflow 3.0 Migration Guide

This guide explains how to migrate from Airflow 2.x to Airflow 3.0+ using the User-Community Airflow Helm Chart.

## Table of Contents

- [Overview](#overview)
- [Key Architectural Changes](#key-architectural-changes)
- [Prerequisites](#prerequisites)
- [Migration Steps](#migration-steps)
- [Configuration Changes](#configuration-changes)
- [Troubleshooting](#troubleshooting)
- [Rollback Plan](#rollback-plan)

---

## Overview

Airflow 3.0 introduces significant architectural changes that affect how components are deployed and communicate. The most notable change is the separation of the Webserver into two distinct components:

- **API Server**: Handles all API requests (replaces the Webserver's API functionality)
- **DAG Processor**: Handles DAG parsing (formerly part of the Scheduler)

This chart automatically manages these architectural differences based on your `airflow.image.tag` configuration.

## Key Architectural Changes

### Component Changes

| Airflow 2.x | Airflow 3.0+ | Purpose |
|-------------|--------------|---------|
| Webserver | **API Server** | Serves the Web UI and handles API requests |
| N/A | **DAG Processor** | Parses DAG files independently from Scheduler |
| Scheduler | Scheduler | Focuses solely on task scheduling (no longer parses DAGs) |

### Internal API Authentication

Airflow 3.0+ requires **JWT (JSON Web Token) authentication** for internal communication between components:
- API Server ↔ Scheduler
- API Server ↔ DAG Processor
- API Server ↔ Workers
- Scheduler ↔ Workers

---

## Prerequisites

Before migrating, ensure you have:

1. **Backup your database**: Always backup your Airflow metadata database before upgrading
2. **Review breaking changes**: Check the [official Airflow 3.0 release notes](https://airflow.apache.org/docs/apache-airflow/stable/release_notes.html)
3. **Test in non-production**: Perform the migration in a test environment first
4. **Chart version**: Ensure you're using chart version `9.0.0` or later

---

## Migration Steps

### Step 1: Generate JWT Secret

Generate a secure JWT secret for internal API authentication:

```bash
python -c "import secrets; print(secrets.token_urlsafe(32))"
```

**Security Best Practice**: Store this in your secret management system (e.g., AWS Secrets Manager, HashiCorp Vault, Kubernetes Secrets) rather than directly in `values.yaml`.

### Step 2: Update values.yaml

Update your Helm values file with Airflow 3.0 configuration:

```yaml
airflow:
  image:
    repository: apache/airflow
    tag: "3.0.1-python3.11"  # or your preferred Python version

  # REQUIRED: Set JWT secret for internal API authentication
  jwtSecret: "your-generated-jwt-secret-here"

  # Optional: Configure API-specific settings
  config:
    # API Server base URL (adjust for your ingress/service setup)
    AIRFLOW__API__BASE_URL: "http://airflow.example.com"

    # JWT token expiration (default: 300 seconds)
    AIRFLOW__API_AUTH__JWT_EXPIRATION_TIME: "600"

    # JWT leeway for clock skew tolerance (default: 0 seconds)
    AIRFLOW__API_AUTH__JWT_LEEWAY: "10"

# API Server configuration (Airflow 3.0+ component)
apiServer:
  # Number of API Server replicas (recommend 2+ for HA)
  replicas: 2

  # Resource requests/limits
  resources:
    requests:
      cpu: "500m"
      memory: "1Gi"
    limits:
      cpu: "1000m"
      memory: "2Gi"

  # Readiness and liveness probes (pre-configured)
  readinessProbe:
    enabled: true
  livenessProbe:
    enabled: true

# DAG Processor configuration (Airflow 3.0+ component)
dagProcessor:
  # Number of DAG Processor replicas
  replicas: 1

  # Resource requests/limits
  resources:
    requests:
      cpu: "500m"
      memory: "1Gi"
    limits:
      cpu: "1000m"
      memory: "2Gi"

  # Probes
  livenessProbe:
    enabled: true

# Webserver is automatically disabled for Airflow 3.0+
# No need to set web.replicas: 0
```

### Step 3: Upgrade Database Schema

Before upgrading the Helm chart, run database migrations:

```bash
# Option 1: Using kubectl exec (if you have an existing deployment)
kubectl exec -it deployment/airflow-scheduler -- airflow db upgrade

# Option 2: Run as a one-time job
kubectl run airflow-db-upgrade \
  --image=apache/airflow:3.0.1 \
  --restart=Never \
  --command -- airflow db upgrade
```

### Step 4: Upgrade Helm Chart

Upgrade your Helm release:

```bash
helm upgrade airflow airflow-helm/airflow \
  --version 9.0.0 \
  -f values.yaml \
  --namespace airflow
```

### Step 5: Verify Deployment

Check that all new components are running:

```bash
# Check API Server pods
kubectl get pods -l component=api-server -n airflow

# Check DAG Processor pods
kubectl get pods -l component=dag_processor -n airflow

# Check Scheduler pods
kubectl get pods -l component=scheduler -n airflow

# View logs
kubectl logs -l component=api-server -n airflow --tail=50
kubectl logs -l component=dag_processor -n airflow --tail=50
```

### Step 6: Test Functionality

1. **Access the Web UI**: Navigate to your Airflow URL
2. **Check DAG parsing**: Verify that DAGs are being parsed correctly
3. **Run a test DAG**: Execute a simple DAG to ensure task execution works
4. **Check API**: Test the API endpoint: `curl http://your-airflow/api/v1/health`

---

## Configuration Changes

### Automatic Configuration Validations

The chart includes automatic validations to prevent version-specific configuration errors:

#### Airflow 3.0+ Validations

When deploying Airflow 3.0+, the chart validates that you use the correct components:

1. **API Server vs Webserver**: You must use `apiServer.*` configuration instead of `web.*`
   - ❌ **Invalid**: `web.replicas: 2`
   - ✅ **Valid**: `apiServer.replicas: 2` and `web.replicas: 0` (or unset)

2. **API Secret Key**: You must use `airflow.apiSecretKey` instead of `airflow.webserverSecretKey`
   - ❌ **Invalid**: Setting `airflow.webserverSecretKey` to a custom value
   - ✅ **Valid**: `airflow.apiSecretKey: "your-secret-key"`

3. **Ingress Configuration**: You must use `ingress.apiServer.*` instead of `ingress.web.*`
   - ❌ **Invalid**: `ingress.web.host: "airflow.example.com"`
   - ✅ **Valid**: `ingress.apiServer.host: "airflow.example.com"`

#### Airflow 2.x Validations

When deploying Airflow 2.x, the chart validates the opposite:

1. **Webserver vs API Server**: You must use `web.*` configuration instead of `apiServer.*`
   - ❌ **Invalid**: `apiServer.replicas: 2`
   - ✅ **Valid**: `web.replicas: 2` and `apiServer.replicas: 0` (default)

2. **Webserver Secret Key**: You must use `airflow.webserverSecretKey` instead of `airflow.apiSecretKey`
   - ❌ **Invalid**: Setting `airflow.apiSecretKey`
   - ✅ **Valid**: `airflow.webserverSecretKey: "your-secret-key"`

3. **Ingress Configuration**: You must use `ingress.web.*` instead of `ingress.apiServer.*`
   - ❌ **Invalid**: `ingress.apiServer.host: "airflow.example.com"`
   - ✅ **Valid**: `ingress.web.host: "airflow.example.com"`

These validations help ensure smooth deployments and prevent common misconfiguration errors during migration.

### JWT Secret via External Secret (Recommended)

Instead of storing the JWT secret directly in `values.yaml`, reference it from a Kubernetes Secret:

```yaml
airflow:
  jwtSecretName: airflow-jwt-secret 
  jwtSecretKey: jwt-secret
```

Create the Kubernetes Secret:

```bash
kubectl create secret generic airflow-secrets \
  --from-literal=jwt-secret="your-generated-jwt-secret" \
  -n airflow
```

### Ingress Configuration

Update your ingress to point to the API Server service instead of the Webserver:

```yaml
ingress:
  enabled: true
  apiServer:
    # The chart automatically routes to api-server service for Airflow 3.0+
    host: "airflow.example.com"
    path: "/"
    annotations: {}
    ingressClassName: ""
```

**Migration Note**: If you have existing `ingress.web.*` configuration in your values.yaml, you must move it to `ingress.apiServer.*`. The chart will fail validation if both are configured or if `ingress.web.*` is configured for Airflow 3.0+.

### Monitoring and Metrics

ServiceMonitor and PrometheusRule are automatically configured for API Server and DAG Processor:

```yaml
serviceMonitor:
  enabled: true
  selector:
    prometheus: "kube-prometheus"

prometheusRule:
  enabled: true
  groups:
    - name: airflow-api-server
      rules:
        - alert: AirflowAPIServerDown
          expr: up{component="api-server"} == 0
          for: 5m
```

### Authentication (REQUIRED for Airflow 3.1.0+)

> 🟧 **Important** 🟧
>
> Airflow 3.1.0+ changed the default authentication from FAB to Simple Authentication.
> For production deployments, you **MUST** explicitly configure authentication.

Airflow 3.0 used FAB (Flask AppBuilder) as the default auth manager. Airflow 3.1.0+ changed the default to Simple Authentication. To continue using FAB (recommended for most deployments with user management and RBAC):

```yaml
airflow:
  image:
    tag: 3.1.0

  config:
    ## Use FAB Auth Manager (required for most production deployments)
    AIRFLOW__CORE__AUTH_MANAGER: "airflow.providers.fab.auth_manager.fab_auth_manager.FabAuthManager"

    ## Configure API authentication backends for FAB
    AIRFLOW__API__AUTH_BACKENDS: "airflow.providers.fab.auth_manager.api.auth.backend.jwt,airflow.providers.fab.auth_manager.api.auth.backend.session,airflow.providers.fab.auth_manager.api.auth.backend.basic_auth"

    ## Ensure FAB permissions are updated on startup (avoids None perms on fresh installs)
    AIRFLOW__FAB__UPDATE_FAB_PERMS: "True"
```

**For Simple Authentication (not recommended for production):**
```yaml
airflow:
  image:
    tag: 3.1.0

  config:
    AIRFLOW__CORE__AUTH_MANAGER: "airflow.auth.managers.simple.simple_auth_manager.SimpleAuthManager"
```

See: [Airflow Auth Manager Documentation](https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/auth-manager/)

---

## Troubleshooting

### JWT Authentication Errors

**Symptom**: Errors like `"Invalid JWT token"` or `"JWT signature verification failed"`

**Solution**:
- Ensure `jwt-secret` is identical across all components
- Check that the secret is properly mounted as an environment variable
- Verify JWT expiration settings are appropriate

### DAG Parsing Issues

**Symptom**: DAGs not appearing in the UI

**Solution**:
- Check DAG Processor logs: `kubectl logs -l component=dag_processor -n airflow`
- Verify DAG files are accessible (check git-sync or volume mounts)
- Ensure DAG Processor has at least 1 replica

### API Server Connection Issues

**Symptom**: Components can't reach the API Server

**Solution**:
- Verify API Server service is running: `kubectl get svc -n airflow`
- Check network policies and firewall rules
- Ensure `AIRFLOW__API__BASE_URL` is correctly configured

### Database Migration Failures

**Symptom**: Database migration fails during upgrade

**Solution**:
- Restore from backup
- Check Airflow 3.0 compatibility with your database version
- Review migration logs for specific errors

---

## Rollback Plan

If you need to rollback to Airflow 2.x:

### Step 1: Restore Database Backup

```bash
# Restore your database backup from before the migration
# Example for PostgreSQL:
pg_restore -h postgres-host -U airflow -d airflow backup_before_upgrade.dump
```

### Step 2: Revert Helm Chart

```bash
helm rollback airflow -n airflow
```

Or update values.yaml:

```yaml
airflow:
  airflowVersion: "2.8.4"  # Your previous version
  image:
    tag: "2.8.4-python3.9"
  jwtSecret: ""  # Can be empty for Airflow 2.x
```

```bash
helm upgrade airflow airflow-helm/airflow -f values.yaml -n airflow
```

### Step 3: Verify Rollback

```bash
# Check that Webserver is running (not API Server)
kubectl get pods -l component=web -n airflow

# Verify DAG Processor is removed
kubectl get pods -l component=dag_processor -n airflow
# Should return: No resources found
```

---

## Additional Resources

- [Official Airflow 3.0 Documentation](https://airflow.apache.org/docs/apache-airflow/3.0.0/)
- [JWT Secret Security Guide](../faq/security/set-jwt-secret.md)
- [Chart Configuration Guide](../faq/configuration/airflow-configs.md)
- [Community Support](https://github.com/airflow-helm/charts/discussions)

---

## Need Help?

If you encounter issues during migration:

1. Check the [Troubleshooting section](#troubleshooting) above
2. Search [existing issues](https://github.com/airflow-helm/charts/issues)
3. Ask in [GitHub Discussions](https://github.com/airflow-helm/charts/discussions)
4. Review [official Airflow documentation](https://airflow.apache.org/docs/)
