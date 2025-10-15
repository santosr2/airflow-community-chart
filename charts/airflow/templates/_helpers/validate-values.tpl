{{/* Checks for `.Release.name` */}}
{{/* NOTE: `allowLongReleaseName` was added when the max length dropped from 43 to 40, and is NOT intended for new deployments */}}
{{- if .Values.allowLongReleaseName }}
  {{- if gt (len .Release.Name) 43 }}
  {{ required "The `.Release.name` must be <= 43 characters (due to the 63 character limit for names in Kubernetes)!" nil }}
  {{- end }}
{{- else }}
  {{- if gt (len .Release.Name) 40 }}
  {{ required "The `.Release.name` must be <= 40 characters (due to the 63 character limit for names in Kubernetes)!" nil }}
  {{- end }}
{{- end }}

{{/* Checks for `airflow.legacyCommands` */}}
{{- if .Values.airflow.legacyCommands }}
  {{- if not (eq "1" (.Values.scheduler.replicas | toString)) }}
  {{ required "If `airflow.legacyCommands=true`, then `scheduler.replicas` must be set to `1`!" nil }}
  {{- end }}
{{- end }}

{{/* Checks for `airflow.image` */}}
{{- if eq .Values.airflow.image.repository "apache/airflow" }}
  {{- if hasPrefix "1." .Values.airflow.image.tag }}
    {{- if not .Values.airflow.legacyCommands }}
    {{ required "When using airflow 1.10.X, `airflow.legacyCommands` must be `true`!" nil }}
    {{- end }}
  {{ end }}
  {{- if hasPrefix "2." .Values.airflow.image.tag }}
    {{- if .Values.airflow.legacyCommands }}
    {{ required "When using airflow 2.X.X, `airflow.legacyCommands` must be `false`!" nil }}
    {{- end }}
  {{ end }}
  {{- if hasPrefix "3." .Values.airflow.image.tag }}
    {{- if .Values.airflow.legacyCommands }}
    {{ required "When using airflow 3.X.X, `airflow.legacyCommands` must be `false`!" nil }}
    {{- end }}
  {{ end }}
{{- end }}

{{/* Checks for `airflow.executor` */}}
{{- if semverCompare "< 3.0.0" (include "airflow.version" .) -}}
  {{- if .Values.airflow.executors -}}
    {{ fail "The `airflow.executors` list is only supported in Airflow 3.0+. Use `airflow.executor` instead!" }}
  {{- end -}}
  {{- if not (has .Values.airflow.executor (list "CeleryExecutor" "CeleryKubernetesExecutor" "KubernetesExecutor")) }}
    {{ required "The `airflow.executor` must be one of: [CeleryExecutor, CeleryKubernetesExecutor, KubernetesExecutor]!" nil }}
  {{- end }}
  {{- if eq .Values.airflow.executor "CeleryExecutor" }}
    {{- if not .Values.workers.enabled }}
    {{ required "If `airflow.executor=CeleryExecutor`, then `workers.enabled` should be `true`!" nil }}
    {{- end }}
  {{- end }}
  {{- if eq .Values.airflow.executor "CeleryKubernetesExecutor" }}
    {{- if not .Values.workers.enabled }}
    {{ required "If `airflow.executor=CeleryKubernetesExecutor`, then `workers.enabled` should be `true`!" nil }}
    {{- end }}
  {{- end }}
  {{- if eq .Values.airflow.executor "KubernetesExecutor" }}
    {{- if or (.Values.workers.enabled) (.Values.flower.enabled) (.Values.redis.enabled) }}
    {{ required "If `airflow.executor=KubernetesExecutor`, then all of [`workers.enabled`, `flower.enabled`, `redis.enabled`] should be `false`!" nil }}
    {{- end }}
  {{- end }}
{{- end }}

