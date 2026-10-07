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
{{- define "digiusher-k8s-agent.agent.fullname" -}}
{{- printf "%s-agent" (include "digiusher-k8s-agent.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "digiusher-k8s-agent.vmagent.fullname" -}}
{{- printf "%s-vmagent" (include "digiusher-k8s-agent.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "digiusher-k8s-agent.apiToken.secretName" -}}
{{- printf "%s-api-token" (include "digiusher-k8s-agent.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Per-component selector labels. Each Deployment selects only its own pods.
*/}}
{{- define "digiusher-k8s-agent.agent.selectorLabels" -}}
{{ include "digiusher-k8s-agent.selectorLabels" . }}
app.kubernetes.io/component: agent
{{- end }}

{{- define "digiusher-k8s-agent.vmagent.selectorLabels" -}}
{{ include "digiusher-k8s-agent.selectorLabels" . }}
app.kubernetes.io/component: vmagent
{{- end }}

{{/*
Resolve image reference based on global.useDevImages.
Caller passes: (dict "image" .Values.<svc>.image "global" .Values.global "appVersion" .Chart.AppVersion)
When image.tag is empty it falls back to the chart's appVersion (the
released image version), so the shipped image is single-sourced in Chart.yaml.
*/}}
{{- define "digiusher-k8s-agent.image" -}}
{{- if .global.useDevImages -}}
{{- if not .image.devTag -}}
{{- fail "global.useDevImages=true but image.devTag is empty. Set it to a SHA, e.g. --set <svc>.image.devTag=<sha>. The *-dev packages have no `latest` tag." -}}
{{- end -}}
{{ .image.devRepository }}:{{ .image.devTag }}
{{- else -}}
{{ .image.repository }}:{{ .image.tag | default .appVersion }}
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

{{/*
Resource requests for each sizing tier. The values.yaml sizing note documents
the tiers.
*/}}
{{- define "digiusher-k8s-agent.sizingRequests" -}}
{{- $tiers := dict
  "small" (dict
    "agent" (dict "cpu" "25m" "memory" "128Mi")
    "vmagent" (dict "cpu" "25m" "memory" "96Mi"))
  "medium" (dict
    "agent" (dict "cpu" "100m" "memory" "256Mi")
    "vmagent" (dict "cpu" "150m" "memory" "160Mi"))
  "large" (dict
    "agent" (dict "cpu" "250m" "memory" "1Gi")
    "vmagent" (dict "cpu" "250m" "memory" "320Mi"))
-}}
{{- $sizing := toString (.root.Values.sizing | default "small") -}}
{{- $tier := get $tiers $sizing -}}
{{- if not $tier -}}
{{- fail (printf "sizing must be small, medium or large, not %q" $sizing) -}}
{{- end -}}
{{- toYaml (get $tier .component) -}}
{{- end }}

{{/*
Container resources: the tier's requests, with any request or limit set in
values on top. Call with (dict "root" $ "component" "agent" "resources" .Values.agent.resources).
*/}}
{{- define "digiusher-k8s-agent.resources" -}}
{{- $resources := deepCopy (default (dict) .resources) -}}
{{- $requests := deepCopy (default (dict) $resources.requests) -}}
{{- $_ := set $resources "requests" (merge $requests (include "digiusher-k8s-agent.sizingRequests" . | fromYaml)) -}}
{{- toYaml $resources -}}
{{- end }}
