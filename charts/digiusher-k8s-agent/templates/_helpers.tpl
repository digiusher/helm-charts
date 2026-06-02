{{/*
Expand the name of the chart.
*/}}
{{- define "digiusher-k8s-agent.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "digiusher-k8s-agent.fullname" -}}
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

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "digiusher-k8s-agent.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "digiusher-k8s-agent.labels" -}}
owner: digiusher-k8s
helm.sh/chart: {{ include "digiusher-k8s-agent.chart" . }}
{{ include "digiusher-k8s-agent.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "digiusher-k8s-agent.selectorLabels" -}}
app.kubernetes.io/name: {{ include "digiusher-k8s-agent.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Per-component fullnames. Each chart-owned resource (Deployment, Service,
ConfigMap, PVC, Secret) is named with these so it's release-prefixed and
two installs in one namespace don't collide.
*/}}
{{- define "digiusher-k8s-agent.api.fullname" -}}
{{- printf "%s-api" (include "digiusher-k8s-agent.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "digiusher-k8s-agent.redis.fullname" -}}
{{- printf "%s-redis" (include "digiusher-k8s-agent.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "digiusher-k8s-agent.uploader.fullname" -}}
{{- printf "%s-uploader" (include "digiusher-k8s-agent.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "digiusher-k8s-agent.apiToken.secretName" -}}
{{- printf "%s-api-token" (include "digiusher-k8s-agent.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
KSM service name. Mirrors the kube-state-metrics subchart's own fullname
output for any release name not containing "kube-state-metrics" and where
KSM has no fullnameOverride — both reasonable assumptions for this chart.
*/}}
{{- define "digiusher-k8s-agent.ksm.fullname" -}}
{{- printf "%s-kube-state-metrics" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Per-component selector labels. Each Deployment selects only its own pods.
*/}}
{{- define "digiusher-k8s-agent.api.selectorLabels" -}}
{{ include "digiusher-k8s-agent.selectorLabels" . }}
app.kubernetes.io/component: api
{{- end }}

{{- define "digiusher-k8s-agent.redis.selectorLabels" -}}
{{ include "digiusher-k8s-agent.selectorLabels" . }}
app.kubernetes.io/component: redis
{{- end }}

{{- define "digiusher-k8s-agent.uploader.selectorLabels" -}}
{{ include "digiusher-k8s-agent.selectorLabels" . }}
app.kubernetes.io/component: uploader
{{- end }}

{{/*
Resolve image reference based on global.useDevImages.
Caller passes: (dict "image" .Values.<svc>.image "global" .Values.global)
*/}}
{{- define "digiusher-k8s-agent.image" -}}
{{- if .global.useDevImages -}}
{{- if not .image.devTag -}}
{{- fail "global.useDevImages=true but image.devTag is empty. Set it to a SHA, e.g. --set <svc>.image.devTag=<sha>. The *-dev packages have no `latest` tag." -}}
{{- end -}}
{{ .image.devRepository }}:{{ .image.devTag }}
{{- else -}}
{{ .image.repository }}:{{ .image.tag }}
{{- end -}}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "digiusher-k8s-agent.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "digiusher-k8s-agent.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