{{- if semverCompare ">= 3.0.0" (include "airflow.version" .) -}}
  {{- if and .Values.airflow.executor (ne .Values.airflow.executor "CeleryExecutor") -}}
    {{ required "The `airflow.executor` setting is deprecated in Airflow 3.0+. Use `airflow.executors` instead!" nil }}
  {{- end -}}
  {{- if not .Values.airflow.executors -}}
    {{ required "In Airflow 3.0+, you must set at least one executor in the `airflow.executors` list!" nil }}
  {{- end -}}
  {{- if has "CeleryKubernetesExecutor" .Values.airflow.executors -}}
    {{ fail "The `CeleryKubernetesExecutor` is no longer supported. Use multiple executors instead!" }}
  {{- end -}}
  {{- range $executor := .Values.airflow.executors -}}
    {{- if not (has $executor (list "CeleryExecutor" "KubernetesExecutor")) }}
      {{ required (printf "The `airflow.executors` list can only contain: [CeleryExecutor, KubernetesExecutor]! Found: %s" $executor) nil }}
    {{- end -}}
    {{- if eq $executor "CeleryExecutor" -}}
      {{- if not $.Values.workers.enabled }}
      {{ required (printf "If `airflow.executors` contains `%s`, then `workers.enabled` should be `true`!" $executor) nil }}
      {{- end }}
    {{- end }}
    {{- if eq $executor "KubernetesExecutor" }}
      {{- if or ($.Values.workers.enabled) ($.Values.flower.enabled) ($.Values.redis.enabled) }}
      {{ required "If `airflow.executors` contains `KubernetesExecutor`, then all of [`workers.enabled`, `flower.enabled`, `redis.enabled`] should be `false`!" nil }}
      {{- end }}
    {{- end -}}
  {{- end -}}
{{- end }}

{{/* Checks for `airflow.config` */}}
{{- if .Values.airflow.config.AIRFLOW__CORE__EXECUTOR }}
  {{ required "Don't define `airflow.config.AIRFLOW__CORE__EXECUTOR`, it will be automatically set from `airflow.executor` or `airflow.executors`!" nil }}
{{- end }}
{{- if or .Values.airflow.config.AIRFLOW__CORE__DAGS_FOLDER }}
  {{ required "Don't define `airflow.config.AIRFLOW__CORE__DAGS_FOLDER`, it will be automatically set from `dags.path`!" nil }}
{{- end }}
{{- if or (.Values.airflow.config.AIRFLOW__CELERY__BROKER_URL) (.Values.airflow.config.AIRFLOW__CELERY__BROKER_URL_CMD) }}
  {{ required "Don't define `airflow.config.AIRFLOW__CELERY__BROKER_URL`, it will be automatically set by the chart!" nil }}
{{- end }}
{{- if or (.Values.airflow.config.AIRFLOW__CELERY__RESULT_BACKEND) (.Values.airflow.config.AIRFLOW__CELERY__RESULT_BACKEND_CMD) }}
  {{ required "Don't define `airflow.config.AIRFLOW__CELERY__RESULT_BACKEND`, it will be automatically set by the chart!" nil }}
{{- end }}
{{- if or (.Values.airflow.config.AIRFLOW__CORE__SQL_ALCHEMY_CONN) (.Values.airflow.config.AIRFLOW__CORE__SQL_ALCHEMY_CONN_CMD) }}
  {{ required "Don't define `airflow.config.AIRFLOW__CORE__SQL_ALCHEMY_CONN`, it will be automatically set by the chart!" nil }}
{{- end }}
{{- if or (.Values.airflow.config.AIRFLOW__DATABASE__SQL_ALCHEMY_CONN) (.Values.airflow.config.AIRFLOW__DATABASE__SQL_ALCHEMY_CONN_CMD) }}
  {{ required "Don't define `airflow.config.AIRFLOW__DATABASE__SQL_ALCHEMY_CONN`, it will be automatically set by the chart!" nil }}
{{- end }}

{{/* Checks for `scheduler.logCleanup` */}}
{{- if .Values.scheduler.logCleanup.enabled }}
  {{- if .Values.logs.persistence.enabled }}
  {{ required "If `logs.persistence.enabled=true`, then `scheduler.logCleanup.enabled` must be `false`!" nil }}
  {{- end }}
  {{- if include "airflow.extraVolumeMounts.has_log_path" . }}
  {{ required "If `logs.path` is under any `airflow.extraVolumeMounts`, then `scheduler.logCleanup.enabled` must be `false`!" nil }}
  {{- end }}
  {{- if include "airflow.scheduler.extraVolumeMounts.has_log_path" . }}
  {{ required "If `logs.path` is under any `scheduler.extraVolumeMounts`, then `scheduler.logCleanup.enabled` must be `false`!" nil }}
  {{- end }}
{{- end }}

