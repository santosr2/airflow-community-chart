[🔗 Return to `Table of Contents` for more FAQ topics 🔗](https://github.com/santosr2/airflow-community-chart/tree/main/charts/airflow#frequently-asked-questions)

> Note, this page was written for the [`User-Community Airflow Helm Chart`](https://github.com/santosr2/airflow-community-chart/tree/main/charts/airflow)

# Load DAGs from AWS S3

This guide shows how to load DAG definitions from AWS S3 buckets using the chart's built-in bucket-sync feature.

## Overview

The bucket-sync sidecar automatically syncs DAG files from your S3 bucket to each Airflow Pod at regular intervals. This approach is recommended for:

- **AWS EKS deployments** - leverages IAM Roles for Service Accounts (IRSA)
- **S3-compatible storage** - MinIO, DigitalOcean Spaces, Ceph, etc.
- **Centralized DAG management** - single source of truth for all DAG files

> 🟦 __Tip__ 🟦
>
> The DAG files from S3 will be synced to `{dags.path}/repo/` in each Pod.
> By default, this is `/opt/airflow/dags/repo/`.
>
> If you specify `dags.bucketSync.subPath`, the DAGs folder will be `{dags.path}/repo/{subPath}`.

## Prerequisites

1. An S3 bucket containing your DAG files
2. Appropriate IAM permissions for Airflow Pods to read from the bucket
3. Kubernetes cluster with the chart installed

## Method 1: IAM Roles for Service Accounts (Recommended for EKS)

This is the recommended approach for EKS clusters as it eliminates the need to manage AWS credentials.

### Step 1: Create an IAM Policy

Create an IAM policy that allows reading from your S3 bucket:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket"
      ],
      "Resource": "arn:aws:s3:::my-airflow-dags"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject"
      ],
      "Resource": "arn:aws:s3:::my-airflow-dags/*"
    }
  ]
}
```

### Step 2: Create an IAM Role for Service Account

Follow the [AWS documentation](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html) to create an IAM role with the above policy and associate it with your Kubernetes service account.

> 🟦 __Tip__ 🟦
>
> Use `eksctl` to simplify this process:
>
> ```bash
> eksctl create iamserviceaccount \
>   --name my-airflow-sa \
>   --namespace airflow \
>   --cluster my-eks-cluster \
>   --attach-policy-arn arn:aws:iam::ACCOUNT_ID:policy/my-airflow-s3-policy \
>   --approve
> ```

### Step 3: Configure the Helm Chart

```yaml
serviceAccount:
  create: true
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::ACCOUNT_ID:role/my-airflow-role"

dags:
  bucketSync:
    enabled: true
    provider: s3

    s3:
      ## The S3 bucket name
      bucket: "my-airflow-dags"

      ## The path within the bucket where DAGs are located
      key: "dags"

      ## AWS region
      region: "us-east-1"

      ## Optional: AWS CLI image (defaults to amazon/aws-cli:2.31.22)
      # image:
      #   repository: amazon/aws-cli
      #   tag: "2.31.22"

      ## Optional: exclude specific files/patterns
      syncFlags: "--exclude '*.pyc' --exclude '__pycache__/*' --exclude '.git/*'"

    ## Sync interval in seconds
    syncInterval: 60

    ## Optional: resource limits for the sync container
    resources:
      requests:
        memory: "128Mi"
        cpu: "100m"
      limits:
        memory: "256Mi"
        cpu: "200m"

    ## Number of consecutive failures before aborting
    maxFailures: 3
```

> 🟦 __Tip__ 🟦
>
> __How IRSA Works:__
>
> When you configure `serviceAccount.annotations.eks.amazonaws.com/role-arn`, the EKS Pod Identity Webhook
> automatically injects AWS credentials into __ALL containers__ in the pod, including the bucket-sync sidecar.
>
> The injected environment variables include:
>
> - `AWS_ROLE_ARN` - The IAM role ARN
> - `AWS_WEB_IDENTITY_TOKEN_FILE` - Path to the token file
> - `AWS_REGION` - (if you set `s3.region`)
>
> No additional configuration is needed in the bucket-sync container - it inherits these credentials automatically!

## Method 2: AWS Credentials (Not Recommended)

For non-EKS environments or testing, you can use AWS access key credentials.

> 🟥 __Warning__ 🟥
>
> This method requires storing AWS credentials in Kubernetes Secrets.
> IAM Roles for Service Accounts (IRSA) is the recommended approach.

### Option A: Permanent IAM User Credentials

For permanent IAM user credentials:

```bash
kubectl create secret generic aws-credentials \
  --from-literal=aws_access_key_id='AKIA...' \
  --from-literal=aws_secret_access_key='...' \
  --namespace airflow
