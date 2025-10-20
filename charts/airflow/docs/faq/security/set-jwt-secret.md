[🔗 Return to `Table of Contents` for more FAQ topics 🔗](https://github.com/airflow-helm/charts/tree/main/charts/airflow#frequently-asked-questions)

> Note, this page was written for the [`User-Community Airflow Helm Chart`](https://github.com/airflow-helm/charts/tree/main/charts/airflow)

# Set Airflow JWT Secret

> 🟦 __Information__ 🟦
>
> JWT authentication is used for internal API communication in Airflow 3.0+.
> The chart **automatically generates** a JWT secret if not provided.
> For **production deployments**, you should set a persistent JWT secret.

## When is this needed?

The JWT (JSON Web Token) secret is only used by **Airflow 3.0 and later**. If you are using Airflow 2.x, you do NOT need to set this value.

### Auto-Generation (Default)

If you do NOT set `airflow.jwtSecret` or `airflow.jwtSecretName`, the chart will automatically generate a random JWT secret during deployment. This works fine for:
- Development environments
- Testing
- Single-deployment scenarios

⚠️ **CRITICAL FOR PRODUCTION**: Auto-generated secrets change on each `helm upgrade`, which will cause:
  - **Service Disruption**: All Airflow components will experience authentication failures
  - **Component Restarts**: All pods (API Server, DAG Processor, Scheduler, Workers) will restart
  - **Task Failures**: Running tasks may fail due to JWT authentication errors
  - **Downtime**: Typically 2-5 minutes until all components synchronize with the new secret

**Production Requirement**: ALWAYS set an explicit `jwtSecretName` to avoid these issues.

### Manual Configuration (Production Recommended)

For production deployments, you should explicitly set `airflow.jwtSecretName` to ensure:
- **Persistence** - Secret remains the same across helm upgrades
- **Consistency** - All components use the identical secret
- **Control** - You manage secret rotation on your schedule

The `jwtSecret` should be:
- **Identical** across ALL components (API Server, DAG Processor, Scheduler, Workers)
- **Secure and random** (minimum 32 characters recommended)
- **Stored securely** (preferably in external secret manager, not values.yaml)

## Generate a JWT Secret

Before setting the JWT secret, generate a secure random string:

```bash
# Using Python (recommended)
python -c "import secrets; print(secrets.token_urlsafe(32))"

# Using OpenSSL
openssl rand -base64 32

# Using /dev/urandom (Linux/Mac)
head -c 32 /dev/urandom | base64
```

## Option 1 - using the value

You may set the JWT secret using the `airflow.jwtSecret` value, which sets the `AIRFLOW__API_AUTH__JWT_SECRET` environment variable.

For example, to define the JWT secret with `airflow.jwtSecret`:

```yaml
airflow:
  image:
    tag: "3.0.1"
  jwtSecret: "your-generated-jwt-secret-here"
```

> 🟥 __Security Warning__ 🟥
>
> Storing secrets directly in `values.yaml` is **NOT recommended for production**.
> Use Option 2 or Option 3 to reference secrets from a secret management system.

## Option 2 - using a secret (recommended)

You may set the JWT secret from a Kubernetes Secret by referencing it with the `airflow.jwtSecretName` value.

For example, to use the `value` key from the existing Secret called `airflow-jwt-secret`:

```yaml
airflow:
  image:
    tag: "3.0.1"

  jwtSecretName: "airflow-jwt-secret"
  jwtSecretKey: "your-secret-key"
```

Create the Kubernetes Secret before deploying the chart:

```bash
# Generate and create secret in one command
kubectl create secret generic airflow-jwt-secret \
  --from-literal=value="$(python -c 'import secrets; print(secrets.token_urlsafe(32))')" \
  --namespace airflow
```

## Option 3 - using `_CMD` or `_SECRET` configs

You may also set the JWT secret by specifying either the `AIRFLOW__API_AUTH__JWT_SECRET_CMD` or `AIRFLOW__API_AUTH__JWT_SECRET_SECRET` environment variables.
Read about how the `_CMD` or `_SECRET` configs work in the ["Setting Configuration Options"](https://airflow.apache.org/docs/apache-airflow/stable/howto/set-config.html) section of the Airflow documentation.

For example, to use `AIRFLOW__API_AUTH__JWT_SECRET_CMD`:

```yaml
airflow:
  image:
    tag: "3.0.1"

  ## NOTE: this is only an example, if your value lives in a Secret, you probably want to use "Option 2" above
  config:
    AIRFLOW__API_AUTH__JWT_SECRET_CMD: "cat /opt/airflow/jwt-secret/value"

  extraVolumeMounts:
    - name: jwt-secret
      mountPath: /opt/airflow/jwt-secret
      readOnly: true

  extraVolumes:
    - name: jwt-secret
      secret:
        secretName: airflow-jwt-secret
```

## Option 4 - external secret managers (production recommended)

For production deployments, consider using external secret management systems:

### Using AWS Secrets Manager

```yaml
airflow:
  image:
    tag: "3.0.1"
  
  jwtSecretName: airflow-jwt-secret 
  jwtSecretKey: jwt-secret

# Install External Secrets Operator and create ExternalSecret
# apiVersion: external-secrets.io/v1beta1
# kind: ExternalSecret
# metadata:
#   name: airflow-jwt-secret
# spec:
#   secretStoreRef:
#     name: aws-secrets-manager
#     kind: SecretStore
#   target:
#     name: airflow-jwt-secret
#   data:
#     - secretKey: jwt-secret
#       remoteRef:
#         key: airflow/jwt-secret
```

### Using HashiCorp Vault

```yaml
airflow:
  image:
    tag: "3.0.1"

  jwtSecretName: airflow-jwt-secret 
  jwtSecretKey: jwt-secret

# Use Vault Secrets Operator to sync secrets
# apiVersion: secrets.hashicorp.com/v1beta1
# kind: VaultStaticSecret
# metadata:
#   name: airflow-jwt-secret
# spec:
#   vaultAuthRef: vault-auth
#   mount: secret
#   path: airflow/jwt-secret
#   destination:
#     name: airflow-jwt-secret
#     create: true
```

### Using Google Secret Manager

```yaml
airflow:
  image:
    tag: "3.0.1"

  jwtSecretName: airflow-jwt-secret 
  jwtSecretKey: jwt-secret

# Use External Secrets Operator with GCP backend
# apiVersion: external-secrets.io/v1beta1
# kind: ExternalSecret
# metadata:
#   name: airflow-jwt-secret
# spec:
#   secretStoreRef:
#     name: gcpsm-secret-store
#     kind: SecretStore
#   target:
#     name: airflow-jwt-secret
#   data:
#     - secretKey: jwt-secret
#       remoteRef:
#         key: airflow-jwt-secret
```

## JWT Configuration Options

Besides setting the JWT secret, you can configure additional JWT-related settings:

```yaml
airflow:
  image:
    tag: "3.0.1"

  jwtSecret: "your-jwt-secret"

  config:
    ## Base URL for API Server (required for JWT validation)
    AIRFLOW__API__BASE_URL: "https://airflow.example.com"

    ## JWT token expiration time in seconds (default: 300)
    AIRFLOW__API_AUTH__JWT_EXPIRATION_TIME: "600"

    ## JWT leeway for clock skew tolerance in seconds (default: 0)
    AIRFLOW__API_AUTH__JWT_LEEWAY: "10"
```

### JWT Audience and Issuer (Strongly Recommended)

Apache Airflow official documentation **strongly recommends** setting JWT audience and issuer for production deployments:

```yaml
airflow:
  image:
    tag: "3.1.0"

  jwtSecret: "your-jwt-secret"

  config:
    ## JWT Audience - strongly recommended per official docs
    ## Can be a single value or comma-separated list
    ## The first value is used when generating, others accepted at validation
    AIRFLOW__API_AUTH__JWT_AUDIENCE: "airflow-prod"

    ## JWT Issuer - strongly recommended per official docs
    ## Should be unique per Airflow deployment
    ## Becomes the 'iss' claim in generated tokens
    AIRFLOW__API_AUTH__JWT_ISSUER: "airflow.example.com"
```

**Why These Are Important:**
- **Audience**: Prevents JWT tokens from one environment being used in another
- **Issuer**: Enables JWT validation to confirm tokens came from your Airflow deployment
- **Security**: Provides defense-in-depth against token reuse attacks

See: [Airflow Configuration Reference - api_auth section](https://airflow.apache.org/docs/apache-airflow/stable/configurations-ref.html)

## Troubleshooting

### JWT Secret Not Persisting Across Upgrades

If you notice Airflow components failing after `helm upgrade`, this is likely because the auto-generated JWT secret changed.

**Solution**: Set an explicit `jwt-secret` using one of the options above to persist the secret across upgrades.

### Error: "Invalid JWT token" or "JWT signature verification failed"

This error usually means the JWT secret is not identical across all components.

**Solutions**:
1. Ensure `jwt-secret` is set to the same value for all deployments
2. If using `airflow.jwtSecretName`, verify the secret exists and has the correct value:
   ```bash
   kubectl get secret airflow-jwt-secret -o jsonpath='{.data.value}' | base64 -d
   ```
3. Restart all Airflow components after changing the JWT secret:
   ```bash
   kubectl rollout restart deployment -l app=airflow
   kubectl rollout restart statefulset -l app=airflow
   ```

### Error: "JWT token expired"

JWT tokens have a default expiration time of 300 seconds (5 minutes).

**Solution**: Increase `AIRFLOW__API_AUTH__JWT_EXPIRATION_TIME`:
```yaml
airflow:
  config:
    AIRFLOW__API_AUTH__JWT_EXPIRATION_TIME: "600"  # 10 minutes
```

### Clock Skew Issues

If you see intermittent JWT validation failures, it might be due to clock skew between nodes.

**Solution**: Add JWT leeway tolerance:
```yaml
airflow:
  config:
    AIRFLOW__API_AUTH__JWT_LEEWAY: "10"  # 10 seconds tolerance
```

## Security Best Practices

1. **Never commit JWT secrets to version control** - Use secret management systems
2. **Rotate JWT secrets regularly** - Implement a secret rotation policy
3. **Use strong random secrets** - Minimum 32 characters, use cryptographically secure random generators
4. **Monitor JWT validation failures** - Set up alerts for repeated JWT authentication failures
5. **Use TLS for API communication** - Even with JWT, encrypt traffic between components
6. **Restrict secret access** - Use Kubernetes RBAC to limit who can read JWT secrets

## Additional Resources

- [Airflow 3.0 Migration Guide](../guides/airflow-3-migration.md)
- [Official Airflow Security Documentation](https://airflow.apache.org/docs/apache-airflow/stable/security/)
- [Airflow Configuration Reference](https://airflow.apache.org/docs/apache-airflow/stable/configurations-ref.html)