{{/* Checks for `workers.logCleanup` */}}
{{- if .Values.workers.enabled }}
  {{- if .Values.workers.logCleanup.enabled }}
    {{- if .Values.logs.persistence.enabled }}
    {{ required "If `logs.persistence.enabled=true`, then `workers.logCleanup.enabled` must be `false`!" nil }}
    {{- end }}
    {{- if include "airflow.extraVolumeMounts.has_log_path" . }}
    {{ required "If `logs.path` is under any `airflow.extraVolumeMounts`, then `workers.logCleanup.enabled` must be `false`!" nil }}
    {{- end }}
    {{- if include "airflow.workers.extraVolumeMounts.has_log_path" . }}
    {{ required "If `logs.path` is under any `workers.extraVolumeMounts`, then `workers.logCleanup.enabled` must be `false`!" nil }}
    {{- end }}
  {{- end }}
{{- end }}

{{/* Checks for `logs.persistence` */}}
{{- if .Values.logs.persistence.enabled }}
  {{- if not (eq .Values.logs.persistence.accessMode "ReadWriteMany") }}
  {{ required "The `logs.persistence.accessMode` must be `ReadWriteMany`!" nil }}
  {{- end }}
  {{- if include "airflow.extraVolumeMounts.has_log_path" . }}
  {{ required "If `logs.path` is under any `airflow.extraVolumeMounts`, then `logs.persistence.enabled` must be `false`!" nil }}
  {{- end }}
{{- end }}

{{/* Checks for `dags.persistence` */}}
{{- if .Values.dags.persistence.enabled }}
  {{- if not (has .Values.dags.persistence.accessMode (list "ReadOnlyMany" "ReadWriteMany")) }}
  {{ required "The `dags.persistence.accessMode` must be one of: [ReadOnlyMany, ReadWriteMany]!" nil }}
  {{- end }}
{{- end }}

{{/* Checks for `dags.gitSync` */}}
{{- if .Values.dags.gitSync.enabled }}
  {{- if .Values.dags.persistence.enabled }}
  {{ required "If `dags.gitSync.enabled=true`, then `persistence.enabled` must be disabled!" nil }}
  {{- end }}
  {{- if not .Values.dags.gitSync.repo }}
  {{ required "If `dags.gitSync.enabled=true`, then `dags.gitSync.repo` must be non-empty!" nil }}
  {{- end }}
  {{- if and (.Values.dags.gitSync.sshSecret) (.Values.dags.gitSync.httpSecret) }}
  {{ required "At most, one of `dags.gitSync.sshSecret` and `dags.gitSync.httpSecret` can be defined!" nil }}
  {{- end }}
  {{- if and (.Values.dags.gitSync.repo | lower | hasPrefix "git@github.com") (not .Values.dags.gitSync.sshSecret) }}
  {{ required "You must define `dags.gitSync.sshSecret` when using GitHub with SSH for `dags.gitSync.repo`!" nil }}
  {{- end }}
{{- end }}

