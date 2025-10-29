[🔗 Return to `Table of Contents` for more FAQ topics 🔗](https://github.com/santosr2/airflow-community-chart/tree/main/charts/airflow#frequently-asked-questions)

> Note, this page was written for the [`User-Community Airflow Helm Chart`](https://github.com/santosr2/airflow-community-chart/tree/main/charts/airflow)

# Manage Airflow FAB Roles

## Overview

The chart allows you to declaratively manage custom FAB (Flask AppBuilder) roles using the `airflow.roles` value. This feature enables you to:

- Create custom RBAC roles with specific permissions
- Define granular access control for Airflow resources
- Keep role configurations in version control
- Automatically sync role changes to Airflow

> 🟨 __Note__ 🟨
>
> - This feature **only works with FAB auth manager** (not SimpleAuthManager)
> - Requires Apache Airflow 2.0+ configured with FAB provider (`apache-airflow-providers-fab`)
> - For Airflow 3.1+, ensure you explicitly set `AIRFLOW__CORE__AUTH_MANAGER` to use FAB
> - Custom roles can be assigned to users via the `airflow.users[].role` field
> - Uses Airflow's SecurityManager API (`get_permission`, `create_permission`, `add_permission_to_role`)

## Understanding FAB Roles and Permissions

### Default FAB Roles

Airflow ships with five default roles:

- **Admin**: Full access to all resources and administrative functions
- **Op**: Operator role with access to connections, pools, variables, and operational tasks
- **User**: Standard user with ability to view and trigger DAGs
- **Viewer**: Read-only access to DAGs and task instances
- **Public**: Anonymous users with no permissions

### Permission Structure

Each permission consists of two components:

- **Action**: The operation allowed (e.g., `can_read`, `can_edit`, `can_create`, `can_delete`, `menu_access`)
- **Resource**: The Airflow resource or view (e.g., `DAG`, `Connections`, `Variables`, `DAG Runs`)

### DAG-Level Permissions

> 🟨 __Important__ 🟨
>
> The Helm chart **only manages permissions explicitly defined** in `airflow.roles`. It **preserves all other existing permissions**, including:
> - DAG-level permissions set via `access_control` in DAG code
> - Permissions added manually through the Airflow UI
> - Permissions managed by other tools
>
> This means you can safely use both Helm-managed general permissions AND DAG-specific permissions in your DAG definitions without conflicts.

## Define Custom Roles

You may use the `airflow.roles` value to create custom FAB roles in a declarative way.

### Example 1: Data Scientist Role (Compact Format)

Create a role with read and edit access to DAGs using the compact plural format:

```yaml
airflow:
  roles:
    - name: DataScientist
      permissions:
        # Multiple actions on one resource
        - actions: [can_read, can_edit, can_create]
          resource: DAG
        # One action on multiple resources
        - action: can_read
          resources: [DAG Runs, Task Instances, Task Logs]
        # Single action/resource
        - action: menu_access
          resource: Browse

  ## if we create a Deployment to perpetually sync `airflow.roles`
  rolesUpdate: true
```

### Example 2: Multiple Custom Roles (Mixed Formats)

Create several custom roles for different teams using different format styles:

```yaml
airflow:
  roles:
    - name: DataScientist
      permissions:
        # Using plural actions
        - actions: [can_read, can_edit, can_create]
          resource: DAG

    - name: DataEngineer
      permissions:
        # Multiple actions on multiple resources (cartesian product)
        - actions: [can_read, can_edit]
          resources: [DAG, Connections, Variables]

    - name: ReadOnlyAdmin
      permissions:
        # One action on multiple resources
        - action: can_read
          resources: [Connections, Variables, Pools]
        - action: menu_access
          resources: [Admin, Browse]

  rolesUpdate: true
```

> 💡 __Tip__ 💡
>
> Using `actions: [can_read, can_edit]` with `resources: [DAG, Connections]` creates a cartesian product:
> - can_read + DAG
> - can_read + Connections
> - can_edit + DAG
> - can_edit + Connections

### Example 3: Assigning Custom Roles to Users

Once you've defined custom roles, assign them to users:

```yaml
airflow:
  roles:
    - name: DataScientist
      permissions:
        - actions: [can_read, can_edit, can_create]
          resource: DAG
        - action: can_read
          resources: [Task Instances, Task Logs]

  users:
    - username: alice
      password: strong-password-here
      role: DataScientist  # Use the custom role
      email: alice@example.com
      firstName: Alice
      lastName: Smith

    - username: bob
      password: strong-password-here
      role:
        - DataScientist  # Users can have multiple roles
        - Viewer
      email: bob@example.com
      firstName: Bob
      lastName: Johnson

  rolesUpdate: true
  usersUpdate: true
```

## Common Actions and Resources

### Common Actions

- `can_create` - Create new resources
- `can_read` - View/read resources
- `can_edit` - Modify existing resources
- `can_delete` - Delete resources
- `menu_access` - Access menu items in UI

### Common Resources

**DAG Management:**
- `DAG` - DAG definitions
- `DAG Runs` - DAG run instances
- `Task Instances` - Individual task executions
- `Task Logs` - Task execution logs

**Configuration:**
- `Connections` - External system connections
- `Variables` - Airflow variables
- `Pools` - Resource pools

**Monitoring:**
- `XComs` - Cross-communication data
- `SLA Misses` - SLA violations
- `Audit Logs` - System audit logs

**Menu Access:**
- `Browse` - Browse menu
- `Admin` - Admin menu
- `Docs` - Documentation menu

**Advanced:**
- `Datasets` - Dataset definitions (Airflow 2.4+)
- `ImportError` - DAG import errors
- `Triggers` - Deferrable triggers (Airflow 2.2+)

> 💡 __Tip__ 💡
>
> To see all available resources and permissions, log in as an Admin user and navigate to:
> **Security → List Roles → [Role Name]** to view existing role permissions.

## Sync Behavior

### Continuous Sync (`rolesUpdate: true`)

When `rolesUpdate` is `true` (default):

- A Deployment continuously monitors and syncs roles
- Role changes are updated in real-time (every 60 seconds)
- Role changes made via the Airflow UI will be reverted
- Recommended for production environments

### One-Time Sync (`rolesUpdate: false`)

When `rolesUpdate` is `false`:

- A Helm hook Job syncs roles once after each `helm upgrade`
- Role changes via UI persist until the next deployment
- Useful for development environments

```yaml
airflow:
  roles:
    - name: CustomRole
      permissions:
        - action: can_read
          resource: DAG

  ## Only sync roles during helm upgrade
  rolesUpdate: false
```

## Advanced Configuration

### Finding Available Permissions

To discover available permissions for your Airflow version:

1. Log in as an Admin user
2. Navigate to **Security → List Permissions**
3. View all registered permissions with their actions and resources
4. Use these exact strings in your `airflow.roles` configuration

### Working with DAG-Level Permissions

You can combine Helm-managed general permissions with DAG-specific permissions set in your DAG code:

**In Helm values (general permissions):**

```yaml
airflow:
  roles:
    - name: FinanceTeam
      permissions:
        # General permissions for all resources
        - action: can_read
          resources: [Variables, Connections]
        - action: menu_access
          resource: Browse
```

**In your DAG code (DAG-specific permissions):**

```python
from airflow import DAG

dag = DAG(
    dag_id="finance_report",
    schedule="@daily",
    # DAG-level access control
    access_control={
        "FinanceTeam": {"can_read", "can_edit"},
        "Admin": {"can_read", "can_edit", "can_delete"},
    },
    ...
)
```

The sync process will:
1. ✅ Apply general permissions from Helm (Variables, Connections, Browse)
2. ✅ Preserve DAG-level permissions from code (finance_report access)
3. ✅ Keep both sets of permissions active for the FinanceTeam role

> 💡 __Best Practice__ 💡
>
> Use Helm for **general resource permissions** (Connections, Variables, Pools, etc.) and DAG code for **DAG-specific access control**.

## Troubleshooting

### Role Not Appearing

If a role doesn't appear in Airflow:

1. Check the sync pod logs:
   ```bash
   kubectl logs deployment/airflow-sync-roles
   ```

2. Verify FAB auth manager is configured (Airflow 3.1+):
   ```yaml
   airflow:
     config:
       AIRFLOW__CORE__AUTH_MANAGER: "airflow.providers.fab.auth_manager.fab_auth_manager.FabAuthManager"
   ```

3. Ensure `apache-airflow-providers-fab` is installed:
   ```yaml
   airflow:
     extraPipPackages:
       - "apache-airflow-providers-fab>=1.0.0"
   ```

### Permission Not Found

If you receive "permission not found" errors:

1. Verify the exact action and resource names from Airflow UI (**Security → List Permissions**)
2. Ensure the resource exists (e.g., DAG must be loaded before creating DAG-level permissions)
3. Check for typos in action or resource names

### User Cannot Be Assigned Custom Role

If users cannot be assigned custom roles:

1. Ensure `airflow.roles` is defined before `airflow.users`
2. Verify `rolesUpdate: true` to ensure roles are created before users
3. Check role name matches exactly (case-sensitive)

## Best Practices

1. **Use Descriptive Role Names**: Choose clear names like `DataScientist`, `DataEngineer` instead of generic names
2. **Principle of Least Privilege**: Grant only necessary permissions for each role
3. **Version Control**: Keep role definitions in Git alongside your Helm values
4. **Test in Development**: Test custom roles in a development environment before production
5. **Document Roles**: Add comments in values.yaml explaining each role's purpose
6. **Keep Roles Simple**: Avoid creating too many roles; use a small set of well-defined roles
7. **Use Default Roles**: Leverage existing roles (Admin, Op, User, Viewer) when possible

## Related Documentation

- [Manage Airflow Users](airflow-users.md) - Configure users and assign roles
- [Integrate with LDAP or OAuth](ldap-oauth.md) - External authentication setup
- [Access Control with FAB](https://airflow.apache.org/docs/apache-airflow-providers-fab/stable/auth-manager/access-control.html) - Official Airflow FAB documentation
- [Airflow 3.0 Migration Guide](../guides/airflow-3-migration.md) - Upgrading to Airflow 3.0
