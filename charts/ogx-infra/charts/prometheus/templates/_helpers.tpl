{{- define "prometheus.name" -}}
prometheus
{{- end }}

{{- define "prometheus.labels" -}}
app: {{ include "prometheus.name" . }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "prometheus.selectorLabels" -}}
app: {{ include "prometheus.name" . }}
{{- end }}