{{/* Checks for `ingress` */}}
{{- if .Values.ingress.enabled }}
  {{/* Checks for `ingress.apiVersion` */}}
  {{- if not (has .Values.ingress.apiVersion (list "networking.k8s.io/v1" "networking.k8s.io/v1beta1")) }}
  {{ required "The `ingress.apiVersion` must be one of: [networking.k8s.io/v1, networking.k8s.io/v1beta1]!" nil }}
  {{- end }}

  {{/* Checks for `ingress.web.path` */}}
  {{- if .Values.ingress.web.path }}
    {{- if not (.Values.ingress.web.path | hasPrefix "/") }}
    {{ required "The `ingress.web.path` should start with a '/'!" nil }}
    {{- end }}
    {{- if .Values.ingress.web.path | hasSuffix "/" }}
    {{ required "The `ingress.web.path` should NOT include a trailing '/'!" nil }}
    {{- end }}
    {{- if or .Values.airflow.config.AIRFLOW__API__BASE_URL .Values.airflow.config.AIRFLOW__WEBSERVER__BASE_URL }}
      {{- if semverCompare ">=3.0.0" (include "airflow.version" .) }}
        {{- $webUrl := .Values.airflow.config.AIRFLOW__API__BASE_URL | urlParse }}
        {{- if not (eq (.Values.ingress.web.path | trimSuffix "/*") (get $webUrl "path")) }}
        {{ required (printf "The `ingress.web.path` must be compatible with `airflow.config.AIRFLOW__API__BASE_URL`! (try setting AIRFLOW__API__BASE_URL to 'http://{HOSTNAME}%s', rather than '%s')" (.Values.ingress.web.path | trimSuffix "/*") .Values.airflow.config.AIRFLOW__API__BASE_URL) nil }}
        {{- end }}
      {{- else }}
        {{- $webUrl := .Values.airflow.config.AIRFLOW__WEBSERVER__BASE_URL | urlParse }}
        {{- if not (eq (.Values.ingress.web.path | trimSuffix "/*") (get $webUrl "path")) }}
        {{ required (printf "The `ingress.web.path` must be compatible with `airflow.config.AIRFLOW__WEBSERVER__BASE_URL`! (try setting AIRFLOW__WEBSERVER__BASE_URL to 'http://{HOSTNAME}%s', rather than '%s')" (.Values.ingress.web.path | trimSuffix "/*") .Values.airflow.config.AIRFLOW__WEBSERVER__BASE_URL) nil }}
        {{- end }}
      {{- end }}
    {{- else }}
      {{- if semverCompare ">=3.0.0" (include "airflow.version" .) }}
      {{ required (printf "If `ingress.web.path` is set, then `airflow.config.AIRFLOW__API__BASE_URL` must be set! (try setting AIRFLOW__API__BASE_URL to 'http://{HOSTNAME}%s')" (.Values.ingress.web.path | trimSuffix "/*")) nil }}
      {{- else }}
      {{ required (printf "If `ingress.web.path` is set, then `airflow.config.AIRFLOW__WEBSERVER__BASE_URL` must be set! (try setting AIRFLOW__WEBSERVER__BASE_URL to 'http://{HOSTNAME}%s')" (.Values.ingress.web.path | trimSuffix "/*")) nil }}
      {{- end }}
    {{- end }}
  {{- end }}

  {{/* Checks for `ingress.flower.path` */}}
  {{- if .Values.ingress.flower.path }}
    {{- if not (.Values.ingress.flower.path | hasPrefix "/") }}
    {{ required "The `ingress.flower.path` should start with a '/'!" nil }}
    {{- end }}
    {{- if .Values.ingress.flower.path | hasSuffix "/" }}
    {{ required "The `ingress.flower.path` should NOT include a trailing '/'!" nil }}
    {{- end }}
    {{- if .Values.airflow.config.AIRFLOW__CELERY__FLOWER_URL_PREFIX }}
      {{- if not (eq (.Values.ingress.flower.path | trimSuffix "/*") .Values.airflow.config.AIRFLOW__CELERY__FLOWER_URL_PREFIX) }}
      {{ required (printf "The `ingress.flower.path` must be compatible with `airflow.config.AIRFLOW__CELERY__FLOWER_URL_PREFIX`! (try setting AIRFLOW__CELERY__FLOWER_URL_PREFIX to '%s', rather than '%s')" (.Values.ingress.flower.path | trimSuffix "/*") .Values.airflow.config.AIRFLOW__CELERY__FLOWER_URL_PREFIX) nil }}
      {{- end }}
    {{- else }}
      {{ required (printf "If `ingress.flower.path` is set, then `airflow.config.AIRFLOW__CELERY__FLOWER_URL_PREFIX` must be set! (try setting AIRFLOW__CELERY__FLOWER_URL_PREFIX to '%s')" (.Values.ingress.flower.path | trimSuffix "/*")) nil }}
    {{- end }}
  {{- end }}
{{- end }}

