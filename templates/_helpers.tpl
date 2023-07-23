{{/*
Return the proper Keycloak image name
*/}}
{{- define "keycloak.image" -}}
  {{- printf "%s/%s:%s" .Values.image.registry .Values.image.repository .Values.image.tag  -}}
{{- end -}}