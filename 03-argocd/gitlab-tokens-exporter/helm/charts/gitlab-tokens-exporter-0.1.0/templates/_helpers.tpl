{{- define "gitlab-tokens-exporter.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "gitlab-tokens-exporter.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{- define "gitlab-tokens-exporter.namespace" -}}
{{- .Values.namespace | default .Release.Namespace }}
{{- end }}

{{- define "gitlab-tokens-exporter.labels" -}}
helm.sh/chart: {{ include "gitlab-tokens-exporter.name" . }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/name: {{ include "gitlab-tokens-exporter.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app: gitlab-tokens-exporter
{{- end }}

{{- define "gitlab-tokens-exporter.selectorLabels" -}}
app.kubernetes.io/name: {{ include "gitlab-tokens-exporter.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app: gitlab-tokens-exporter
{{- end }}

{{- define "gitlab-tokens-exporter.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "gitlab-tokens-exporter.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