{{/* Checks for `pgbouncer` */}}
{{- if include "airflow.pgbouncer.should_use" . }}
    {{- if .Values.pgbouncer.clientSSL.keyFile.existingSecret }}
        {{- if not .Values.pgbouncer.clientSSL.certFile.existingSecret }}
        {{ required "If `pgbouncer.clientSSL.keyFile.existingSecret` is set, then `pgbouncer.clientSSL.certFile.existingSecret` must also be!" nil }}
        {{- end }}
    {{- end }}
    {{- if .Values.pgbouncer.clientSSL.certFile.existingSecret }}
        {{- if not .Values.pgbouncer.clientSSL.keyFile.existingSecret }}
        {{ required "If `pgbouncer.clientSSL.certFile.existingSecret` is set, then `pgbouncer.clientSSL.keyFile.existingSecret` must also be!" nil }}
        {{- end }}
    {{- end }}
    {{- if .Values.pgbouncer.serverSSL.keyFile.existingSecret }}
        {{- if not .Values.pgbouncer.serverSSL.certFile.existingSecret }}
        {{ required "If `pgbouncer.serverSSL.keyFile.existingSecret` is set, then `pgbouncer.serverSSL.certFile.existingSecret` must also be!" nil }}
        {{- end }}
    {{- end }}
    {{- if .Values.pgbouncer.serverSSL.certFile.existingSecret }}
        {{- if not .Values.pgbouncer.serverSSL.keyFile.existingSecret }}
        {{ required "If `pgbouncer.serverSSL.certFile.existingSecret` is set, then `pgbouncer.serverSSL.keyFile.existingSecret` must also be!" nil }}
        {{- end }}
    {{- end }}
{{- end }}

{{/* Checks for `externalDatabase` */}}
{{- if .Values.externalDatabase.host }}
  {{/* check if they are using externalDatabase (the default value for `externalDatabase.host` is "localhost") */}}
  {{- if not (eq .Values.externalDatabase.host "localhost") }}
    {{- if .Values.postgresql.enabled }}
    {{ required "If `externalDatabase.host` is set, then `postgresql.enabled` should be `false`!" nil }}
    {{- end }}
    {{- if not (has .Values.externalDatabase.type (list "mysql" "postgres")) }}
    {{ required "The `externalDatabase.type` must be one of: [mysql, postgres]!" nil }}
    {{- end }}
  {{- end }}
{{- end }}

{{/* Checks for `externalRedis` */}}
{{- if .Values.externalRedis.host }}
  {{/* check if they are using externalRedis (the default value for `externalRedis.host` is "localhost") */}}
  {{- if not (eq .Values.externalRedis.host "localhost") }}
    {{- if .Values.redis.enabled }}
    {{ required "If `externalRedis.host` is set, then `redis.enabled` should be `false`!" nil }}
    {{- end }}
  {{- end }}
{{- end }}

{{/* Checks for insecure default secrets */}}
{{- if eq .Values.airflow.fernetKey "7T512UXSSmBOkpWimFHIVb8jK6lfmSAvx4mO6Arehnc=" }}
# ###############################################################################
# WARNING: Using default fernet key is EXTREMELY INSECURE
# ###############################################################################
#   The current fernetKey is the chart's default value and is publicly known.
#   This allows ANYONE to decrypt your Airflow connections and variables.
#
#   IMMEDIATE ACTION REQUIRED:
#   1. Generate a new fernet key:
#      python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
#
#   2. Set the key in your values:
#      airflow:
#        fernetKey: "<your-generated-key>"
#
#   3. For production, use external secret manager (AWS Secrets Manager, Vault, etc.)
#
#   See: charts/airflow/docs/faq/security/set-fernet-key.md
# ###############################################################################
{{- end }}

{{- if and (semverCompare "<3.0.0" (include "airflow.version" .)) (eq .Values.airflow.webserverSecretKey "THIS IS UNSAFE!") }}
# ###############################################################################
# WARNING: Using default webserver secret key is EXTREMELY INSECURE
# ###############################################################################
#   The current webserverSecretKey is the chart's default value and is publicly known.
#   This enables session hijacking and unauthorized access.
#
#   IMMEDIATE ACTION REQUIRED:
#   1. Generate a new secret key:
#      python -c "import secrets; print(secrets.token_urlsafe(32))"
#
#   2. Set the key in your values:
#      airflow:
#        webserverSecretKey: "<your-generated-key>"
#
#   3. For production, use external secret manager (AWS Secrets Manager, Vault, etc.)
#
#   See: charts/airflow/docs/faq/security/set-webserver-secret-key.md
# ###############################################################################
{{- end }}

