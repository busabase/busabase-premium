{{- define "busabase.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "busabase.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "busabase.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "busabase.labels" -}}
app.kubernetes.io/name: {{ include "busabase.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- end -}}

{{- define "busabase.selectorLabels" -}}
app.kubernetes.io/name: {{ include "busabase.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "busabase.secretName" -}}
{{- if .Values.secrets.existingSecret -}}
{{- .Values.secrets.existingSecret -}}
{{- else -}}
{{- printf "%s-secrets" (include "busabase.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
The host the BROWSER uses for object storage.

Defaults to appUrl's host because that is almost always right and getting it
wrong breaks attachments in a way that looks like an application bug. Never a
cluster-internal Service name: the browser cannot resolve one.
*/}}
{{- define "busabase.storageHost" -}}
{{- if .Values.storage.publicHost -}}
{{- .Values.storage.publicHost -}}
{{- else -}}
{{/*
  Strip scheme, then any port/path. Written as two explicit steps with an
  intermediate: piping into regexReplaceAll passes the previous result as the
  LAST argument, so `a | regexReplaceAll x y` reads as replacing `a` inside `y`
  and silently produced an empty host — the app then pointed at `@:8333` and
  every attachment would have failed. Caught by rendering the chart.
*/}}
{{- $noScheme := regexReplaceAll "^https?://" .Values.appUrl "" -}}
{{- regexReplaceAll "[:/].*$" $noScheme "" -}}
{{- end -}}
{{- end -}}

{{/*
Endpoint the APP POD uses for its own S3 calls (bucket create, CORS, the
actual upload/download/list/delete traffic) — separate from `storageHost`,
which is embedded into presigned URLs the BROWSER uses.

Only meaningful for `storage.mode: bundled`: the in-cluster Service DNS name
is reachable from the pod but never from a browser, which is exactly why
`storageHost` can't just reuse it. For `storage.mode: external` the customer's
S3 endpoint is assumed reachable from both sides (the normal case for a real
cloud S3/R2 bucket), so no override is emitted and the app falls back to
`storageHost` for everything.

Without this, `storage.publicHost` (an ingress hostname, or a workstation's
`localhost` during `kubectl port-forward` testing) is the ONLY host the app
pod knows about, and the pod cannot route back into the cluster through it —
every attachment upload fails with a generic 500 from `ensureBucketExists()`
trying to reach a host that only means something to a browser. Found by
actually installing this chart and uploading a file, not by `helm template`.
*/}}
{{- define "busabase.storageInternalEndpoint" -}}
{{- if eq .Values.storage.mode "bundled" -}}
{{- printf "http://%s-storage:%v" (include "busabase.fullname" .) .Values.storage.publicPort -}}
{{- end -}}
{{- end -}}

{{- define "busabase.postgresHost" -}}
{{- if eq .Values.postgres.mode "external" -}}
{{- .Values.postgres.external.host -}}
{{- else -}}
{{- printf "%s-postgres" (include "busabase.fullname" .) -}}
{{- end -}}
{{- end -}}
