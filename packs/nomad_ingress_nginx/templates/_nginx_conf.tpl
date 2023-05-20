[[- define "ingress_conf" -]]
{{- $serverMap := dict -}}
{{- range services -}}
{{- with service .Name -}}
{{- with index . 0}}
  {{- $enabled := false -}}
  {{- $hostname := "" -}}
  {{- $path := slice -}}
  {{- $port := [[.nomad_ingress_nginx.http_port]] -}}
  {{- $allow := "" -}}
  {{- $deny := "" -}}
  {{- if (index .ServiceMeta "nomad_ingress_enabled") -}}
    {{$enabled = true}}
    {{- if (index .ServiceMeta "nomad_ingress_hostname") -}}
      {{- $hostname = (index .ServiceMeta "nomad_ingress_hostname") -}}
    {{- end -}}
    {{- if (index .ServiceMeta "nomad_ingress_path") -}}
      {{- $path = split (index .ServiceMeta "nomad_ingress_path") "," -}}
    {{- end -}}
    {{- if (index .ServiceMeta "nomad_ingress_port") -}}
      {{- $port = (index .ServiceMeta "nomad_ingress_port") -}}
    {{- end -}}
    {{- if (index .ServiceMeta "nomad_ingress_allow") -}}
      {{- $allow = (index .ServiceMeta "nomad_ingress_allow") -}}
    {{- end -}}
    {{- if (index .ServiceMeta "nomad_ingress_deny") -}}
      {{- $deny = (index .ServiceMeta "nomad_ingress_deny") -}}
    {{- end -}}
  {{- else if .Tags | contains "nomad_ingress_enabled=true" -}}
    {{$enabled = true}}
    {{- range .Tags -}}
      {{- $kv := (. | split "=") -}}
      {{- if eq (index $kv 0) "nomad_ingress_hostname" -}}
        {{- $hostname = (index $kv  1) -}}
      {{- end -}}
      {{- if eq (index $kv 0) "nomad_ingress_path" -}}
        {{- $path = split (index $kv  1) "," -}}
      {{- end -}}
      {{- if eq (index $kv 0) "nomad_ingress_port" -}}
        {{- $port = (index $kv  1) -}}
      {{- end -}}
      {{- if eq (index $kv 0) "nomad_ingress_allow" -}}
        {{- $allow = (index $kv  1) -}}
      {{- end -}}
      {{- if eq (index $kv 0) "nomad_ingress_deny" -}}
        {{- $deny = (index $kv  1) -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
  {{- if $enabled -}}
    {{- $upstream := .Name | toLower -}}
    {{- if not (index $serverMap $upstream) -}}
      {{- $serverMap[$upstream] = dict "hostname" $hostname "port" $port "allow" $allow "deny" $deny "path" $path -}}
    {{- else -}}
      {{- $serverMap[$upstream].path = append $serverMap[$upstream].path $path -}}
    {{- end -}}
  {{- end -}}
{{end}}
{{- end -}}
{{end}}

{{- range $server, $serverConfig := $serverMap }}
# Configuration for service {{$server}}.
upstream {{$server}} {
  {{- range service $server }}
  server {{.Address}}:{{.Port}};
  {{- end}}
}

server {
  listen {{$serverConfig.port}};
  {{- if $serverConfig.hostname}}
  server_name {{$serverConfig.hostname}};
  {{- end}}

  {{- range ($serverConfig.allow | split ",")}}
  allow {{.}};
  {{- end}}
  {{- if ne $serverConfig.allow ""}}
  deny all;
  {{- end}}

  {{- range ($serverConfig.deny | split ",")}}
  deny {{.}};
  {{- end}}
  {{- if ne $serverConfig.deny ""}}
  allow all;
  {{- end}}

  proxy_set_header Upgrade $http_upgrade;
  proxy_set_header X-Real-IP $remote_addr;
  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  proxy_set_header X-Forwarded-Host $host;
  proxy_set_header X-Forwarded-Port $server_port;

  {{- range $path := $serverConfig.path }}
  location {{$path}} {
     proxy_pass http://{{$server}};
  }
  {{- end }}
}
{{- end -}}
[[- end -]]