{{- if .Values.airflow.users }}
{{- range $user := .Values.airflow.users }}
{{- if and (eq $user.username "admin") (eq $user.password "admin") }}
# ###############################################################################
# WARNING: Using default admin credentials is EXTREMELY INSECURE
# ###############################################################################
#   The default admin/admin credentials are publicly known and must be changed.
#
#   IMMEDIATE ACTION REQUIRED:
#   1. Remove the default admin user or change the password:
#      airflow:
#        users:
#          - username: admin
#            password: "<strong-password>"  # Or remove entirely
#            role: Admin
#            email: admin@example.com
#            firstName: admin
#            lastName: admin
#
#   2. For production, disable default users and use external authentication:
#      - LDAP integration
#      - OAuth (Google, GitHub, etc.)
#      - SAML
#
#   See: charts/airflow/docs/faq/security/
# ###############################################################################
{{- end }}
{{- end }}
{{- end }}

{{/* JWT Secret warning for Airflow 3.0+ */}}
{{- if semverCompare ">=3.0.0" (include "airflow.version" .) }}
{{- if and (not .Values.airflow.jwtSecret) (not .Values.airflow.jwtSecretName) }}
# ###############################################################################
# WARNING: JWT secret will be AUTO-GENERATED
# ###############################################################################
#   Auto-generated JWT secrets change on every `helm upgrade`, causing:
#   - Service disruption during upgrades
#   - Component restarts (API Server, DAG Processor, Scheduler, Workers)
#   - Task failures due to JWT authentication errors
#   - Downtime (typically 2-5 minutes)
#
#   RECOMMENDED ACTION FOR PRODUCTION:
#   Set airflow.jwtSecretName to reference a persistent Kubernetes Secret:
#
#     airflow:
#       jwtSecretName: "airflow-jwt-secret"
#       jwtSecretKey: "jwt-secret"
#
#   See: charts/airflow/docs/faq/security/set-jwt-secret.md
# ###############################################################################
{{- end }}
{{- end }}

{{/* Checks for Airflow 3.0+ requirements */}}
{{- if semverCompare ">=3.0.0" (include "airflow.version" .) }}
  {{/* API Server must have at least 1 replica */}}
  {{- if lt (int .Values.apiServer.replicas) 1 }}
# ###############################################################################
# ERROR: Airflow 3.0+ requires at least 1 API Server replica
# ###############################################################################
#     In Airflow 3.0+, the API Server is a mandatory component that replaces
#     the traditional Webserver. All components communicate through the API Server.
#
#     Current apiServer.replicas: {{ .Values.apiServer.replicas }}
#     Recommended: apiServer.replicas >= 1
# ###############################################################################
  {{ required "apiServer.replicas must be >= 1 for Airflow 3.0+" nil }}
  {{- end }}

  {{/* DAG Processor must have at least 1 replica */}}
  {{- if or (not .Values.dagProcessor.enabled) (lt (int .Values.dagProcessor.replicas) 1) }}
# ###############################################################################
# ERROR: Airflow 3.0+ requires at least 1 DAG Processor replica
# ###############################################################################
#     In Airflow 3.0+, the DAG Processor is a separate mandatory component
#     that handles DAG parsing independently from the Scheduler.
#
#     Current dagProcessor.replicas: {{ .Values.dagProcessor.replicas }}
#     Recommended: dagProcessor.replicas >= 1
# ###############################################################################
  {{ required "dagProcessor.replicas must be >= 1 and enabled for Airflow 3.0+" nil }}
  {{- end }}

  {{/* Validate apiServer component is configured instead of web */}}
  {{- if and (gt (int .Values.web.replicas) 0) (ne (int .Values.web.replicas) 1) }}
