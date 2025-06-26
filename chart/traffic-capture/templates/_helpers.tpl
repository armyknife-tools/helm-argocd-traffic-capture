{{/*
Expand the name of the chart.
*/}}
{{- define "traffic-capture.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "traffic-capture.fullname" -}}
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
{{- define "traffic-capture.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "traffic-capture.labels" -}}
helm.sh/chart: {{ include "traffic-capture.chart" . }}
{{ include "traffic-capture.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: istio-traffic-capture
{{- if .Values.global }}
{{- if .Values.global.environment }}
environment: {{ .Values.global.environment }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "traffic-capture.selectorLabels" -}}
app.kubernetes.io/name: {{ include "traffic-capture.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "traffic-capture.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "traffic-capture.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Proxy labels
*/}}
{{- define "traffic-capture.proxyLabels" -}}
{{ include "traffic-capture.labels" . }}
app: passthrough-proxy
{{- end }}

{{/*
Collector labels
*/}}
{{- define "traffic-capture.collectorLabels" -}}
{{ include "traffic-capture.labels" . }}
app: traffic-collector
{{- end }}

{{/*
Example app labels
*/}}
{{- define "traffic-capture.exampleAppLabels" -}}
{{ include "traffic-capture.labels" . }}
app: example-app
{{- end }}

{{/*
Test client labels
*/}}
{{- define "traffic-capture.testClientLabels" -}}
{{ include "traffic-capture.labels" . }}
app: test-client
{{- end }}