```

Configure the Helm Chart:

```yaml
dags:
  bucketSync:
    enabled: true
    provider: s3

    s3:
      bucket: "my-airflow-dags"
      key: "dags"
      region: "us-east-1"

      ## Reference the credentials secret
      credentialsSecret: "aws-credentials"
      credentialsSecretAccessKeyKey: "aws_access_key_id"
      credentialsSecretSecretKeyKey: "aws_secret_access_key"

    syncInterval: 60
```

### Option B: Temporary Credentials (STS, AssumeRole)

For temporary security credentials (STS AssumeRole, federated access, EC2 instance profiles):

```bash
kubectl create secret generic aws-temp-credentials \
  --from-literal=aws_access_key_id='ASIAQ...' \
  --from-literal=aws_secret_access_key='...' \
  --from-literal=aws_session_token='IQoJb3JpZ2luX2VjE...' \
  --namespace airflow
```

Configure the Helm Chart:

```yaml
dags:
  bucketSync:
    enabled: true
    provider: s3

    s3:
      bucket: "my-airflow-dags"
      key: "dags"
      region: "us-east-1"

      ## Reference the temporary credentials secret
      credentialsSecret: "aws-temp-credentials"
      credentialsSecretAccessKeyKey: "aws_access_key_id"
      credentialsSecretSecretKeyKey: "aws_secret_access_key"
      credentialsSecretSessionTokenKey: "aws_session_token"

    syncInterval: 60
```

> 🟦 **Tip** 🟦
>
> Temporary credentials typically expire after 1-12 hours. You'll need to:
>
> - Automate credential refresh before expiration
> - Update the Kubernetes secret with new credentials
> - Restart pods to pick up the new credentials
>
> For cross-account access, use STS AssumeRole:
>
> ```bash
> aws sts assume-role \
>   --role-arn "arn:aws:iam::ACCOUNT:role/ROLE_NAME" \
>   --role-session-name "airflow-dags-sync"
> ```

</details>

### Option C: Inline Credentials (NOT RECOMMENDED - Testing/Development Only)

> 🟥 __WARNING__ 🟥
>
> __This method hardcodes credentials in your values.yaml and is EXTREMELY INSECURE.__
>
> - Credentials exposed in version control (Git history)
> - Visible in Helm release data
> - No credential rotation
> - __NEVER use in production__
>
> A security warning will be displayed during deployment.

For local development or testing only, you can specify credentials directly in values.yaml:

```yaml
dags:
  bucketSync:
    enabled: true
    provider: s3

    s3:
      bucket: "my-airflow-dags"
      key: "dags"
      region: "us-east-1"

      ## [NOT RECOMMENDED] Inline credentials (permanent IAM user)
      accessKeyId: "AKIA..."
      secretAccessKey: "..."

    syncInterval: 60
```

For temporary credentials (STS, AssumeRole), include the session token:

```yaml
dags:
  bucketSync:
    enabled: true
    provider: s3

    s3:
      bucket: "my-airflow-dags"
      key: "dags"
      region: "us-east-1"

      ## [NOT RECOMMENDED] Inline temporary credentials
      accessKeyId: "ASIAQ..."
      secretAccessKey: "..."
      sessionToken: "IQoJb3JpZ2luX2VjE..."

    syncInterval: 60
```

> 🟥 __Security Reminder__ 🟥
>
> If you must use this method:
>
> 1. __NEVER commit credentials to Git__ - use `.gitignore` for values files
> 2. __Rotate credentials frequently__ - especially after testing
> 3. __Use restrictive IAM policies__ - limit to specific S3 bucket/prefix
> 4. __Migrate to IRSA or Secrets__ before production deployment
>
> See: [charts/airflow/docs/faq/dags/load-dag-definitions-from-s3.md](./load-dag-definitions-from-s3.md)

## Method 3: S3-Compatible Storage (MinIO, DigitalOcean Spaces, etc.)

You can use S3-compatible storage providers by specifying a custom endpoint.

```yaml
dags:
  bucketSync:
    enabled: true
    provider: s3

    s3:
      bucket: "my-airflow-dags"
      key: "dags"

      ## Custom endpoint for S3-compatible storage
      endpoint: "https://minio.example.com"

      ## S3-compatible credentials
      credentialsSecret: "s3-compatible-credentials"

    syncInterval: 60