# ###############################################################################
# ERROR: Airflow 3.0+ requires using `apiServer` instead of `web`
# ###############################################################################
#     Airflow 3.0+ replaces the Webserver component with the API Server.
#     You are currently configuring `web.replicas`, which is not used in Airflow 3.0+.
#
#     Current configuration:
#       web.replicas: {{ .Values.web.replicas }}
#       apiServer.replicas: {{ .Values.apiServer.replicas }}
#
#     REQUIRED CHANGES:
#     1. Remove or set `web.replicas: 0` in your values.yaml
#     2. Configure `apiServer.replicas: <desired-count>` instead
#     3. Move any `web.*` configuration (resources, nodeSelector, etc.) to `apiServer.*`
#
#     Migration Guide: charts/airflow/docs/guides/airflow-3-migration.md
# ###############################################################################
  {{ required "For Airflow 3.0+, use `apiServer` instead of `web`. Set `web.replicas: 0` and configure `apiServer.replicas` instead!" nil }}
  {{- end }}

  {{/* Validate apiSecretKey is used instead of webserverSecretKey */}}
  {{- if and .Values.airflow.webserverSecretKey (ne .Values.airflow.webserverSecretKey "THIS IS UNSAFE!") }}
# ###############################################################################
# ERROR: Airflow 3.0+ requires `apiSecretKey` instead of `webserverSecretKey`
# ###############################################################################
#     Airflow 3.0+ uses `AIRFLOW__API__SECRET_KEY` for Flask session signing,
#     not `AIRFLOW__WEBSERVER__SECRET_KEY`.
#
#     Current configuration:
#       airflow.webserverSecretKey: (configured)
#       airflow.apiSecretKey: {{ .Values.airflow.apiSecretKey | default "NOT SET" }}
#
#     REQUIRED CHANGES:
#     1. Copy your webserverSecretKey value to apiSecretKey:
#        airflow:
#          apiSecretKey: "<your-current-webserverSecretKey>"
#          webserverSecretKey: ""  # Clear this value
#
#     2. Or generate a new API secret key:
#        python -c "import secrets; print(secrets.token_urlsafe(32))"
#
#     See: charts/airflow/docs/faq/security/set-webserver-secret-key.md
# ###############################################################################
  {{ required "For Airflow 3.0+, use `airflow.apiSecretKey` instead of `airflow.webserverSecretKey`!" nil }}
  {{- end }}

  {{/* Validate ingress.apiServer is used instead of ingress.web */}}
  {{- if and .Values.ingress.enabled (or .Values.ingress.web.host .Values.ingress.web.path (ne (.Values.ingress.web.annotations | toString) "map[]")) }}
# ###############################################################################
# ERROR: Airflow 3.0+ requires `ingress.apiServer` instead of `ingress.web`
# ###############################################################################
#     Airflow 3.0+ uses the API Server component, not the Webserver.
#     You must configure ingress routing to the API Server.
#
#     Current configuration:
#       ingress.web.host: {{ .Values.ingress.web.host | default "NOT SET" }}
#       ingress.web.path: {{ .Values.ingress.web.path | default "NOT SET" }}
#
#     REQUIRED CHANGES:
#     1. Move your ingress.web configuration to ingress.apiServer:
#        ingress:
#          apiServer:
#            host: "<your-ingress.web.host>"
#            path: "<your-ingress.web.path>"
#            annotations: <your-ingress.web.annotations>
#            # ... other configs
#          web:
#            host: ""       # Clear web configuration
#            path: ""
#            annotations: {}
#
#     2. Update AIRFLOW__API__BASE_URL if using custom paths:
#        airflow:
#          config:
#            AIRFLOW__API__BASE_URL: "http://{HOSTNAME}<path>"
#
#     Migration Guide: charts/airflow/docs/guides/airflow-3-migration.md
# ###############################################################################
  {{ required "For Airflow 3.0+, use `ingress.apiServer` instead of `ingress.web`!" nil }}
  {{- end }}
{{- end }}

{{/* Checks for Airflow <3.0 deprecated configuration */}}
{{- if semverCompare "<3.0.0" (include "airflow.version" .) }}
  {{/* Validate web component is configured instead of apiServer */}}
  {{- if gt (int .Values.apiServer.replicas) 0 }}
