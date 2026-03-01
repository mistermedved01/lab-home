{{/*
Returns the Registry rate limiter configuration
*/}}
{{- define "registry.rateLimiter.config" -}}
rate_limiter:
  enabled: {{ .Values.rateLimiter.enabled }}
  
  {{- if hasKey .Values.rateLimiter "limiters" }}
  limiters:
    {{- range $limiter := .Values.rateLimiter.limiters }}
    - name: {{ $limiter.name | quote }}
      {{- if hasKey $limiter "description" }}
      description: {{ $limiter.description | quote }}
      {{- end }}
      {{- if hasKey $limiter "log_only" }}
      log_only: {{ $limiter.log_only }}
      {{- end }}
      {{- if hasKey $limiter "precedence" }}
      precedence: {{ $limiter.precedence }}
      {{- end }}
      
      {{- if hasKey $limiter "match" }}
      match:
        {{- if hasKey $limiter.match "type" }}
        type: {{ $limiter.match.type }}
        {{- end }}
      {{- end }}
      
      {{- if hasKey $limiter "limit" }}
      limit:
        {{- if hasKey $limiter.limit "rate" }}
        rate: {{ $limiter.limit.rate }}
        {{- end }}
        {{- if hasKey $limiter.limit "period" }}
        period: {{ $limiter.limit.period | quote }}
        {{- end }}
        {{- if hasKey $limiter.limit "burst" }}
        burst: {{ $limiter.limit.burst }}
        {{- end }}
      {{- end }}
      
      {{- if hasKey $limiter "action" }}
      action:
        {{- if hasKey $limiter.action "warn_threshold" }}
        warn_threshold: {{ $limiter.action.warn_threshold }}
        {{- end }}
        {{- if hasKey $limiter.action "warn_action" }}
        warn_action: {{ $limiter.action.warn_action | quote }}
        {{- end }}
        {{- if hasKey $limiter.action "hard_action" }}
        hard_action: {{ $limiter.action.hard_action | quote }}
        {{- end }}
      {{- end }}
    {{- end }}
  {{- end }}
{{- end -}}