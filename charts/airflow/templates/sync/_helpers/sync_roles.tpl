{{/*
The python sync script for roles.
*/}}
{{- define "airflow.sync.sync_roles.py" }}
############################
#### BEGIN: GLOBAL CODE ####
############################
{{- include "airflow.sync.global_code" . }}
##########################
#### END: GLOBAL CODE ####
##########################


#############
## Imports ##
#############
import sys
{{- if .Values.airflow.legacyCommands }}
import airflow.www_rbac.app as www_app
flask_app, flask_appbuilder = www_app.create_app()
{{- else }}
{{- if semverCompare ">= 3.0.0" (include "airflow.version" .) }}
import airflow.providers.fab.www.app as www_app
flask_app = www_app.create_app(enable_plugins=True)
{{- else }}
import airflow.www.app as www_app
flask_app = www_app.create_app()
{{- end }}
flask_appbuilder = flask_app.appbuilder
{{- end }}

# we want type hints, but airflow keeps moving the `Role` and `Permission` models around
#                                  (╯°□°)╯︵ ┻━┻
from typing import Any
Role = Any
Permission = Any

#############
## Classes ##
#############
class PermissionWrapper(object):
    def __init__(
            self,
            action: str,
            resource: str
    ):
        self.action = action
        self.resource = resource

    def __repr__(self):
        return f"PermissionWrapper(action={self.action}, resource={self.resource})"


class RoleWrapper(object):
    def __init__(
            self,
            name: str,
            permissions: Optional[List[PermissionWrapper]] = None
    ):
        self.name = name
        self.permissions = permissions or []

    def __repr__(self):
        return f"RoleWrapper(name={self.name}, permissions={self.permissions})"


###############
## Variables ##
###############
VAR__TEMPLATE_NAMES = []
VAR__TEMPLATE_MTIME_CACHE = {}
VAR__TEMPLATE_VALUE_CACHE = {}
VAR__ROLE_WRAPPERS = {
  {{- range .Values.airflow.roles }}
  {{ .name | quote }}: RoleWrapper(
    name={{ (required "each `name` in `airflow.roles` must be non-empty!" .name) | quote }},
    permissions=[
      {{- if .permissions }}
      {{- range .permissions }}
      {{- /* Determine actions - support both singular 'action' and plural 'actions' */ -}}
      {{- $actions := list -}}
      {{- if .action -}}
        {{- $actions = list .action -}}
      {{- else if .actions -}}
        {{- $actions = .actions -}}
      {{- else -}}
        {{ required "each permission in `airflow.roles[].permissions` must have either `action` or `actions`!" nil }}
      {{- end -}}
      {{- /* Determine resources - support both singular 'resource' and plural 'resources' */ -}}
      {{- $resources := list -}}
      {{- if .resource -}}
        {{- $resources = list .resource -}}
      {{- else if .resources -}}
        {{- $resources = .resources -}}
      {{- else -}}
        {{ required "each permission in `airflow.roles[].permissions` must have either `resource` or `resources`!" nil }}
      {{- end -}}
      {{- /* Generate PermissionWrapper for each action-resource combination */ -}}
      {{- range $action := $actions }}
      {{- range $resource := $resources }}
      PermissionWrapper(
        action={{ (required "action must be non-empty!" $action) | quote }},
        resource={{ (required "resource must be non-empty!" $resource) | quote }}
      ),
      {{- end }}
      {{- end }}
      {{- end }}
      {{- end }}
    ]
  ),
  {{- end }}
}


###############
## Functions ##
###############
def get_or_create_permission(action: str, resource: str) -> Permission:
    """
    Get or create a FAB Permission object for an action/resource pair.
    Works with Airflow 2.x+ SecurityManager API.
    """
    permission = flask_appbuilder.sm.get_permission(action, resource)
    if not permission:
        # create the permission if it doesn't exist
        logging.info(f"Creating new permission: action=`{action}`, resource=`{resource}`")
        permission = flask_appbuilder.sm.create_permission(action, resource)
        if not permission:
            logging.error(f"Failed to create permission: action=`{action}`, resource=`{resource}`")
            sys.exit(1)
    return permission