# ###############################################################################
# ERROR: Airflow <3.0 requires using `web` instead of `apiServer`
# ###############################################################################
#     Airflow 2.x and earlier use the Webserver component.
#     The API Server is only available in Airflow 3.0+.
#
#     Current Airflow version: {{ include "airflow.version" . }}
#     Current configuration:
#       web.replicas: {{ .Values.web.replicas }}
#       apiServer.replicas: {{ .Values.apiServer.replicas }}
#
#     REQUIRED CHANGES:
#     1. Set `apiServer.replicas: 0` in your values.yaml
#     2. Configure `web.replicas: <desired-count>` instead
#     3. Move any `apiServer.*` configuration to `web.*`
#
#     OR upgrade to Airflow 3.0+ to use the API Server component.
# ###############################################################################
  {{ required "For Airflow <3.0, use `web` instead of `apiServer`. Set `apiServer.replicas: 0` and configure `web.replicas` instead!" nil }}
  {{- end }}

  {{/* Validate webserverSecretKey is used instead of apiSecretKey */}}
  {{- if .Values.airflow.apiSecretKey }}
# ###############################################################################
# ERROR: Airflow <3.0 requires `webserverSecretKey` instead of `apiSecretKey`
# ###############################################################################
#     Airflow 2.x and earlier use `AIRFLOW__WEBSERVER__SECRET_KEY` for Flask
#     session signing. The `apiSecretKey` is only used in Airflow 3.0+.
#
#     Current Airflow version: {{ include "airflow.version" . }}
#     Current configuration:
#       airflow.webserverSecretKey: {{ .Values.airflow.webserverSecretKey | default "NOT SET" }}
#       airflow.apiSecretKey: (configured)
#
#     REQUIRED CHANGES:
#     1. Copy your apiSecretKey value to webserverSecretKey:
#        airflow:
#          webserverSecretKey: "<your-current-apiSecretKey>"
#          apiSecretKey: ""  # Clear this value
#
#     2. Or generate a new webserver secret key:
#        python -c "import secrets; print(secrets.token_urlsafe(32))"
#
#     OR upgrade to Airflow 3.0+ to use apiSecretKey.
#
#     See: charts/airflow/docs/faq/security/set-webserver-secret-key.md
# ###############################################################################
  {{ required "For Airflow <3.0, use `airflow.webserverSecretKey` instead of `airflow.apiSecretKey`!" nil }}
  {{- end }}

  {{/* Validate ingress.web is used instead of ingress.apiServer */}}
  {{- if and .Values.ingress.enabled (or .Values.ingress.apiServer.host .Values.ingress.apiServer.path (ne (.Values.ingress.apiServer.annotations | toString) "map[]")) }}
# ###############################################################################
# ERROR: Airflow <3.0 requires `ingress.web` instead of `ingress.apiServer`
# ###############################################################################
#     Airflow 2.x and earlier use the Webserver component.
#     You must configure ingress routing to the Webserver, not the API Server.
#
#     Current Airflow version: {{ include "airflow.version" . }}
#     Current configuration:
#       ingress.apiServer.host: {{ .Values.ingress.apiServer.host | default "NOT SET" }}
#       ingress.apiServer.path: {{ .Values.ingress.apiServer.path | default "NOT SET" }}
#
#     REQUIRED CHANGES:
#     1. Move your ingress.apiServer configuration to ingress.web:
#        ingress:
#          web:
#            host: "<your-ingress.apiServer.host>"
#            path: "<your-ingress.apiServer.path>"
#            annotations: <your-ingress.apiServer.annotations>
#            # ... other configs
#          apiServer:
#            host: ""       # Clear apiServer configuration
#            path: ""
#            annotations: {}
#
#     2. Update AIRFLOW__WEBSERVER__BASE_URL if using custom paths:
#        airflow:
#          config:
#            AIRFLOW__WEBSERVER__BASE_URL: "http://{HOSTNAME}<path>"
#
#     OR upgrade to Airflow 3.0+ to use the API Server component.
# ###############################################################################
  {{ required "For Airflow <3.0, use `ingress.web` instead of `ingress.apiServer`!" nil }}
  {{- end }}
{{- end }}
