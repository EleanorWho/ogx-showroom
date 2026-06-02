{{- define "grafana.name" -}}
grafana
{{- end }}

{{- define "grafana.labels" -}}
app: {{ include "grafana.name" . }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "grafana.selectorLabels" -}}
app: {{ include "grafana.name" . }}
{{- end }}

{{- define "grafana.secretName" -}}
grafana-secret
{{- end }}
