{{/*
Get DigiUsher url from remote write target with "digiusher" name.
*/}}
{{- define "kube-cost-metrics-collector.digiusherUrl" -}}
{{- range $value := .Values.prometheus.server.remote_write }}
{{- if eq $value.name "digiusher" }}
{{- printf "%s" $value.url | trimSuffix "storage/api/v2/write" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Define the prometheus.namespace template if set with forceNamespace or .Release.Namespace is set
*/}}
{{- define "digiusher-k8s-collector.prometheus.namespace" -}}
{{- if .Values.prometheus.forceNamespace -}}
{{ printf "namespace: %s" .Values.prometheus.forceNamespace }}
{{- else -}}
{{ printf "namespace: %s" .Release.Namespace }}
{{- end -}}
{{- end -}}

{{/*
Expand the name of the chart.
*/}}
{{- define "digiusher-k8s-collector.prometheus.name" -}}
{{- default .Chart.Name .Values.prometheus.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "digiusher-k8s-collector.prometheus.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create unified labels for prometheus components
*/}}
{{- define "digiusher-k8s-collector.prometheus.common.matchLabels" -}}
app: {{ template "digiusher-k8s-collector.prometheus.name" . }}
release: {{ .Release.Name }}
{{- end -}}

{{- define "digiusher-k8s-collector.prometheus.common.metaLabels" -}}
chart: {{ template "digiusher-k8s-collector.prometheus.chart" . }}
heritage: {{ .Release.Service }}
{{- end -}}

{{- define "digiusher-k8s-collector.prometheus.server.labels" -}}
{{ include "digiusher-k8s-collector.prometheus.server.matchLabels" . }}
{{ include "digiusher-k8s-collector.prometheus.common.metaLabels" . }}
{{- end -}}

{{- define "digiusher-k8s-collector.prometheus.server.matchLabels" -}}
component: {{ .Values.prometheus.server.name | quote }}
{{ include "digiusher-k8s-collector.prometheus.common.matchLabels" . }}
{{- end -}}
