{{/* Common name */}}
{{- define "eks-demo-app.name" -}}
{{- .Chart.Name -}}
{{- end -}}

{{/* Fully qualified app name */}}
{{- define "eks-demo-app.fullname" -}}
{{- .Chart.Name -}}
{{- end -}}

{{/* Common labels */}}
{{- define "eks-demo-app.labels" -}}
app.kubernetes.io/name: {{ include "eks-demo-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/* Selector labels */}}
{{- define "eks-demo-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "eks-demo-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/* Service account name */}}
{{- define "eks-demo-app.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{ default (include "eks-demo-app.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
{{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}
