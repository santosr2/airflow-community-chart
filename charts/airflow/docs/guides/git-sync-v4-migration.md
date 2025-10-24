# Git-Sync v4 Migration Guide

This guide covers migrating from git-sync v3 to v4 in the Airflow Helm Chart.

## Overview

Git-sync v4 introduces significant architectural improvements and breaking changes compared to v3. However, this chart maintains **backward compatibility** by detecting the git-sync version and automatically configuring the appropriate environment variables.

## What Changed in v4?

### Key Improvements

1. **Better Performance**: v4 fetches only the specific commit SHA needed, transferring less data
2. **Simplified Sync Loop**: Eliminates race conditions where symbolic refs could change between operations
3. **Enhanced Security**: Latest base images with CVE fixes
4. **Cleaner API**: More consistent flag naming and behavior

### Breaking Changes

| Aspect | v3 | v4 |
|--------|----|----|
| **Default Sync** | Full history | Single commit (depth=1) |
| **Environment Prefix** | `GIT_SYNC_*` | `GITSYNC_*` (accepts both) |
| **Branch/Revision** | Separate `--branch` and `--rev` flags | Unified `--ref` flag |
| **Sync Period** | `--wait` (seconds) | `--period` (Go duration) |
| **Permissions** | `--change-permissions` (deprecated) | `--group-write` |
| **SSH Detection** | Explicit `--ssh` flag required | Auto-detected from repo URL |
| **Root Directory** | `/tmp/git` | `/git` (chart uses `/dags`) |
| **Logging** | Free-form text | Structured JSON |

## Migration Strategies

### Option 1: Automatic (Recommended)

The chart **automatically detects** the git-sync version and configures appropriate environment variables. Simply update the image tag:

```yaml
dags:
  gitSync:
    enabled: true
    image:
      tag: v4.5.0  # Update from v3.6.9
    repo: "https://github.com/your-org/airflow-dags.git"
    branch: main
    revision: HEAD
```

**Result**: The chart continues using v3-compatible variables that v4 accepts.

### Option 2: Opt-in to v4 Features

To leverage v4-specific features, use the new values:

```yaml
dags:
  gitSync:
    enabled: true
    image:
      tag: v4.5.0
    repo: "https://github.com/your-org/airflow-dags.git"

    # v4-specific: Use unified ref instead of branch + revision
    ref: "main"  # Can be branch, tag, or commit SHA

    # v4-specific: Use Go duration format for period
    period: "30s"  # Instead of syncWait: 30

    # v4-change: Sync timeout now requires Go duration format
    syncTimeout: "60s"

    # v4-specific: Enable group-writable permissions
    groupWrite: true

    # v4-specific: Additional git config options
    gitConfig: "http.postBuffer:524288000"
```

### Option 3: Stay on v3

If you need to remain on v3, pin the version:

```yaml
dags:
  gitSync:
    enabled: true
    image:
      tag: v3.6.9  # Pin to v3
    # Continue using existing v3 configuration
```

## New Values in v4

### `dags.gitSync.ref`

**Type**: `string`
**Default**: `""`
**v4 Only**: Yes

Unified git reference (branch, tag, or commit SHA). When set, overrides both `branch` and `revision`.

```yaml
# Examples:
ref: "main"                    # Branch
ref: "v1.2.3"                  # Tag
ref: "abc123def456..."         # Full commit SHA
```

### `dags.gitSync.period`

**Type**: `string`
**Default**: `""`
**v4 Only**: Yes

Sync period using Go duration format. When set, overrides `syncWait`.

```yaml
# Examples:
period: "30s"    # 30 seconds
period: "1m"     # 1 minute
period: "90s"    # 90 seconds
period: "100ms"  # 100 milliseconds
```

### `dags.gitSync.groupWrite`

**Type**: `bool`
**Default**: `false`
**v4 Only**: Yes

Make synced files group-writable. Replaces the deprecated `--change-permissions` flag from v3.

```yaml
groupWrite: true
```

### `dags.gitSync.gitConfig`

**Type**: `string`
**Default**: `""`
**v4 Only**: Yes

Additional git configuration options in `key:value` format (comma-separated).

```yaml
# Examples:
gitConfig: "http.postBuffer:524288000"
gitConfig: "http.postBuffer:524288000,core.compression:0"
```