def sync_role(role_wrapper: RoleWrapper) -> None:
    """
    Sync the Role defined by a provided RoleWrapper into the FAB DB.
    This function only manages the permissions explicitly defined in the Helm chart.
    It preserves any existing permissions not managed by this chart (e.g., DAG-level permissions).
    """
    role_name = role_wrapper.name
    logging.info(f"Syncing role: {role_name}")

    # find or create the role
    role = flask_appbuilder.sm.find_role(role_name)
    if not role:
        logging.info(f"Role=`{role_name}` is missing, creating...")
        role = flask_appbuilder.sm.add_role(role_name)
        if not role:
            logging.error(f"Failed to create Role=`{role_name}`")
            sys.exit(1)
        logging.info(f"Role=`{role_name}` was successfully created.")

    # build the set of permissions we're managing from Helm
    managed_permissions_map = {}  # key: (action, resource), value: Permission
    for perm_wrapper in role_wrapper.permissions:
        perm = get_or_create_permission(perm_wrapper.action, perm_wrapper.resource)
        key = (perm_wrapper.action, perm_wrapper.resource)
        managed_permissions_map[key] = perm

    # get current permissions and separate managed from unmanaged
    current_managed = {}
    unmanaged_permissions = []

    for perm in role.permissions:
        # Permission objects have .action.name and .resource.name attributes
        key = (perm.action.name, perm.resource.name)
        if key in managed_permissions_map:
            # this is a permission we're managing
            current_managed[key] = perm
        else:
            # this is an unmanaged permission (e.g., DAG-level), preserve it
            unmanaged_permissions.append(perm)

    # determine which managed permissions need to be added or removed
    current_managed_keys = set(current_managed.keys())
    desired_managed_keys = set(managed_permissions_map.keys())

    to_add = desired_managed_keys - current_managed_keys
    to_remove = current_managed_keys - desired_managed_keys

    # if no changes needed, we're done
    if not to_add and not to_remove:
        logging.debug(f"Role=`{role_name}` managed permissions are already up-to-date.")
        return

    logging.info(f"Role=`{role_name}` managed permissions have changed, updating...")
    logging.info(f"  Preserving {len(unmanaged_permissions)} unmanaged permissions (e.g., DAG-level)")
    logging.info(f"  Managing {len(managed_permissions_map)} permissions from Helm chart")

    if to_add:
        logging.info(f"  Adding {len(to_add)} new managed permissions")
        for key in to_add:
            perm = managed_permissions_map[key]
            flask_appbuilder.sm.add_permission_to_role(role, perm)

    if to_remove:
        logging.info(f"  Removing {len(to_remove)} managed permissions")
        for key in to_remove:
            perm = current_managed[key]
            flask_appbuilder.sm.remove_permission_from_role(role, perm)

    logging.info(f"Role=`{role_name}` permissions were successfully updated.")


def sync_all_roles(role_wrappers: Dict[str, RoleWrapper]) -> None:
    """
    Sync all roles in provided `role_wrappers`.
    """
    logging.info("BEGIN: airflow roles sync")
{{- if semverCompare ">= 3.0.0" (include "airflow.version" .) }}
    # Airflow 3.0+ requires Flask application context for FAB provider operations
    with flask_app.app_context():
        for role_wrapper in role_wrappers.values():
            sync_role(role_wrapper)
{{- else }}
    for role_wrapper in role_wrappers.values():
        sync_role(role_wrapper)
{{- end }}
    logging.info("END: airflow roles sync")

    # ensures than any SQLAlchemy sessions are closed (so we don't hold a connection to the database)
    flask_app.do_teardown_appcontext()


def sync_with_airflow() -> None:
    """
    Preform a sync of all objects with airflow (note, `sync_with_airflow()` is called in `main()` template).
    """
    sync_all_roles(role_wrappers=VAR__ROLE_WRAPPERS)


##############
## Run Main ##
##############
{{- if .Values.airflow.rolesUpdate }}
main(sync_forever=True)
{{- else }}
main(sync_forever=False)
{{- end }}

{{- end }}
