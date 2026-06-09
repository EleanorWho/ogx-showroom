{{- define "jaeger.name" -}}
jaeger
{{- end }}

{{- define "jaeger.labels" -}}
app: {{ include "jaeger.name" . }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "jaeger.selectorLabels" -}}
app: {{ include "jaeger.name" . }}
{{- end }}