```

> 🟦 **Tip** 🟦
>
> For MinIO, create the credentials secret with:
>
> ```bash
> kubectl create secret generic s3-compatible-credentials \
>   --from-literal=aws_access_key_id='minioadmin' \
>   --from-literal=aws_secret_access_key='minioadmin' \
>   --namespace airflow
> ```

## Advanced Configuration

### Organizing DAGs with Sub-Paths

You can use the `subPath` option to organize multiple environments in one bucket:

```yaml
dags:
  bucketSync:
    enabled: true
    provider: s3

    s3:
      bucket: "my-airflow-dags"
      key: "production"  # Base path in bucket

    subPath: "team-a"  # Additional filter: production/team-a/
    syncInterval: 60
```

This configuration syncs files from `s3://my-airflow-dags/production/team-a/` to `/opt/airflow/dags/repo/team-a/`.

### Sync Flags and Filtering

Use `syncFlags` to pass additional options to the AWS CLI `s3 sync` command:

```yaml
dags:
  bucketSync:
    enabled: true
    provider: s3

    s3:
      bucket: "my-airflow-dags"
      key: "dags"
      region: "us-east-1"

      ## Exclude patterns, delete removed files, etc.
      syncFlags: >-
        --exclude '*.pyc'
        --exclude '__pycache__/*'
        --exclude '.git/*'
        --exclude '*.md'
        --delete
```

### Handling Sync Failures

Configure failure handling to make the sync process more resilient:

```yaml
dags:
  bucketSync:
    enabled: true
    provider: s3

    s3:
      bucket: "my-airflow-dags"
      key: "dags"
      region: "us-east-1"

    syncInterval: 60

    ## Allow up to 3 consecutive failures before the container exits
    ## Set to -1 to retry forever after the initial sync
    maxFailures: 3
```

## Troubleshooting

### Check Sync Container Logs

View logs from the bucket-sync sidecar:

```bash
# For scheduler
kubectl logs -n airflow -l component=scheduler -c dags-bucket-sync

# For workers
kubectl logs -n airflow -l component=worker -c dags-bucket-sync
```

### Common Issues

**"Access Denied" Errors:**

- Verify IAM role permissions include `s3:ListBucket` and `s3:GetObject`
- Check that the service account annotation is correct
- Ensure the trust relationship allows the service account to assume the role

**Sync Takes Too Long:**

- Reduce the number of files in your S3 bucket
- Use `syncFlags` to exclude unnecessary files
- Increase `resources.limits` for the sync container

**DAGs Not Appearing:**

- Verify the bucket name and key path are correct
- Check that DAG files have the `.py` extension
- Ensure files are in the correct location within the bucket
- Check scheduler logs for DAG parsing errors

### Validation

After deployment, verify the sync is working:

```bash
# Check that the DAGs folder is populated
kubectl exec -it -n airflow deploy/my-release-scheduler -- ls -la /opt/airflow/dags/

# Verify sync container is running
kubectl get pods -n airflow -l component=scheduler

# Check sync logs for successful syncs
kubectl logs -n airflow -l component=scheduler -c dags-bucket-sync --tail=50
```

## Best Practices

1. **Use IAM Roles** - Always prefer IAM Roles for Service Accounts over credentials
2. **Organize Your Bucket** - Use clear folder structures: `{environment}/{team}/{dags}/`
3. **Exclude Unnecessary Files** - Use `syncFlags` to exclude `.pyc`, `__pycache__`, `.git`, etc.
4. **Monitor Sync Performance** - Set appropriate `syncInterval` based on your DAG update frequency
5. **Set Resource Limits** - Configure `resources` to prevent sync containers from consuming too many cluster resources
6. **Version Your DAGs** - Consider using git tags or version folders in S3
7. **Test in Non-Production First** - Validate your configuration in a development environment

## Related Documentation

- [Load DAG Definitions (Overview)](./load-dag-definitions.md)
- [AWS EKS IAM Roles for Service Accounts](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
