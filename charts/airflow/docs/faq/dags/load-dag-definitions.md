[🔗 Return to `Table of Contents` for more FAQ topics 🔗](https://github.com/santosr2/airflow-community-chart/tree/main/charts/airflow#frequently-asked-questions)

> Note, this page was written for the [`User-Community Airflow Helm Chart`](https://github.com/santosr2/airflow-community-chart/tree/main/charts/airflow)

# Load Airflow DAGs

To use your airflow cluster, you will need to make your DAG definitions (python files) available to airflow.

While there are many ways you can achieve this, we natively support the following methods.

## Option 1 - Git-Sync Sidecar

You may store DAG definitions in a git repo and configure the chart to automatically sync a local copy this repo into each airflow Pod at a regular interval.

> 🟨 __Note__ 🟨
>
> The chart supports both git-sync v3 and v4 with automatic version detection.
> For git-sync v4 migration information, see the [git-sync v4 migration guide](../../guides/git-sync-v4-migration.md).

> 🟦 __Tip__ 🟦
>
> The content of the git repo will be stored at `{dags.path}/repo/`,
> by default this will be `/opt/airflow/dags/repo/`.

<details>
<summary>
  <a id="ssh-authentication"></a>
  <b>SSH Authentication</b>
</summary>

---

The git-sync sidecars can access the git repo using SSH authentication.

For example to sync `git@github.com:USERNAME/REPOSITORY.git` using the RSA keys stored in `Secret/airflow-ssh-git-secret`:

```yaml
airflow:
  config:
    ## NOTE: set by `dags.gitSync.syncWait`, unless you override it
    #AIRFLOW__SCHEDULER__DAG_DIR_LIST_INTERVAL: 60

dags:
  ## NOTE: this is the default value
  path: /opt/airflow/dags
  
  gitSync:
    enabled: true
    
    ## NOTE: some git providers will need an `ssh://` prefix
    repo: "git@github.com:USERNAME/REPOSITORY.git"
    branch: "master"
    revision: "HEAD"
    
    ## the sub-path within your repo where dags are located
    ## NOTE: airflow will only see dags under this path, but the whole repo will still be synced
    #repoSubPath: "path/to/dags"
    
    ## number of seconds to wait between syncs
    ## NOTE: also sets `AIRFLOW__SCHEDULER__DAG_DIR_LIST_INTERVAL` unless overwritten in `airflow.config`
    syncWait: 60
    
    ## the max number of seconds allowed for a complete sync
    ## NOTE: if your repo takes a very long time to sync, you may need to increase this value
    #syncTimeout: 120
    
    ## the number of consecutive failures allowed before aborting
    ## NOTE: if your repo regularly has intermittent failures, you may wish to set a non-0 value
    #maxFailures: 0
    
    sshSecret: "airflow-ssh-git-secret"
    sshSecretKey: "id_rsa"
    
    ## NOTE: "known_hosts" verification can be disabled by setting to "" 
    sshKnownHosts: |-
      github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=
```

> 🟦 __Tip__ 🟦
>
> You may create `Secret/airflow-ssh-git-secret` using this command,
> if you have the SSH private key stored under `$HOME/.ssh/id_rsa`:
> 
> ```shell
> kubectl create secret generic \
>   airflow-ssh-git-secret \
>   --from-file=id_rsa=$HOME/.ssh/id_rsa \
>   --namespace my-airflow-namespace
> ```

</details>

<details>
<summary>
  <a id="https-authentication"></a>
  <b>HTTP Authentication</b>
</summary>

---

The git-sync sidecars can access the git repo using HTTP authentication.

For example, to sync `https://github.com/USERNAME/REPOSITORY.git` using the HTTP credentials stored in `Secret/airflow-http-git-secret`:

```yaml
airflow:
  config:
    ## NOTE: set by `dags.gitSync.syncWait`, unless you override it
    #AIRFLOW__SCHEDULER__DAG_DIR_LIST_INTERVAL: 60

dags:
  ## NOTE: this is the default value
  path: /opt/airflow/dags
  
  gitSync:
    enabled: true
    
    repo: "https://github.com/USERNAME/REPOSITORY.git"
    branch: "master"
    revision: "HEAD"
    
    ## the sub-path within your repo where dags are located
    ## NOTE: airflow will only see dags under this path, but the whole repo will still be synced
    #repoSubPath: "path/to/dags"
    
    ## number of seconds to wait between syncs
    ## NOTE: also sets `AIRFLOW__SCHEDULER__DAG_DIR_LIST_INTERVAL` unless overwritten in `airflow.config`
    syncWait: 60
    
    ## the max number of seconds allowed for a complete sync
    ## NOTE: if your repo takes a very long time to sync, you may need to increase this value
    #syncTimeout: 120
    
    ## the number of consecutive failures allowed before aborting
    ## NOTE: if your repo regularly has intermittent failures, you may wish to set a non-0 value
    #maxFailures: 0
    
    httpSecret: "airflow-http-git-secret"
    httpSecretUsernameKey: username
    httpSecretPasswordKey: password
```

> 🟦 __Tip__ 🟦
>
> You may create `Secret/airflow-http-git-secret` using this command, 
> replacing `MY_GIT_USERNAME` and `MY_GIT_TOKEN` with your HTTP credentials:
> 
> ```shell
> kubectl create secret generic \
>   airflow-http-git-secret \
>   --from-literal=username='MY_GIT_USERNAME' \
>   --from-literal=password='MY_GIT_TOKEN' \
>   --namespace my-airflow-namespace
> ```

</details>

## Option 2 - Bucket-Sync Sidecar

You may store DAG definitions in cloud storage buckets and configure the chart to automatically sync a local copy into each airflow Pod at a regular interval.

> 🟨 __Note__ 🟨
>
> Currently supported providers:
>
> - __AWS S3__ (and S3-compatible storage like MinIO, DigitalOcean Spaces)
>
> Future providers (coming soon):
>
> - Google Cloud Storage (GCS)
> - Azure Blob Storage

> 🟦 __Tip__ 🟦
>
> The content of the bucket will be stored at `{dags.path}/repo/`,
> by default this will be `/opt/airflow/dags/repo/`.
>
> If you specify `dags.bucketSync.subPath`, the DAGs folder will be `{dags.path}/repo/{subPath}`.

> 🟨 __Note__ 🟨
>
> - Bucket-sync and git-sync are __mutually exclusive__ - you can only enable one at a time
> - For detailed S3 setup guide, see: [Load DAGs from AWS S3](./load-dag-definitions-from-s3.md)

<details>
<summary>
  <a id="s3-example"></a>
  <b>AWS S3 Example (with IAM roles)</b>
</summary>

---

The bucket-sync sidecars can access S3 buckets using IAM roles (recommended for EKS) or credentials.

For example, to sync from S3 bucket `my-airflow-dags` with IRSA (IAM Roles for Service Accounts):

```yaml
serviceAccount:
  create: true
  annotations:
    ## EKS - IAM Roles for Service Accounts (IRSA)
    ## This automatically provides AWS credentials to all containers in the pod
    eks.amazonaws.com/role-arn: "arn:aws:iam::XXXXXXXXXX:role/my-airflow-role"

dags:
  bucketSync:
    enabled: true
    provider: s3

    s3:
      bucket: "my-airflow-dags"
      key: "dags"  ## Prefix within the bucket
      region: "us-east-1"

      ## Optional: sync only a subdirectory within the synced content
      ## DAGs will be at: /opt/airflow/dags/repo/production
      # subPath: "production"

      ## Optional: exclude files from sync
      syncFlags: "--exclude '*.pyc' --exclude '__pycache__/*' --exclude '.git/*'"

    ## number of seconds to wait between syncs
    syncInterval: 60

    ## the number of consecutive failures allowed before aborting
    maxFailures: 3
```

> 🟦 __Tip__ 🟦
>
> __IRSA__ (IAM Roles for Service Accounts) is the __recommended authentication method__ for EKS:
>
> - No credentials stored in Kubernetes
> - Automatic credential rotation
> - Fine-grained IAM policies
> - Better audit trail via CloudTrail
>
> The service account annotation automatically injects AWS credentials into ALL containers in the pod,
> including the bucket-sync sidecar.

</details>

<details>
<summary>
  <a id="s3-credentials"></a>
  <b>S3 with Credentials (not recommended)</b>
</summary>

---

For non-EKS environments or testing, you can use AWS credentials stored in a Kubernetes Secret:

```yaml
dags:
  bucketSync:
    enabled: true
    provider: s3

    s3:
      bucket: "my-airflow-dags"
      key: "dags"
      region: "us-east-1"
      credentialsSecret: "aws-credentials"

    syncInterval: 60
```

> 🟦 __Tip__ 🟦
>
> For permanent IAM user credentials:
>
> ```shell
> kubectl create secret generic \
>   aws-credentials \
>   --from-literal=aws_access_key_id='AKIA...' \
>   --from-literal=aws_secret_access_key='...' \
>   --namespace my-airflow-namespace
> ```
>
> For temporary credentials (STS, AssumeRole) include the session token:
>
> ```shell
> kubectl create secret generic \
>   aws-temp-credentials \
>   --from-literal=aws_access_key_id='ASIAQ...' \
>   --from-literal=aws_secret_access_key='...' \
>   --from-literal=aws_session_token='IQoJb3...' \
>   --namespace my-airflow-namespace
> ```
>
> Then configure: `credentialsSecretSessionTokenKey: "aws_session_token"`
>
> See the [S3 DAG loading guide](./load-dag-definitions-from-s3.md) for detailed examples.

</details>

<details>
<summary>
  <a id="s3-compatible"></a>
  <b>S3-Compatible Storage (MinIO, DigitalOcean Spaces, etc.)</b>
</summary>

---

You can use S3-compatible storage by specifying a custom endpoint:

```yaml
dags:
  bucketSync:
    enabled: true
    provider: s3

    s3:
      bucket: "my-airflow-dags"
      key: "dags"
      endpoint: "https://minio.example.com"
      credentialsSecret: "s3-compatible-credentials"

    syncInterval: 60
```

</details>

## Option 3 - Persistent Volume Claim

You may use a [`PersistentVolumeClaim`](https://kubernetes.io/docs/concepts/storage/persistent-volumes/) to share your DAG definitions across the airflow Pods.

> 🟨 __Note__ 🟨
>
> The `PersistentVolumeClaim` will be empty by default,
> you must either manually fill it with your DAG files, or configure an external system to automate this process.
> For example, you may create a CI/CD pipeline on your DAGs repo to update the volume as commits are made.

<details>
<summary>
  <a id="chart-managed-volume"></a>
  <b>Chart Managed Volume</b>
</summary>

---

The chart can manage the initial creation of a PersistentVolumeClaim for your DAG files.

> 🟦 __Tip__ 🟦
>
> The name of the `PersistentVolumeClaim` will be your helm release-name with `"-dags"` appended.
> <br>
> For example, if you use `helm install my-airflow ...`, the PVC will be called `my-airflow-dags`.

For example, to have the chart create a PersistentVolumeClaim with the `storageClass` called `default` and a `size` of `1Gi`:

```yaml
dags:
  ## NOTE: this is the default value
  path: /opt/airflow/dags
  
  persistence:
    enabled: true
    
    ## NOTE: set `storageClass` to "" for the cluster-default
    storageClass: "default" 
    
    ## NOTE: some types of StorageClass will ignore this request (for example, EFS)
    size: 1Gi
    
    ## NOTE: as multiple Pods read the DAGs concurrently this MUST be ReadOnlyMany or ReadWriteMany
    accessMode: ReadOnlyMany
```

</details>

<details>
<summary>
  <a id="user-managed-volume"></a>
  <b>User Managed Volume</b>
</summary>

---

If you wish to take more control of the PersistentVolumeClaim used for your DAG files, you may create a 
[`PersistentVolumeClaim`](https://kubernetes.io/docs/concepts/storage/persistent-volumes/#persistentvolumeclaims) 
resource inside your helm install namespace and then tell the chart to use it.

For example, to have the chart use an existing PersistentVolumeClaim called `my-dags-pvc`:

```yaml
dags:
  ## NOTE: this is the default value
  path: /opt/airflow/dags
  
  persistence:
    enabled: true
    
    ## NOTE: this is name of your existing volume
    existingClaim: my-dags-pvc
    
    ## NOTE: as multiple Pods read the DAGs concurrently this MUST be ReadOnlyMany or ReadWriteMany
    accessMode: ReadOnlyMany
```

</details>

## Option 4 - Embedded Into Container Image

You may embed your DAG files directly into the container image.

> 🟥 __Warning__ 🟥
>
> This method requires all airflow containers to restart after each update to your DAG files.
> <br>
> All airflow Pods will run the same image, and have the latest DAG definitions.

<details>
<summary>
  <a id="example"></a>
  <b>Example</b>
</summary>

---

This chart uses the official [`apache/airflow`](https://hub.docker.com/r/apache/airflow) Docker images.

Here is a Dockerfile that extends `apache/airflow:2.8.4-python3.9` by placing DAG files into `/opt/airflow/dags`:

```dockerfile
FROM apache/airflow:2.8.4-python3.9

## copy the content of local folder `./my_dag_folder` into container folder `/opt/airflow/dags`
COPY ./my_dag_folder /opt/airflow/dags
```

You might then build and tag this Dockerfile as `MY_REPO:MY_TAG`.

The following values tell the chart to use the `MY_REPO:MY_TAG` container image:

```yaml
airflow:
  image:
    repository: MY_REPO
    tag: MY_TAG

    ## WARNING: even if set to "Always" DO NOT reuse tag names, 
    ##          containers only pull the latest image when restarting
    pullPolicy: IfNotPresent
```

> 🟥 __Warning__ 🟥
>
> Ensure that you NEVER REUSE an image tag name.
> <br>
> This ensures that whenever you update `airflow.image.tag`, all airflow pods will restart and have the same DAGs.
> <br>
> For example, you may append a version or git hash corresponding to your DAGs:
>
> 1. `MY_REPO:MY_TAG-v1`, `MY_REPO:MY_TAG-v2`, `MY_REPO:MY_TAG-v3`
> 2. `MY_REPO:MY_TAG-0.1.0`, `MY_REPO:MY_TAG-0.1.1`, `MY_REPO:MY_TAG-0.1.3`
> 3. `MY_REPO:MY_TAG-a1a1a1a`, `MY_REPO:MY_TAG-a2a2a3a`, `MY_REPO:MY_TAG-a3a3a3a`

</details>