## Validation

The chart validates that v4-specific values are not used with v3 images. If you try:

```yaml
dags:
  gitSync:
    image:
      tag: v3.6.9  # Using v3
    ref: "main"    # ERROR: v4-only value
```

You'll receive a clear error message:

```
ERROR: git-sync v3 Configuration Error

You have set `dags.gitSync.ref` but are using git-sync v3.6.9.

The `ref` value is only supported in git-sync v4+.

Please either:
  1. Update to git-sync v4: dags.gitSync.image.tag=v4.5.0
  2. Use v3 values: dags.gitSync.branch and dags.gitSync.revision
```

## Complete Examples

### Example 1: Basic v4 Migration

**Before (v3):**
```yaml
dags:
  gitSync:
    enabled: true
    image:
      tag: v3.6.9
    repo: "https://github.com/apache/airflow.git"
    branch: main
    revision: HEAD
    syncWait: 60
    depth: 1
```

**After (v4 - Backward Compatible):**
```yaml
dags:
  gitSync:
    enabled: true
    image:
      tag: v4.5.0
    repo: "https://github.com/apache/airflow.git"
    branch: main      # Still works!
    revision: HEAD    # Still works!
    syncWait: 60      # Still works!
    # v4-change: Sync timeout now requires Go duration format
    syncTimeout: "60s"
    depth: 1
```

**After (v4 - Using New Features):**
```yaml
dags:
  gitSync:
    enabled: true
    image:
      tag: v4.5.0
    repo: "https://github.com/apache/airflow.git"
    ref: "main"       # Unified ref
    period: "1m"      # Go duration format
    depth: 1
    groupWrite: true  # v4 feature
    # v4-change: Sync timeout now requires Go duration format
    syncTimeout: "60s"
```

### Example 2: SSH with v4

**Before (v3):**
```yaml
dags:
  gitSync:
    enabled: true
    image:
      tag: v3.6.9
    repo: "git@github.com:your-org/dags.git"
    branch: main
    sshSecret: "airflow-git-ssh-secret"
    sshKnownHosts: |
      github.com ssh-rsa AAAAB3NzaC1yc2E...
```

**After (v4):**
```yaml
dags:
  gitSync:
    enabled: true
    image:
      tag: v4.5.0
    repo: "git@github.com:your-org/dags.git"
    ref: "main"  # Use v4 ref
    # v4-change: Sync timeout now requires Go duration format
    syncTimeout: "60s"
    sshSecret: "airflow-git-ssh-secret"
    sshKnownHosts: |
      github.com ssh-rsa AAAAB3NzaC1yc2E...
    # Note: GIT_SYNC_SSH is no longer needed - auto-detected!
```

### Example 3: HTTP Auth with v4

```yaml
dags:
  gitSync:
    enabled: true
    image:
      tag: v4.5.0
    repo: "https://github.com/your-org/private-dags.git"
    ref: "v1.2.3"  # Tag
    period: "30s"
    # v4-change: Sync timeout now requires Go duration format
    syncTimeout: "60s"
    httpSecret: "airflow-git-http-secret"
    httpSecretUsernameKey: username
    httpSecretPasswordKey: token
```

### Example 4: Private Repo with Submodules

```yaml
dags:
  gitSync:
    enabled: true
    image:
      tag: v4.5.0
    repo: "https://github.com/your-org/dags-with-submodules.git"
    ref: "main"
    depth: 0  # Full history for submodules
    submodules: recursive
    period: "2m"
    # v4-change: Sync timeout now requires Go duration format
    syncTimeout: "60s"
    httpSecret: "git-credentials"
    groupWrite: true
```

## Additional Resources

- [git-sync v4 Official Migration Guide](https://github.com/kubernetes/git-sync/blob/master/v3-to-v4.md)
- [git-sync GitHub Repository](https://github.com/kubernetes/git-sync)
- [Chart Git-Sync Configuration Docs](../../README.md#dags)

## Getting Help

If you encounter issues during migration:

1. Check the validation error messages for specific guidance
2. Review the [git-sync v4 migration guide](https://github.com/kubernetes/git-sync/blob/master/v3-to-v4.md)
3. Open an issue at [santosr2/airflow-community-chart](https://github.com/santosr2/airflow-community-chart/issues)
