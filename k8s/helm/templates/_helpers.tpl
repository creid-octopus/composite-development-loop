{{/*
Common labels
*/}}
{{- define "app.labels" -}}
app: {{ .Values.appName }}
{{- end }}

{{/*
K8s standard labels for version tracking — used by DataDog auto-discovery
*/}}
{{- define "app.versionLabels" -}}
app.kubernetes.io/version: {{ .Values.appVersion | default "latest" | quote }}
app.kubernetes.io/commit: {{ .Values.commitSha | default "unknown" | quote }}
app.kubernetes.io/environment: {{ .Values.appEnv | quote }}
{{- end }}

{{/*
Datadog Pod Auto-Discovery annotation — configures the DD agent's health checks
*/}}
{{- define "app.datadogAnnotations" -}}
{{- if .Values.datadog.enabled }}
ad.datadoghq.com/{{ .Values.appName }}: |
  checks:
    http_check:
      - init_config:
        instances:
          - name: pod health
            url: "http://%%host%%:{{ .Values.containerPort }}/health"
            timeout: 1
{{- if .Values.datadog.autoInstrumentation.enabled }}
ad.itcontainers.io/container.0.image: ddapm-trace:latest
ad.itcontainers.io/container.0.env/DD_TRACE_ENABLED: "true"
ad.itcontainers.io/container.0.env/DD_SERVICE: {{ .Values.appName | quote }}
{{- end }}
{{- end }}
{{- end }}
