{{- define "gomi-no-hi.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "gomi-no-hi.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{- define "gomi-no-hi.frontend.fullname" -}}
{{- printf "%s-frontend" (include "gomi-no-hi.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "gomi-no-hi.backend.fullname" -}}
{{- printf "%s-backend" (include "gomi-no-hi.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "gomi-no-hi.redis.fullname" -}}
{{- printf "%s-redis" (include "gomi-no-hi.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "gomi-no-hi.registry.fullname" -}}
{{- printf "%s-registry" (include "gomi-no-hi.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "gomi-no-hi.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/name: {{ include "gomi-no-hi.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
{{- end }}

{{- define "gomi-no-hi.frontend.selectorLabels" -}}
app.kubernetes.io/name: {{ include "gomi-no-hi.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: frontend
{{- end }}

{{- define "gomi-no-hi.backend.selectorLabels" -}}
app.kubernetes.io/name: {{ include "gomi-no-hi.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: backend
{{- end }}

{{- define "gomi-no-hi.redis.selectorLabels" -}}
app.kubernetes.io/name: {{ include "gomi-no-hi.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: redis
{{- end }}

{{- define "gomi-no-hi.imagePullSecrets" -}}
{{- if .Values.registry.existingSecret }}
imagePullSecrets:
  - name: {{ .Values.registry.existingSecret }}
{{- end }}
{{- end }}

{{- define "gomi-no-hi.frontendImage" -}}
{{- printf "%s:%s" (required "frontend.image.repository is required" .Values.frontend.image.repository) .Values.frontend.image.tag -}}
{{- end }}

{{- define "gomi-no-hi.backendImage" -}}
{{- printf "%s:%s" (required "backend.image.repository is required" .Values.backend.image.repository) .Values.backend.image.tag -}}
{{- end }}
