{{- define "otel-collector.name" -}}
otel-collector
{{- end }}

{{- define "otel-collector.labels" -}}
app: {{ include "otel-collector.name" . }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "otel-collector.selectorLabels" -}}
app: {{ include "otel-collector.name" . }}
{{- end }}
