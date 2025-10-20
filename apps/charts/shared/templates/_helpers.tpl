{{/*
Return the desired service account name.
- If serviceAccount.create is true and a name is not provided, default to .Values.name.
- If serviceAccount.create is false, return the explicit name (or empty string if unset).
*/}}
{{- define "shared.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- if .Values.serviceAccount.name -}}
{{- .Values.serviceAccount.name -}}
{{- else -}}
{{- .Values.name -}}
{{- end -}}
{{- else -}}
{{- default "" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}
